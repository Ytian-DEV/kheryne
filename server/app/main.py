from typing import Optional
from fastapi import Depends, FastAPI, File, Form, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware

from .auth import verify_user
from .config import settings
from .engine import engine
from .schemas import (
    AnalyzeResponse,
    BoxCheckResponse,
    DetectResponse,
    HealthResponse,
    NormRect,
    QualityResponse,
)

app = FastAPI(
    title="Kheryne ML Server",
    version=settings.model_version,
    description="Hybrid OpenCV + ONNX Runtime nematode detection and genus classification API.",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


def _parse_rect(
    left: Optional[float],
    top: Optional[float],
    right: Optional[float],
    bottom: Optional[float],
) -> Optional[NormRect]:
    if left is None or top is None or right is None or bottom is None:
        return None
    return NormRect(left=left, top=top, right=right, bottom=bottom)


@app.get("/health", response_model=HealthResponse)
async def health() -> HealthResponse:
    return HealthResponse(
        status="ok",
        detector_engine=engine.detector_mode,
        classifier_engine=engine.classifier_mode,
        model_version=settings.model_version,
    )


@app.post("/v1/quality", response_model=QualityResponse)
async def check_quality(
    image: UploadFile = File(...),
    _user: Optional[dict] = Depends(verify_user),
) -> QualityResponse:
    try:
        bgr = engine.decode_image(await image.read())
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    return engine.evaluate_quality(bgr)


@app.post("/v1/detect", response_model=DetectResponse)
async def detect(
    image: UploadFile = File(...),
    _user: Optional[dict] = Depends(verify_user),
) -> DetectResponse:
    try:
        bgr = engine.decode_image(await image.read())
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    quality = engine.evaluate_quality(bgr)
    detections = engine.detect_candidates(bgr)
    return DetectResponse(
        quality=quality,
        detections=detections,
        engine=engine.detector_mode,
        model_version=settings.model_version,
    )


@app.post("/v1/check-box", response_model=BoxCheckResponse)
async def check_box(
    image: UploadFile = File(...),
    left: float = Form(...),
    top: float = Form(...),
    right: float = Form(...),
    bottom: float = Form(...),
    _user: Optional[dict] = Depends(verify_user),
) -> BoxCheckResponse:
    try:
        bgr = engine.decode_image(await image.read())
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    rect = NormRect(left=left, top=top, right=right, bottom=bottom)
    return engine.check_box(bgr, rect)


@app.post("/v1/analyze", response_model=AnalyzeResponse)
async def analyze(
    image: UploadFile = File(...),
    left: Optional[float] = Form(default=None),
    top: Optional[float] = Form(default=None),
    right: Optional[float] = Form(default=None),
    bottom: Optional[float] = Form(default=None),
    _user: Optional[dict] = Depends(verify_user),
) -> AnalyzeResponse:
    try:
        bgr = engine.decode_image(await image.read())
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    rect = _parse_rect(left, top, right, bottom)
    try:
        return engine.analyze(bgr, rect)
    except RuntimeError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
