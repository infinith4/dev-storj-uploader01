# Dev Container 設定

このディレクトリには、Storj Uploader プロジェクトの Dev Container 設定が含まれています。

## 使用方法

### VS Code で開く

1. VS Code で拡張機能 "Dev Containers" をインストール
2. このプロジェクトを VS Code で開く
3. コマンドパレット（Cmd/Ctrl + Shift + P）を開く
4. "Dev Containers: Reopen in Container" を選択

コンテナが起動すると、自動的に以下が実行されます：
- Python 3.11 のインストール
- Node.js 18 のインストール
- rclone のインストール
- 全コンポーネントの依存関係インストール（pip、npm）
- 必要なディレクトリの作成
- .env ファイルのテンプレート作成

### 初回セットアップ後

Dev Container が起動したら、以下の手順で rclone を設定してください：

```bash
# 1. rclone の設定
rclone config

# 2. 設定ファイルをコピー
cp ~/.config/rclone/rclone.conf storj_container_app/

# 3. .env ファイルを編集（各コンポーネントのディレクトリにあります）
# - storj_container_app/.env
# - storj_uploader_backend_api_container_app/.env
# - storj_uploader_frontend_container_app/.env
```

## ポートフォワーディング

以下のポートが自動的にフォワードされます：

- **8010**: Backend API (FastAPI)
- **9010**: Frontend (Production build)
- **3000**: Frontend (Development server)

## 開発の開始

### バックエンド API の起動

```bash
cd storj_uploader_backend_api_container_app
python main.py
```

API ドキュメント:
- http://localhost:8010/docs (Swagger UI)
- http://localhost:8010/redoc (ReDoc)

### フロントエンドの起動

```bash
cd storj_uploader_frontend_container_app
npm start
```

ブラウザで http://localhost:3000 にアクセス

### Storj Container App の実行

```bash
cd storj_container_app
python3 storj_uploader.py
```

## インストールされているツール

- Python 3.11
- Node.js 18
- Docker-in-Docker
- Git
- rclone
- pip パッケージ（requirements.txt から）
- npm パッケージ（package.json から）

## VS Code 拡張機能

自動的にインストールされる拡張機能：

- Python
- Pylint
- Pylance
- ESLint
- Prettier
- Tailwind CSS IntelliSense
- TypeScript

## ディレクトリ構造

```
/workspaces/dev-storj-uploader01/
├── storj_container_app/
│   ├── upload_target/     # アップロード対象ファイル（マウント）
│   └── uploaded/          # アップロード完了ファイル（マウント）
├── storj_uploader_backend_api_container_app/
│   └── temp/              # 一時ファイル
└── storj_uploader_frontend_container_app/
    └── node_modules/      # npm パッケージ
```

## トラブルシューティング

### rclone が見つからない

```bash
# setup.sh を手動で再実行
bash .devcontainer/setup.sh
```

### Python/Node.js パッケージのインストールに失敗

```bash
# 各コンポーネントで手動インストール
cd storj_container_app && pip install -r requirements.txt
cd ../storj_uploader_backend_api_container_app && pip install -r requirements.txt
cd ../storj_uploader_frontend_container_app && npm install
```

### コンテナを再ビルド

1. コマンドパレットを開く
2. "Dev Containers: Rebuild Container" を選択
