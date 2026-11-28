from typing import Dict, List, Literal, Optional
from pydantic import BaseModel, Field


class NormRect(BaseModel):
    left: float = Field(ge=0.0, le=1.0)
    top: float = Field(ge=0.0, le=1.0)
    right: float = Field(ge=0.0, le=1.0)
    bottom: float = Field(ge=0.0, le=1.0)


class QualityResponse(BaseModel):
    blurry: bool
    dark: bool
    focus_score: float
    brightness_score: float


class DetectionItem(BaseModel):
    id: str
    rect: NormRect
    kind: Literal["ai", "user", "confirmed", "rejected"] = "ai"
    confidence: float


class DetectResponse(BaseModel):
    quality: QualityResponse
    detections: List[DetectionItem]
    engine: str
    model_version: str


class BoxCheckResponse(BaseModel):
    is_nematode: bool
    confidence: float
    reason: Optional[str] = None
    engine: str


class RankScore(BaseModel):
    rank: Literal["order", "family", "genus"]
    name: str
    confidence: float


class ClassificationPayload(BaseModel):
    order: RankScore
    family: RankScore
    genus: RankScore
    runners_up: List[RankScore] = []


class TraitPayload(BaseModel):
    name: str
    value: str
    why: str
    region: Literal["head", "stylet", "esophagus", "vulva", "tail"]
    illustration: str


class AnalyzeResponse(BaseModel):
    classification: ClassificationPayload
    traits: List[TraitPayload]
    regions: Dict[str, NormRect]
    engine: str
    model_version: str


class HealthResponse(BaseModel):
    status: str
    detector_engine: str
    classifier_engine: str
    model_version: str
    trained_genera: List[str] = []
    sample_count: int = 0


class TrainRequest(BaseModel):
    epochs_detector: int = Field(default=20, ge=3, le=100)
    epochs_classifier: int = Field(default=28, ge=5, le=150)


class TrainResponse(BaseModel):
    status: str
    model_version: str
    sample_count: int
    crop_count: int
    trained_genera: List[str]
    per_genus_counts: Dict[str, int]
    detector_size_mb: float
    classifier_size_mb: float
    classifier_val_accuracy: float
    detector_engine: str
    classifier_engine: str
