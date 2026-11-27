---
title: Kheryne ML Server
emoji: 🔬
colorFrom: pink
colorTo: purple
sdk: docker
app_port: 7860
pinned: false
---

# Kheryne — Python FastAPI ML Server

Cloud analysis and image-quality verification microservice for **Kheryne** (Visayas State University, BS Computer Science).

Designed to run locally during development or for **$0/month** on **Hugging Face Spaces (Docker, 2 vCPU / 16 GB RAM)**.

## Endpoints

| Method | Path | Description |
|---|---|---|
| `GET` | `/health` | Health status, loaded engine mode (`opencv-fallback` vs `onnx`), and model version |
| `POST` | `/v1/quality` | OpenCV focus (Laplacian variance) & illumination check for `CaptureReviewScreen` |
| `POST` | `/v1/detect` | Detects candidate nematode bounding boxes (`0..1` normalized rects) on a microscope image |
| `POST` | `/v1/check-box` | Verifies whether a cropped user/candidate box contains a plant-parasitic nematode |
| `POST` | `/v1/analyze` | Hierarchical `Order -> Family -> Genus` classification, diagnostic traits, and region localization |

## Plugging in Your Trained Models

Drop exported ONNX weights into `server/models/`:
- `server/models/detector.onnx` — candidate nematode detector
- `server/models/classifier.onnx` — 19-genus morphological classifier

When those files exist, `app/engine.py` automatically switches from the OpenCV contour/morphological baseline engine to `onnxruntime.InferenceSession` without changing any API contracts.

## Run Locally

```bash
cd server
python -m venv .venv
.venv\Scripts\activate   # Windows PowerShell
pip install -r requirements.txt
uvicorn app.main:app --reload --port 7860
```

## Deploy Free to Hugging Face Spaces

1. Create a new Space at `https://huggingface.co/new-space`, choose **Docker** → **Blank**, and pick **CPU basic (Free · 2 vCPU · 16 GB RAM)**.
2. Push the contents of `server/` to that Space repository.
3. In Space **Settings → Variables and secrets**, set:
   - `SUPABASE_URL=https://wxdacmoxlvblmakrwkog.supabase.co`
   - `SUPABASE_PUBLISHABLE_KEY=sb_publishable_4RgXahz2RGB2O6LWNa-YvQ_pwhTrWCo`
   - `REQUIRE_AUTH=true`
4. Set your Space URL (e.g. `https://<username>-kheryne-ml.hf.space`) in Settings inside the Kheryne app or `--dart-define=ML_SERVER_URL=...`.
