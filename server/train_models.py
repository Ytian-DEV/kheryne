"""
CLI trainer for Kheryne's 2-stage nematode vision pipeline:
1. YOLOv8n candidate nematode vs. debris detector -> `server/models/detector.onnx`
2. MobileNetV3 morphological genus classifier -> `server/models/classifier.onnx` + `model_meta.json`

Supports either:
- Live Supabase fetch (`SUPABASE_URL` + `SUPABASE_KEY`), OR
- Offline pre-exported manifest (`--manifest <samples.json>` + `--local-cache-dir <specimens_dir>`).
"""

import argparse
import hashlib
import json
import os
from pathlib import Path
from typing import Any, Dict, List

from app.config import settings
from app.trainer import fetch_supabase_verified_samples, train_and_reload_from_samples


def load_samples_from_manifest(manifest_path: Path, cache_dir: Path) -> List[Dict[str, Any]]:
    raw = json.loads(manifest_path.read_text(encoding="utf-8"))
    by_md5: Dict[str, Path] = {}
    for img_file in cache_dir.glob("*"):
        if img_file.is_file():
            digest = hashlib.md5(img_file.read_bytes()).hexdigest()
            by_md5[digest] = img_file

    hydrated: List[Dict[str, Any]] = []
    for item in raw:
        etag = (item.get("etag") or "").strip('"')
        match = by_md5.get(etag)
        if match is not None:
            item["_image_bytes"] = match.read_bytes()
            hydrated.append(item)
    return hydrated


def main() -> None:
    parser = argparse.ArgumentParser(description="Train Kheryne detector.onnx and classifier.onnx")
    parser.add_argument("--epochs-detector", type=int, default=20)
    parser.add_argument("--epochs-classifier", type=int, default=28)
    parser.add_argument("--manifest", type=str, default="")
    parser.add_argument("--local-cache-dir", type=str, default="")
    args = parser.parse_args()

    os.chdir(Path(__file__).resolve().parent)

    if args.manifest and args.local_cache_dir:
        samples = load_samples_from_manifest(Path(args.manifest), Path(args.local_cache_dir))
    else:
        supabase_key = os.environ.get("SUPABASE_KEY") or settings.supabase_service_key
        if not supabase_key:
            raise SystemExit("Provide SUPABASE_KEY or --manifest + --local-cache-dir.")
        samples = fetch_supabase_verified_samples(
            settings.supabase_url,
            settings.supabase_publishable_key,
            supabase_key,
        )

    res = train_and_reload_from_samples(
        samples=samples,
        epochs_detector=args.epochs_detector,
        epochs_classifier=args.epochs_classifier,
        bearer_token=os.environ.get("SUPABASE_KEY"),
    )
    print(json.dumps(res.model_dump(), indent=2))


if __name__ == "__main__":
    main()
