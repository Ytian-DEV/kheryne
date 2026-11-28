import json
import os
from typing import Any, Dict, List, Optional
import cv2
import numpy as np

try:
    import onnxruntime as ort
except ImportError:
    ort = None

from .config import settings
from .features import extract_morphological_features, propose_nematode_regions
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

_GENUS_LOOKUP: Dict[str, Dict[str, Any]] = {g["name"]: g for g in PHILIPPINE_GENERA}

_IMAGENET_MEAN = np.array([0.485, 0.456, 0.406], dtype=np.float32).reshape(3, 1, 1)
_IMAGENET_STD = np.array([0.229, 0.224, 0.225], dtype=np.float32).reshape(3, 1, 1)


class KheryneMLEngine:
    """Pluggable OpenCV + ONNX Runtime engine supporting both Morphological-ONNX and CNN/YOLO-ONNX weights."""

    def __init__(self) -> None:
        self.detector_session = None
        self.classifier_session = None
        self.class_names: List[str] = []
        self.active_version: str = settings.model_version
        self.sample_count: int = 0
        self.reload()

    def reload(self) -> None:
        self.detector_session = self._load_session(settings.detector_model_path)
        self.classifier_session = self._load_session(settings.classifier_model_path)
        self.class_names = []
        self.sample_count = 0
        self.active_version = settings.model_version

        # Resolve paths relative to server root if cwd differs
        server_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        if self.detector_session is None:
            self.detector_session = self._load_session(os.path.join(server_root, settings.detector_model_path))
        if self.classifier_session is None:
            self.classifier_session = self._load_session(os.path.join(server_root, settings.classifier_model_path))

        meta_candidates = [
            settings.model_meta_path,
            os.path.join(server_root, settings.model_meta_path),
        ]
        for mp in meta_candidates:
            if os.path.isfile(mp):
                try:
                    with open(mp, "r", encoding="utf-8") as fh:
                        meta = json.load(fh)
                    if isinstance(meta.get("classes"), list):
                        self.class_names = [str(c) for c in meta["classes"]]
                    if meta.get("version"):
                        self.active_version = str(meta["version"])
                    if meta.get("sample_count") is not None:
                        self.sample_count = int(meta["sample_count"])
                    break
                except Exception:
                    pass

        if not self.class_names and self.classifier_session is not None:
            self.class_names = [g["name"] for g in PHILIPPINE_GENERA]

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
            blurry=focus_var < 35.0,
            dark=mean_lum < 50.0,
            focus_score=round(min(focus_var / 250.0, 1.0), 3),
            brightness_score=round(mean_lum / 255.0, 3),
        )

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

    @staticmethod
    def _rect_aspect(bgr: np.ndarray, rect: Optional[NormRect]) -> float:
        if rect is None:
            h, w = bgr.shape[:2]
            return float(max(w, h)) / float(max(min(w, h), 1))
        h, w = bgr.shape[:2]
        bw = max(1.0, (rect.right - rect.left) * w)
        bh = max(1.0, (rect.bottom - rect.top) * h)
        return float(max(bw, bh)) / float(max(min(bw, bh), 1.0))

    def _score_detector_feature_batch(self, feats: np.ndarray) -> np.ndarray:
        """Runs 2D feature batch (N, F) through morphological detector.onnx and returns P(nematode)."""
        inp_name = self.detector_session.get_inputs()[0].name
        outputs = self.detector_session.run(None, {inp_name: feats.astype(np.float32)})
        # skl2onnx with zipmap=False returns [labels, probabilities (N, 2)]
        if len(outputs) >= 2 and isinstance(outputs[1], np.ndarray) and outputs[1].ndim == 2:
            probs = outputs[1]
            return probs[:, 1] if probs.shape[1] > 1 else probs[:, 0]
        arr = np.asarray(outputs[0], dtype=np.float32)
        if arr.ndim == 2 and arr.shape[1] >= 2:
            return arr[:, 1]
        return arr.reshape(-1)

    def _run_yolo_4d_detector(self, bgr: np.ndarray, conf_thresh: float = 0.25) -> List[DetectionItem]:
        inp_meta = self.detector_session.get_inputs()[0]
        resized = cv2.resize(bgr, (640, 640))
        blob = resized[:, :, ::-1].transpose(2, 0, 1).astype(np.float32) / 255.0
        raw_out = self.detector_session.run(None, {inp_meta.name: blob[None, ...]})[0]
        preds = np.squeeze(raw_out)
        if preds.ndim != 2:
            return []
        if preds.shape[0] < preds.shape[1] and preds.shape[0] <= 64:
            preds = preds.T
        if preds.shape[1] < 5:
            return []

        xywh = preds[:, :4]
        class_scores = preds[:, 4:]
        nematode_scores = class_scores[:, 0]
        keep_mask = nematode_scores >= conf_thresh
        if class_scores.shape[1] > 1:
            keep_mask = keep_mask & (nematode_scores >= np.max(class_scores[:, 1:], axis=1))

        filtered_xywh = xywh[keep_mask]
        filtered_scores = nematode_scores[keep_mask]
        if len(filtered_scores) == 0:
            return []

        boxes_px = [[int(cx - bw / 2), int(cy - bh / 2), int(bw), int(bh)] for cx, cy, bw, bh in filtered_xywh]
        scores_list = [float(s) for s in filtered_scores]
        indices = cv2.dnn.NMSBoxes(boxes_px, scores_list, conf_thresh, 0.45)
        if len(indices) == 0:
            return []

        results: List[DetectionItem] = []
        for rank, idx in enumerate(np.array(indices).flatten()[:8]):
            x, y, bw, bh = boxes_px[int(idx)]
            x1 = max(0.0, min(0.99, x / 640.0))
            y1 = max(0.0, min(0.99, y / 640.0))
            x2 = max(x1 + 0.01, min(1.0, (x + bw) / 640.0))
            y2 = max(y1 + 0.01, min(1.0, (y + bh) / 640.0))
            results.append(
                DetectionItem(
                    id=f"ai-{rank}",
                    rect=NormRect(left=x1, top=y1, right=x2, bottom=y2),
                    kind="ai",
                    confidence=min(0.99, round(scores_list[int(idx)], 3)),
                )
            )
        return results

    def detect_candidates(self, bgr: np.ndarray) -> List[DetectionItem]:
        if self.detector_session is not None:
            inp_shape = self.detector_session.get_inputs()[0].shape
            if len(inp_shape) == 4:
                yolo_boxes = self._run_yolo_4d_detector(bgr, conf_thresh=0.25)
                if yolo_boxes:
                    return yolo_boxes
            else:
                proposals = propose_nematode_regions(bgr, max_proposals=14)
                if proposals:
                    feats = []
                    rects = []
                    heuristics = []
                    for l, t, r, b, h_sc in proposals:
                        nr = NormRect(left=l, top=t, right=r, bottom=b)
                        crop = self._crop(bgr, nr)
                        feats.append(extract_morphological_features(crop, self._rect_aspect(bgr, nr)))
                        rects.append(nr)
                        heuristics.append(h_sc)
                    onnx_probs = self._score_detector_feature_batch(np.stack(feats, axis=0))
                    h_px, w_px = bgr.shape[:2]
                    boxes_px = []
                    scores = []
                    kept_rects = []
                    for nr, p_onnx, h_sc in zip(rects, onnx_probs, heuristics):
                        combined = float(0.75 * float(p_onnx) + 0.25 * float(h_sc))
                        if combined >= 0.42:
                            boxes_px.append(
                                [
                                    int(nr.left * w_px),
                                    int(nr.top * h_px),
                                    int((nr.right - nr.left) * w_px),
                                    int((nr.bottom - nr.top) * h_px),
                                ]
                            )
                            scores.append(combined)
                            kept_rects.append(nr)
                    if boxes_px:
                        idxs = cv2.dnn.NMSBoxes(boxes_px, scores, 0.42, 0.35)
                        if len(idxs) > 0:
                            return [
                                DetectionItem(
                                    id=f"ai-{rank}",
                                    rect=kept_rects[int(i)],
                                    kind="ai",
                                    confidence=min(0.99, round(scores[int(i)], 3)),
                                )
                                for rank, i in enumerate(np.array(idxs).flatten()[:6])
                            ]

        # Illumination-invariant OpenCV fallback when detector.onnx is not trained yet
        proposals = propose_nematode_regions(bgr, max_proposals=5)
        return [
            DetectionItem(
                id=f"ai-{idx}",
                rect=NormRect(left=l, top=t, right=r, bottom=b),
                kind="ai",
                confidence=round(sc, 2),
            )
            for idx, (l, t, r, b, sc) in enumerate(proposals)
        ]

    def check_box(self, bgr: np.ndarray, rect: NormRect) -> BoxCheckResponse:
        crop = self._crop(bgr, rect)
        gray = cv2.cvtColor(crop, cv2.COLOR_BGR2GRAY)
        edges = cv2.Canny(gray, 30, 105)
        edge_density = float(np.count_nonzero(edges)) / max(gray.size, 1)
        std_contrast = float(np.std(gray))

        if std_contrast < 5.5 or edge_density < 0.0025:
            return BoxCheckResponse(
                is_nematode=False,
                confidence=0.88,
                reason="Empty slide / background",
                engine=self.detector_mode,
            )

        if self.detector_session is not None:
            inp_shape = self.detector_session.get_inputs()[0].shape
            if len(inp_shape) == 2:
                feat = extract_morphological_features(crop, self._rect_aspect(bgr, rect))[None, :]
                prob = float(self._score_detector_feature_batch(feat)[0])
                if prob >= 0.40:
                    return BoxCheckResponse(
                        is_nematode=True,
                        confidence=min(0.99, round(prob, 2)),
                        reason=None,
                        engine=self.detector_mode,
                    )
                return BoxCheckResponse(
                    is_nematode=False,
                    confidence=min(0.96, round(1.0 - prob, 2)),
                    reason="Not a nematode / debris",
                    engine=self.detector_mode,
                )

        if edge_density > 0.45:
            return BoxCheckResponse(
                is_nematode=False,
                confidence=0.79,
                reason="Dense root tissue",
                engine=self.detector_mode,
            )
        conf = min(0.96, round(0.76 + min(std_contrast / 180.0, 0.18), 2))
        return BoxCheckResponse(
            is_nematode=True,
            confidence=conf,
            reason=None,
            engine=self.detector_mode,
        )

    @staticmethod
    def _genus_metadata(genus_name: str) -> Dict[str, Any]:
        if genus_name in _GENUS_LOOKUP:
            return _GENUS_LOOKUP[genus_name]
        return {
            "name": genus_name,
            "family": "Criconematidae" if "criconem" in genus_name.lower() else "Pratylenchidae",
            "order": "Rhabditida",
            "vulva_pct": 0.80,
            "similar": [],
            "traits": [],
        }

    def analyze(self, bgr: np.ndarray, rect: Optional[NormRect] = None) -> AnalyzeResponse:
        if self.classifier_session is None or not self.class_names:
            raise RuntimeError(
                "Genus classifier weights (models/classifier.onnx) are not loaded on the server yet. "
                "Open Lab dataset → Dataset stats and click 'Train & Reload AI Model'."
            )

        crop = self._crop(bgr, rect)
        inp_meta = self.classifier_session.get_inputs()[0]

        if len(inp_meta.shape) == 4:
            resized = cv2.resize(crop, (224, 224))
            rgb = resized[:, :, ::-1].astype(np.float32) / 255.0
            chw = (rgb.transpose(2, 0, 1) - _IMAGENET_MEAN) / _IMAGENET_STD
            logits = np.squeeze(self.classifier_session.run(None, {inp_meta.name: chw[None, ...]})[0])
            if logits.ndim == 0:
                logits = np.array([float(logits)], dtype=np.float32)
            exp = np.exp(logits - np.max(logits))
            probs = exp / np.sum(exp)
        else:
            aspect = self._rect_aspect(bgr, rect)
            f_orig = extract_morphological_features(crop, aspect)
            f_flip = extract_morphological_features(cv2.flip(crop, 1), aspect)
            batch = np.stack([f_orig, f_flip], axis=0).astype(np.float32)
            outputs = self.classifier_session.run(None, {inp_meta.name: batch})
            if len(outputs) >= 2 and isinstance(outputs[1], np.ndarray) and outputs[1].ndim == 2:
                probs = np.mean(outputs[1], axis=0).astype(np.float32)
            else:
                raw = np.mean(np.asarray(outputs[0], dtype=np.float32), axis=0).reshape(-1)
                exp = np.exp(raw - np.max(raw))
                probs = exp / np.sum(exp)

        probs = probs / max(float(np.sum(probs)), 1e-6)
        ranked_indices = np.argsort(probs)[::-1]
        top_idx = int(ranked_indices[0])
        genus_name = self.class_names[top_idx] if top_idx < len(self.class_names) else self.class_names[0]
        genus_conf = round(min(0.99, float(probs[top_idx])), 3)

        info = self._genus_metadata(genus_name)
        family_conf = round(min(0.98, max(genus_conf + 0.08, 0.76)), 2)
        order_conf = round(min(0.99, max(family_conf + 0.04, 0.90)), 2)

        runners: List[RankScore] = []
        for idx in ranked_indices[1:3]:
            idx_int = int(idx)
            if idx_int < len(self.class_names):
                runners.append(
                    RankScore(
                        rank="genus",
                        name=self.class_names[idx_int],
                        confidence=round(max(0.01, float(probs[idx_int])), 3),
                    )
                )

        if len(runners) < 2:
            existing_names = {genus_name, *(r.name for r in runners)}
            rem = max(0.03, 1.0 - genus_conf)
            for sim_name in info.get("similar", []):
                if sim_name not in existing_names and len(runners) < 2:
                    runners.append(
                        RankScore(
                            rank="genus",
                            name=sim_name,
                            confidence=round(max(0.01, rem * 0.25), 3),
                        )
                    )

        v = float(info.get("vulva_pct", 0.80))
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
            traits=[TraitPayload(**t) for t in info.get("traits", [])],
            regions=regions,
            engine=self.classifier_mode,
            model_version=self.active_version,
        )


engine = KheryneMLEngine()
