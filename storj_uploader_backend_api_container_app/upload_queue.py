"""File-based upload queue using Azure File Share."""
import os
import json
import uuid
from pathlib import Path
from typing import Optional, Dict, Any
from datetime import datetime


class UploadQueue:
    """Manages upload queue using JSON files on Azure File Share."""

    def __init__(self):
        self.temp_root = Path(os.getenv("TEMP_DIR", "/mnt/temp"))
        self.files_dir = self.temp_root / "files"
        self.queue_dir = self.temp_root / "queue"
        self.processed_dir = self.temp_root / "processed"

        # Create directories if not exist
        self.files_dir.mkdir(parents=True, exist_ok=True)
        self.queue_dir.mkdir(parents=True, exist_ok=True)
        self.processed_dir.mkdir(parents=True, exist_ok=True)

    def add_upload_request(
        self,
        file_path: Path,
        file_name: str,
        file_size: int,
        content_type: str,
        saved_as: Optional[str] = None,
        original_name: Optional[str] = None
    ) -> str:
        """
        Add upload request to queue.

        Args:
            file_path: Path to the file in files directory
            file_name: Original filename
            file_size: File size in bytes
            content_type: MIME content type

        Returns:
            Request ID (UUID)
        """
        request_id = str(uuid.uuid4())
        request_file = self.queue_dir / f"upload-{request_id}.json"

        request_data = {
            "request_id": request_id,
            "file_path": str(file_path),
            "file_name": file_name,
            "file_size": file_size,
            "content_type": content_type,
            "saved_as": saved_as or file_name,
            "original_name": original_name or file_name,
            "status": "pending",
            "created_at": datetime.utcnow().isoformat(),
        }

        with open(request_file, 'w') as f:
            json.dump(request_data, f, indent=2)

        print(f"Added upload request to queue: {request_id} for file: {file_name}")
        return request_id

    def get_pending_count(self) -> int:
        """Get number of pending requests."""
        return len(list(self.queue_dir.glob("upload-*.json")))

    def get_processed_count(self) -> int:
        """Get number of processed requests."""
        return len(list(self.processed_dir.glob("upload-*.json")))

    def get_queue_status(self) -> Dict[str, int]:
        """Get queue status with counts."""
        return {
            "pending": self.get_pending_count(),
            "processed": self.get_processed_count(),
        }

    def _find_request_file(self, saved_as: str):
        """Locate request JSON by saved_as in queue or processed."""
        for folder in (self.queue_dir, self.processed_dir):
            for req_file in folder.glob("upload-*.json"):
                try:
                    data = json.loads(req_file.read_text())
                except Exception:
                    continue
                if data.get("saved_as") == saved_as:
                    return req_file, data
        return None, None

    def get_status_by_saved_as(self, saved_as: str) -> Dict[str, Any]:
        """
        Return status info for a given saved_as.
        """
        req_file, data = self._find_request_file(saved_as)
        if not data:
            return {"saved_as": saved_as, "status": "unknown"}

        # Best effort: if in queue dir, treat pending/processing; if in processed -> completed/failed
        status = data.get("status", "unknown")
        if req_file and req_file.parent == self.queue_dir and status not in ("pending", "processing"):
            status = "pending"
        if req_file and req_file.parent == self.processed_dir and status not in ("completed", "failed"):
            status = "completed"

        return {
            "saved_as": data.get("saved_as", saved_as),
            "original_name": data.get("original_name", data.get("file_name")),
            "status": status,
            "request_id": data.get("request_id"),
        }

    def list_statuses(self, saved_as_list) -> Dict[str, str]:
        """
        Return map of saved_as -> status.
        """
        result = {}
        for name in saved_as_list:
            status_info = self.get_status_by_saved_as(name)
            result[name] = status_info.get("status", "unknown")
        return result
