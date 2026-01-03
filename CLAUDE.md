# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a **Storj file uploader system** with five main components:
1. **storj_container_app** - Core Python uploader using rclone
2. **storj_uploader_backend_api_container_app** - FastAPI backend with OpenAPI v3
3. **storj_uploader_frontend_container_app** - React + TypeScript frontend (Web)
4. **flutter_app_storj_uploader** - Flutter cross-platform app (Web + Android)
5. **android_storj_uploader** - Kotlin Android native app (legacy)

The system allows users to upload files (images, videos, documents, etc.) through web and mobile interfaces, which are then automatically uploaded to Storj cloud storage with intelligent deduplication and parallel processing.

## Architecture

### Data Flow
```
Frontend (React/Flutter) / Mobile App (Flutter/Kotlin) → Backend API (FastAPI) → Storj Container App (rclone) → Storj Cloud
```

1. **Frontend/Mobile** sends files via POST to backend API endpoints
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
  - `GET /storj/images` - List Storj images with thumbnail/full URLs
  - `GET /storj/images/{path}` - Serve image (supports `thumbnail=true/false` query param)
  - `POST /trigger-upload` - Manual Storj upload (synchronous)
  - `POST /trigger-upload-async` - Manual Storj upload (asynchronous)
- **Key classes**:
  - `ImageProcessor`: Image validation and filename generation
  - `FileProcessor`: Generic file validation and info extraction
  - `StorjClient` (storj_client.py): Interface to storj_container_app
- **Auto-upload**: Triggers when ≥5 files in upload_target
- **Default port**: 8010
- **CORS**: Allows localhost:9010, localhost:3000, 127.0.0.1:9010, 127.0.0.1:3000

#### storj_uploader_frontend_container_app (React + TypeScript)
- **Main components**:
  - `App.tsx` - Tab-based navigation (images/videos/files/gallery/status)
  - `UploaderTab.tsx` - Reusable upload interface for different file types
  - `ImageGallery.tsx` - Grid display of Storj images with thumbnails
  - `ImageModal.tsx` - Full-size image viewer with zoom/download
  - `FileDropzone.tsx` - Drag & drop file selection
  - `FilePreview.tsx` - File preview (images) and info display
  - `SystemStatus.tsx` - Real-time system status and manual triggers
- **API client**: `api.ts` with `StorjUploaderAPI` class
- **Styling**: Tailwind CSS with mobile-first responsive design
- **Default port**: 9010 (production), 3000 (dev)

#### flutter_app_storj_uploader (Flutter - Web + Android)
- **Main files**:
  - `main.dart` - App entry point with Material Design 3
  - `screens/home_screen.dart` - Main upload interface
  - `widgets/file_upload_area.dart` - Cross-platform file selection (drag & drop on Web, picker on Android)
  - `services/api_service.dart` - Dio HTTP client with error handling
  - `services/file_service.dart` - Cross-platform file handling
  - `models/api_models.dart` - API response models
- **Key features**:
  - **Cross-platform**: Web and Android support from single codebase
  - File picker with camera/gallery integration on Android
  - Drag & drop file upload on Web (using `flutter_dropzone`)
  - Conditional imports for web-only packages
  - Riverpod state management
  - Material Design 3 with light/dark theme
  - Auto-upload queue management
- **Configuration**:
  - `.env` file for API URL (supports Azure Container Apps)
  - Environment variables loaded via `flutter_dotenv`
  - Same API URL for both Web and Android builds
- **Android requirements**:
  - minSdkVersion: 24 (Android 7.0)
  - targetSdkVersion: 34 (Android 14)
  - Permissions: Internet, Storage, Camera, Media
- **Deployment**:
  - Web: Docker with nginx (deployed to Azure Container Apps)
  - Android: APK build via `flutter build apk`

#### android_storj_uploader (Kotlin Android - Legacy)
- **Main activities**:
  - `MainActivity.kt` - Photo grid view with upload status
  - `SettingsActivity.kt` - Upload list and manual trigger
  - `ImageViewerActivity.kt` - Full-size image viewer with pinch-zoom
- **Key features**:
  - Auto-upload every 15 minutes (WorkManager)
  - Displays local photos with Storj upload status
  - Fetches and displays Storj images via backend API
  - PhotoView library for zoom/pan
  - DownloadManager for saving images
- **Architecture**: Repository Pattern with Retrofit + Coroutines
- **API URL**: `http://10.0.2.2:8010/` (emulator), custom IP for real devices
- **Build system**: Gradle with Kotlin 1.9.25, Material Design 3

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

### Android App Development

**Windows環境でのビルド:**
```cmd
cd android_storj_uploader

# Debug APK build
gradlew.bat assembleDebug

# Release APK build
gradlew.bat assembleRelease

# Install on emulator/device
gradlew.bat installDebug

# Run tests
gradlew.bat test

# Lint check
gradlew.bat lint
```

**Linux/Mac/Dev Container環境でのビルド:**
```bash
cd android_storj_uploader

# Make gradlew executable
chmod +x gradlew

# Debug APK build
./gradlew assembleDebug

# Install on emulator/device
./gradlew installDebug
```

**エミュレータでの実行:**
```bash
# List available emulators
emulator -list-avds

# Start emulator (別ターミナルで)
emulator -avd Pixel_9a_API_33

# Install and run app
./gradlew installDebug
adb shell am start -n com.example.storjapp.debug/com.example.storjapp.MainActivity
```

**ログの確認:**
```bash
# Real-time logs
adb logcat -s MainActivity:D PhotoRepository:D ImageViewerActivity:D

# Save logs to file
adb logcat > app_log.txt
```

詳細は `android_storj_uploader/README.md` を参照してください（Windows専用手順あり）。

## Key Configuration Files

### Backend (.env)
- `UPLOAD_TARGET_DIR`: Path to storj_container_app/upload_target
- `TEMP_DIR`: Temporary file storage
- `MAX_FILE_SIZE`: Max upload size in bytes (default: 100MB)
- `API_HOST`: API server host (default: 0.0.0.0)
- `API_PORT`: API server port (default: 8010)
- `API_BASE_URL`: Base URL for generating image URLs (default: http://10.0.2.2:8010)

### Storj Container App (.env)
- `STORJ_BUCKET_NAME`: Storj bucket name
- `STORJ_REMOTE_NAME`: rclone remote name (default: storj)
- `HASH_LENGTH`: Hash substring length for deduplication (default: 10)
- `MAX_WORKERS`: Parallel upload workers (default: 8)

### Frontend (.env)
- `REACT_APP_API_URL`: Backend API URL (default: http://localhost:8010)

### Android App Configuration
- **RetrofitClient.kt**: `BASE_URL = "http://10.0.2.2:8010/"` (エミュレータ用)
- **実機の場合**: BASE_URLをPCのローカルIPに変更して再ビルド

## Important Implementation Notes

### File Upload Flow
1. Frontend/Android sends files to `/upload` (images) or `/upload/files` (all files)
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

### Image URL Construction (Android App)
- **Critical**: Backend API's `BASE_URL` has trailing slash: `"http://10.0.2.2:8010/"`
- **Important**: Always use `trimEnd('/')` when constructing URLs to prevent double slashes
- Example in ImageViewerActivity.kt:
  ```kotlin
  val baseUrl = RetrofitClient.BASE_URL.trimEnd('/')
  val imageUrl = "$baseUrl/storj/images/$imagePath?thumbnail=false"
  ```
- Backend returns thumbnail/full URLs with query parameters from storj_client.py
- Query parameter: `thumbnail=true` for thumbnails, `thumbnail=false` for full-size

### Android Theme Requirements
- ImageViewerActivity requires AppCompat-based theme
- Use `Theme.Material3.DayNight.NoActionBar` or descendants
- Never use `@android:style` themes with AppCompatActivity

## Testing

### Backend API Testing
```bash
# Health check
curl http://localhost:8010/health

# System status
curl http://localhost:8010/status

# List Storj images
curl http://localhost:8010/storj/images?limit=10

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

### Android Image Loading Failures (404 Errors)
- Check for double slashes in URLs (`//storj/images`)
- Ensure `trimEnd('/')` is used when constructing image URLs
- Verify backend is returning proper thumbnail_url and url fields
- Check logcat: `adb logcat | grep -E "ImageViewerActivity|PhotoRepository"`

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

## GitHub Actions CI/CD

### Android App
- **Workflow**: `.github/workflows/android-build.yml`
- **Triggers**: Push/PR to any branch, tag push
- **Tasks**: Build debug APK, run tests, lint check
- **Release**: Tag push (e.g., `v1.0.0`) creates signed release APK

詳細は `android_storj_uploader/RELEASE.md` を参照してください。

## Documentation Files

- `android_storj_uploader/README.md` - Android app setup (Windows専用手順)
- `android_storj_uploader/SCREEN_DESIGN.md` - 画面設計書・画面遷移図
- `android_storj_uploader/RELEASE.md` - リリースビルドとデプロイ
- `.devcontainer/README.md` - Dev Container setup guide
- `.github/workflows/android-build.yml` - CI/CD configuration
