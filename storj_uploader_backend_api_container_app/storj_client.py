#!/usr/bin/env python3
import subprocess
import os
from pathlib import Path
from typing import Optional, Tuple
import threading
import time
from datetime import datetime

class StorjClient:
    """Storj Container Appとの連携クライアント"""

    def __init__(self, storj_app_path: str = None):
        # Dockerコンテナ内では /app/storj_container_app、開発環境では ../storj_container_app
        if storj_app_path is None:
            if os.path.exists("/app/storj_container_app"):
                storj_app_path = "/app/storj_container_app"
            else:
                storj_app_path = "../storj_container_app"

        self.storj_app_path = Path(storj_app_path)
        self.storj_script = self.storj_app_path / "storj_uploader.py"
        self.lock = threading.Lock()

    def check_storj_app_available(self) -> bool:
        """Storj Container Appが利用可能かチェック"""
        exists = self.storj_script.exists()
        print(f"Storj script path: {self.storj_script}")
        print(f"Storj script exists: {exists}")
        if not exists:
            print(f"Storj app directory: {self.storj_app_path}")
            print(f"Storj app directory exists: {self.storj_app_path.exists()}")
            if self.storj_app_path.exists():
                print(f"Contents: {list(self.storj_app_path.iterdir())}")
        return exists

    def get_upload_target_dir(self) -> Path:
        """アップロード対象ディレクトリのパスを取得"""
        return self.storj_app_path / "upload_target"

    def get_uploaded_dir(self) -> Path:
        """アップロード済みディレクトリのパスを取得"""
        return self.storj_app_path / "uploaded"

    def count_files_in_target(self) -> int:
        """アップロード対象ディレクトリのファイル数を取得"""
        try:
            target_dir = self.get_upload_target_dir()
            if not target_dir.exists():
                return 0
            return len([f for f in target_dir.iterdir() if f.is_file()])
        except Exception:
            return 0

    def run_storj_uploader(self) -> Tuple[bool, str]:
        """
        Storj uploader scriptを実行
        Returns: (success: bool, output: str)
        """
        if not self.check_storj_app_available():
            return False, "Storj uploader script not found"

        try:
            with self.lock:
                print(f"[{datetime.now()}] Starting Storj uploader process...")
                print(f"Working directory: {self.storj_app_path}")
                print(f"Script path: {self.storj_script}")

                # storj_container_appディレクトリで実行
                result = subprocess.run(
                    ["python3", str(self.storj_script)],
                    cwd=str(self.storj_app_path),
                    capture_output=True,
                    text=True,
                    timeout=300  # 5分のタイムアウト
                )

                if result.returncode == 0:
                    print(f"[{datetime.now()}] Storj uploader completed successfully")
                    return True, result.stdout
                else:
                    print(f"[{datetime.now()}] Storj uploader failed: {result.stderr}")
                    return False, result.stderr

        except subprocess.TimeoutExpired:
            return False, "Storj uploader process timed out"
        except Exception as e:
            return False, f"Error running storj uploader: {str(e)}"

    def run_storj_uploader_async(self) -> None:
        """
        Storj uploaderを非同期で実行（バックグラウンド処理）
        """
        def _run_async():
            success, output = self.run_storj_uploader()
            if success:
                print(f"Background Storj upload completed: {output}")
            else:
                print(f"Background Storj upload failed: {output}")

        thread = threading.Thread(target=_run_async, daemon=True)
        thread.start()
        return thread

    def trigger_upload_if_files_exist(self) -> Tuple[bool, str]:
        """
        ファイルが存在する場合にアップロードを実行
        """
        file_count = self.count_files_in_target()
        if file_count == 0:
            return True, "No files to upload"

        return self.run_storj_uploader()

    def get_status(self) -> dict:
        """
        Storj Container Appの状態を取得
        """
        target_dir = self.get_upload_target_dir()
        uploaded_dir = self.get_uploaded_dir()

        try:
            target_files = self.count_files_in_target()
            uploaded_files = len([f for f in uploaded_dir.iterdir() if f.is_file()]) if uploaded_dir.exists() else 0

            return {
                "storj_app_available": self.check_storj_app_available(),
                "storj_app_path": str(self.storj_app_path),
                "upload_target_dir": str(target_dir),
                "uploaded_dir": str(uploaded_dir),
                "files_in_target": target_files,
                "files_uploaded": uploaded_files,
                "target_dir_exists": target_dir.exists(),
                "uploaded_dir_exists": uploaded_dir.exists()
            }
        except Exception as e:
            return {
                "error": str(e),
                "storj_app_available": False
            }