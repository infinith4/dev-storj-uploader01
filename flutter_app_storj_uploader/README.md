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

### Android APK Build

```bash
# Debug APK
flutter build apk --debug

# Release APK (requires signing config)
flutter build apk --release

# APK output location:
# build/app/outputs/flutter-apk/app-debug.apk
# build/app/outputs/flutter-apk/app-release.apk

# Install on connected device
flutter install
```

**Note**: For Android builds, you need to have Android SDK installed. The app requires:
- minSdkVersion: 24 (Android 7.0)
- targetSdkVersion: 34 (Android 14)

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