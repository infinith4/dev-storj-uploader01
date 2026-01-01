# Use official Flutter Docker image
FROM ghcr.io/cirruslabs/flutter:stable

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

# Ensure asset directories and env file exist for web build
RUN mkdir -p assets/images assets/icons && \
    if [ ! -f .env ]; then \
      if [ -f .env.example ]; then cp .env.example .env; else touch .env; fi; \
    fi

# Enable web platform and build
ENV FLUTTER_WEB_USE_SKIA=true
RUN flutter config --enable-web && \
    flutter create . --platforms web && \
    flutter build web --release --web-renderer canvaskit

# Use nginx to serve the web app
FROM nginx:alpine

# Copy built web files to nginx
COPY --from=0 /app/build/web /usr/share/nginx/html

# Copy nginx configuration
COPY nginx.conf /etc/nginx/nginx.conf

# Expose port 80
EXPOSE 80

# Start nginx
CMD ["nginx", "-g", "daemon off;"]
