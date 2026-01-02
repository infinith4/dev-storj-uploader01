# Storj Uploader Backend API

HEICやJPEGなどの画像ファイルをFastAPI経由で受信し、Storj Container Appと連携してStorjにアップロードするバックエンドAPIです。

## 機能

- **画像ファイルアップロード**（HEIC、JPEG、PNG、WebP等対応）
- **汎用ファイルアップロード**（動画、音声、ドキュメント等すべてのファイル形式対応）
- **OpenAPI v3完全対応**（自動APIドキュメント生成、スキーマ検証）
- 自動ファイル検証・変換
- Storj Container Appとの連携
- バックグラウンド処理によるStorjアップロード
- 自動アップロードトリガー（5ファイル蓄積時）

## APIエンドポイント

### 1. 画像アップロード（画像ファイル専用）

#### 複数画像ファイルアップロード
```bash
POST /upload
Content-Type: multipart/form-data

curl -X POST "http://localhost:8000/upload" \
  -F "files=@image1.heic" \
  -F "files=@image2.jpg"
```

#### 単一画像ファイルアップロード
```bash
POST /upload/single
Content-Type: multipart/form-data

curl -X POST "http://localhost:8000/upload/single" \
  -F "file=@image.heic"
```

### 2. 汎用ファイルアップロード（すべてのファイル形式対応）

#### 複数ファイルアップロード（動画・その他ファイル）
```bash
POST /upload/files
Content-Type: multipart/form-data

curl -X POST "http://localhost:8000/upload/files" \
  -F "files=@video1.mp4" \
  -F "files=@video2.mov" \
  -F "files=@document.pdf"
```

#### 単一ファイルアップロード（動画・その他ファイル）
```bash
POST /upload/files/single
Content-Type: multipart/form-data

curl -X POST "http://localhost:8000/upload/files/single" \
  -F "file=@video.mp4"
```

### 3. システム管理

#### ヘルスチェック
```bash
GET /health

curl http://localhost:8000/health
```

#### システムステータス確認
```bash
GET /status

curl http://localhost:8000/status
```

#### 手動アップロード実行
```bash
POST /trigger-upload

curl -X POST http://localhost:8000/trigger-upload
```

#### 非同期アップロード実行
```bash
POST /trigger-upload-async

curl -X POST http://localhost:8000/trigger-upload-async
```

## OpenAPI v3ドキュメント

### 自動生成されるAPIドキュメント

#### Swagger UI（対話型）
```
http://localhost:8000/docs
```

#### ReDoc（詳細表示）
```
http://localhost:8000/redoc
```

#### OpenAPI JSONスキーマ
```
http://localhost:8000/openapi.json
```

### API仕様の特徴

- **完全なスキーマ検証**: Pydanticモデルによるリクエスト・レスポンスの型安全性
- **詳細なドキュメント**: 各エンドポイントの説明、パラメータ、レスポンス例
- **タグによる分類**:
  - `images`: 画像ファイル専用API
  - `files`: 汎用ファイルAPI
  - `system`: システム管理API
  - `storj`: Storjアップロード管理API
- **エラーハンドリング**: 各種エラーケースに対応したレスポンス定義
- **サンプルデータ**: 実際の使用例を含むレスポンス例

## セットアップ

### 1. 依存関係インストール
```bash
pip install -r requirements.txt
```

### 2. 環境変数設定（.env）
```env
UPLOAD_TARGET_DIR=../storj_container_app/upload_target
TEMP_DIR=./temp
MAX_FILE_SIZE=100000000
API_HOST=0.0.0.0
API_PORT=8000
```

### 3. アプリケーション起動

#### 開発環境
```bash
python main.py
```

#### Docker Compose
```bash
cd storj_uploader_backend_api_container_app
docker compose down
docker rmi storj_uploader_backend_api_container_app-storj-uploader-api
docker-compose up --build
```

## ワークフロー

1. **ファイルアップロード**: フロントエンドから画像ファイルを `/upload` エンドポイントに送信
2. **ファイル検証**: 画像形式・サイズの検証
3. **一時保存**: 検証済みファイルを一時ディレクトリに保存
4. **ターゲット移動**: バックグラウンドでStorj Container Appの`upload_target`ディレクトリに移動
5. **自動アップロード**: ファイル数が5個以上で自動的にStorjアップロード開始
6. **完了**: Storj Container Appがファイルを処理し、`uploaded`ディレクトリに移動

## サポートされているファイル形式

### 画像ファイル（/upload, /upload/single）
- JPEG/JPG
- PNG
- HEIC/HEIF
- WebP
- BMP
- TIFF

### 汎用ファイル（/upload/files, /upload/files/single）
- **動画**: MP4, MOV, AVI, MKV, WMV, FLV, WebM等
- **音声**: MP3, WAV, FLAC, AAC, OGG等
- **ドキュメント**: PDF, DOC, DOCX, XLS, XLSX, PPT, PPTX等
- **アーカイブ**: ZIP, RAR, 7Z, TAR, GZ等
- **その他**: すべてのファイル形式（制限なし）

### 進捗確認
- POST `/upload/status`  
  Body: `{"files": ["<saved_as1>", "<saved_as2>"]}`  
  レスポンス: `queued` / `processing` / `uploaded` / `error`

## 設定

| 環境変数 | デフォルト値 | 説明 |
|---------|-------------|------|
| UPLOAD_TARGET_DIR | ../storj_container_app/upload_target | Storjアップロード対象ディレクトリ |
| TEMP_DIR | /mnt/temp | 一時ファイル保存ディレクトリ (Azure File Share) |
| STORJ_CONTAINER_URL | http://stjup2-storj-udm3tutq7eb7i/process | Storj Container HTTPトリガー |
| MAX_FILE_SIZE | 100000000 | 最大ファイルサイズ（バイト） |
| UPLOAD_WORKERS | 8 | Blob Storage I/O用スレッド数 |
| AZURE_BLOB_UPLOAD_CONCURRENCY | 4 | Blobアップロードの並列度 |
| AZURE_BLOB_DOWNLOAD_CONCURRENCY | 4 | Blobダウンロードの並列度 |
| AZURE_BLOB_UPLOAD_BLOCK_SIZE_MB | 4 | Blobアップロードのブロックサイズ(MB) |
| MIRROR_BLOB_TO_LOCAL | true | Blobアップロード後もローカル`upload_target`へ配置（Storj Containerがローカルモードでも拾えるように） |
| API_HOST | 0.0.0.0 | APIサーバーホスト |
| API_PORT | 8000 | APIサーバーポート |

## エラーハンドリング

APIは以下のエラーを適切に処理します：

- ファイルサイズ超過
- サポートされていない画像形式
- 無効な画像ファイル
- ディスク容量不足
- Storj Container App接続エラー

## 開発

### ローカル開発
```bash
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

### テスト
```bash
# 画像ファイルテスト
curl -X POST "http://localhost:8000/upload" \
  -F "files=@test.jpg"

# 動画ファイルテスト
curl -X POST "http://localhost:8000/upload/files" \
  -F "files=@test.mp4"

# ステータス確認
curl http://localhost:8000/status
```
