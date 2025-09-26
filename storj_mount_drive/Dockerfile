FROM python:3.12-slim

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# Install rclone
RUN curl https://rclone.org/install.sh | bash

# Set working directory
WORKDIR /app

# Copy requirements and install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application files
COPY storj_virtual_drive.py .

# Create directories for virtual files and config
RUN mkdir -p /app/virtual_files /app/config

# Set environment variables
ENV PYTHONUNBUFFERED=1

# Default command
CMD ["python", "storj_virtual_drive.py", "status"]