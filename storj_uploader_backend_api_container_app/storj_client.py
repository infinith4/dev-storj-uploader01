#!/usr/bin/env python3
import subprocess
import os
import json
from pathlib import Path
from typing import Optional, Tuple, Iterator, List, Dict
import threading
import time
from datetime import datetime
from collections import defaultdict

try:
    from blob_storage import BlobStorageHelper
    BLOB_STORAGE_AVAILABLE = True
except ImportError:
    BlobStorageHelper = None
    BLOB_STORAGE_AVAILABLE = False
    print("Warning: azure-storage-blob not installed. Blob Storage功能will not be available.")

class StorjClient:
    """Storj Container Appとの連携クライアント"""

    def __init__(self, storj_app_path: str = None):
        # Dockerコンテナ内では /app/storj_container_app、開発環境では ../storj_container_app
        if storj_app_path is None:
            # 優先順位: 1. 絶対パス(Docker), 2. 相対パス(開発環境)
            if os.path.exists("/app/storj_container_app/storj_uploader.py"):
                storj_app_path = "/app/storj_container_app"
            elif os.path.exists("../storj_container_app/storj_uploader.py"):
                storj_app_path = "../storj_container_app"
            else:
                # フォールバック: ディレクトリの存在のみチェック
                if os.path.exists("/app/storj_container_app"):
                    storj_app_path = "/app/storj_container_app"
                else:
                    storj_app_path = "../storj_container_app"

        self.storj_app_path = Path(storj_app_path)
        self.storj_script = self.storj_app_path / "storj_uploader.py"
        self.lock = threading.Lock()
        self._rclone_config_path = None
        self._rclone_config_lock = threading.Lock()

        # 同時実行制限: rcloneコマンドの並行実行を最大5つに制限
        self.rclone_semaphore = threading.Semaphore(30)

        # 画像ごとのロック: 同じ画像を複数スレッドが同時生成しないようにする
        self.image_locks = defaultdict(threading.Lock)
        self.image_locks_lock = threading.Lock()

        # Blob Storage helper (常に初期化を試行)
        self.blob_helper = None
        if BLOB_STORAGE_AVAILABLE and BlobStorageHelper:
            try:
                self.blob_helper = BlobStorageHelper()
                print("✓ Blob Storage initialized successfully")
            except Exception as e:
                print(f"⚠ Failed to initialize Blob Storage: {e}")
                print("  Files will be stored locally instead")

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

    def _looks_like_rclone_config(self, value: str) -> bool:
        if "\n" in value:
            return True
        stripped = value.strip()
        if stripped.startswith("[") and "]" in stripped:
            return True
        if "type =" in value or "access_grant" in value:
            return True
        return False

    def _write_rclone_config_content(self, config_text: str) -> Optional[Path]:
        temp_dir = Path(os.getenv("TEMP_DIR", "/tmp"))
        try:
            temp_dir.mkdir(parents=True, exist_ok=True)
        except Exception as e:
            print(f"Failed to create temp dir for rclone config: {e}")
            return None

        temp_path = temp_dir / "rclone.conf"
        try:
            temp_path.write_text(config_text, encoding="utf-8")
            os.chmod(temp_path, 0o600)
            return temp_path
        except Exception as e:
            print(f"Failed to write rclone config content: {e}")
            return None

    def _get_rclone_config_path(self) -> Tuple[Optional[Path], Optional[str]]:
        with self._rclone_config_lock:
            if self._rclone_config_path and self._rclone_config_path.exists():
                return self._rclone_config_path, None

            searched_paths = []

            env_value = os.getenv("RCLONE_CONFIG")
            if env_value:
                looks_like_config = self._looks_like_rclone_config(env_value)
                if looks_like_config or len(env_value) > 256:
                    temp_path = self._write_rclone_config_content(env_value)
                    if temp_path and temp_path.exists():
                        self._rclone_config_path = temp_path
                        return temp_path, None
                else:
                    candidate = Path(env_value).expanduser()
                    try:
                        if candidate.is_file():
                            self._rclone_config_path = candidate
                            return candidate, None
                    except OSError as e:
                        print(f"Invalid rclone config path from env: {e}")

                    searched_paths.append(candidate)
                    if not candidate.is_absolute():
                        searched_paths.append((self.storj_app_path / candidate).resolve())

            default_paths = [
                Path.home() / ".config" / "rclone" / "rclone.conf",
                Path("/root/.config/rclone/rclone.conf"),
                Path("/app/config/rclone.conf"),
                self.storj_app_path / "rclone.conf",
                Path.cwd() / "rclone.conf"
            ]

            for path in default_paths:
                if path not in searched_paths:
                    searched_paths.append(path)

            for path in searched_paths:
                if path.exists():
                    self._rclone_config_path = path
                    return path, None

            message = "rclone.conf not found. Checked: " + ", ".join(str(path) for path in searched_paths)
            return None, message

    def _get_rclone_env(self, require_config: bool = True) -> Tuple[dict, Optional[str]]:
        env = os.environ.copy()
        rclone_conf, error_message = self._get_rclone_config_path()
        if rclone_conf and rclone_conf.exists():
            env["RCLONE_CONFIG"] = str(rclone_conf)
            return env, None
        if require_config:
            return env, error_message or "rclone.conf not found"
        return env, None

    def get_upload_target_dir(self) -> Path:
        """アップロード対象ディレクトリのパスを取得"""
        return self.storj_app_path / "upload_target"

    def get_uploaded_dir(self) -> Path:
        """アップロード済みディレクトリのパスを取得"""
        return self.storj_app_path / "uploaded"

    def count_files_in_target(self) -> int:
        """アップロード対象ディレクトリのファイル数を取得"""
        try:
            # Cloud環境ではBlob Storageのファイル数を取得
            if self.blob_helper:
                return self.blob_helper.get_blob_count()

            # Local環境ではファイルシステムを使用
            target_dir = self.get_upload_target_dir()
            if not target_dir.exists():
                return 0
            return len([f for f in target_dir.iterdir() if f.is_file()])
        except Exception as e:
            print(f"Error counting files: {e}")
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

                # 環境変数を準備 (rclone設定パスなど)
                env, error_message = self._get_rclone_env(require_config=False)
                if error_message:
                    print(f"Warning: {error_message}")

                # storj_container_appディレクトリで実行
                result = subprocess.run(
                    ["python3", str(self.storj_script)],
                    cwd=str(self.storj_app_path),
                    capture_output=True,
                    text=True,
                    timeout=300,  # 5分のタイムアウト
                    env=env
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
            if self.blob_helper:
                uploaded_files = self.blob_helper.get_blob_count(
                    container_name=self.blob_helper.uploaded_container
                )
            else:
                uploaded_files = len([f for f in uploaded_dir.iterdir() if f.is_file()]) if uploaded_dir.exists() else 0

            storj_app_local = self.check_storj_app_available()
            cloud_env = os.getenv("CLOUD_ENV", "").lower()
            storj_app_available = storj_app_local or (self.blob_helper and cloud_env == "azure")
            storj_app_mode = "local" if storj_app_local else ("blob" if self.blob_helper else "unknown")

            return {
                "storj_app_available": storj_app_available,
                "storj_app_mode": storj_app_mode,
                "storj_app_path": str(self.storj_app_path),
                "upload_target_dir": str(target_dir),
                "uploaded_dir": str(uploaded_dir),
                "files_in_target": target_files,
                "files_uploaded": uploaded_files,
                "target_dir_exists": target_dir.exists() or bool(self.blob_helper),
                "uploaded_dir_exists": uploaded_dir.exists() or bool(self.blob_helper)
            }
        except Exception as e:
            return {
                "error": str(e),
                "storj_app_available": False
            }

    def _list_blob_images(
        self,
        container_name: str,
        limit: int,
        offset: int,
        base_url: Optional[str]
    ) -> Tuple[bool, list, str]:
        if not self.blob_helper:
            return False, [], "Blob Storage not available"

        try:
            blobs = self.blob_helper.list_blobs_with_properties(
                container_name=container_name
            )

            images = []
            thumbnails = {}
            image_extensions = ('.jpg', '.jpeg', '.png', '.heic', '.webp', '.bmp', '.tiff', '.gif')
            video_extensions = ('.mp4', '.mov', '.avi', '.mkv', '.webm', '.m4v', '.3gp', '.flv', '.wmv')

            all_files = []
            for blob in blobs:
                path = blob.get("name", "")
                size = blob.get("size", 0) or 0
                mod_time = blob.get("last_modified", "") or ""
                if not path:
                    continue

                filename = path.split('/')[-1]

                if '_thumb_' in filename.lower() or filename.lower().endswith('_thumb.jpg'):
                    thumb_index = filename.lower().find('_thumb')
                    if thumb_index > 0:
                        video_stem = filename[:thumb_index]
                        thumbnails[video_stem.lower()] = path

                if path.lower().endswith(image_extensions) or path.lower().endswith(video_extensions):
                    all_files.append((path, size, mod_time))

            api_base_url = (base_url or os.getenv("API_BASE_URL") or "http://localhost:8010").rstrip("/")

            for path, size, mod_time in all_files:
                filename = path.split('/')[-1]
                if '_thumb_' in filename.lower() or filename.lower().endswith('_thumb.jpg'):
                    continue

                is_video = path.lower().endswith(video_extensions)
                full_url = f"{api_base_url}/storj/images/{path}?thumbnail=false"

                if is_video:
                    file_stem = filename.rsplit('.', 1)[0]
                    thumbnail_path = thumbnails.get(file_stem.lower())
                    if thumbnail_path:
                        thumbnail_url = f"{api_base_url}/storj/images/{thumbnail_path}?thumbnail=false"
                    else:
                        thumbnail_url = f"{api_base_url}/storj/images/{path}?thumbnail=true"
                else:
                    thumbnail_url = f"{api_base_url}/storj/images/{path}?thumbnail=true"

                images.append({
                    "filename": filename,
                    "path": path,
                    "size": size,
                    "modified_time": mod_time,
                    "thumbnail_url": thumbnail_url,
                    "url": full_url,
                    "is_video": is_video
                })

            total_count = len(images)
            paginated_images = images[offset:offset + limit]
            return True, paginated_images, f"Successfully retrieved {len(paginated_images)} images"

        except Exception as e:
            print(f"Error listing Blob images: {str(e)}")
            return False, [], str(e)

    def list_storj_images(
        self,
        bucket_name: str = None,
        limit: int = 100,
        offset: int = 0,
        base_url: str = None
    ) -> Tuple[bool, list, str]:
        """
        Storjからrcloneを使って画像リストを取得
        Returns: (success: bool, images: list, error_message: str)
        """
        try:
            gallery_source = os.getenv("GALLERY_SOURCE", "").lower()
            if gallery_source in ("azure", "blob", "storage"):
                container_name = os.getenv("AZURE_STORAGE_UPLOADED_CONTAINER", "uploaded")
                return self._list_blob_images(
                    container_name=container_name,
                    limit=limit,
                    offset=offset,
                    base_url=base_url
                )

            # .envから設定を取得
            if bucket_name is None:
                bucket_name = os.getenv("STORJ_BUCKET_NAME", "storj-upload-bucket")
            remote_name = os.getenv("STORJ_REMOTE_NAME", "storj")

            env, error_message = self._get_rclone_env()
            if error_message:
                return False, [], error_message

            # rclone lsf コマンドでファイルリストを取得
            # Format: path;size;time
            remote_path = f"{remote_name}:{bucket_name}/"
            cmd = [
                "rclone", "lsf",
                remote_path,
                "--format", "pst",
                "--recursive"
            ]

            print(f"[{datetime.now()}] Listing Storj images from {remote_path}")
            print(f"Command: {' '.join(cmd)}")

            result = subprocess.run(
                cmd,
                cwd=str(self.storj_app_path),
                env=env,
                capture_output=True,
                text=True,
                timeout=30
            )

            if result.returncode != 0:
                error_msg = result.stderr or "Unknown error"
                print(f"rclone lsf failed: {error_msg}")
                return False, [], error_msg

            # Parse output
            images = []
            thumbnails = {}  # サムネイルマップ: video_stem -> thumbnail_path
            image_extensions = ('.jpg', '.jpeg', '.png', '.heic', '.webp', '.bmp', '.tiff', '.gif')
            video_extensions = ('.mp4', '.mov', '.avi', '.mkv', '.webm', '.m4v', '.3gp', '.flv', '.wmv')

            # First pass: collect all files and identify thumbnails
            all_files = []
            for line in result.stdout.strip().split('\n'):
                if not line:
                    continue

                # Parse: path;size;time
                parts = line.split(';')
                if len(parts) != 3:
                    continue

                path, size_str, mod_time = parts
                filename = path.split('/')[-1]

                # Check if this is a thumbnail file (contains _thumb_)
                if '_thumb_' in filename.lower() or filename.lower().endswith('_thumb.jpg'):
                    # Extract the video stem (remove _thumb_hash.jpg or _thumb.jpg)
                    # For files like: VID_20251114_053243_20251114_065302_d50f7d78_thumb_a0fc57649b.jpg
                    # We want to match with: VID_20251114_053243_20251114_065302_d50f7d78.mp4
                    thumb_index = filename.lower().find('_thumb')
                    if thumb_index > 0:
                        video_stem = filename[:thumb_index]
                        thumbnails[video_stem.lower()] = path

                # Collect all media files (images and videos)
                if path.lower().endswith(image_extensions) or path.lower().endswith(video_extensions):
                    all_files.append((path, size_str, mod_time))

            # Second pass: process media files and link thumbnails
            for path, size_str, mod_time in all_files:
                filename = path.split('/')[-1]

                # Skip thumbnail files from the main list (contains _thumb_)
                if '_thumb_' in filename.lower() or filename.lower().endswith('_thumb.jpg'):
                    continue

                try:
                    size = int(size_str)
                except ValueError:
                    size = 0

                # Generate URLs for media access
                api_base_url = (base_url or os.getenv("API_BASE_URL") or "http://localhost:8010").rstrip("/")
                full_url = f"{api_base_url}/storj/images/{path}?thumbnail=false"

                # Determine thumbnail URL
                # For videos, check if a thumbnail exists
                is_video = path.lower().endswith(video_extensions)
                if is_video:
                    # Check if there's a corresponding thumbnail
                    file_stem = filename.rsplit('.', 1)[0]  # Remove extension
                    thumbnail_path = thumbnails.get(file_stem.lower())

                    if thumbnail_path:
                        # Use the thumbnail file
                        thumbnail_url = f"{api_base_url}/storj/images/{thumbnail_path}?thumbnail=false"
                    else:
                        # No thumbnail found, let the API generate on-demand
                        thumbnail_url = f"{api_base_url}/storj/images/{path}?thumbnail=true"
                else:
                    # For images, use the standard thumbnail parameter
                    thumbnail_url = f"{api_base_url}/storj/images/{path}?thumbnail=true"

                images.append({
                    "filename": filename,
                    "path": path,
                    "size": size,
                    "modified_time": mod_time,
                    "thumbnail_url": thumbnail_url,
                    "url": full_url,
                    "is_video": is_video
                })

            print(f"Found {len(images)} images in Storj")

            # Apply pagination
            total_count = len(images)
            paginated_images = images[offset:offset + limit]

            return True, paginated_images, f"Successfully retrieved {len(paginated_images)} images"

        except subprocess.TimeoutExpired:
            return False, [], "rclone command timed out"
        except Exception as e:
            print(f"Error listing Storj images: {str(e)}")
            return False, [], str(e)

    def _is_video_path(self, path: str) -> bool:
        if not path:
            return False
        video_extensions = (
            '.mp4', '.mov', '.avi', '.mkv', '.webm',
            '.m4v', '.3gp', '.flv', '.wmv'
        )
        return path.lower().endswith(video_extensions)

    def _thumbnail_key(self, path: str) -> str:
        return str(Path(path).with_suffix('')).lower()

    def _build_thumb_map(self, blob_names: List[str]) -> Dict[str, List[str]]:
        thumb_map: Dict[str, List[str]] = defaultdict(list)
        for name in blob_names:
            filename = Path(name).name
            lower = filename.lower()
            thumb_index = lower.find('_thumb')
            if thumb_index <= 0:
                continue
            base_filename = filename[:thumb_index]
            key = str(Path(name).with_name(base_filename)).lower()
            thumb_map[key].append(name)
        return thumb_map

    def _is_not_found_error(self, exc: Exception) -> bool:
        message = str(exc).lower()
        return "not found" in message or "resourcenotfound" in message

    def delete_gallery_paths(self, paths: List[str]) -> Tuple[bool, List[str], List[dict], str]:
        if not paths:
            return False, [], [], "No paths provided"

        gallery_source = os.getenv("GALLERY_SOURCE", "").lower()
        deleted: List[str] = []
        failed: List[dict] = []

        if gallery_source in ("azure", "blob", "storage") and self.blob_helper:
            container_name = os.getenv("AZURE_STORAGE_UPLOADED_CONTAINER", "uploaded")
            blob_props = self.blob_helper.list_blobs_with_properties(
                container_name=container_name
            )
            blob_names = [b.get("name") for b in blob_props if b.get("name")]
            thumb_map = self._build_thumb_map(blob_names)

            for path in paths:
                if not path:
                    failed.append({"path": path, "message": "Empty path"})
                    continue

                to_delete = [path]
                if self._is_video_path(path):
                    thumb_key = self._thumbnail_key(path)
                    to_delete.extend(thumb_map.get(thumb_key, []))

                for name in to_delete:
                    try:
                        self.blob_helper.delete_blob(
                            name,
                            container_name=container_name
                        )
                        deleted.append(name)
                    except Exception as e:
                        if name != path and self._is_not_found_error(e):
                            continue
                        failed.append({"path": name, "message": str(e)})

            success = len(failed) == 0
            message = f"Deleted {len(deleted)} item(s)"
            return success, deleted, failed, message

        # Default to Storj via rclone
        env, error_message = self._get_rclone_env()
        if error_message:
            return False, [], [{"path": "*", "message": error_message}], error_message

        if not paths:
            return False, [], [], "No paths provided"

        bucket_name = os.getenv("STORJ_BUCKET_NAME", "storj-upload-bucket")
        remote_name = os.getenv("STORJ_REMOTE_NAME", "storj")

        for path in paths:
            if not path:
                failed.append({"path": path, "message": "Empty path"})
                continue

            remote_path = f"{remote_name}:{bucket_name}/{path}"
            cmd = ["rclone", "deletefile", remote_path]
            result = subprocess.run(
                cmd,
                cwd=str(self.storj_app_path),
                env=env,
                capture_output=True,
                text=True,
                timeout=30
            )

            if result.returncode != 0:
                error_msg = result.stderr or "Unknown error"
                failed.append({"path": path, "message": error_msg})
                continue

            deleted.append(path)

            if self._is_video_path(path):
                # Thumbnail is in thumbnails/YYYYMM/ directory
                path_obj = Path(path)
                dir_name = path_obj.parent.name  # YYYYMM
                file_stem = path_obj.stem  # filename without extension
                thumb_path = f"thumbnails/{dir_name}/{file_stem}_thumb.jpg"
                thumb_remote_path = f"{remote_name}:{bucket_name}/{thumb_path}"
                thumb_cmd = ["rclone", "deletefile", thumb_remote_path]
                thumb_result = subprocess.run(
                    thumb_cmd,
                    cwd=str(self.storj_app_path),
                    env=env,
                    capture_output=True,
                    text=True,
                    timeout=30
                )
                if thumb_result.returncode != 0:
                    error_msg = thumb_result.stderr or "Unknown error"
                    if "not found" not in error_msg.lower():
                        failed.append({"path": thumb_path, "message": error_msg})
                else:
                    deleted.append(thumb_path)

        success = len(failed) == 0
        message = f"Deleted {len(deleted)} item(s)"
        return success, deleted, failed, message

    def get_storj_image(self, image_path: str, bucket_name: str = None) -> Tuple[bool, bytes, str]:
        """
        Storjから指定されたパスの画像を取得
        Returns: (success: bool, image_data: bytes, error_message: str)
        """
        # rcloneセマフォで同時実行数を制限
        with self.rclone_semaphore:
            try:
                # .envから設定を取得
                if bucket_name is None:
                    bucket_name = os.getenv("STORJ_BUCKET_NAME", "storj-upload-bucket")
                remote_name = os.getenv("STORJ_REMOTE_NAME", "storj")

                env, error_message = self._get_rclone_env()
                if error_message:
                    return False, b"", error_message

                # rclone cat コマンドでファイルを取得
                remote_path = f"{remote_name}:{bucket_name}/{image_path}"
                cmd = [
                    "rclone", "cat",
                    remote_path
                ]

                print(f"[{datetime.now()}] Fetching image from {remote_path}")

                result = subprocess.run(
                    cmd,
                    cwd=str(self.storj_app_path),
                    env=env,
                    capture_output=True,
                    timeout=60
                )

                if result.returncode != 0:
                    error_msg = result.stderr.decode('utf-8') if result.stderr else "Unknown error"
                    print(f"rclone cat failed: {error_msg}")
                    return False, b"", error_msg

                print(f"Successfully fetched image: {len(result.stdout)} bytes")
                return True, result.stdout, "Success"

            except subprocess.TimeoutExpired:
                return False, b"", "rclone command timed out"
            except Exception as e:
                print(f"Error fetching Storj image: {str(e)}")
                return False, b"", str(e)

    def download_storj_file_to_path(
        self,
        object_path: str,
        dest_path: Path,
        bucket_name: str = None,
        timeout: int = 300
    ) -> Tuple[bool, str]:
        """
        Storjファイルをローカルパスへダウンロード（メモリ使用を抑える）
        Returns: (success: bool, error_message: str)
        """
        try:
            if bucket_name is None:
                bucket_name = os.getenv("STORJ_BUCKET_NAME", "storj-upload-bucket")
            remote_name = os.getenv("STORJ_REMOTE_NAME", "storj")

            env, error_message = self._get_rclone_env()
            if error_message:
                return False, error_message

            remote_path = f"{remote_name}:{bucket_name}/{object_path}"
            cmd = [
                "rclone", "cat",
                remote_path
            ]

            dest_path.parent.mkdir(parents=True, exist_ok=True)
            with open(dest_path, "wb") as outfile:
                result = subprocess.run(
                    cmd,
                    cwd=str(self.storj_app_path),
                    env=env,
                    stdout=outfile,
                    stderr=subprocess.PIPE,
                    timeout=timeout
                )

            if result.returncode != 0:
                error_msg = result.stderr.decode("utf-8", errors="ignore") if result.stderr else "Unknown error"
                print(f"rclone cat failed: {error_msg}")
                if dest_path.exists():
                    dest_path.unlink()
                return False, error_msg

            if not dest_path.exists() or dest_path.stat().st_size == 0:
                if dest_path.exists():
                    dest_path.unlink()
                return False, "Downloaded file is empty"

            return True, "Success"

        except subprocess.TimeoutExpired:
            if dest_path.exists():
                dest_path.unlink()
            return False, "rclone command timed out"
        except Exception as e:
            print(f"Error downloading Storj file: {str(e)}")
            if dest_path.exists():
                dest_path.unlink()
            return False, str(e)

    def get_storj_object_info(self, object_path: str, bucket_name: str = None) -> Tuple[bool, dict, str]:
        """
        Storjオブジェクトのメタ情報を取得 (サイズなど)
        Returns: (success: bool, info: dict, error_message: str)
        """
        try:
            if bucket_name is None:
                bucket_name = os.getenv("STORJ_BUCKET_NAME", "storj-upload-bucket")
            remote_name = os.getenv("STORJ_REMOTE_NAME", "storj")

            env, error_message = self._get_rclone_env()
            if error_message:
                return False, {}, error_message

            remote_path = f"{remote_name}:{bucket_name}/{object_path}"
            cmd = [
                "rclone", "lsjson",
                "--stat",
                remote_path
            ]

            result = subprocess.run(
                cmd,
                cwd=str(self.storj_app_path),
                env=env,
                capture_output=True,
                text=True,
                timeout=30
            )

            if result.returncode != 0:
                error_msg = result.stderr or "Unknown error"
                print(f"rclone lsjson failed: {error_msg}")
                return False, {}, error_msg

            info = json.loads(result.stdout)
            if not isinstance(info, dict):
                return False, {}, "Invalid lsjson response"

            return True, info, "Success"

        except subprocess.TimeoutExpired:
            return False, {}, "rclone command timed out"
        except Exception as e:
            print(f"Error fetching Storj object info: {str(e)}")
            return False, {}, str(e)

    def stream_storj_file(
        self,
        object_path: str,
        bucket_name: str = None,
        offset: int = None,
        count: int = None
    ) -> Tuple[bool, Iterator[bytes], str]:
        """
        Storjのファイルをストリームで取得
        Returns: (success: bool, iterator: Iterator[bytes], error_message: str)
        """
        try:
            if bucket_name is None:
                bucket_name = os.getenv("STORJ_BUCKET_NAME", "storj-upload-bucket")
            remote_name = os.getenv("STORJ_REMOTE_NAME", "storj")

            env, error_message = self._get_rclone_env()
            if error_message:
                return False, iter(()), error_message

            remote_path = f"{remote_name}:{bucket_name}/{object_path}"
            cmd = [
                "rclone", "cat",
                remote_path
            ]
            if offset is not None:
                cmd.extend(["--offset", str(offset)])
            if count is not None:
                cmd.extend(["--count", str(count)])

            proc = subprocess.Popen(
                cmd,
                cwd=str(self.storj_app_path),
                env=env,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE
            )

            def iterator() -> Iterator[bytes]:
                try:
                    if not proc.stdout:
                        return
                    for chunk in iter(lambda: proc.stdout.read(1024 * 1024), b""):
                        yield chunk
                finally:
                    if proc.stdout:
                        proc.stdout.close()
                    stderr = None
                    if proc.stderr:
                        stderr = proc.stderr.read()
                        proc.stderr.close()
                    return_code = proc.wait()
                    if return_code != 0:
                        error_detail = stderr.decode("utf-8", errors="ignore") if stderr else ""
                        print(f"rclone cat failed: {error_detail or return_code}")

            return True, iterator(), "Success"

        except Exception as e:
            print(f"Error streaming Storj file: {str(e)}")
            return False, iter(()), str(e)

    def get_storj_thumbnail(self, image_path: str, bucket_name: str = None, size: tuple = (300, 300)) -> Tuple[bool, bytes, str]:
        """
        Storjから事前生成されたサムネイルを取得
        サムネイルが存在しない場合は生成する（旧データ用のフォールバック）
        Returns: (success: bool, thumbnail_data: bytes, error_message: str)
        """
        # 画像ごとのロックを取得（同じ画像への並行アクセスを防ぐ）
        with self.image_locks_lock:
            image_lock = self.image_locks[image_path]

        # この画像専用のロックを取得
        with image_lock:
            try:
                # .envから設定を取得
                if bucket_name is None:
                    bucket_name = os.getenv("STORJ_BUCKET_NAME", "storj-upload-bucket")
                remote_name = os.getenv("STORJ_REMOTE_NAME", "storj")

                env, error_message = self._get_rclone_env()
                if error_message:
                    return False, b"", error_message

                # サムネイルファイル名を生成（拡張子を.jpgに変更）
                thumbnail_path = "thumbnails/" + image_path.rsplit('.', 1)[0] + '.jpg'

                # キャッシュディレクトリのパス
                cache_dir = Path(__file__).parent / "thumbnail_cache"
                cache_dir.mkdir(exist_ok=True)

                # キャッシュファイル名を生成（パスをエンコード）
                cache_filename = image_path.replace("/", "_").replace("\\", "_")
                cache_path = cache_dir / cache_filename

                # キャッシュが存在する場合は返す
                if cache_path.exists() and cache_path.stat().st_size > 0:
                    print(f"[{datetime.now()}] Serving cached thumbnail for {image_path}")
                    with open(cache_path, 'rb') as f:
                        return True, f.read(), "Success (cached)"

                # rcloneセマフォで同時実行数を制限
                with self.rclone_semaphore:
                    # Storjからサムネイルを取得
                    remote_path = f"{remote_name}:{bucket_name}/{thumbnail_path}"
                    cmd = [
                        "rclone", "cat",
                        remote_path
                    ]

                    print(f"[{datetime.now()}] Fetching thumbnail from {remote_path}")

                    result = subprocess.run(
                        cmd,
                        cwd=str(self.storj_app_path),
                        env=env,
                        capture_output=True,
                        timeout=30
                    )

                    if result.returncode == 0 and len(result.stdout) > 0:
                        # サムネイルが存在する場合
                        print(f"[{datetime.now()}] Successfully fetched thumbnail: {len(result.stdout)} bytes")
                        return True, result.stdout, "Success (pre-generated)"
                    else:
                        # サムネイルが存在しない場合（旧データ）、オンデマンドで生成
                        if result.returncode == 0:
                            print(f"[{datetime.now()}] Thumbnail is empty (0 bytes), generating on-demand for {image_path}")
                        else:
                            print(f"[{datetime.now()}] Thumbnail not found, generating on-demand for {image_path}")

                        # 元画像を取得してリサイズ
                        success, image_data, error_msg = self.get_storj_image(image_path, bucket_name)

                        if not success:
                            return False, b"", error_msg

                        # Pillowで画像をリサイズ
                        from PIL import Image
                        import io

                        try:
                            # 画像を開く
                            img = Image.open(io.BytesIO(image_data))

                            # サムネイルを生成（アスペクト比を維持）
                            img.thumbnail(size, Image.Resampling.LANCZOS)

                            # JPEGとして保存（元の形式に関わらず）
                            output = io.BytesIO()
                            # RGBAの場合はRGBに変換
                            if img.mode in ('RGBA', 'LA', 'P'):
                                img = img.convert('RGB')
                            img.save(output, format='JPEG', quality=85, optimize=True)
                            thumbnail_data = output.getvalue()

                            # キャッシュに保存（アトミックな書き込み）
                            temp_cache_path = cache_path.with_suffix('.tmp')
                            with open(temp_cache_path, 'wb') as f:
                                f.write(thumbnail_data)
                            # アトミックに移動
                            temp_cache_path.replace(cache_path)

                            print(f"[{datetime.now()}] Thumbnail generated and cached: {len(thumbnail_data)} bytes")
                            return True, thumbnail_data, "Success (generated on-demand)"

                        except Exception as e:
                            print(f"Error generating thumbnail: {str(e)}")
                            # サムネイル生成に失敗した場合は元画像を返す
                            return True, image_data, f"Success (original - thumbnail failed: {str(e)})"

            except subprocess.TimeoutExpired:
                return False, b"", "rclone command timed out"
            except Exception as e:
                print(f"Error in get_storj_thumbnail: {str(e)}")
                return False, b"", str(e)

    def get_storj_thumbnail_by_prefix(
        self,
        video_stem: str,
        dir_name: str,
        bucket_name: str = None
    ) -> Tuple[bool, bytes, str]:
        """
        Storjからプレフィックスマッチでサムネイルを検索して取得
        サムネイル形式: thumbnails/YYYYMM/{video_stem}_thumb_{hash}.jpg
        Returns: (success: bool, thumbnail_data: bytes, error_message: str)
        """
        with self.rclone_semaphore:
            try:
                if bucket_name is None:
                    bucket_name = os.getenv("STORJ_BUCKET_NAME", "storj-upload-bucket")
                remote_name = os.getenv("STORJ_REMOTE_NAME", "storj")

                env, error_message = self._get_rclone_env()
                if error_message:
                    return False, b"", error_message

                # Search for thumbnail with prefix: thumbnails/YYYYMM/{video_stem}_thumb
                thumbnail_prefix = f"thumbnails/{dir_name}/{video_stem}_thumb"
                remote_path = f"{remote_name}:{bucket_name}/{thumbnail_prefix}"

                # Use rclone lsf to find matching files
                cmd = [
                    "rclone", "lsf",
                    remote_path,
                    "--max-depth", "1"
                ]

                print(f"[{datetime.now()}] Searching for thumbnail with prefix: {thumbnail_prefix}")

                result = subprocess.run(
                    cmd,
                    cwd=str(self.storj_app_path),
                    env=env,
                    capture_output=True,
                    text=True,
                    timeout=30
                )

                # Parse the result to find matching thumbnail files
                matching_files = []
                if result.returncode == 0 and result.stdout.strip():
                    for line in result.stdout.strip().split('\n'):
                        if line and line.endswith('.jpg'):
                            # Full path: thumbnails/YYYYMM/{video_stem}_thumb_{hash}.jpg
                            full_path = f"thumbnails/{dir_name}/{video_stem}_thumb{line}"
                            matching_files.append(full_path)

                if not matching_files:
                    # Try alternative: list the thumbnails directory and filter
                    alt_remote_path = f"{remote_name}:{bucket_name}/thumbnails/{dir_name}/"
                    alt_cmd = [
                        "rclone", "lsf",
                        alt_remote_path,
                        "--max-depth", "1"
                    ]

                    alt_result = subprocess.run(
                        alt_cmd,
                        cwd=str(self.storj_app_path),
                        env=env,
                        capture_output=True,
                        text=True,
                        timeout=30
                    )

                    if alt_result.returncode == 0 and alt_result.stdout.strip():
                        for line in alt_result.stdout.strip().split('\n'):
                            # Check if file matches {video_stem}_thumb pattern
                            if line and line.startswith(f"{video_stem}_thumb") and line.endswith('.jpg'):
                                full_path = f"thumbnails/{dir_name}/{line}"
                                matching_files.append(full_path)

                if not matching_files:
                    print(f"[{datetime.now()}] No thumbnail found for prefix: {thumbnail_prefix}")
                    return False, b"", "Thumbnail not found"

                # Get the first matching thumbnail
                thumbnail_path = matching_files[0]
                print(f"[{datetime.now()}] Found thumbnail: {thumbnail_path}")

                # Fetch the thumbnail
                fetch_remote_path = f"{remote_name}:{bucket_name}/{thumbnail_path}"
                fetch_cmd = ["rclone", "cat", fetch_remote_path]

                fetch_result = subprocess.run(
                    fetch_cmd,
                    cwd=str(self.storj_app_path),
                    env=env,
                    capture_output=True,
                    timeout=60
                )

                if fetch_result.returncode == 0 and len(fetch_result.stdout) > 0:
                    print(f"[{datetime.now()}] Successfully fetched thumbnail from Storj: {len(fetch_result.stdout)} bytes")
                    return True, fetch_result.stdout, f"Success (path: {thumbnail_path})"
                else:
                    error_msg = fetch_result.stderr.decode('utf-8') if fetch_result.stderr else "Unknown error"
                    print(f"[{datetime.now()}] Failed to fetch thumbnail: {error_msg}")
                    return False, b"", error_msg

            except subprocess.TimeoutExpired:
                return False, b"", "rclone command timed out"
            except Exception as e:
                print(f"Error in get_storj_thumbnail_by_prefix: {str(e)}")
                return False, b"", str(e)
