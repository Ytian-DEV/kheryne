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
| `POST` | `/v1/train` | Exports verified Gold + Silver samples from Supabase, trains YOLOv8 (`detector.onnx`) + MobileNetV3 (`classifier.onnx`), and hot-reloads the engine |
| `POST` | `/v1/reload` | Reloads `detector.onnx`, `classifier.onnx`, and `model_meta.json` into memory without restarting |

## Exporting Verified Training Data & Plugging in Trained Models

1. Export Scientist **Gold** (`verified_gold`) and Scientist-verified user **Silver** (`verified_silver`) samples from Supabase into Ultralytics YOLO detection + 19-genus classification folders:

```bash
SUPABASE_URL=https://wxdacmoxlvblmakrwkog.supabase.co \
SUPABASE_SERVICE_KEY=<service-or-scientist-jwt> \
python export_dataset.py --out dataset_out
```

This creates:
- `dataset_out/yolo_detector/dataset.yaml` (`train/` + `val/` images & normalized YOLO labels)
- `dataset_out/genus_classifier/{train,val}/<Genus>/` (cropped nematode specimens across the 19 target genera)

2. After training YOLO + your genus classifier and exporting ONNX weights, drop them into `server/models/`:
- `server/models/detector.onnx` — candidate nematode detector
- `server/models/classifier.onnx` — 19-genus morphological classifier

When those files exist, `app/engine.py` automatically runs `onnxruntime.InferenceSession`. Until `classifier.onnx` is present, `/v1/analyze` returns HTTP `503` instead of fabricating placeholder genus predictions.

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
