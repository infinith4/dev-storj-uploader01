FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        unzip \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p upload_target uploaded

RUN chmod +x ./devcontainer/setup.sh
