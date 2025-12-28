#!/usr/bin/env python3
import subprocess
import os
from pathlib import Path
from typing import Optional, Tuple
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
                env = os.environ.copy()

                # rclone.confのパスを設定
                rclone_conf = self.storj_app_path / "rclone.conf"
                if rclone_conf.exists():
                    env['RCLONE_CONFIG'] = str(rclone_conf)

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

    def list_storj_images(self, bucket_name: str = None, limit: int = 100, offset: int = 0) -> Tuple[bool, list, str]:
        """
        Storjからrcloneを使って画像リストを取得
        Returns: (success: bool, images: list, error_message: str)
        """
        try:
            # .envから設定を取得
            if bucket_name is None:
                bucket_name = os.getenv("STORJ_BUCKET_NAME", "storj-upload-bucket")
            remote_name = os.getenv("STORJ_REMOTE_NAME", "storj")

            # rclone.confのパスを設定
            rclone_conf = self.storj_app_path / "rclone.conf"
            if not rclone_conf.exists():
                return False, [], f"rclone.conf not found at {rclone_conf}"

            env = os.environ.copy()
            env["RCLONE_CONFIG"] = str(rclone_conf)

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
                api_base_url = os.getenv("API_BASE_URL", "http://10.0.2.2:8010")
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
                        # No thumbnail found, use the video itself
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

                # rclone.confのパスを設定
                rclone_conf = self.storj_app_path / "rclone.conf"
                if not rclone_conf.exists():
                    return False, b"", f"rclone.conf not found at {rclone_conf}"

                env = os.environ.copy()
                env["RCLONE_CONFIG"] = str(rclone_conf)

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

                # rclone.confのパスを設定
                rclone_conf = self.storj_app_path / "rclone.conf"
                if not rclone_conf.exists():
                    return False, b"", f"rclone.conf not found at {rclone_conf}"

                env = os.environ.copy()
                env["RCLONE_CONFIG"] = str(rclone_conf)

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