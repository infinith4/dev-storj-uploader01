@echo off
REM Flutter Android Build Script for Windows
REM This script builds the Android APK for the Storj Uploader Flutter app

setlocal EnableDelayedExpansion

echo ==========================================
echo Flutter Android Build Script
echo ==========================================
echo.

REM Check if Flutter is installed
where flutter >nul 2>nul
if %errorlevel% neq 0 (
    echo Error: Flutter is not installed or not in PATH
    echo Please install Flutter: https://docs.flutter.dev/get-started/install
    exit /b 1
)

REM Check Flutter version
echo Flutter version:
flutter --version
echo.

REM Check if .env file exists
if not exist ".env" (
    echo Warning: .env file not found
    if exist ".env.example" (
        echo Creating .env from .env.example...
        copy .env.example .env
        echo Created .env file. Please edit it with your API URL.
    ) else (
        echo Error: .env.example not found. Creating default .env...
        (
            echo API_BASE_URL=http://localhost:8010
            echo APP_NAME=Storj Uploader
            echo APP_VERSION=1.0.0
            echo ENABLE_DEBUG_LOGGING=false
            echo ENABLE_AUTO_UPLOAD=true
        ) > .env
        echo Created default .env file.
    )
    echo.
)

REM Show current API configuration
echo Current API Configuration:
if exist ".env" (
    findstr "API_BASE_URL" .env
) else (
    echo Warning: .env file not found
)
echo.

REM Get dependencies
echo Getting Flutter dependencies...
flutter pub get
echo.

REM Clean build artifacts
echo Cleaning previous build artifacts...
flutter clean
echo.

REM Parse command line arguments
set BUILD_TYPE=debug
set SPLIT_PER_ABI=false
set ANALYZE_SIZE=false

:parse_args
if "%~1"=="" goto end_parse
if /i "%~1"=="--release" (
    set BUILD_TYPE=release
    shift
    goto parse_args
)
if /i "%~1"=="--split-per-abi" (
    set SPLIT_PER_ABI=true
    shift
    goto parse_args
)
if /i "%~1"=="--analyze-size" (
    set ANALYZE_SIZE=true
    shift
    goto parse_args
)
if /i "%~1"=="--help" (
    echo Usage: %~nx0 [OPTIONS]
    echo.
    echo Options:
    echo   --release         Build release APK ^(default: debug^)
    echo   --split-per-abi   Split APK per ABI ^(arm64-v8a, armeabi-v7a, x86_64^)
    echo   --analyze-size    Analyze APK size after build
    echo   --help            Show this help message
    echo.
    echo Examples:
    echo   %~nx0                      # Build debug APK
    echo   %~nx0 --release            # Build release APK
    echo   %~nx0 --release --split-per-abi  # Build release with ABI splits
    exit /b 0
)
echo Unknown option: %~1
echo Use --help for usage information
exit /b 1

:end_parse

REM Build APK
echo Building Android APK ^(%BUILD_TYPE% mode^)...
if "%SPLIT_PER_ABI%"=="true" (
    flutter build apk --%BUILD_TYPE% --split-per-abi
) else (
    flutter build apk --%BUILD_TYPE%
)
echo.

REM Show build output location
echo Build completed successfully!
echo.
echo APK Location:
if "%BUILD_TYPE%"=="release" (
    if "%SPLIT_PER_ABI%"=="true" (
        dir /s /b build\app\outputs\flutter-apk\app-*-release.apk
    ) else (
        dir build\app\outputs\flutter-apk\app-release.apk
    )
) else (
    dir build\app\outputs\flutter-apk\app-debug.apk
)
echo.

REM Analyze size if requested
if "%ANALYZE_SIZE%"=="true" (
    echo Analyzing APK size...
    if "%BUILD_TYPE%"=="release" (
        flutter build apk --analyze-size --%BUILD_TYPE%
    )
    echo.
)

REM Show installation instructions
echo Installation:
echo   1. Connect your Android device via USB
echo   2. Enable USB debugging on your device
echo   3. Run: flutter install
echo   4. Or manually install: adb install build\app\outputs\flutter-apk\app-%BUILD_TYPE%.apk
echo.

REM Show next steps
echo Next Steps:
echo   - Test on emulator: flutter run -d android
echo   - Install on device: flutter install
echo   - View logs: flutter logs
echo.

echo ==========================================
echo Build completed!
echo ==========================================

endlocal
