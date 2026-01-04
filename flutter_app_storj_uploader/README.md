# Storj Uploader Flutter App

Flutter web application that provides a user-friendly interface for uploading files to Storj storage via the backend API.

## Features

- **File Upload**: Support for images, videos, and documents
- **Drag & Drop**: Intuitive file selection interface
- **Upload Queue**: Manage files before uploading
- **System Status**: Monitor backend service status
- **Cross-platform**: Works on web, mobile, and desktop
- **Responsive Design**: Material Design 3 with light/dark themes

## Architecture

- **Frontend**: Flutter with Riverpod state management
- **Backend API**: storj_uploader_backend_api_container_app
- **File Services**: Cross-platform file picking and handling
- **API Client**: Dio HTTP client with error handling

## Quick Start

### Development

```bash
# Install dependencies
flutter pub get

# Run on Web
flutter run -d web-server --web-port 8080

# Run on Android (emulator or connected device)
flutter run -d android

# Run on Chrome browser
flutter run -d chrome
```

### Android Development with Android Studio

You can open and develop the Android part of this Flutter project directly in Android Studio:

1. **Open in Android Studio**:
   - Launch Android Studio
   - Select "Open an Existing Project"
   - Navigate to `flutter_app_storj_uploader/android/` and open it
   - Android Studio will sync Gradle automatically

2. **Run/Debug from Android Studio**:
   - Select your device/emulator from the device dropdown
   - Click the Run button (▶) or Debug button (🐛)
   - The app will build and launch

3. **Edit Native Android Code**:
   - Open `app/src/main/kotlin/com/example/storj_uploader_flutter/MainActivity.kt`
   - You can add native Android features using platform channels

4. **Gradle Tasks**:
   - Right-click on the project → Tasks → build → assembleDebug
   - Or use Terminal in Android Studio: `./gradlew assembleDebug`

### Android APK Build (Command Line)

**Quick Build (Using Build Scripts):**

```bash
# Linux/Mac
./build_android.sh                 # Build debug APK
./build_android.sh --release       # Build release APK
./build_android.sh --release --split-per-abi  # Build with ABI splits
./build_android.sh --help          # Show all options

# Windows
build_android.bat                  # Build debug APK
build_android.bat --release        # Build release APK
build_android.bat --release --split-per-abi
```

**Manual Build:**

```bash
# Debug APK
flutter build apk --debug

# Release APK (requires signing config)
flutter build apk --release

# Release APK with ABI splits (recommended for production)
flutter build apk --release --split-per-abi

# APK output location:
# build/app/outputs/flutter-apk/app-debug.apk
# build/app/outputs/flutter-apk/app-release.apk
# build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
# build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk
# build/app/outputs/flutter-apk/app-x86_64-release.apk

# Install on connected device
flutter install

# Or use Gradle directly from android directory:
cd android
./gradlew assembleDebug        # Linux/Mac
gradlew.bat assembleDebug      # Windows
```

**Note**: For Android builds, you need to have Android SDK installed. The app requires:
- minSdkVersion: 24 (Android 7.0)
- compileSdkVersion: 35 (Android 15)
- targetSdkVersion: 35 (Android 15)
- Kotlin: 2.0.21
- Android Gradle Plugin: 8.7.3
- Java: 17

**Android Azure Connection**: The `.env` file is automatically included in the Android build, so the same Azure Backend URL configured for Web will be used for Android as well.

### Production (Docker)

```bash
# Build and run with Docker Compose
docker-compose up --build

# Access the app at http://localhost:3000
```

## Configuration

### Environment Variables

The app uses environment variables for configuration. Copy `.env.example` to `.env` and configure:

```bash
cp .env.example .env
```

Edit `.env` to set the API base URL:

```env
# Local development
API_BASE_URL=http://localhost:8010

# Azure Container Apps (Production)
API_BASE_URL=https://stjup2-backend-udm3tutq7eb7i.yellowplant-e4c48860.japaneast.azurecontainerapps.io
```

### Azure Environment Connection

To connect to the Azure production environment:

1. **Option 1: Use .env file** (Recommended for development)
   ```bash
   # Edit .env file
   API_BASE_URL=https://stjup2-backend-udm3tutq7eb7i.yellowplant-e4c48860.japaneast.azurecontainerapps.io

   # Run the app
   flutter run -d chrome
   ```

2. **Option 2: Use Settings Screen** (Runtime configuration)
   - Launch the app
   - Tap the Settings icon (⚙️) in the app bar
   - Under "Quick Presets", select "Azure Production"
   - Tap "Test Connection" to verify
   - Tap "Save Settings"

3. **Option 3: Edit constants.dart** (Not recommended)
   - Modify `lib/utils/constants.dart`
   - Change the default URL (will be overridden by .env)

### Configuration Files

- `.env` - Environment variables (not committed to git)
- `.env.example` - Template for environment variables
- `lib/utils/constants.dart` - App constants and API endpoints
- `nginx.conf` - Nginx proxy configuration for production

## File Support

### Supported Formats

- **Images**: JPG, JPEG, PNG, GIF, WebP, BMP, HEIC, HEIF
- **Videos**: MP4, MOV, AVI, MKV, WebM, FLV, 3GP
- **Documents**: PDF, DOC, DOCX, XLS, XLSX, PPT, PPTX, TXT

### Size Limits

- Images: 50MB maximum
- Other files: 500MB maximum

## Development

### Project Structure

```
lib/
├── main.dart                 # App entry point
├── models/                   # Data models
│   └── api_models.dart      # API response models
├── services/                 # Business logic
│   ├── api_service.dart     # HTTP client
│   └── file_service.dart    # File operations
├── screens/                  # UI screens
│   └── home_screen.dart     # Main interface
├── widgets/                  # Reusable components
│   ├── file_upload_area.dart
│   ├── upload_queue.dart
│   ├── system_status_card.dart
│   └── connection_status.dart
└── utils/                    # Utilities
    └── constants.dart       # App constants
```

### Key Dependencies

- `flutter_riverpod`: State management
- `dio`: HTTP client
- `file_picker`: Cross-platform file selection
- `image_picker`: Camera and gallery access
- `path_provider`: File system access
- `mime`: MIME type detection
- `uuid`: Unique ID generation

## Docker Deployment

The app is containerized using a multi-stage Docker build:

1. **Build Stage**: Uses Flutter Docker image to build web version
2. **Runtime Stage**: Uses nginx to serve static files

### Environment Variables

- `FLUTTER_WEB_USE_SKIA=true`: Enable Skia rendering for better performance

## API Integration

The app integrates with the following backend endpoints:

- `GET /health` - Health check
- `GET /status` - System status
- `POST /upload` - Upload multiple images
- `POST /upload/single` - Upload single image
- `POST /upload/files` - Upload multiple files
- `POST /upload/files/single` - Upload single file
- `POST /trigger-upload` - Trigger Storj upload
- `POST /trigger-upload-async` - Async Storj upload

## Error Handling

- Network connectivity monitoring
- File validation (size, type, existence)
- Comprehensive error messages
- Retry mechanisms for failed uploads
- Graceful degradation when backend is unavailable

## Performance

- Lazy loading of widgets
- Image compression for uploads
- Batch uploading with configurable limits
- Caching of API responses
- Optimized nginx configuration with gzip compression

## Troubleshooting

### Web Version Drag & Drop Issues

If you encounter errors when using drag & drop in the web version (`flutter run -d web-server`):

**Problem**: `flutter_dropzone` package has compatibility issues with some Flutter web server configurations.

**Solution**: Use the file picker button instead:

1. Click the "Select Files" button instead of dragging files
2. This uses the `file_picker` package which has better web compatibility

**Alternative**: If you need drag & drop functionality:

1. Build and run with production configuration:
   ```bash
   flutter build web --release
   cd build/web
   python3 -m http.server 8080
   ```

2. Or use Chrome browser directly:
   ```bash
   flutter run -d chrome
   ```

### API Connection Issues

If the app cannot connect to the backend:

1. **Check API URL**: Go to Settings → verify API Base URL
2. **Test Connection**: Tap "Test Connection" button in Settings
3. **Check Backend**: Ensure backend API is running:
   ```bash
   curl https://stjup2-backend-udm3tutq7eb7i.yellowplant-e4c48860.japaneast.azurecontainerapps.io/health
   ```
4. **CORS Issues**: If running locally, ensure backend allows CORS from your origin

### Environment Variable Not Loading

If `.env` file is not loading:

1. Ensure `.env` file is in the project root (`flutter_app_storj_uploader/.env`)
2. Check that `.env` is listed in `pubspec.yaml` under `assets:`
3. Run `flutter pub get` after modifying `pubspec.yaml`
4. Clean and rebuild:
   ```bash
   flutter clean
   flutter pub get
   flutter build web
   ```

## Azure Container Apps Deployment

To deploy the Flutter app to Azure Container Apps:

### Prerequisites

- Azure CLI installed and logged in
- ACR (Azure Container Registry) access
- `.env` file configured with Azure backend URL

### Build and Push Docker Image

```bash
# Login to Azure Container Registry
az acr login --name stjup2acrudm3tutq7eb7i

# Build the Docker image
docker build -t stjup2acrudm3tutq7eb7i.azurecr.io/storj-flutter:latest .

# Push to ACR
docker push stjup2acrudm3tutq7eb7i.azurecr.io/storj-flutter:latest
```

### Deploy to Container Apps

The Flutter app can be deployed as a separate Container App or served from the frontend container. See `AZURE_ENV.md` for deployment details.

### Environment Configuration for Azure

When deploying to Azure, ensure the `.env` file is built into the image with the Azure backend URL:

```dockerfile
# In Dockerfile, before building
COPY .env .env
RUN flutter build web --release
```

Or set the API URL at runtime using environment variables in the Container App configuration.

## CI/CD with GitHub Actions

This repository includes automated build workflows for Flutter Android:

### Workflow: Flutter Android CI/CD

**File**: `.github/workflows/flutter-android-build.yml`

**Triggers**:
- Push to `main`, `master`, `develop`, or `claude/**` branches
- Pull requests to `main`, `master`, or `develop` branches
- Manual workflow dispatch

**Jobs**:

1. **build-android**: Builds Flutter Android APKs
   - Runs on every push/PR
   - Outputs:
     - Debug APK: `flutter-app-debug`
     - Release APK: `flutter-app-release`
     - Split APKs: `flutter-app-release-split` (arm64-v8a, armeabi-v7a, x86_64)
   - Also runs `flutter analyze` and `flutter test`

2. **release**: Creates GitHub Release
   - Runs only on tag push matching `flutter-v*` (e.g., `flutter-v1.0.0`)
   - Uploads split APKs to GitHub Release
   - Generates release notes with installation instructions

3. **quality**: Code quality checks
   - Runs `flutter analyze` and `flutter format`
   - Uploads analysis reports as artifacts

### Creating a Release

To create a new Flutter Android release:

```bash
# Tag the current commit
git tag flutter-v1.0.0
git push origin flutter-v1.0.0

# GitHub Actions will automatically:
# 1. Build release APKs with ABI splits
# 2. Create a GitHub Release
# 3. Upload APKs to the release
```

### Downloading Build Artifacts

After a successful build, you can download the APK artifacts from:
- GitHub Actions → Select workflow run → Artifacts section
- Or from the GitHub Release page (for tagged releases)

### Local Testing Before Release

Before creating a release tag, test the build locally:

```bash
# Use the build script
./build_android.sh --release --split-per-abi

# Or use Flutter directly
flutter build apk --release --split-per-abi

# Test the APK on a device
adb install build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```