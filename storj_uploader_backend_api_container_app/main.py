#!/usr/bin/env python3
"""
Storj Uploader Backend API

FastAPI + OpenAPI v3対応のファイルアップロードAPI
HEICやJPEGなどの画像ファイル、動画ファイル、その他すべてのファイル形式に対応
"""
from fastapi import FastAPI, File, UploadFile, HTTPException, BackgroundTasks, Request
from fastapi.responses import JSONResponse, Response, StreamingResponse
from fastapi.middleware.cors import CORSMiddleware
import os
import shutil
from pathlib import Path
from typing import List
import uuid
import tempfile
from datetime import datetime
import hashlib
import aiofiles
from PIL import Image
import io
from dotenv import load_dotenv
from storj_client import StorjClient
from video_processor import VideoProcessor
from models import (
    UploadResponse, HealthResponse, StatusResponse, TriggerUploadResponse,
    ErrorResponse, FileUploadResult, FileInfo, FileStatus,
    StorjImageListResponse, StorjImageItem
)

VIDEO_MIME_TYPES = {
    ".mp4": "video/mp4",
    ".mov": "video/quicktime",
    ".avi": "video/x-msvideo",
    ".mkv": "video/x-matroska",
    ".webm": "video/webm",
    ".m4v": "video/x-m4v",
    ".3gp": "video/3gpp",
    ".flv": "video/x-flv",
    ".wmv": "video/x-ms-wmv"
}


def _parse_range_header(range_header: str, file_size: int):
    if not range_header or not range_header.startswith("bytes="):
        return None

    range_spec = range_header.replace("bytes=", "", 1).strip()
    if "," in range_spec:
        range_spec = range_spec.split(",", 1)[0].strip()

    if range_spec.startswith("-"):
        try:
            suffix_length = int(range_spec[1:])
        except ValueError:
            return None
        if suffix_length <= 0:
            return None
        start = max(file_size - suffix_length, 0)
        end = file_size - 1
        return start, end

    start_str, _, end_str = range_spec.partition("-")
    try:
        start = int(start_str)
    except ValueError:
        return None

    if start >= file_size:
        return None

    if end_str:
        try:
            end = int(end_str)
        except ValueError:
            return None
        end = min(end, file_size - 1)
    else:
        end = file_size - 1

    if end < start:
        return None

    return start, end


def _get_video_content_type(filename: str) -> str:
    ext = Path(filename).suffix.lower()
    return VIDEO_MIME_TYPES.get(ext, "application/octet-stream")


def _generate_video_thumbnail(
    video_path: str,
    bucket: str,
    width: int = 320,
    height: int = 240
) -> tuple:
    cache_dir = Path(__file__).parent / "thumbnail_cache"
    cache_dir.mkdir(exist_ok=True)
    cache_filename = video_path.replace("/", "_").replace("\\", "_")
    cache_path = cache_dir / cache_filename

    if cache_path.exists() and cache_path.stat().st_size > 0:
        return True, cache_path.read_bytes(), "Success (cached)"

    success, video_data, error_msg = storj_client.get_storj_image(
        image_path=video_path,
        bucket_name=bucket
    )
    if not success:
        return False, b"", error_msg

    temp_dir = Path(os.getenv("TEMP_DIR", "./temp"))
    temp_dir.mkdir(exist_ok=True, parents=True)

    temp_video = None
    temp_thumb = None
    try:
        with tempfile.NamedTemporaryFile(
            dir=temp_dir,
            suffix=Path(video_path).suffix or ".mp4",
            delete=False
        ) as temp_file:
            temp_video = Path(temp_file.name)
            temp_file.write(video_data)

        temp_thumb = temp_dir / f"{uuid.uuid4().hex}_thumb.jpg"

        generated = VideoProcessor.generate_thumbnail(
            str(temp_video),
            str(temp_thumb),
            width=width,
            height=height,
            method="ffmpeg"
        )

        if not generated or not temp_thumb.exists():
            return False, b"", "Failed to generate video thumbnail"

        thumb_data = temp_thumb.read_bytes()
        if not thumb_data:
            return False, b"", "Generated thumbnail is empty"

        temp_cache_path = cache_path.with_name(cache_path.name + ".tmp")
        with open(temp_cache_path, "wb") as cache_file:
            cache_file.write(thumb_data)
        temp_cache_path.replace(cache_path)

        return True, thumb_data, "Success (generated)"
    finally:
        if temp_video and temp_video.exists():
            temp_video.unlink()
        if temp_thumb and temp_thumb.exists():
            temp_thumb.unlink()

try:
    from blob_storage import BlobStorageHelper
    BLOB_STORAGE_AVAILABLE = True
except ImportError:
    BlobStorageHelper = None
    BLOB_STORAGE_AVAILABLE = False
    print("Warning: azure-storage-blob not installed. Blob Storage functions will not be available.")

# Load environment variables from storj_container_app/.env
load_dotenv()  # Load from current directory first
storj_env_path = Path(__file__).parent / "../storj_container_app/.env"
if storj_env_path.exists():
    load_dotenv(storj_env_path)  # Override with storj_container_app settings

# OpenAPI v3メタデータ設定
app = FastAPI(
    title="Storj Uploader Backend API",
    description="""
    ## Storj Uploader Backend API

    HEICやJPEGなどの画像ファイル、動画ファイル、その他すべてのファイル形式をアップロードして、
    Storj Container Appと連携してStorjにアップロードするバックエンドAPIです。

    ### 主な機能
    - 🖼️ **画像ファイル専用アップロード** (HEIC, JPEG, PNG, WebP等)
    - 📹 **汎用ファイルアップロード** (動画、音声、ドキュメント等すべてのファイル形式)
    - 🔄 **Storj Container App連携** (自動アップロード処理)
    - ⚡ **バックグラウンド処理** (非同期アップロード)
    - 🚀 **自動トリガー** (5ファイル蓄積時の自動アップロード)

    ### API使用例
    ```bash
    # 画像ファイルアップロード
    curl -X POST "/upload" -F "files=@image.heic"

    # 動画ファイルアップロード
    curl -X POST "/upload/files" -F "files=@video.mp4"
    ```
    """,
    version="1.0.0",
    contact={
        "name": "Storj Uploader API Support",
        "email": "support@example.com",
    },
    license_info={
        "name": "MIT",
        "url": "https://opensource.org/licenses/MIT",
    },
    openapi_tags=[
        {
            "name": "images",
            "description": "画像ファイル専用アップロード操作",
        },
        {
            "name": "files",
            "description": "汎用ファイルアップロード操作（すべてのファイル形式対応）",
        },
        {
            "name": "system",
            "description": "システム管理・ステータス確認",
        },
        {
            "name": "storj",
            "description": "Storjアップロード管理",
        },
    ]
)

# Storjクライアント初期化
storj_client = StorjClient()

# Blob Storage初期化
blob_helper = None
if BLOB_STORAGE_AVAILABLE and BlobStorageHelper:
    try:
        blob_helper = BlobStorageHelper()
        print("✓ Blob Storage initialized successfully in main.py")
    except Exception as e:
        print(f"⚠ Failed to initialize Blob Storage in main.py: {e}")
        print("  Files will be stored locally instead")

# CORS設定
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost:9010",
        "http://localhost:3000",  # 開発環境 (React)
        "http://localhost:8080",  # 開発環境 (Flutter)
        "http://127.0.0.1:9010",
        "http://127.0.0.1:3000",
        "http://127.0.0.1:8080",
        # Azure Container Apps URLs
        "https://stjup2-frontend-udm3tutq7eb7i.yellowplant-e4c48860.japaneast.azurecontainerapps.io",
        "https://stjup2-backend-udm3tutq7eb7i.yellowplant-e4c48860.japaneast.azurecontainerapps.io",
    ],
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allow_headers=["*"],
)

# 設定
UPLOAD_TARGET_DIR = storj_client.get_upload_target_dir()
TEMP_DIR = Path(os.getenv('TEMP_DIR', './temp'))
MAX_FILE_SIZE = int(os.getenv('MAX_FILE_SIZE', '100000000'))  # 100MB
SUPPORTED_IMAGE_FORMATS = {'jpeg', 'jpg', 'png', 'heic', 'heif', 'webp', 'bmp', 'tiff'}

# ディレクトリ作成
UPLOAD_TARGET_DIR.mkdir(exist_ok=True, parents=True)
TEMP_DIR.mkdir(exist_ok=True, parents=True)

class ImageProcessor:
    """画像処理クラス"""

    @staticmethod
    def is_supported_format(filename: str) -> bool:
        """サポートされている画像形式かチェック"""
        return filename.lower().split('.')[-1] in SUPPORTED_IMAGE_FORMATS

    @staticmethod
    def validate_image(file_content: bytes) -> bool:
        """画像ファイルの検証"""
        try:
            with Image.open(io.BytesIO(file_content)) as img:
                img.verify()
            return True
        except Exception:
            return False

    @staticmethod
    def generate_unique_filename(original_filename: str) -> str:
        """一意のファイル名を生成"""
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        unique_id = str(uuid.uuid4())[:8]
        name, ext = os.path.splitext(original_filename)
        return f"{name}_{timestamp}_{unique_id}{ext}"

class FileProcessor:
    """汎用ファイル処理クラス（動画・その他ファイル用）"""

    @staticmethod
    def validate_file_basic(file_content: bytes, filename: str) -> bool:
        """基本的なファイル検証（空ファイルチェック等）"""
        if not file_content or len(file_content) == 0:
            return False

        # ファイル名の基本検証
        if not filename or len(filename.strip()) == 0:
            return False

        return True

    @staticmethod
    def generate_unique_filename(original_filename: str) -> str:
        """一意のファイル名を生成"""
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        unique_id = str(uuid.uuid4())[:8]
        name, ext = os.path.splitext(original_filename)
        return f"{name}_{timestamp}_{unique_id}{ext}"

    @staticmethod
    def get_file_info(filename: str, file_size: int) -> dict:
        """ファイル情報を取得"""
        name, ext = os.path.splitext(filename)
        return {
            "original_name": filename,
            "name": name,
            "extension": ext.lower() if ext else "",
            "size_bytes": file_size,
            "size_mb": round(file_size / (1024 * 1024), 2)
        }

async def save_file_to_target(file_path: Path, target_path: Path):
    """ファイルをターゲットディレクトリに移動し、必要に応じてアップロードをトリガー"""
    try:
        # Blob Storageが利用可能な場合はBlobにアップロード、そうでなければローカルに移動
        if blob_helper:
            try:
                # Blobにアップロード
                blob_name = target_path.name
                blob_helper.upload_file(str(file_path), blob_name)
                print(f"✓ File uploaded to Blob Storage: {blob_name}")

                # アップロード後、ローカルファイルを削除
                if file_path.exists():
                    file_path.unlink()

            except Exception as blob_error:
                print(f"⚠ Blob Storage upload failed: {blob_error}")
                print(f"  Falling back to local filesystem")
                # フォールバック: ローカルファイルシステムに移動
                shutil.move(str(file_path), str(target_path))
                print(f"File moved to target directory: {target_path}")
        else:
            # Blob Storageが利用不可の場合はローカルに移動
            shutil.move(str(file_path), str(target_path))
            print(f"File moved to target directory: {target_path}")

        # 動画ファイルの場合、サムネイルを生成
        # Note: サムネイル生成はローカルファイルが必要なため、Blob Storageモードでは一時的にダウンロードが必要
        video_filename = target_path.name
        if VideoProcessor.is_video_file(video_filename):
            print(f"Generating thumbnail for video: {video_filename}")
            try:
                # Blob Storageからダウンロードしてサムネイル生成
                if blob_helper and blob_helper.blob_exists(video_filename):
                    # 一時ファイルにダウンロード
                    temp_video_path = TEMP_DIR / video_filename
                    blob_helper.download_file(video_filename, str(temp_video_path))
                    video_file_path = temp_video_path
                else:
                    # ローカルファイルを使用
                    video_file_path = target_path

                # サムネイルのファイル名を生成 (basename_thumb.jpg)
                video_stem = Path(video_filename).stem  # 拡張子なしのファイル名
                thumbnail_filename = f"{video_stem}_thumb.jpg"
                thumbnail_path = TEMP_DIR / thumbnail_filename

                # サムネイル生成
                success = VideoProcessor.generate_thumbnail(
                    str(video_file_path),
                    str(thumbnail_path),
                    width=320,
                    height=240
                )

                if success:
                    print(f"✓ Thumbnail generated: {thumbnail_filename}")
                    # サムネイルもBlobにアップロード
                    if blob_helper:
                        try:
                            blob_helper.upload_file(str(thumbnail_path), thumbnail_filename)
                            print(f"✓ Thumbnail uploaded to Blob Storage: {thumbnail_filename}")
                            thumbnail_path.unlink()  # アップロード後削除
                        except Exception as thumb_upload_error:
                            print(f"⚠ Failed to upload thumbnail to Blob: {thumb_upload_error}")
                else:
                    print(f"✗ Failed to generate thumbnail for: {video_filename}")

                # 一時ダウンロードしたファイルを削除
                if blob_helper and temp_video_path.exists():
                    temp_video_path.unlink()

            except Exception as thumb_error:
                print(f"Error generating thumbnail: {thumb_error}")

        # ファイル数が5個以上になったら自動的にアップロードを実行
        file_count = storj_client.count_files_in_target()
        if file_count >= 5:
            print(f"Auto-triggering upload for {file_count} files")
            storj_client.run_storj_uploader_async()

    except Exception as e:
        print(f"Error moving file to target: {e}")
        if file_path.exists():
            file_path.unlink()

@app.post(
    "/upload",
    response_model=UploadResponse,
    tags=["images"],
    summary="画像ファイル複数アップロード",
    description="""
    複数の画像ファイルを一括でアップロードします。

    **サポートされている画像形式:**
    - JPEG/JPG
    - PNG
    - HEIC/HEIF
    - WebP
    - BMP
    - TIFF

    **処理フロー:**
    1. ファイルサイズ・形式の検証
    2. 画像ファイルの妥当性検証
    3. 一意のファイル名生成
    4. Storj Container Appのアップロード対象ディレクトリに配置
    5. 5ファイル蓄積時の自動アップロードトリガー
    """,
    responses={
        200: {"description": "アップロード成功", "model": UploadResponse},
        400: {"description": "リクエストエラー", "model": ErrorResponse},
        413: {"description": "ファイルサイズ超過", "model": ErrorResponse},
        422: {"description": "バリデーションエラー", "model": ErrorResponse},
    }
)
async def upload_images(
    background_tasks: BackgroundTasks,
    files: List[UploadFile] = File(..., description="アップロードする画像ファイル（複数可）")
):
    """
    画像ファイルをアップロードして、storj_container_appでの処理キューに追加
    """
    if not files:
        raise HTTPException(status_code=400, detail="ファイルが指定されていません")

    results = []

    for file in files:
        try:
            # ファイルサイズチェック
            if file.size and file.size > MAX_FILE_SIZE:
                results.append({
                    "filename": file.filename,
                    "status": "error",
                    "message": f"ファイルサイズが上限({MAX_FILE_SIZE / (1024*1024):.1f}MB)を超えています"
                })
                continue

            # ファイル形式チェック
            if not ImageProcessor.is_supported_format(file.filename):
                results.append({
                    "filename": file.filename,
                    "status": "error",
                    "message": "サポートされていない画像形式です"
                })
                continue

            # ファイル内容を読み取り
            content = await file.read()

            # 画像検証
            if not ImageProcessor.validate_image(content):
                results.append({
                    "filename": file.filename,
                    "status": "error",
                    "message": "有効な画像ファイルではありません"
                })
                continue

            # 一意のファイル名生成
            unique_filename = ImageProcessor.generate_unique_filename(file.filename)
            temp_path = TEMP_DIR / unique_filename
            target_path = UPLOAD_TARGET_DIR / unique_filename

            # 一時ファイルに保存
            async with aiofiles.open(temp_path, 'wb') as f:
                await f.write(content)

            # バックグラウンドタスクでターゲットディレクトリに移動
            background_tasks.add_task(save_file_to_target, temp_path, target_path)

            results.append({
                "filename": file.filename,
                "saved_as": unique_filename,
                "status": "success",
                "message": "アップロード完了、処理キューに追加されました"
            })

        except Exception as e:
            results.append({
                "filename": file.filename,
                "status": "error",
                "message": f"処理エラー: {str(e)}"
            })

    return {
        "message": f"{len([r for r in results if r['status'] == 'success'])}個のファイルが正常にアップロードされました",
        "results": results
    }

@app.post(
    "/upload/single",
    response_model=UploadResponse,
    tags=["images"],
    summary="単一画像ファイルアップロード",
    description="単一の画像ファイルをアップロードします。複数画像アップロードAPI（/upload）のシングルファイル版です。",
    responses={
        200: {"description": "アップロード成功", "model": UploadResponse},
        400: {"description": "リクエストエラー", "model": ErrorResponse},
        413: {"description": "ファイルサイズ超過", "model": ErrorResponse},
        422: {"description": "バリデーションエラー", "model": ErrorResponse},
    }
)
async def upload_single_image(
    background_tasks: BackgroundTasks,
    file: UploadFile = File(..., description="アップロードする画像ファイル")
):
    """
    単一画像ファイルのアップロード
    """
    return await upload_images(background_tasks, [file])

@app.post(
    "/upload/files",
    response_model=UploadResponse,
    tags=["files"],
    summary="汎用ファイル複数アップロード",
    description="""
    複数のファイルを一括でアップロードします。**ファイル形式の制限はありません。**

    **対応ファイル形式（例）:**
    - **動画**: MP4, MOV, AVI, MKV, WMV, FLV, WebM等
    - **音声**: MP3, WAV, FLAC, AAC, OGG等
    - **ドキュメント**: PDF, DOC, DOCX, XLS, XLSX, PPT, PPTX等
    - **アーカイブ**: ZIP, RAR, 7Z, TAR, GZ等
    - **その他**: すべてのファイル形式

    **処理フロー:**
    1. ファイルサイズの検証（形式制限なし）
    2. 基本的なファイル妥当性検証（空ファイルチェック等）
    3. 一意のファイル名生成
    4. Storj Container Appのアップロード対象ディレクトリに配置
    5. 5ファイル蓄積時の自動アップロードトリガー
    """,
    responses={
        200: {"description": "アップロード成功", "model": UploadResponse},
        400: {"description": "リクエストエラー", "model": ErrorResponse},
        413: {"description": "ファイルサイズ超過", "model": ErrorResponse},
        422: {"description": "バリデーションエラー", "model": ErrorResponse},
    }
)
async def upload_files(
    background_tasks: BackgroundTasks,
    files: List[UploadFile] = File(..., description="アップロードするファイル（複数可、すべてのファイル形式対応）")
):
    """
    汎用ファイルアップロード（動画・その他すべてのファイル形式対応）
    ファイル形式の制限なし
    """
    if not files:
        raise HTTPException(status_code=400, detail="ファイルが指定されていません")

    results = []

    for file in files:
        try:
            # ファイルサイズチェック
            if file.size and file.size > MAX_FILE_SIZE:
                results.append({
                    "filename": file.filename,
                    "status": "error",
                    "message": f"ファイルサイズが上限({MAX_FILE_SIZE / (1024*1024):.1f}MB)を超えています",
                    "file_info": FileProcessor.get_file_info(file.filename, file.size)
                })
                continue

            # ファイル内容を読み取り
            content = await file.read()

            # 基本的なファイル検証（形式制限なし）
            if not FileProcessor.validate_file_basic(content, file.filename):
                results.append({
                    "filename": file.filename,
                    "status": "error",
                    "message": "無効なファイルです（空ファイルまたは無効なファイル名）",
                    "file_info": FileProcessor.get_file_info(file.filename, len(content))
                })
                continue

            # 一意のファイル名生成
            unique_filename = FileProcessor.generate_unique_filename(file.filename)
            temp_path = TEMP_DIR / unique_filename
            target_path = UPLOAD_TARGET_DIR / unique_filename

            # ファイル情報取得
            file_info = FileProcessor.get_file_info(file.filename, len(content))

            # 一時ファイルに保存
            async with aiofiles.open(temp_path, 'wb') as f:
                await f.write(content)

            # バックグラウンドタスクでターゲットディレクトリに移動
            background_tasks.add_task(save_file_to_target, temp_path, target_path)

            results.append({
                "filename": file.filename,
                "saved_as": unique_filename,
                "status": "success",
                "message": "アップロード完了、処理キューに追加されました",
                "file_info": file_info
            })

        except Exception as e:
            results.append({
                "filename": file.filename,
                "status": "error",
                "message": f"処理エラー: {str(e)}",
                "file_info": FileProcessor.get_file_info(file.filename, 0) if file.filename else {}
            })

    return {
        "message": f"{len([r for r in results if r['status'] == 'success'])}個のファイルが正常にアップロードされました",
        "results": results
    }

@app.post(
    "/upload/files/single",
    response_model=UploadResponse,
    tags=["files"],
    summary="汎用ファイル単一アップロード",
    description="単一ファイルをアップロードします。汎用ファイル複数アップロードAPI（/upload/files）のシングルファイル版です。",
    responses={
        200: {"description": "アップロード成功", "model": UploadResponse},
        400: {"description": "リクエストエラー", "model": ErrorResponse},
        413: {"description": "ファイルサイズ超過", "model": ErrorResponse},
        422: {"description": "バリデーションエラー", "model": ErrorResponse},
    }
)
async def upload_single_file(
    background_tasks: BackgroundTasks,
    file: UploadFile = File(..., description="アップロードするファイル（すべてのファイル形式対応）")
):
    """
    単一ファイルのアップロード（すべてのファイル形式対応）
    """
    return await upload_files(background_tasks, [file])

@app.get(
    "/health",
    response_model=HealthResponse,
    tags=["system"],
    summary="ヘルスチェック",
    description="APIサーバーの健康状態と基本的なシステム情報を取得します。"
)
async def health_check():
    """ヘルスチェックエンドポイント"""
    return {
        "status": "healthy",
        "timestamp": datetime.now().isoformat(),
        "upload_target_dir": str(UPLOAD_TARGET_DIR),
        "upload_target_exists": UPLOAD_TARGET_DIR.exists()
    }

@app.get(
    "/status",
    response_model=StatusResponse,
    tags=["system"],
    summary="詳細ステータス取得",
    description="""APIサーバーとStorj Container Appの詳細なステータス情報を取得します。

    **取得できる情報:**
    - ファイル数（アップロード対象・一時ディレクトリ）
    - サポートされている画像形式
    - 最大ファイルサイズ
    - 利用可能なエンドポイント
    - Storj Container Appの状態
    """
)
async def get_status():
    """システムステータス取得"""
    try:
        # アップロード対象ディレクトリのファイル数
        target_files = list(UPLOAD_TARGET_DIR.glob('*')) if UPLOAD_TARGET_DIR.exists() else []
        target_count = len([f for f in target_files if f.is_file()])

        # 一時ディレクトリのファイル数
        temp_files = list(TEMP_DIR.glob('*')) if TEMP_DIR.exists() else []
        temp_count = len([f for f in temp_files if f.is_file()])

        # Storjクライアントのステータス
        storj_status = storj_client.get_status()

        return {
            "api_info": {
                "upload_target_dir": str(UPLOAD_TARGET_DIR),
                "temp_dir": str(TEMP_DIR),
                "files_in_target": target_count,
                "files_in_temp": temp_count,
                "supported_image_formats": list(SUPPORTED_IMAGE_FORMATS),
                "max_file_size_mb": MAX_FILE_SIZE / (1024 * 1024),
                "endpoints": {
                    "image_upload": "/upload (画像ファイル専用)",
                    "image_single": "/upload/single (単一画像ファイル)",
                    "file_upload": "/upload/files (すべてのファイル形式)",
                    "file_single": "/upload/files/single (単一ファイル)"
                }
            },
            "storj_status": storj_status
        }
    except Exception as e:
        return {
            "error": str(e)
        }

@app.post(
    "/trigger-upload",
    response_model=TriggerUploadResponse,
    tags=["storj"],
    summary="手動Storjアップロード実行",
    description="""アップロード対象ディレクトリ内のファイルを手動でStorjにアップロードします。

    **注意:**
    - この処理は同期的であり、完了まで時間がかかる場合があります
    - ファイルがない場合はエラーではなく 'no_files' ステータスを返します
    """
)
async def trigger_upload():
    """
    手動でStorjアップロードを実行
    """
    try:
        file_count = storj_client.count_files_in_target()
        if file_count == 0:
            return {
                "status": "no_files",
                "message": "アップロード対象のファイルがありません",
                "files_count": 0
            }

        success, output = storj_client.run_storj_uploader()

        return {
            "status": "success" if success else "error",
            "message": "アップロード処理が完了しました" if success else "アップロード処理でエラーが発生しました",
            "files_processed": file_count,
            "output": output
        }
    except Exception as e:
        return {
            "status": "error",
            "message": f"アップロード実行エラー: {str(e)}"
        }

@app.post(
    "/trigger-upload-async",
    response_model=TriggerUploadResponse,
    tags=["storj"],
    summary="非同期Storjアップロード実行",
    description="""アップロード対象ディレクトリ内のファイルを非同期でStorjにアップロードします。

    **特徴:**
    - バックグラウンドで処理されるため、即座にレスポンスが返されます
    - 進行状況の確認はシステムログで行ってください
    - ファイルがない場合はエラーではなく 'no_files' ステータスを返します
    """
)
async def trigger_upload_async():
    """
    非同期でStorjアップロードを実行
    """
    try:
        file_count = storj_client.count_files_in_target()
        if file_count == 0:
            return {
                "status": "no_files",
                "message": "アップロード対象のファイルがありません",
                "files_count": 0
            }

        storj_client.run_storj_uploader_async()

        return {
            "status": "started",
            "message": "バックグラウンドでアップロード処理を開始しました",
            "files_to_process": file_count
        }
    except Exception as e:
        return {
            "status": "error",
            "message": f"アップロード開始エラー: {str(e)}"
        }

@app.get(
    "/storj/images",
    response_model=StorjImageListResponse,
    tags=["storj"],
    summary="Storj画像リスト取得",
    description="""Storjに保存されている画像のリストを取得します。

    **パラメータ:**
    - **limit**: 取得する最大画像数（デフォルト: 100）
    - **offset**: ページネーション用のオフセット（デフォルト: 0）
    - **bucket**: Storjバケット名（指定しない場合は環境変数から取得）

    **使用例:**
    ```bash
    # 最初の100枚を取得
    curl http://localhost:8010/storj/images

    # 50枚をスキップして次の20枚を取得
    curl "http://localhost:8010/storj/images?limit=20&offset=50"
    ```
    """
)
async def get_storj_images(
    limit: int = 100,
    offset: int = 0,
    bucket: str = None,
    request: Request = None
):
    """
    Storjに保存されている画像リストを取得
    """
    try:
        base_url = str(request.base_url).rstrip("/") if request else None
        success, images, message = storj_client.list_storj_images(
            bucket_name=bucket,
            limit=limit,
            offset=offset,
            base_url=base_url
        )

        if not success:
            return StorjImageListResponse(
                success=False,
                images=[],
                total_count=0,
                message=f"Failed to retrieve images: {message}"
            )

        return StorjImageListResponse(
            success=True,
            images=[StorjImageItem(**img) for img in images],
            total_count=len(images),
            message=message
        )

    except Exception as e:
        return StorjImageListResponse(
            success=False,
            images=[],
            total_count=0,
            message=f"Error: {str(e)}"
        )

@app.get(
    "/storj/images/{image_path:path}",
    tags=["storj"],
    summary="Storj画像取得",
    description="""Storjに保存されている画像を取得します。

    **パラメータ:**
    - **image_path**: Storj内の画像パス（例: 202509/image_abc123.jpg）
    - **bucket**: Storjバケット名（オプション、指定しない場合は環境変数から取得）
    - **thumbnail**: trueの場合、300x300pxのサムネイルを返す（デフォルト: true）

    **使用例:**
    ```bash
    # サムネイルを取得（デフォルト）
    curl http://localhost:8010/storj/images/202509/image_abc123.jpg

    # フルサイズ画像を取得
    curl "http://localhost:8010/storj/images/202509/image_abc123.jpg?thumbnail=false"
    ```
    """,
    responses={
        200: {
            "description": "画像データ",
            "content": {
                "image/jpeg": {},
                "image/png": {},
                "image/webp": {},
                "image/heic": {}
            }
        },
        404: {"description": "画像が見つかりません"},
        500: {"description": "サーバーエラー"}
    }
)
async def get_storj_image(
    image_path: str,
    thumbnail: bool = True,
    bucket: str = None,
    request: Request = None
):
    """
    Storjから画像を取得して配信
    thumbnailがtrueの場合はサムネイル（300x300px）を返す
    """
    print(f"=== Image Request ===")
    print(f"image_path: {image_path}")
    print(f"thumbnail: {thumbnail}")
    print(f"bucket: {bucket}")
    print(f"====================")

    try:
        is_video = VideoProcessor.is_video_file(image_path)

        if is_video and not thumbnail:
            info_success, info, info_error = storj_client.get_storj_object_info(
                object_path=image_path,
                bucket_name=bucket
            )
            if not info_success:
                raise HTTPException(status_code=404, detail=info_error)

            file_size = info.get("Size") or info.get("size")
            if not isinstance(file_size, int) or file_size <= 0:
                raise HTTPException(status_code=500, detail="Invalid file size")

            range_header = request.headers.get("range") if request else None
            range_tuple = _parse_range_header(range_header, file_size) if range_header else None
            if range_header and not range_tuple:
                return Response(status_code=416, headers={"Content-Range": f"bytes */{file_size}"})

            if range_tuple:
                start, end = range_tuple
                content_length = end - start + 1
                status_code = 206
            else:
                start, end = 0, file_size - 1
                content_length = file_size
                status_code = 200

            stream_success, stream_iter, stream_error = storj_client.stream_storj_file(
                object_path=image_path,
                bucket_name=bucket,
                offset=start if range_tuple else None,
                count=content_length if range_tuple else None
            )
            if not stream_success:
                raise HTTPException(status_code=500, detail=stream_error)

            headers = {
                "Accept-Ranges": "bytes",
                "Content-Length": str(content_length)
            }
            if range_tuple:
                headers["Content-Range"] = f"bytes {start}-{end}/{file_size}"

            return StreamingResponse(
                stream_iter,
                media_type=_get_video_content_type(image_path),
                headers=headers,
                status_code=status_code
            )

        # サムネイルまたはフルサイズ画像を取得
        if thumbnail:
            if is_video:
                thumbnail_path = f"{Path(image_path).with_suffix('')}_thumb.jpg"
                success, image_data, error_msg = storj_client.get_storj_image(
                    image_path=thumbnail_path,
                    bucket_name=bucket
                )
                if not success or not image_data:
                    success, image_data, error_msg = _generate_video_thumbnail(
                        video_path=image_path,
                        bucket=bucket
                    )
            else:
                success, image_data, error_msg = storj_client.get_storj_thumbnail(
                    image_path=image_path,
                    bucket_name=bucket,
                    size=(300, 300)
                )
        else:
            success, image_data, error_msg = storj_client.get_storj_image(
                image_path=image_path,
                bucket_name=bucket
            )

        if not success:
            raise HTTPException(status_code=404, detail=error_msg)

        # Content-Typeを判定
        # サムネイルの場合は常にJPEG、それ以外は拡張子から判定
        if thumbnail:
            content_type = 'image/jpeg'
        else:
            ext = image_path.lower().split('.')[-1]
            content_type_map = {
                'jpg': 'image/jpeg',
                'jpeg': 'image/jpeg',
                'png': 'image/png',
                'webp': 'image/webp',
                'heic': 'image/heic',
                'bmp': 'image/bmp',
                'tiff': 'image/tiff',
                'gif': 'image/gif'
            }
            content_type = content_type_map.get(ext, 'image/jpeg')

        # Add cache headers (cache for 1 day for thumbnails, 1 hour for full images)
        cache_max_age = 86400 if thumbnail else 3600  # 1 day or 1 hour
        etag_source = f"{image_path}|{'thumb' if thumbnail else 'full'}"
        etag_hash = hashlib.sha256(etag_source.encode("utf-8")).hexdigest()
        headers = {
            "Cache-Control": f"public, max-age={cache_max_age}",
            # Keep ETag ASCII-safe even for non-ASCII filenames.
            "ETag": f"\"sha256-{etag_hash}\""
        }

        return Response(content=image_data, media_type=content_type, headers=headers)

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8010)
