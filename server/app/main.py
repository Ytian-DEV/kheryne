from typing import Optional
from fastapi import Body, Depends, FastAPI, File, Form, Header, HTTPException, UploadFile
from fastapi.concurrency import run_in_threadpool
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
    TrainRequest,
    TrainResponse,
)
from .trainer import fetch_supabase_verified_samples, train_and_reload_from_samples

app = FastAPI(
    title="Kheryne ML Server",
    version="0.1.0",
    description="Hybrid OpenCV + ONNX Runtime nematode detection, genus classification, and active-learning trainer API.",
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
    return NormRect(
        left=max(0.0, min(1.0, left)),
        top=max(0.0, min(1.0, top)),
        right=max(0.0, min(1.0, right)),
        bottom=max(0.0, min(1.0, bottom)),
    )


@app.get("/health", response_model=HealthResponse)
async def health() -> HealthResponse:
    return HealthResponse(
        status="ok",
        detector_engine=engine.detector_mode,
        classifier_engine=engine.classifier_mode,
        model_version=engine.active_version,
        trained_genera=engine.class_names,
        sample_count=engine.sample_count,
    )


@app.post("/v1/reload", response_model=HealthResponse)
async def reload_models(_user: Optional[dict] = Depends(verify_user)) -> HealthResponse:
    engine.reload()
    return await health()


@app.post("/v1/train", response_model=TrainResponse)
async def train_models(
    payload: TrainRequest = Body(default=TrainRequest()),
    authorization: Optional[str] = Header(default=None),
    _user: Optional[dict] = Depends(verify_user),
) -> TrainResponse:
    bearer = None
    if authorization and authorization.lower().startswith("bearer "):
        bearer = authorization.split(" ", 1)[1].strip()
    elif settings.supabase_service_key:
        bearer = settings.supabase_service_key

    if not bearer:
        raise HTTPException(
            status_code=401,
            detail="Sign in as an Owner or Scientist so the server can read verified samples from Supabase.",
        )

    try:
        samples = await run_in_threadpool(
            fetch_supabase_verified_samples,
            settings.supabase_url,
            settings.supabase_publishable_key,
            bearer,
        )
        return await run_in_threadpool(
            train_and_reload_from_samples,
            samples,
            payload.epochs_detector,
            payload.epochs_classifier,
            bearer,
        )
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except RuntimeError as exc:
        raise HTTPException(status_code=409, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Training failed: {exc}") from exc


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
        model_version=engine.active_version,
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
    rect = NormRect(
        left=max(0.0, min(1.0, left)),
        top=max(0.0, min(1.0, top)),
        right=max(0.0, min(1.0, right)),
        bottom=max(0.0, min(1.0, bottom)),
    )
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
