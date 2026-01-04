#!/bin/bash
set -e

echo "===== Storj Uploader Development Container Setup ====="

# Update package lists
echo "Updating package lists..."
sudo apt-get update

# Install system dependencies
echo "Installing system dependencies..."
sudo apt-get install -y curl wget git build-essential

# Install Azure CLI (includes Bicep CLI)
echo "Installing Azure CLI..."
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Ensure latest Bicep CLI
echo "Ensuring Bicep CLI is installed..."
az bicep install
az bicep version

# Install rclone
echo "Installing rclone..."
curl https://rclone.org/install.sh | sudo bash

# Verify rclone installation
rclone version

# Install Flutter SDK
echo "Installing Flutter SDK..."
if [ ! -d "$HOME/flutter" ]; then
    cd ~
    git clone https://github.com/flutter/flutter.git -b stable
    cd -
fi

# Add Flutter to PATH permanently
if ! grep -q 'flutter/bin' ~/.bashrc; then
    echo 'export PATH="$HOME/flutter/bin:$PATH"' >> ~/.bashrc
    echo "Added Flutter to PATH in ~/.bashrc"
fi

# Export Flutter PATH for this session
export PATH="$HOME/flutter/bin:$PATH"

# Precache Flutter
echo "Precaching Flutter..."
flutter precache

# Verify Flutter installation
flutter --version

# Install Android SDK Command Line Tools
echo "Installing Android SDK Command Line Tools..."
sudo apt-get install -y openjdk-17-jdk unzip

# Set JAVA_HOME
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
if ! grep -q 'JAVA_HOME' ~/.bashrc; then
    echo 'export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64' >> ~/.bashrc
    echo 'export PATH="$JAVA_HOME/bin:$PATH"' >> ~/.bashrc
    echo "Added JAVA_HOME to PATH in ~/.bashrc"
fi

# Install Android Command Line Tools
ANDROID_SDK_ROOT="$HOME/Android/Sdk"
if [ ! -d "$ANDROID_SDK_ROOT" ]; then
    echo "Setting up Android SDK..."
    mkdir -p "$ANDROID_SDK_ROOT/cmdline-tools"
    cd "$ANDROID_SDK_ROOT/cmdline-tools"

    # Download Android Command Line Tools
    wget -q https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip
    unzip -q commandlinetools-linux-11076708_latest.zip
    mv cmdline-tools latest
    rm commandlinetools-linux-11076708_latest.zip

    cd -
fi

# Set Android environment variables
if ! grep -q 'ANDROID_SDK_ROOT' ~/.bashrc; then
    echo 'export ANDROID_SDK_ROOT="$HOME/Android/Sdk"' >> ~/.bashrc
    echo 'export PATH="$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:$PATH"' >> ~/.bashrc
    echo 'export PATH="$ANDROID_SDK_ROOT/platform-tools:$PATH"' >> ~/.bashrc
    echo "Added Android SDK to PATH in ~/.bashrc"
fi

export ANDROID_SDK_ROOT="$HOME/Android/Sdk"
export PATH="$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:$PATH"
export PATH="$ANDROID_SDK_ROOT/platform-tools:$PATH"

# Accept Android licenses and install required SDK packages
echo "Installing Android SDK packages..."
yes | sdkmanager --licenses >/dev/null 2>&1 || true
sdkmanager "platform-tools" "platforms;android-35" "build-tools;35.0.0" "cmdline-tools;latest"

# Run Flutter doctor to accept Android licenses
echo "Configuring Flutter for Android..."
flutter doctor --android-licenses || true
flutter config --android-sdk "$ANDROID_SDK_ROOT"

# Verify Flutter setup
flutter doctor -v

# Create necessary directories
echo "Creating necessary directories..."
mkdir -p storj_container_app/upload_target
mkdir -p storj_container_app/uploaded
mkdir -p storj_uploader_backend_api_container_app/temp

# Install Python dependencies for Storj Container App
echo "Installing Python dependencies for Storj Container App..."
cd storj_container_app
pip install -r requirements.txt
cd ..

# Install Python dependencies for Backend API
echo "Installing Python dependencies for Backend API..."
cd storj_uploader_backend_api_container_app
pip install -r requirements.txt
cd ..

# Install Node.js dependencies for Frontend
echo "Installing Node.js dependencies for Frontend..."
cd storj_uploader_frontend_container_app
npm install
cd ..

# Create .env files if they don't exist
echo "Creating .env files from examples (if they don't exist)..."

# Storj Container App .env
if [ ! -f storj_container_app/.env ] && [ -f storj_container_app/.env.example ]; then
    cp storj_container_app/.env.example storj_container_app/.env
    echo "Created storj_container_app/.env from .env.example"
fi

# Backend API .env
if [ ! -f storj_uploader_backend_api_container_app/.env ]; then
    cat > storj_uploader_backend_api_container_app/.env <<EOF
UPLOAD_TARGET_DIR=../storj_container_app/upload_target
TEMP_DIR=./temp
MAX_FILE_SIZE=2000000000
API_HOST=0.0.0.0
API_PORT=8010
EOF
    echo "Created storj_uploader_backend_api_container_app/.env"
fi

# Frontend .env
if [ ! -f storj_uploader_frontend_container_app/.env ]; then
    cat > storj_uploader_frontend_container_app/.env <<EOF
REACT_APP_API_URL=http://localhost:8010
EOF
    echo "Created storj_uploader_frontend_container_app/.env"
fi

# Flutter App .env
if [ ! -f flutter_app_storj_uploader/.env ]; then
    cat > flutter_app_storj_uploader/.env <<EOF
# Storj Uploader Flutter App - Environment Variables
# Local development
API_BASE_URL=http://localhost:8010

# App Configuration
APP_NAME=Storj Uploader
APP_VERSION=1.0.0

# Feature Flags
ENABLE_DEBUG_LOGGING=false
ENABLE_AUTO_UPLOAD=true
EOF
    echo "Created flutter_app_storj_uploader/.env"
fi

# Install Flutter dependencies
echo "Installing Flutter dependencies..."
cd flutter_app_storj_uploader
flutter pub get
cd ..

echo ""
echo "===== Setup Complete ====="
echo ""
echo "Next steps:"
echo "1. Configure rclone for Storj access:"
echo "   rclone config"
echo ""
echo "2. Copy your rclone.conf to storj_container_app/:"
echo "   cp ~/.config/rclone/rclone.conf storj_container_app/"
echo ""
echo "3. Update .env files with your Storj bucket settings"
echo ""
echo "To start development:"
echo "  Backend:       cd storj_uploader_backend_api_container_app && python main.py"
echo "  Frontend:      cd storj_uploader_frontend_container_app && npm start"
echo "  Flutter Web:   cd flutter_app_storj_uploader && flutter run -d web-server --web-port 8080"
echo "  Flutter Chrome: cd flutter_app_storj_uploader && flutter run -d chrome"
echo ""
echo "Flutter Doctor:"
flutter doctor
echo ""
