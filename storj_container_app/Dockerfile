FROM python:3.12-slim

# Prevent Python from writing .pyc files and enable unbuffered logs
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

# Install OS deps and rclone
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        unzip \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /root/.config/rclone \
    && curl -fsSL https://rclone.org/install.sh | bash

# Install Python dependencies first for better layer caching
COPY requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . /app

# Ensure runtime directories exist
RUN mkdir -p /app/upload_target /app/uploaded

# Copy and setup entrypoint script
COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

# Use entrypoint script
ENTRYPOINT ["/docker-entrypoint.sh"]
EXPOSE 8080
