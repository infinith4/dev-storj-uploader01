import os
import json
from datetime import datetime
from pathlib import Path
from flask import Flask, jsonify

from storj_uploader import StorjUploader

FILE_SHARE_ROOT = Path(os.getenv("FILE_SHARE_MOUNT", "/mnt/temp"))
FILES_DIR = FILE_SHARE_ROOT / "files"
QUEUE_DIR = FILE_SHARE_ROOT / "queue"
PROCESSED_DIR = FILE_SHARE_ROOT / "processed"

for path in (FILES_DIR, QUEUE_DIR, PROCESSED_DIR):
    path.mkdir(parents=True, exist_ok=True)

uploader = StorjUploader()
app = Flask(__name__)


def _write_json(path: Path, data: dict):
    path.parent.mkdir(parents=True, exist_ok=True)
    temp = path.with_suffix(path.suffix + ".tmp")
    temp.write_text(json.dumps(data, indent=2), encoding="utf-8")
    temp.replace(path)


def _update_status(data: dict, status: str, error: str = ""):
    data["status"] = status
    data["updated_at"] = datetime.utcnow().isoformat()
    if error:
        data["error"] = error


def process_queue():
    queue_files = sorted(QUEUE_DIR.glob("upload-*.json"))
    processed = 0
    failed = 0

    for queue_file in queue_files:
        try:
            data = json.loads(queue_file.read_text())
        except Exception as e:
            print(f"Failed to read queue file {queue_file}: {e}")
            failed += 1
            continue

        saved_as = data.get("saved_as") or data.get("file_name")
        file_path = Path(data.get("file_path", ""))
        _update_status(data, "processing")
        _write_json(queue_file, data)

        if not file_path.exists():
            _update_status(data, "failed", "file missing")
            _write_json(PROCESSED_DIR / queue_file.name, data)
            queue_file.unlink(missing_ok=True)
            failed += 1
            continue

        try:
            success, _, status = uploader.upload_single_file(file_path)
            if success:
                _update_status(data, "completed")
                processed += 1
            else:
                _update_status(data, "failed", status or "upload error")
                failed += 1
        except Exception as e:
            _update_status(data, "failed", str(e))
            failed += 1

        # move request file to processed and cleanup file
        _write_json(PROCESSED_DIR / queue_file.name, data)
        queue_file.unlink(missing_ok=True)
        if file_path.exists():
            try:
                file_path.unlink()
            except Exception:
                pass

    return processed, failed


@app.route("/health", methods=["GET"])
def health():
    return jsonify({"status": "ok", "pending": len(list(QUEUE_DIR.glob('upload-*.json')))}), 200


@app.route("/process", methods=["POST"])
def process_endpoint():
    processed, failed = process_queue()
    return jsonify({"processed": processed, "failed": failed}), 200


if __name__ == "__main__":
    port = int(os.getenv("PORT", "8080"))
    app.run(host="0.0.0.0", port=port)
