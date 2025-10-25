FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        unzip \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p ./storj_container_app/upload_target ./storj_container_app/uploaded

RUN chmod +x ./devcontainer/setup.sh
