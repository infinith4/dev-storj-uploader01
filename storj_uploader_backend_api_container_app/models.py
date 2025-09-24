#!/usr/bin/env python3
"""
OpenAPI v3対応のPydanticモデル定義
"""
from pydantic import BaseModel, Field
from typing import List, Optional, Dict, Any
from enum import Enum

class FileStatus(str, Enum):
    """ファイル処理ステータス"""
    SUCCESS = "success"
    ERROR = "error"
    NO_FILES = "no_files"
    STARTED = "started"
    SKIPPED = "skipped"

class FileInfo(BaseModel):
    """ファイル情報モデル"""
    original_name: str = Field(..., description="元のファイル名")
    name: str = Field(..., description="拡張子を除いたファイル名")
    extension: str = Field(..., description="ファイル拡張子")
    size_bytes: int = Field(..., description="ファイルサイズ（バイト）")
    size_mb: float = Field(..., description="ファイルサイズ（MB）")

    class Config:
        json_schema_extra = {
            "example": {
                "original_name": "video.mp4",
                "name": "video",
                "extension": ".mp4",
                "size_bytes": 50234567,
                "size_mb": 47.9
            }
        }

class FileUploadResult(BaseModel):
    """ファイルアップロード結果モデル"""
    filename: str = Field(..., description="アップロードされたファイル名")
    saved_as: Optional[str] = Field(None, description="保存されたファイル名（一意のファイル名）")
    status: FileStatus = Field(..., description="処理ステータス")
    message: str = Field(..., description="処理結果メッセージ")
    file_info: Optional[FileInfo] = Field(None, description="ファイル詳細情報")

    class Config:
        json_schema_extra = {
            "example": {
                "filename": "example.mp4",
                "saved_as": "example_20240923_143012_abc12345.mp4",
                "status": "success",
                "message": "アップロード完了、処理キューに追加されました",
                "file_info": {
                    "original_name": "example.mp4",
                    "name": "example",
                    "extension": ".mp4",
                    "size_bytes": 50234567,
                    "size_mb": 47.9
                }
            }
        }

class UploadResponse(BaseModel):
    """アップロードAPIレスポンスモデル"""
    message: str = Field(..., description="処理結果の概要メッセージ")
    results: List[FileUploadResult] = Field(..., description="各ファイルの処理結果")

    class Config:
        json_schema_extra = {
            "example": {
                "message": "2個のファイルが正常にアップロードされました",
                "results": [
                    {
                        "filename": "video1.mp4",
                        "saved_as": "video1_20240923_143012_abc12345.mp4",
                        "status": "success",
                        "message": "アップロード完了、処理キューに追加されました",
                        "file_info": {
                            "original_name": "video1.mp4",
                            "name": "video1",
                            "extension": ".mp4",
                            "size_bytes": 50234567,
                            "size_mb": 47.9
                        }
                    }
                ]
            }
        }

class HealthResponse(BaseModel):
    """ヘルスチェックレスポンスモデル"""
    status: str = Field(..., description="システムの健康状態")
    timestamp: str = Field(..., description="チェック実行時刻")
    upload_target_dir: str = Field(..., description="アップロード対象ディレクトリパス")
    upload_target_exists: bool = Field(..., description="アップロード対象ディレクトリの存在確認")

    class Config:
        json_schema_extra = {
            "example": {
                "status": "healthy",
                "timestamp": "2024-09-23T14:30:12.123456",
                "upload_target_dir": "/app/upload_target",
                "upload_target_exists": True
            }
        }

class ApiInfo(BaseModel):
    """API情報モデル"""
    upload_target_dir: str = Field(..., description="アップロード対象ディレクトリ")
    temp_dir: str = Field(..., description="一時ファイルディレクトリ")
    files_in_target: int = Field(..., description="アップロード対象ディレクトリ内のファイル数")
    files_in_temp: int = Field(..., description="一時ディレクトリ内のファイル数")
    supported_image_formats: List[str] = Field(..., description="サポートされている画像形式")
    max_file_size_mb: float = Field(..., description="最大ファイルサイズ（MB）")
    endpoints: Dict[str, str] = Field(..., description="利用可能なエンドポイント")

class StorjStatus(BaseModel):
    """Storjステータスモデル"""
    storj_app_available: bool = Field(..., description="Storj Container Appの利用可能性")
    storj_app_path: str = Field(..., description="Storj Container Appのパス")
    upload_target_dir: str = Field(..., description="アップロード対象ディレクトリ")
    uploaded_dir: str = Field(..., description="アップロード済みディレクトリ")
    files_in_target: int = Field(..., description="アップロード対象ファイル数")
    files_uploaded: int = Field(..., description="アップロード済みファイル数")
    target_dir_exists: bool = Field(..., description="アップロード対象ディレクトリの存在")
    uploaded_dir_exists: bool = Field(..., description="アップロード済みディレクトリの存在")

class StatusResponse(BaseModel):
    """ステータスAPIレスポンスモデル"""
    api_info: ApiInfo = Field(..., description="API情報")
    storj_status: StorjStatus = Field(..., description="Storjシステムステータス")

class TriggerUploadResponse(BaseModel):
    """アップロードトリガーレスポンスモデル"""
    status: FileStatus = Field(..., description="実行ステータス")
    message: str = Field(..., description="実行結果メッセージ")
    files_count: Optional[int] = Field(None, description="対象ファイル数")
    files_processed: Optional[int] = Field(None, description="処理されたファイル数")
    files_to_process: Optional[int] = Field(None, description="処理予定ファイル数")
    output: Optional[str] = Field(None, description="実行出力")

    class Config:
        json_schema_extra = {
            "example": {
                "status": "success",
                "message": "アップロード処理が完了しました",
                "files_processed": 5,
                "output": "Successfully uploaded 5 files to Storj"
            }
        }

class ErrorResponse(BaseModel):
    """エラーレスポンスモデル"""
    error: str = Field(..., description="エラーメッセージ")

    class Config:
        json_schema_extra = {
            "example": {
                "error": "ファイルサイズが上限を超えています"
            }
        }