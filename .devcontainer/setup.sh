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
MAX_FILE_SIZE=100000000
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
echo "  Backend:  cd storj_uploader_backend_api_container_app && python main.py"
echo "  Frontend: cd storj_uploader_frontend_container_app && npm start"
echo ""
