# Use official Flutter Docker image
FROM ghcr.io/cirruslabs/flutter:stable AS builder

# Build arguments for environment configuration
ARG API_BASE_URL=https://stjup2-backend-udm3tutq7eb7i.yellowplant-e4c48860.japaneast.azurecontainerapps.io
ARG ENABLE_DEBUG_LOGGING=false

# Set working directory
WORKDIR /app

# Check if flutter user exists, if not create it
RUN id -u flutter >/dev/null 2>&1 || useradd -m flutter

# Copy pubspec files
COPY --chown=flutter:flutter pubspec.yaml pubspec.lock ./

# Get dependencies
RUN flutter pub get

# Copy source code
COPY --chown=flutter:flutter . .

# Ensure asset directories exist
RUN mkdir -p assets/images assets/icons

# Create .env file with build arguments (overwrite any existing)
RUN echo "# Auto-generated during Docker build" > .env && \
    echo "API_BASE_URL=${API_BASE_URL}" >> .env && \
    echo "APP_NAME=Storj Uploader" >> .env && \
    echo "APP_VERSION=1.0.0" >> .env && \
    echo "ENABLE_DEBUG_LOGGING=${ENABLE_DEBUG_LOGGING}" >> .env && \
    echo "ENABLE_AUTO_UPLOAD=true" >> .env && \
    cat .env

# Enable web platform and build
ENV FLUTTER_WEB_USE_SKIA=true
RUN flutter config --enable-web && \
    flutter create . --platforms web && \
    flutter build web --release

# Use nginx to serve the web app
FROM nginx:alpine

# Copy built web files to nginx
COPY --from=builder /app/build/web /usr/share/nginx/html

# Copy nginx configuration
COPY nginx.conf /etc/nginx/nginx.conf

# Expose port 80
EXPOSE 80

# Start nginx
CMD ["nginx", "-g", "daemon off;"]
