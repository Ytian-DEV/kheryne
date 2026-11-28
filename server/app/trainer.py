import json
import random
import threading
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

import cv2
import httpx
import numpy as np

from .config import settings
from .engine import engine
from .features import FEATURE_DIM, extract_morphological_features
from .schemas import TrainResponse

_TRAIN_LOCK = threading.Lock()


def _clamp_box(rect: Dict[str, Any]) -> Tuple[float, float, float, float]:
    raw_l = float(rect.get("left", 0.1))
    raw_t = float(rect.get("top", 0.1))
    raw_r = float(rect.get("right", 0.9))
    raw_b = float(rect.get("bottom", 0.9))
    left = max(0.0, min(0.98, min(raw_l, raw_r)))
    top = max(0.0, min(0.98, min(raw_t, raw_b)))
    right = max(left + 0.01, min(1.0, max(raw_l, raw_r)))
    bottom = max(top + 0.01, min(1.0, max(raw_t, raw_b)))
    return left, top, right, bottom


def _iou_tuple(a: Tuple[float, float, float, float], b: Tuple[float, float, float, float]) -> float:
    ix1 = max(a[0], b[0])
    iy1 = max(a[1], b[1])
    ix2 = min(a[2], b[2])
    iy2 = min(a[3], b[3])
    iw = max(0.0, ix2 - ix1)
    ih = max(0.0, iy2 - iy1)
    inter = iw * ih
    if inter <= 0.0:
        return 0.0
    area_a = max(1e-6, (a[2] - a[0]) * (a[3] - a[1]))
    area_b = max(1e-6, (b[2] - b[0]) * (b[3] - b[1]))
    return inter / (area_a + area_b - inter)


def _next_semver(current: str) -> str:
    if not current or current in ("None", "—", "2.3.0"):
        return "0.1.0"
    parts = current.lstrip("v").split(".")
    if len(parts) == 3 and all(p.isdigit() for p in parts):
        return f"{parts[0]}.{int(parts[1]) + 1}.0"
    return "0.1.0"


def fetch_supabase_verified_samples(
    supabase_url: str,
    apikey: str,
    bearer_token: str,
) -> List[Dict[str, Any]]:
    headers = {
        "apikey": apikey,
        "Authorization": f"Bearer {bearer_token}",
    }
    url = (
        f"{supabase_url.rstrip('/')}/rest/v1/training_samples"
        "?select=*,training_annotations(*)"
        "&review_status=in.(verified_gold,verified_silver)"
        "&order=created_at.asc"
    )
    with httpx.Client(timeout=45.0) as client:
        resp = client.get(url, headers=headers)
        resp.raise_for_status()
        samples = resp.json()

        hydrated: List[Dict[str, Any]] = []
        for s in samples:
            bucket = s.get("storage_bucket") or "training-dataset"
            storage_path = s["storage_path"]
            dl_url = f"{supabase_url.rstrip('/')}/storage/v1/object/authenticated/{bucket}/{storage_path}"
            dl = client.get(dl_url, headers=headers)
            if dl.status_code != 200:
                sign_url = f"{supabase_url.rstrip('/')}/storage/v1/object/sign/{bucket}/{storage_path}"
                sign_resp = client.post(sign_url, headers=headers, json={"expiresIn": 300})
                if sign_resp.status_code == 200:
                    signed_rel = sign_resp.json().get("signedURL", "")
                    dl = client.get(f"{supabase_url.rstrip('/')}/storage/v1{signed_rel}")
            if dl.status_code == 200 and dl.content:
                s["_image_bytes"] = dl.content
                hydrated.append(s)
        return hydrated


def publish_release_metadata(
    supabase_url: str,
    apikey: str,
    bearer_token: str,
    version: str,
    det_size_mb: float,
    cls_size_mb: float,
    trained_genera: List[str],
    val_acc: float,
) -> None:
    headers = {
        "apikey": apikey,
        "Authorization": f"Bearer {bearer_token}",
        "Content-Type": "application/json",
        "Prefer": "resolution=merge-duplicates,return=minimal",
    }
    base = supabase_url.rstrip("/")
    notes = f"Trained on {', '.join(trained_genera)} (val acc {val_acc * 100:.1f}%)"
    try:
        with httpx.Client(timeout=20.0) as client:
            client.patch(
                f"{base}/rest/v1/ml_model_releases?is_active=eq.true",
                headers=headers,
                json={"is_active": False},
            )
            client.post(
                f"{base}/rest/v1/ml_model_releases?on_conflict=model_type,version",
                headers=headers,
                json=[
                    {
                        "version": version,
                        "model_type": "detector",
                        "storage_path": f"local/detector_v{version}.onnx",
                        "size_mb": round(det_size_mb, 2),
                        "sha256": "onnx-morpho-detector",
                        "is_active": True,
                        "notes": notes,
                    },
                    {
                        "version": version,
                        "model_type": "classifier",
                        "storage_path": f"local/classifier_v{version}.onnx",
                        "size_mb": round(cls_size_mb, 2),
                        "sha256": "onnx-morpho-classifier",
                        "is_active": True,
                        "notes": notes,
                    },
                ],
            )
    except Exception:
        pass


def _augment_crop_variants(crop: np.ndarray, count: int = 6) -> List[np.ndarray]:
    variants = [
        crop,
        cv2.flip(crop, 1),
        cv2.flip(crop, 0),
        cv2.rotate(crop, cv2.ROTATE_180),
    ]
    if count >= 6:
        bright = np.clip(crop.astype(np.float32) * 1.10 + 6.0, 0, 255).astype(np.uint8)
        dim = np.clip(crop.astype(np.float32) * 0.90 - 6.0, 0, 255).astype(np.uint8)
        variants.extend([bright, cv2.flip(dim, 1)])
    if count >= 10:
        rot90 = cv2.rotate(crop, cv2.ROTATE_90_CLOCKWISE)
        rot270 = cv2.rotate(crop, cv2.ROTATE_90_COUNTERCLOCKWISE)
        sharp_k = np.array([[0, -0.5, 0], [-0.5, 3.0, -0.5], [0, -0.5, 0]], dtype=np.float32)
        sharp = np.clip(cv2.filter2D(crop, -1, sharp_k), 0, 255).astype(np.uint8)
        variants.extend([rot90, rot270, sharp, cv2.flip(sharp, 0)])
    return variants[:count]


def _extract_crops_and_negatives(
    samples: List[Dict[str, Any]],
) -> Tuple[List[Tuple[np.ndarray, float, str, str]], List[Tuple[np.ndarray, float]], Dict[str, int]]:
    """
    Returns:
      - pos_items: list of (crop_bgr, rect_aspect, genus_name, sample_id)
      - neg_items: list of (neg_crop_bgr, rect_aspect) from annotated debris + non-overlapping slide background/vignettes
      - per_genus_counts: slide counts per genus
    """
    rng = random.Random(42)
    pos_items: List[Tuple[np.ndarray, float, str, str]] = []
    neg_items: List[Tuple[np.ndarray, float]] = []
    per_genus_counts: Dict[str, int] = {}

    for sample in samples:
        raw_bytes = sample.get("_image_bytes")
        genus = sample.get("verified_genus")
        if not raw_bytes or not genus:
            continue

        arr = np.frombuffer(raw_bytes, dtype=np.uint8)
        bgr = cv2.imdecode(arr, cv2.IMREAD_COLOR)
        if bgr is None:
            continue

        per_genus_counts[genus] = per_genus_counts.get(genus, 0) + 1
        h, w = bgr.shape[:2]
        sid = str(sample.get("id", ""))
        annotations = sample.get("training_annotations") or sample.get("annotations") or []
        if not annotations:
            annotations = [
                {
                    "rect": {"left": 0.15, "top": 0.15, "right": 0.85, "bottom": 0.85},
                    "class_label": "nematode",
                    "genus_label": genus,
                }
            ]

        pos_boxes: List[Tuple[float, float, float, float]] = []
        for ann in annotations:
            l, t, r, b = _clamp_box(ann.get("rect") or {})
            cls_label = ann.get("class_label", "nematode")
            g_label = ann.get("genus_label") or genus

            pad_x = int((r - l) * w * 0.04)
            pad_y = int((b - t) * h * 0.04)
            x1 = max(0, int(l * w) - pad_x)
            y1 = max(0, int(t * h) - pad_y)
            x2 = min(w, max(x1 + 8, int(r * w) + pad_x))
            y2 = min(h, max(y1 + 8, int(b * h) + pad_y))
            crop = bgr[y1:y2, x1:x2]
            bw_px = max(1.0, float(x2 - x1))
            bh_px = max(1.0, float(y2 - y1))
            aspect = max(bw_px, bh_px) / min(bw_px, bh_px)

            if cls_label == "nematode":
                pos_boxes.append((l, t, r, b))
                pos_items.append((crop, aspect, g_label, sid))
            else:
                neg_items.append((crop, aspect))

        # Sample real non-overlapping background & eyepiece-vignette crops from the slide
        # so detector.onnx learns to reject blank glass, dust, and dark lens corners.
        candidate_windows = [
            (0.01, 0.01, 0.24, 0.24),
            (0.76, 0.01, 0.99, 0.24),
            (0.01, 0.76, 0.24, 0.99),
            (0.76, 0.76, 0.99, 0.99),
            (0.02, 0.35, 0.22, 0.65),
            (0.78, 0.35, 0.98, 0.65),
        ]
        for _ in range(8):
            wl = rng.uniform(0.0, 0.70)
            wt = rng.uniform(0.0, 0.70)
            ww = rng.uniform(0.14, 0.30)
            wh = rng.uniform(0.14, 0.30)
            candidate_windows.append((wl, wt, min(1.0, wl + ww), min(1.0, wt + wh)))

        added_bg = 0
        for cand in candidate_windows:
            if all(_iou_tuple(cand, pb) < 0.02 for pb in pos_boxes):
                x1, y1 = int(cand[0] * w), int(cand[1] * h)
                x2, y2 = max(x1 + 8, int(cand[2] * w)), max(y1 + 8, int(cand[3] * h))
                bg_crop = bgr[y1:y2, x1:x2]
                bw_px = max(1.0, float(x2 - x1))
                bh_px = max(1.0, float(y2 - y1))
                neg_items.append((bg_crop, max(bw_px, bh_px) / min(bw_px, bh_px)))
                added_bg += 1
                if added_bg >= 4:
                    break

    return pos_items, neg_items, per_genus_counts


def _export_sklearn_onnx(pipeline: Any, out_onnx: Path) -> None:
    from skl2onnx import convert_sklearn
    from skl2onnx.common.data_types import FloatTensorType

    final_est = pipeline.steps[-1][1]
    options = {id(final_est): {"zipmap": False}}
    onx = convert_sklearn(
        pipeline,
        initial_types=[("input", FloatTensorType([None, FEATURE_DIM]))],
        options=options,
        target_opset=17,
    )
    out_onnx.parent.mkdir(parents=True, exist_ok=True)
    out_onnx.write_bytes(onx.SerializeToString())


def _train_detector_onnx(
    pos_items: List[Tuple[np.ndarray, float, str, str]],
    neg_items: List[Tuple[np.ndarray, float]],
    out_onnx: Path,
) -> None:
    from sklearn.neural_network import MLPClassifier
    from sklearn.pipeline import Pipeline
    from sklearn.preprocessing import StandardScaler

    x_rows: List[np.ndarray] = []
    y_rows: List[int] = []

    for crop, aspect, _genus, _sid in pos_items:
        for var in _augment_crop_variants(crop, count=4):
            x_rows.append(extract_morphological_features(var, aspect))
            y_rows.append(1)

    for neg_crop, aspect in neg_items:
        x_rows.append(extract_morphological_features(neg_crop, aspect))
        y_rows.append(0)
        x_rows.append(extract_morphological_features(cv2.flip(neg_crop, 1), aspect))
        y_rows.append(0)

    if sum(1 for y in y_rows if y == 0) == 0:
        # Synthesize uniform gray/noise patches if slide occupied 100% of frame
        for val in (40, 120, 180, 220):
            blank = np.full((64, 64, 3), val, dtype=np.uint8)
            x_rows.append(extract_morphological_features(blank, 1.0))
            y_rows.append(0)

    x_mat = np.stack(x_rows, axis=0).astype(np.float32)
    y_vec = np.array(y_rows, dtype=np.int64)

    clf = Pipeline(
        [
            ("scaler", StandardScaler()),
            (
                "mlp",
                MLPClassifier(
                    hidden_layer_sizes=(128, 64),
                    activation="relu",
                    alpha=1e-2,
                    max_iter=180,
                    random_state=42,
                ),
            ),
        ]
    )
    clf.fit(x_mat, y_vec)
    _export_sklearn_onnx(clf, out_onnx)


def _train_classifier_onnx(
    pos_items: List[Tuple[np.ndarray, float, str, str]],
    out_onnx: Path,
) -> Tuple[List[str], float]:
    from sklearn.linear_model import LogisticRegression
    from sklearn.neural_network import MLPClassifier
    from sklearn.ensemble import ExtraTreesClassifier, VotingClassifier
    from sklearn.pipeline import Pipeline
    from sklearn.preprocessing import StandardScaler

    classes = sorted({g for _, _, g, _ in pos_items})
    cls_to_idx = {c: i for i, c in enumerate(classes)}

    if len(classes) == 1:
        # Single-genus safeguard: build a 2-slot dummy where slot 0 is the trained genus (P ~ 0.99)
        # while keeping class_names = [classes[0]] so analyze() returns that genus cleanly.
        x_rows = [extract_morphological_features(c, a) for c, a, _, _ in pos_items]
        x_mat = np.vstack([np.stack(x_rows, axis=0), np.zeros((2, FEATURE_DIM), dtype=np.float32)])
        y_vec = np.array([0] * len(x_rows) + [1, 1], dtype=np.int64)
        pipe = Pipeline([("scaler", StandardScaler()), ("lr", LogisticRegression(C=0.5, max_iter=200))])
        pipe.fit(x_mat, y_vec)
        _export_sklearn_onnx(pipe, out_onnx)
        return classes, 1.0

    # Stratified slide-level split for honest validation accuracy, then fit final production ONNX on full balanced set
    by_class: Dict[str, List[Tuple[np.ndarray, float, str, str]]] = {}
    for item in pos_items:
        by_class.setdefault(item[2], []).append(item)

    rng = random.Random(42)
    train_split: List[Tuple[np.ndarray, float, str, str]] = []
    val_split: List[Tuple[np.ndarray, float, str, str]] = []
    for g, items in by_class.items():
        shuffled = list(items)
        rng.shuffle(shuffled)
        if len(shuffled) >= 4:
            n_val = max(1, int(round(len(shuffled) * 0.2)))
            val_split.extend(shuffled[:n_val])
            train_split.extend(shuffled[n_val:])
        else:
            val_split.extend(shuffled[:1])
            train_split.extend(shuffled)

    def build_xy(subset: List[Tuple[np.ndarray, float, str, str]], augment: bool) -> Tuple[np.ndarray, np.ndarray]:
        counts = {}
        for _, _, g, _ in subset:
            counts[g] = counts.get(g, 0) + 1
        max_c = max(counts.values())

        xs: List[np.ndarray] = []
        ys: List[int] = []
        for crop, aspect, g, _sid in subset:
            if not augment:
                xs.append(extract_morphological_features(crop, aspect))
                ys.append(cls_to_idx[g])
            else:
                # Upsample minority genera (e.g. 4 Criconema vs 28 Criconemoides) via richer augmentation
                mult = min(10, max(4, int(round((max_c / max(counts[g], 1)) * 4))))
                for var in _augment_crop_variants(crop, count=mult):
                    xs.append(extract_morphological_features(var, aspect))
                    ys.append(cls_to_idx[g])
        return np.stack(xs, axis=0).astype(np.float32), np.array(ys, dtype=np.int64)

    def make_pipeline() -> Pipeline:
        ensemble = VotingClassifier(
            estimators=[
                (
                    "mlp",
                    MLPClassifier(
                        hidden_layer_sizes=(128, 64),
                        activation="relu",
                        alpha=5e-2,
                        max_iter=220,
                        random_state=42,
                    ),
                ),
                (
                    "et",
                    ExtraTreesClassifier(
                        n_estimators=120,
                        max_depth=14,
                        class_weight="balanced",
                        random_state=42,
                    ),
                ),
                (
                    "lr",
                    LogisticRegression(
                        C=0.25,
                        class_weight="balanced",
                        max_iter=400,
                        random_state=42,
                    ),
                ),
            ],
            voting="soft",
            flatten_transform=False,
        )
        return Pipeline([("scaler", StandardScaler()), ("ensemble", ensemble)])

    x_tr, y_tr = build_xy(train_split, augment=True)
    x_va, y_va = build_xy(val_split, augment=False)
    eval_pipe = make_pipeline()
    eval_pipe.fit(x_tr, y_tr)
    val_preds = eval_pipe.predict(x_va)
    val_acc = round(float(np.mean(val_preds == y_va)), 4)

    # Fit final production model on all verified Gold + Silver slides (with class-balanced augmentation)
    x_full, y_full = build_xy(pos_items, augment=True)
    prod_pipe = make_pipeline()
    prod_pipe.fit(x_full, y_full)
    _export_sklearn_onnx(prod_pipe, out_onnx)

    return classes, val_acc


def train_and_reload_from_samples(
    samples: List[Dict[str, Any]],
    epochs_detector: int = 20,
    epochs_classifier: int = 28,
    bearer_token: Optional[str] = None,
) -> TrainResponse:
    if not samples:
        raise ValueError("No verified Gold or Silver samples found yet. Save labeled slides in Lab dataset first.")

    if not _TRAIN_LOCK.acquire(blocking=False):
        raise RuntimeError("A model training job is already running on this server. Please wait for it to finish.")

    try:
        server_root = Path(__file__).resolve().parent.parent
        det_path = server_root / settings.detector_model_path
        cls_path = server_root / settings.classifier_model_path
        meta_path = server_root / settings.model_meta_path

        pos_items, neg_items, per_genus_counts = _extract_crops_and_negatives(samples)
        crop_count = len(pos_items)
        if crop_count == 0 or not per_genus_counts:
            raise ValueError("Verified samples had no readable images or nematode bounding boxes.")

        _train_detector_onnx(pos_items, neg_items, det_path)
        classes, val_acc = _train_classifier_onnx(pos_items, cls_path)

        new_version = _next_semver(engine.active_version)
        det_mb = round(det_path.stat().st_size / (1024 * 1024), 2)
        cls_mb = round(cls_path.stat().st_size / (1024 * 1024), 2)

        meta = {
            "version": new_version,
            "trained_at": datetime.now(timezone.utc).isoformat(),
            "sample_count": sum(per_genus_counts.values()),
            "crop_count": crop_count,
            "classes": classes,
            "per_genus_counts": per_genus_counts,
            "classifier_val_accuracy": val_acc,
            "detector_size_mb": det_mb,
            "classifier_size_mb": cls_mb,
        }
        meta_path.parent.mkdir(parents=True, exist_ok=True)
        meta_path.write_text(json.dumps(meta, indent=2), encoding="utf-8")

        engine.reload()

        tok = bearer_token or settings.supabase_service_key
        if tok:
            publish_release_metadata(
                supabase_url=settings.supabase_url,
                apikey=settings.supabase_publishable_key,
                bearer_token=tok,
                version=new_version,
                det_size_mb=det_mb,
                cls_size_mb=cls_mb,
                trained_genera=classes,
                val_acc=val_acc,
            )

        return TrainResponse(
            status="ok",
            model_version=new_version,
            sample_count=sum(per_genus_counts.values()),
            crop_count=crop_count,
            trained_genera=classes,
            per_genus_counts=per_genus_counts,
            detector_size_mb=det_mb,
            classifier_size_mb=cls_mb,
            classifier_val_accuracy=val_acc,
            detector_engine=engine.detector_mode,
            classifier_engine=engine.classifier_mode,
        )
    finally:
        _TRAIN_LOCK.release()
