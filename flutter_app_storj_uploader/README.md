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

# Run in debug mode
flutter run -d web-server --web-port 8080

```

### Production (Docker)

```bash
# Build and run with Docker Compose
docker-compose up --build

# Access the app at http://localhost:3000
```

## Configuration

The app connects to the backend API at `http://localhost:8010` by default. This can be configured in:

- `lib/utils/constants.dart` - API base URL
- `nginx.conf` - Proxy configuration for production

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