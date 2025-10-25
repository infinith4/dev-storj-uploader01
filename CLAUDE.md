# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a **Storj file uploader system** with three main components:
1. **storj_container_app** - Core Python uploader using rclone
2. **storj_uploader_backend_api_container_app** - FastAPI backend with OpenAPI v3
3. **storj_uploader_frontend_container_app** - React + TypeScript frontend

The system allows users to upload files (images, videos, documents, etc.) through a web interface, which are then automatically uploaded to Storj cloud storage with intelligent deduplication and parallel processing.

## Architecture

### Data Flow
```
Frontend (React) → Backend API (FastAPI) → Storj Container App (rclone) → Storj Cloud
```

1. **Frontend** sends files via POST to backend API endpoints
2. **Backend** validates files, saves to `temp/`, moves to `../storj_container_app/upload_target/`
3. **Auto-trigger**: When ≥5 files accumulate, backend automatically calls storj_uploader.py
4. **Storj Container App** uses rclone to upload to Storj with hash-based deduplication
5. Successfully uploaded files are moved to `uploaded/` directory

### Component Details

#### storj_container_app (Python + rclone)
- **Main script**: `storj_uploader.py` - Parallel file uploader with ThreadPoolExecutor
- **Key features**:
  - Creates/checks Storj buckets automatically
  - Uploads to `YYYYMM` directories based on file date (extracted from filename or file metadata)
  - MD5 hash-based deduplication (first 10 chars by default)
  - Parallel uploads (8 workers by default, configurable via `MAX_WORKERS`)
  - Filename format: `basename_hash[_timestamp].ext`
  - Skips duplicates with same name + hash
- **Environment**: Requires `rclone.conf` for Storj authentication

#### storj_uploader_backend_api_container_app (FastAPI)
- **Main script**: `main.py` - OpenAPI v3 compliant REST API
- **Endpoints**:
  - `POST /upload` - Multiple image files (HEIC, JPEG, PNG, WebP, BMP, TIFF)
  - `POST /upload/single` - Single image file
  - `POST /upload/files` - Multiple files (all formats)
  - `POST /upload/files/single` - Single file (all formats)
  - `GET /health` - Health check
  - `GET /status` - System status with file counts
  - `POST /trigger-upload` - Manual Storj upload (synchronous)
  - `POST /trigger-upload-async` - Manual Storj upload (asynchronous)
- **Key classes**:
  - `ImageProcessor`: Image validation and filename generation
  - `FileProcessor`: Generic file validation and info extraction
  - `StorjClient` (storj_client.py): Interface to storj_container_app
- **Auto-upload**: Triggers when ≥5 files in upload_target
- **Default port**: 8010

#### storj_uploader_frontend_container_app (React + TypeScript)
- **Main components**:
  - `App.tsx` - Tab-based navigation (images/videos/files/status)
  - `UploaderTab.tsx` - Reusable upload interface for different file types
  - `FileDropzone.tsx` - Drag & drop file selection
  - `FilePreview.tsx` - File preview (images) and info display
  - `SystemStatus.tsx` - Real-time system status and manual triggers
- **API client**: `api.ts` with `StorjUploaderAPI` class
- **Styling**: Tailwind CSS with mobile-first responsive design
- **Default port**: 9010 (production), 3000 (dev)

## Dev Container Setup

このプロジェクトは VS Code Dev Container に対応しています。

### Dev Container で開く

```bash
# VS Code で開く
code .

# コマンドパレット: "Dev Containers: Reopen in Container"
```

自動的に以下がセットアップされます：
- Python 3.11, Node.js 18, rclone
- 全コンポーネントの依存関係（pip, npm）
- 必要なディレクトリとテンプレート .env ファイル
- ポートフォワーディング（8010, 9010, 3000）

初回起動後に rclone を設定してください：
```bash
rclone config
cp ~/.config/rclone/rclone.conf storj_container_app/
```

詳細は `.devcontainer/README.md` を参照してください。

## Common Development Commands

### Backend API Development
```bash
cd storj_uploader_backend_api_container_app

# Install dependencies
pip install -r requirements.txt

# Run development server
python main.py
# or
uvicorn main:app --reload --host 0.0.0.0 --port 8010

# Rebuild and run with Docker Compose
docker compose down
docker rmi storj_uploader_backend_api_container_app-storj-uploader-api
docker-compose up --build

# API docs available at:
# http://localhost:8010/docs (Swagger UI)
# http://localhost:8010/redoc (ReDoc)
```

### Frontend Development
```bash
cd storj_uploader_frontend_container_app

# Install dependencies
npm install

# Run development server
npm start  # http://localhost:3000

# Build for production
npm run build

# Run with Docker (full stack)
docker compose down
docker rmi storj_uploader_frontend_container_app-backend
docker rmi storj_uploader_frontend_container_app-frontend
docker-compose up --build
# Frontend: http://localhost:9010
# Backend: http://localhost:8010
```

### Storj Container App (Core Uploader)
```bash
cd storj_container_app

# Setup rclone config
cp ~/.config/rclone/rclone.conf ./rclone.conf

# Configure environment
cp .env.example .env
# Edit .env with STORJ_BUCKET_NAME and STORJ_REMOTE_NAME

# Run directly (for testing)
python3 storj_uploader.py

# Run with Docker Compose
docker compose down
docker rmi storj_container_app-storj_container_app
docker-compose up
```

## Key Configuration Files

### Backend (.env)
- `UPLOAD_TARGET_DIR`: Path to storj_container_app/upload_target
- `TEMP_DIR`: Temporary file storage
- `MAX_FILE_SIZE`: Max upload size in bytes (default: 100MB)
- `API_HOST`: API server host (default: 0.0.0.0)
- `API_PORT`: API server port (default: 8010)

### Storj Container App (.env)
- `STORJ_BUCKET_NAME`: Storj bucket name
- `STORJ_REMOTE_NAME`: rclone remote name (default: storj)
- `HASH_LENGTH`: Hash substring length for deduplication (default: 10)
- `MAX_WORKERS`: Parallel upload workers (default: 8)

### Frontend (.env)
- `REACT_APP_API_URL`: Backend API URL (default: http://localhost:8010)

## Important Implementation Notes

### File Upload Flow
1. Frontend sends files to `/upload` (images) or `/upload/files` (all files)
2. Backend validates file size and format (images only for `/upload`)
3. Backend generates unique filename with timestamp + UUID
4. File saved to `temp/` then moved to `upload_target/` via background task
5. Backend counts files in `upload_target/`; if ≥5, triggers `storj_client.run_storj_uploader_async()`
6. Storj uploader processes all files in `upload_target/` in parallel
7. Each file gets MD5 hash, checks for duplicates in Storj
8. If duplicate (same base name + hash), file is skipped
9. If not duplicate, uploads to `storj:bucket/YYYYMM/basename_hash.ext`
10. Successfully uploaded/skipped files moved to `uploaded/`

### Deduplication Logic
- Files are deduplicated by **base name + MD5 hash** (first 10 chars)
- Format: `basename_hash.ext` or `basename_hash_timestamp.ext`
- The `parse_filename_with_hash()` function extracts components
- `check_duplicate_by_hash_and_name()` compares against existing files in Storj
- Duplicate files are moved to `uploaded/` without re-uploading

### Parallel Processing
- Storj uploader uses `ThreadPoolExecutor` with 8 workers (default)
- Each thread has its own temp directory to avoid conflicts
- Thread-safe operations use `self.lock` for console output and file moves
- Background tasks in FastAPI use `BackgroundTasks` for async file moves

### Date-based Directory Structure
- Files uploaded to `YYYYMM` directories in Storj
- Date extracted from filename pattern: `YYYY-MM-DD_HH-MM-SS` (e.g., smartphone photos)
- Falls back to file creation time if pattern not found
- Implemented in `get_file_date()` and `extract_date_from_filename()`

### CORS Configuration
Backend allows requests from:
- http://localhost:9010 (production frontend)
- http://localhost:3000 (development frontend)
- http://127.0.0.1:9010
- http://127.0.0.1:3000

## Testing

### Backend API Testing
```bash
# Health check
curl http://localhost:8010/health

# System status
curl http://localhost:8010/status

# Upload image
curl -X POST "http://localhost:8010/upload" -F "files=@test.jpg"

# Upload video
curl -X POST "http://localhost:8010/upload/files" -F "files=@test.mp4"

# Manual trigger
curl -X POST http://localhost:8010/trigger-upload

# Async trigger
curl -X POST http://localhost:8010/trigger-upload-async
```

### Directory Structure Verification
```bash
# Check file counts
ls -la storj_container_app/upload_target/
ls -la storj_container_app/uploaded/

# Monitor backend logs
docker logs -f storj_uploader_backend_api_container_app-storj-uploader-api-1

# Monitor storj uploader output
docker logs -f storj_container_app-storj_container_app-1
```

## Troubleshooting

### Storj Container App Not Found
- Backend looks for storj_container_app at `/app/storj_container_app` (Docker) or `../storj_container_app` (local)
- Verify `docker-compose.yml` volume mounts are correct
- Check `StorjClient.__init__()` path resolution in `storj_client.py`

### Files Not Auto-Uploading
- Auto-upload only triggers when ≥5 files in `upload_target/`
- Check `save_file_to_target()` in `main.py` for trigger logic
- Use manual trigger endpoints for immediate upload

### Duplicate File Detection Issues
- Ensure filename follows format: `basename_hash.ext`
- Hash length must match `HASH_LENGTH` env var (default: 10)
- Check `_is_temp_hash_file()` isn't filtering files incorrectly

### rclone Configuration
- `rclone.conf` must be present in storj_container_app directory
- Test with: `rclone lsd storj:` (should list buckets)
- Verify remote name matches `STORJ_REMOTE_NAME` in .env

## OpenAPI v3 Documentation
The backend API is fully documented with OpenAPI v3:
- Interactive docs: http://localhost:8010/docs
- Detailed docs: http://localhost:8010/redoc
- JSON schema: http://localhost:8010/openapi.json

All endpoints have:
- Detailed descriptions
- Request/response schemas (Pydantic models in `models.py`)
- Error response examples
- Tags for organization (images, files, system, storj)
