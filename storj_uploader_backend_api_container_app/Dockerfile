FROM python:3.12-slim

WORKDIR /app

# システムの依存関係をインストール (rclone追加)
RUN apt-get update && apt-get install -y \
    curl \
    unzip \
    && curl https://rclone.org/install.sh | bash \
    && rm -rf /var/lib/apt/lists/*

# Pythonの依存関係をコピー・インストール
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# アプリケーションコードをコピー
COPY . .

# ディレクトリ作成
RUN mkdir -p temp

# ポート設定
EXPOSE 8010

# アプリケーション起動
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8010", "--reload"]