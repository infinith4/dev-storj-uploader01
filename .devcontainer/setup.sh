#!/bin/bash
set -e

# Update package lists
apt-get update
npm install -g @anthropic-ai/claude-code
# Install Python requirements
pip install -r requirements.txt

# Install rclone
curl https://rclone.org/install.sh | bash
