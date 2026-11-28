from typing import List, Tuple
import cv2
import numpy as np


_HOG = cv2.HOGDescriptor((64, 64), (16, 16), (8, 8), (8, 8), 9)


def propose_nematode_regions(bgr: np.ndarray, max_proposals: int = 12) -> List[Tuple[float, float, float, float, float]]:
    """
    Illumination-invariant brightfield microscope region proposer.
    Cancels circular eyepiece vignetting and fuses transverse cuticular rings
    so both slender (Pratylenchus) and stout ringed (Criconema / Criconemoides)
    nematodes produce clean candidate boxes (left, top, right, bottom, heuristic_score).
    """
    h, w = bgr.shape[:2]
    scale = 640.0 / max(h, w)
    if scale < 1.0:
        work = cv2.resize(bgr, (max(32, int(w * scale)), max(32, int(h * scale))))
    else:
        work = bgr
    wh, ww = work.shape[:2]

    gray = cv2.cvtColor(work, cv2.COLOR_BGR2GRAY).astype(np.float32)
    # Estimate smooth illumination field (removes dark eyepiece corners & uneven condenser light)
    ksize = max(31, (min(wh, ww) // 7) | 1)
    illum = cv2.GaussianBlur(gray, (ksize, ksize), 0)
    diff = np.clip(illum - gray, 0.0, 255.0)
    if float(diff.max()) > 1.0:
        norm_diff = (diff / (float(np.percentile(diff, 99.5)) + 1e-5) * 255.0).clip(0, 255).astype(np.uint8)
    else:
        norm_diff = diff.astype(np.uint8)

    # Combine local contrast + internal cuticular edge energy
    gx = cv2.Sobel(gray, cv2.CV_32F, 1, 0, ksize=3)
    gy = cv2.Sobel(gray, cv2.CV_32F, 0, 1, ksize=3)
    grad = cv2.magnitude(gx, gy)
    grad_u8 = np.clip(grad / (float(np.percentile(grad, 99.2)) + 1e-5) * 255.0, 0, 255).astype(np.uint8)

    fused = cv2.addWeighted(norm_diff, 0.65, grad_u8, 0.35, 0)
    blurred = cv2.GaussianBlur(fused, (5, 5), 0)
    _, binary = cv2.threshold(blurred, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)

    # Close gaps across coarse annules / hyaline segments
    k_close = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (11, 11))
    k_open = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (5, 5))
    mask = cv2.morphologyEx(binary, cv2.MORPH_CLOSE, k_close, iterations=2)
    mask = cv2.morphologyEx(mask, cv2.MORPH_OPEN, k_open, iterations=1)

    contours, _ = cv2.findContours(mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    img_area = float(wh * ww)
    proposals: List[Tuple[float, float, float, float, float]] = []

    for c in contours:
        area = float(cv2.contourArea(c))
        if area < img_area * 0.0008 or area > img_area * 0.70:
            continue
        x, y, bw, bh = cv2.boundingRect(c)
        # Reject pure corner vignette artifacts hugging 2 outer borders simultaneously
        touches_x = x <= 2 or (x + bw) >= (ww - 2)
        touches_y = y <= 2 or (y + bh) >= (wh - 2)
        if touches_x and touches_y and (bw * bh) < img_area * 0.12:
            continue

        rect_min = cv2.minAreaRect(c)
        rw, rh = rect_min[1]
        short_side = max(min(rw, rh), 1.0)
        long_side = max(rw, rh)
        elongation = long_side / short_side
        if elongation < 1.35:
            continue

        pad_x = int(bw * 0.05) + 3
        pad_y = int(bh * 0.05) + 3
        l = max(0.0, (x - pad_x) / ww)
        t = max(0.0, (y - pad_y) / wh)
        r = min(1.0, (x + bw + pad_x) / ww)
        b = min(1.0, (y + bh + pad_y) / wh)

        roi_diff = float(np.mean(norm_diff[y : y + bh, x : x + bw])) / 255.0
        score = min(0.96, 0.45 + min(elongation / 14.0, 0.28) + min(roi_diff * 0.45, 0.23))
        proposals.append((area * elongation * (0.4 + roi_diff), l, t, r, b, score))

    proposals.sort(key=lambda item: item[0], reverse=True)
    return [(l, t, r, b, sc) for _, l, t, r, b, sc in proposals[:max_proposals]]


def extract_morphological_features(crop_bgr: np.ndarray, rect_aspect: float = 1.0) -> np.ndarray:
    """
    Extracts a fixed-length float32 morphological & cuticular texture descriptor (1856 dims):
    1. HOG (1764 dims): silhouette, head/tail taper, stylet/median-bulb internal structure.
    2. Cuticular Ring & Frequency Spectrum (48 dims): 1D axial/transverse FFT bands + Sobel orientation/magnitude histograms (distinguishes spiny/fringed Criconema vs smooth-ringed Criconemoides vs slender Pratylenchidae).
    3. Multi-zone Intensity, Contrast & Shape Moments (44 dims): Hu moments, elongation, Otsu body occupancy, and 4x4 spatial contrast grid.
    """
    if crop_bgr is None or crop_bgr.size == 0:
        return np.zeros(FEATURE_DIM, dtype=np.float32)

    ch, cw = crop_bgr.shape[:2]
    raw_ratio = float(max(cw, ch)) / float(max(min(cw, ch), 1))

    # Canonical orientation: align dominant axis vertically so horizontal/diagonal worms share feature space
    if cw > ch:
        oriented = cv2.rotate(crop_bgr, cv2.ROTATE_90_CLOCKWISE)
    else:
        oriented = crop_bgr

    gray = cv2.cvtColor(oriented, cv2.COLOR_BGR2GRAY)
    clahe = cv2.createCLAHE(clipLimit=2.2, tileGridSize=(4, 4)).apply(gray)

    # 1. HOG on 64x64 normalized patch (1764 dims)
    hog_patch = cv2.resize(clahe, (64, 64), interpolation=cv2.INTER_AREA)
    hog_vec = _HOG.compute(hog_patch).reshape(-1).astype(np.float32)

    # 2. Cuticular annulation & ring-edge frequency spectrum on 128x64 patch (48 dims)
    tex_patch = cv2.resize(clahe, (64, 128), interpolation=cv2.INTER_AREA).astype(np.float32) / 255.0
    # Axial profile (along worm body length -> detects transverse ring periodicity!)
    axial_profile = np.mean(tex_patch[:, 16:48], axis=1) - np.mean(tex_patch[:, 16:48])
    fft_mag = np.abs(np.fft.rfft(axial_profile))[1:17]  # 16 frequency bins
    fft_mag = fft_mag / (np.linalg.norm(fft_mag) + 1e-6)

    gx = cv2.Sobel(tex_patch, cv2.CV_32F, 1, 0, ksize=3)
    gy = cv2.Sobel(tex_patch, cv2.CV_32F, 0, 1, ksize=3)
    mag, ang = cv2.cartToPolar(gx, gy, angleInDegrees=True)
    ang_hist, _ = np.histogram(ang, bins=16, range=(0.0, 360.0), weights=mag)
    ang_hist = (ang_hist / (np.sum(ang_hist) + 1e-6)).astype(np.float32)

    lap = np.abs(cv2.Laplacian(tex_patch, cv2.CV_32F, ksize=3))
    lap_hist, _ = np.histogram(lap, bins=16, range=(0.0, 1.5))
    lap_hist = (lap_hist / (np.sum(lap_hist) + 1e-6)).astype(np.float32)

    # 3. Shape moments + 4x4 contrast grid (44 dims)
    inv_u8 = 255 - cv2.resize(clahe, (96, 96), interpolation=cv2.INTER_AREA)
    _, mask = cv2.threshold(inv_u8, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
    occupancy = float(np.count_nonzero(mask)) / float(mask.size)
    moments = cv2.moments(mask)
    hu = cv2.HuMoments(moments).reshape(-1)
    hu_log = (-np.sign(hu) * np.log10(np.abs(hu) + 1e-12)).astype(np.float32)  # 7 dims

    # Width profile across 5 longitudinal slices (head, stylet/neck, mid, vulva/post, tail)
    slice_widths = []
    for s_idx in range(5):
        r0 = int(s_idx * 96 / 5)
        r1 = int((s_idx + 1) * 96 / 5)
        row_occ = np.mean(mask[r0:r1, :] > 0, axis=1)
        slice_widths.append(float(np.percentile(row_occ, 75)))

    grid_std = []
    grid_mean = []
    for gy_i in range(4):
        for gx_i in range(4):
            cell = tex_patch[gy_i * 32 : (gy_i + 1) * 32, gx_i * 16 : (gx_i + 1) * 16]
            grid_mean.append(float(np.mean(cell)))
            grid_std.append(float(np.std(cell)))

    geom = np.array(
        [
            min(raw_ratio / 10.0, 2.0),
            min(float(rect_aspect) / 10.0, 2.0),
            occupancy,
            float(np.std(tex_patch)),
            *slice_widths,
            *hu_log.tolist(),
            *grid_mean,
            *grid_std,
        ],
        dtype=np.float32,
    )  # 4 + 5 + 7 + 16 + 16 = 48? Wait: 4+5+7+16+16 = 48 -> 1764 + 48 + 48 = 1860 dims!

    vec = np.concatenate([hog_vec, fft_mag.astype(np.float32), ang_hist, lap_hist, geom]).astype(np.float32)
    return np.nan_to_num(vec, nan=0.0, posinf=2.0, neginf=-2.0)


FEATURE_DIM = 1860
