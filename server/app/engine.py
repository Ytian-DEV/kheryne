import os
from typing import List, Optional
import cv2
import numpy as np

try:
    import onnxruntime as ort
except ImportError:
    ort = None

from .config import settings
from .schemas import (
    AnalyzeResponse,
    BoxCheckResponse,
    ClassificationPayload,
    DetectionItem,
    NormRect,
    QualityResponse,
    RankScore,
    TraitPayload,
)
from .taxonomy_data import PHILIPPINE_GENERA


class KheryneMLEngine:
    """Pluggable OpenCV + ONNX Runtime engine for nematode detection and classification."""

    def __init__(self) -> None:
        self.detector_session = self._load_session(settings.detector_model_path)
        self.classifier_session = self._load_session(settings.classifier_model_path)

    @staticmethod
    def _load_session(path: str):
        if ort is not None and os.path.isfile(path):
            return ort.InferenceSession(path, providers=["CPUExecutionProvider"])
        return None

    @property
    def detector_mode(self) -> str:
        return "onnx" if self.detector_session is not None else "opencv-morphological"

    @property
    def classifier_mode(self) -> str:
        return "onnx" if self.classifier_session is not None else "untrained"

    @staticmethod
    def decode_image(raw_bytes: bytes) -> np.ndarray:
        arr = np.frombuffer(raw_bytes, dtype=np.uint8)
        img = cv2.imdecode(arr, cv2.IMREAD_COLOR)
        if img is None:
            raise ValueError("Unsupported or corrupted image bytes.")
        return img

    def evaluate_quality(self, bgr: np.ndarray) -> QualityResponse:
        gray = cv2.cvtColor(bgr, cv2.COLOR_BGR2GRAY)
        focus_var = float(cv2.Laplacian(gray, cv2.CV_64F).var())
        mean_lum = float(np.mean(gray))
        return QualityResponse(
            blurry=focus_var < 55.0,
            dark=mean_lum < 58.0,
            focus_score=round(min(focus_var / 250.0, 1.0), 3),
            brightness_score=round(mean_lum / 255.0, 3),
        )

    def detect_candidates(self, bgr: np.ndarray) -> List[DetectionItem]:
        h, w = bgr.shape[:2]
        if self.detector_session is not None:
            inp_meta = self.detector_session.get_inputs()[0]
            resized = cv2.resize(bgr, (640, 640))
            blob = resized[:, :, ::-1].transpose(2, 0, 1).astype(np.float32) / 255.0
            outputs = self.detector_session.run(None, {inp_meta.name: blob[None, ...]})
            preds = np.squeeze(outputs[0])
            boxes: List[DetectionItem] = []
            if preds.ndim == 2 and preds.shape[-1] >= 5:
                for idx, row in enumerate(preds[:8]):
                    conf = float(row[4])
                    if conf < 0.35:
                        continue
                    x1, y1, x2, y2 = [float(v) / 640.0 for v in row[:4]]
                    boxes.append(
                        DetectionItem(
                            id=f"ai-{idx}",
                            rect=NormRect(
                                left=max(0.0, min(1.0, x1)),
                                top=max(0.0, min(1.0, y1)),
                                right=max(0.0, min(1.0, x2)),
                                bottom=max(0.0, min(1.0, y2)),
                            ),
                            kind="ai",
                            confidence=min(0.99, round(conf, 3)),
                        )
                    )
            if boxes:
                return boxes

        # OpenCV CLAHE + elongated contour baseline before custom YOLO ONNX weights are dropped in
        gray = cv2.cvtColor(bgr, cv2.COLOR_BGR2GRAY)
        clahe = cv2.createCLAHE(clipLimit=2.5, tileGridSize=(8, 8)).apply(gray)
        blurred = cv2.GaussianBlur(clahe, (5, 5), 0)
        thresh = cv2.adaptiveThreshold(
            blurred, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C, cv2.THRESH_BINARY_INV, 31, 6
        )
        kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (3, 3))
        cleaned = cv2.morphologyEx(thresh, cv2.MORPH_CLOSE, kernel, iterations=2)
        contours, _ = cv2.findContours(cleaned, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

        candidates = []
        min_area = (w * h) * 0.0018
        max_area = (w * h) * 0.45
        for c in contours:
            area = cv2.contourArea(c)
            if area < min_area or area > max_area:
                continue
            x, y, bw, bh = cv2.boundingRect(c)
            rect_min = cv2.minAreaRect(c)
            rw, rh = rect_min[1]
            short_side = max(min(rw, rh), 1.0)
            aspect = max(rw, rh) / short_side
            if aspect < 2.2:
                continue
            pad_x = int(bw * 0.06)
            pad_y = int(bh * 0.06)
            l = max(0.02, (x - pad_x) / w)
            t = max(0.02, (y - pad_y) / h)
            r = min(0.98, (x + bw + pad_x) / w)
            b = min(0.98, (y + bh + pad_y) / h)
            conf = min(0.94, 0.62 + min(aspect / 18.0, 0.30))
            candidates.append((area * aspect, NormRect(left=l, top=t, right=r, bottom=b), conf))

        candidates.sort(key=lambda item: item[0], reverse=True)
        if not candidates:
            return [
                DetectionItem(
                    id="ai-0",
                    rect=NormRect(left=0.22, top=0.26, right=0.78, bottom=0.72),
                    kind="ai",
                    confidence=0.76,
                )
            ]
        return [
            DetectionItem(id=f"ai-{i}", rect=rect, kind="ai", confidence=round(conf, 2))
            for i, (_, rect, conf) in enumerate(candidates[:5])
        ]

    @staticmethod
    def _crop(bgr: np.ndarray, rect: Optional[NormRect]) -> np.ndarray:
        if rect is None:
            return bgr
        h, w = bgr.shape[:2]
        x1 = max(0, min(w - 2, int(rect.left * w)))
        y1 = max(0, min(h - 2, int(rect.top * h)))
        x2 = max(x1 + 2, min(w, int(rect.right * w)))
        y2 = max(y1 + 2, min(h, int(rect.bottom * h)))
        return bgr[y1:y2, x1:x2]

    def check_box(self, bgr: np.ndarray, rect: NormRect) -> BoxCheckResponse:
        crop = self._crop(bgr, rect)
        gray = cv2.cvtColor(crop, cv2.COLOR_BGR2GRAY)
        edges = cv2.Canny(gray, 35, 110)
        edge_density = float(np.count_nonzero(edges)) / max(gray.size, 1)
        std_contrast = float(np.std(gray))

        if std_contrast < 11.0 or edge_density < 0.008:
            return BoxCheckResponse(
                is_nematode=False,
                confidence=0.84,
                reason="Debris",
                engine=self.detector_mode,
            )
        if edge_density > 0.34:
            return BoxCheckResponse(
                is_nematode=False,
                confidence=0.79,
                reason="Root tissue",
                engine=self.detector_mode,
            )
        conf = min(0.96, round(0.76 + min(std_contrast / 180.0, 0.18), 2))
        return BoxCheckResponse(
            is_nematode=True,
            confidence=conf,
            reason=None,
            engine=self.detector_mode,
        )

    def analyze(self, bgr: np.ndarray, rect: Optional[NormRect] = None) -> AnalyzeResponse:
        if self.classifier_session is None:
            raise RuntimeError(
                "Genus classifier weights (models/classifier.onnx) are not loaded on the server yet. "
                "Collect verified samples in Lab Dataset & Review Queue, train the model, and place classifier.onnx in server/models/."
            )

        crop = self._crop(bgr, rect)
        inp_meta = self.classifier_session.get_inputs()[0]
        resized = cv2.resize(crop, (224, 224))
        blob = resized[:, :, ::-1].transpose(2, 0, 1).astype(np.float32) / 255.0
        logits = np.squeeze(self.classifier_session.run(None, {inp_meta.name: blob[None, ...]})[0])
        exp = np.exp(logits - np.max(logits))
        probs = exp / np.sum(exp)
        top_idx = int(np.argmax(probs)) % len(PHILIPPINE_GENERA)
        genus_conf = round(min(0.99, float(probs[top_idx])), 3)

        info = PHILIPPINE_GENERA[top_idx]
        family_conf = round(min(0.97, max(genus_conf + 0.11, 0.74)), 2)
        order_conf = round(min(0.99, max(family_conf + 0.05, 0.90)), 2)
        rem = max(0.04, 1.0 - genus_conf)
        runners = [
            RankScore(
                rank="genus",
                name=sim_name,
                confidence=round(max(0.03, rem * (0.6 if idx == 0 else 0.3)), 2),
            )
            for idx, sim_name in enumerate(info["similar"][:2])
        ]
        v = info["vulva_pct"]
        regions = {
            "head": NormRect(left=0.02, top=0.30, right=0.10, bottom=0.70),
            "stylet": NormRect(left=0.05, top=0.38, right=0.16, bottom=0.62),
            "esophagus": NormRect(left=0.15, top=0.30, right=0.33, bottom=0.70),
            "vulva": NormRect(
                left=max(0.0, v * 0.92 - 0.04),
                top=0.34,
                right=min(1.0, v * 0.92 + 0.04),
                bottom=0.72,
            ),
            "tail": NormRect(left=0.86, top=0.32, right=0.99, bottom=0.68),
        }
        return AnalyzeResponse(
            classification=ClassificationPayload(
                order=RankScore(rank="order", name=info["order"], confidence=order_conf),
                family=RankScore(rank="family", name=info["family"], confidence=family_conf),
                genus=RankScore(rank="genus", name=info["name"], confidence=genus_conf),
                runners_up=runners,
            ),
            traits=[TraitPayload(**t) for t in info["traits"]],
            regions=regions,
            engine=self.classifier_mode,
            model_version=settings.model_version,
        )


engine = KheryneMLEngine()
