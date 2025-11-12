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
            image_extensions = ('.jpg', '.jpeg', '.png', '.heic', '.webp', '.bmp', '.tiff', '.gif')

            for line in result.stdout.strip().split('\n'):
                if not line:
                    continue

                # Parse: path;size;time
                parts = line.split(';')
                if len(parts) != 3:
                    continue

                path, size_str, mod_time = parts

                # Filter image files only
                if not path.lower().endswith(image_extensions):
                    continue

                filename = path.split('/')[-1]

                try:
                    size = int(size_str)
                except ValueError:
                    size = 0

                # Generate URLs for image access
                # Use environment variable or default to localhost
                api_base_url = os.getenv("API_BASE_URL", "http://10.0.2.2:8010")
                image_url = f"{api_base_url}/storj/images/{path}"

                images.append({
                    "filename": filename,
                    "path": path,
                    "size": size,
                    "modified_time": mod_time,
                    "thumbnail_url": image_url,  # Use same URL for thumbnail (can be optimized later)
                    "url": image_url
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

                # キャッシュディレクトリのパス
                cache_dir = Path(__file__).parent / "thumbnail_cache"
                cache_dir.mkdir(exist_ok=True)

                # キャッシュファイル名を生成（パスをエンコード）
                cache_filename = image_path.replace("/", "_").replace("\\", "_")
                cache_path = cache_dir / cache_filename

                # キャッシュが存在する場合は返す
                if cache_path.exists():
                    print(f"[{datetime.now()}] Serving cached thumbnail for {image_path}")
                    with open(cache_path, 'rb') as f:
                        return True, f.read(), "Success (cached)"

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

                    # キャッシュに保存
                    with open(cache_path, 'wb') as f:
                        f.write(thumbnail_data)

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