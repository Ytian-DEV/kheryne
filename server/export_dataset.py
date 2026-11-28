"""
Exports verified Gold (Scientist lab) + Silver (Scientist-verified user) samples
from Supabase into two ready-to-train datasets:

1. Ultralytics YOLO Object Detection (`<out>/yolo_detector/dataset.yaml`):
   - Class 0: `nematode`
   - Class 1: `debris`
   - Normalized `class_id cx cy w h` labels under `labels/{train,val}/`

2. 19-Genus Morphological Classification (`<out>/genus_classifier/{train,val}/<GenusName>/`):
   - Tight bounding-box crops of verified nematodes for PyTorch / `yolo classify` training.

Usage:
  export SUPABASE_URL="https://wxdacmoxlvblmakrwkog.supabase.co"
  export SUPABASE_KEY="<service_role_key_or_scientist_access_token>"
  python server/export_dataset.py --out server/dataset_out
"""

import argparse
import os
import random
from pathlib import Path
from typing import Dict, List

import cv2
import httpx
import numpy as np


CLASS_MAP = {
    "nematode": 0,
    "debris": 1,
    "root_tissue": 1,
    "hyphae": 1,
    "free_living": 1,
}


def fetch_verified_samples(base_url: str, api_key: str) -> List[Dict]:
    headers = {
        "apikey": api_key,
        "Authorization": f"Bearer {api_key}",
    }
    url = (
        f"{base_url.rstrip('/')}/rest/v1/training_samples"
        "?select=*,training_annotations(*)"
        "&review_status=in.(verified_gold,verified_silver)"
        "&order=created_at.asc"
    )
    with httpx.Client(timeout=30.0) as client:
        resp = client.get(url, headers=headers)
        resp.raise_for_status()
        return resp.json()


def download_object(base_url: str, api_key: str, bucket: str, path: str) -> bytes:
    headers = {
        "apikey": api_key,
        "Authorization": f"Bearer {api_key}",
    }
    url = f"{base_url.rstrip('/')}/storage/v1/object/authenticated/{bucket}/{path}"
    with httpx.Client(timeout=30.0) as client:
        resp = client.get(url, headers=headers)
        resp.raise_for_status()
        return resp.content


def export_datasets(base_url: str, api_key: str, out_dir: Path, val_ratio: float = 0.2) -> None:
    samples = fetch_verified_samples(base_url, api_key)
    if not samples:
        print("No verified_gold or verified_silver samples found in Supabase yet.")
        return

    rng = random.Random(42)
    rng.shuffle(samples)
    val_cutoff = max(1, int(len(samples) * val_ratio)) if len(samples) >= 5 else 0

    yolo_root = out_dir / "yolo_detector"
    cls_root = out_dir / "genus_classifier"
    for split in ("train", "val"):
        (yolo_root / "images" / split).mkdir(parents=True, exist_ok=True)
        (yolo_root / "labels" / split).mkdir(parents=True, exist_ok=True)

    exported_det = 0
    exported_crops = 0

    for idx, sample in enumerate(samples):
        split = "val" if idx < val_cutoff else "train"
        sample_id = sample["id"]
        bucket = sample.get("storage_bucket") or "training-dataset"
        storage_path = sample["storage_path"]
        verified_genus = sample.get("verified_genus")
        annotations = sample.get("training_annotations") or []

        raw_bytes = download_object(base_url, api_key, bucket, storage_path)
        arr = np.frombuffer(raw_bytes, dtype=np.uint8)
        bgr = cv2.imdecode(arr, cv2.IMREAD_COLOR)
        if bgr is None:
            continue

        h, w = bgr.shape[:2]
        img_out = yolo_root / "images" / split / f"{sample_id}.jpg"
        lbl_out = yolo_root / "labels" / split / f"{sample_id}.txt"
        cv2.imwrite(str(img_out), bgr)

        yolo_lines: List[str] = []
        for box_idx, ann in enumerate(annotations):
            rect = ann.get("rect") or {}
            raw_l = float(rect.get("left", 0.0))
            raw_t = float(rect.get("top", 0.0))
            raw_r = float(rect.get("right", 1.0))
            raw_b = float(rect.get("bottom", 1.0))
            left = max(0.0, min(0.98, min(raw_l, raw_r)))
            top = max(0.0, min(0.98, min(raw_t, raw_b)))
            right = max(left + 0.01, min(1.0, max(raw_l, raw_r)))
            bottom = max(top + 0.01, min(1.0, max(raw_t, raw_b)))
            bw = max(0.01, right - left)
            bh = max(0.01, bottom - top)
            cx = min(0.995, max(0.005, left + bw / 2.0))
            cy = min(0.995, max(0.005, top + bh / 2.0))
            cls_id = CLASS_MAP.get(ann.get("class_label", "nematode"), 0)
            yolo_lines.append(f"{cls_id} {cx:.6f} {cy:.6f} {bw:.6f} {bh:.6f}")

            genus_label = ann.get("genus_label") or verified_genus
            if cls_id == 0 and genus_label:
                x1 = max(0, int(left * w))
                y1 = max(0, int(top * h))
                x2 = min(w, max(x1 + 4, int(right * w)))
                y2 = min(h, max(y1 + 4, int(bottom * h)))
                crop = bgr[y1:y2, x1:x2]
                genus_dir = cls_root / split / genus_label
                genus_dir.mkdir(parents=True, exist_ok=True)
                cv2.imwrite(str(genus_dir / f"{sample_id}_{box_idx}.jpg"), crop)
                exported_crops += 1

        lbl_out.write_text("\n".join(yolo_lines) + ("\n" if yolo_lines else ""), encoding="utf-8")
        exported_det += 1

    yaml_text = (
        f"path: {yolo_root.resolve().as_posix()}\n"
        "train: images/train\n"
        "val: images/val\n"
        "names:\n"
        "  0: nematode\n"
        "  1: debris\n"
    )
    (yolo_root / "dataset.yaml").write_text(yaml_text, encoding="utf-8")
    print(f"Exported {exported_det} YOLO slides and {exported_crops} genus crops to {out_dir}")


def main() -> None:
    parser = argparse.ArgumentParser(description="Export verified Kheryne training dataset from Supabase.")
    parser.add_argument("--out", default="server/dataset_out", help="Output dataset directory")
    parser.add_argument("--val-ratio", type=float, default=0.2, help="Validation split fraction")
    args = parser.parse_args()

    supabase_url = os.environ.get("SUPABASE_URL", "https://wxdacmoxlvblmakrwkog.supabase.co")
    supabase_key = os.environ.get("SUPABASE_KEY") or os.environ.get("SUPABASE_SERVICE_ROLE_KEY")
    if not supabase_key:
        raise SystemExit("Set SUPABASE_KEY (service role key or scientist access token) before exporting.")

    export_datasets(supabase_url, supabase_key, Path(args.out), val_ratio=args.val_ratio)


if __name__ == "__main__":
    main()
