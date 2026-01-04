#!/bin/bash

# Flutter Android Build Script
# This script builds the Android APK for the Storj Uploader Flutter app

set -e

echo "=========================================="
echo "Flutter Android Build Script"
echo "=========================================="
echo ""

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    echo "❌ Error: Flutter is not installed or not in PATH"
    echo "Please install Flutter: https://docs.flutter.dev/get-started/install"
    exit 1
fi

# Check Flutter version
echo "📱 Flutter version:"
flutter --version
echo ""

# Check if .env file exists
if [ ! -f ".env" ]; then
    echo "⚠️  Warning: .env file not found"
    echo "Creating .env from .env.example..."
    if [ -f ".env.example" ]; then
        cp .env.example .env
        echo "✅ Created .env file. Please edit it with your API URL."
    else
        echo "❌ Error: .env.example not found. Creating default .env..."
        cat > .env << 'EOF'
API_BASE_URL=http://localhost:8010
APP_NAME=Storj Uploader
APP_VERSION=1.0.0
ENABLE_DEBUG_LOGGING=false
ENABLE_AUTO_UPLOAD=true
EOF
        echo "✅ Created default .env file."
    fi
    echo ""
fi

# Show current API configuration
echo "📡 Current API Configuration:"
if [ -f ".env" ]; then
    grep "API_BASE_URL" .env || echo "API_BASE_URL not set"
else
    echo "⚠️  .env file not found"
fi
echo ""

# Get dependencies
echo "📦 Getting Flutter dependencies..."
flutter pub get
echo ""

# Clean build artifacts
echo "🧹 Cleaning previous build artifacts..."
flutter clean
echo ""

# Parse command line arguments
BUILD_TYPE="debug"
SPLIT_PER_ABI=false
ANALYZE_SIZE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --release)
            BUILD_TYPE="release"
            shift
            ;;
        --split-per-abi)
            SPLIT_PER_ABI=true
            shift
            ;;
        --analyze-size)
            ANALYZE_SIZE=true
            shift
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --release         Build release APK (default: debug)"
            echo "  --split-per-abi   Split APK per ABI (arm64-v8a, armeabi-v7a, x86_64)"
            echo "  --analyze-size    Analyze APK size after build"
            echo "  --help            Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0                      # Build debug APK"
            echo "  $0 --release            # Build release APK"
            echo "  $0 --release --split-per-abi  # Build release with ABI splits"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Build APK
echo "🔨 Building Android APK ($BUILD_TYPE mode)..."
if [ "$SPLIT_PER_ABI" = true ]; then
    flutter build apk --$BUILD_TYPE --split-per-abi
else
    flutter build apk --$BUILD_TYPE
fi
echo ""

# Show build output location
echo "✅ Build completed successfully!"
echo ""
echo "📁 APK Location:"
if [ "$BUILD_TYPE" = "release" ]; then
    if [ "$SPLIT_PER_ABI" = true ]; then
        find build/app/outputs/flutter-apk -name "app-*-release.apk" -type f
    else
        ls -lh build/app/outputs/flutter-apk/app-release.apk
    fi
else
    ls -lh build/app/outputs/flutter-apk/app-debug.apk
fi
echo ""

# Analyze size if requested
if [ "$ANALYZE_SIZE" = true ]; then
    echo "📊 Analyzing APK size..."
    if [ "$BUILD_TYPE" = "release" ]; then
        flutter build apk --analyze-size --$BUILD_TYPE
    fi
    echo ""
fi

# Show installation instructions
echo "📲 Installation:"
echo "  1. Connect your Android device via USB"
echo "  2. Enable USB debugging on your device"
echo "  3. Run: flutter install"
echo "  4. Or manually install: adb install build/app/outputs/flutter-apk/app-$BUILD_TYPE.apk"
echo ""

# Show next steps
echo "🚀 Next Steps:"
echo "  - Test on emulator: flutter run -d android"
echo "  - Install on device: flutter install"
echo "  - View logs: flutter logs"
echo ""

echo "=========================================="
echo "Build completed!"
echo "=========================================="
