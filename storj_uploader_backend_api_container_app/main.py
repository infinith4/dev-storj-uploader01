#!/usr/bin/env python3
"""
Storj Uploader Backend API

FastAPI + OpenAPI v3対応のファイルアップロードAPI
HEICやJPEGなどの画像ファイル、動画ファイル、その他すべてのファイル形式に対応
"""
from fastapi import FastAPI, File, UploadFile, HTTPException, BackgroundTasks
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
import os
import shutil
from pathlib import Path
from typing import List
import uuid
from datetime import datetime
import aiofiles
from PIL import Image
import io
from dotenv import load_dotenv
from storj_client import StorjClient
from models import (
    UploadResponse, HealthResponse, StatusResponse, TriggerUploadResponse,
    ErrorResponse, FileUploadResult, FileInfo, FileStatus
)

load_dotenv()

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

# CORS設定
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost:9010",
        "http://localhost:3000",  # 開発環境
        "http://127.0.0.1:9010",
        "http://127.0.0.1:3000"
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
        shutil.move(str(file_path), str(target_path))
        print(f"File moved to target directory: {target_path}")

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

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8010)