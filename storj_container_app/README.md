# Storj Uploader

Storjクラウドストレージにファイルを自動アップロードするPythonコンテナアプリケーションです。

## 機能

- rcloneを使用したStorjバケットの自動作成（存在しない場合のみ）
- YYYYMM形式のディレクトリ構造でファイルアップロード
- アップロード後のファイル自動移動機能
- Dockerコンテナでの実行

## セットアップ

### 1. 環境設定

`.env.example`を`.env`にコピーして設定を調整：

```bash
cp .env.example .env
```

`.env`ファイルを編集：

```
STORJ_BUCKET_NAME=your-bucket-name
STORJ_REMOTE_NAME=storj
```

### 2. rclone設定

Storjアクセス用のrclone設定ファイル(`rclone.conf`)を準備します。

rclone設定の例：

```bash
rclone config
```

設定後、`~/.config/rclone/rclone.conf`をプロジェクトルートにコピー：

```bash
cp ~/.config/rclone/rclone.conf ./rclone.conf
```

## 使用方法

### Docker Composeを使用する場合（推奨）

```bash
docker compose down
docker rmi storj_container_app-storj_container_app
```



1. アップロード対象ファイルを`upload_target`フォルダに配置

2. コンテナを実行：

```bash
docker-compose up
```

### Dockerを直接使用する場合

1. イメージをビルド：

```bash
docker build -t storj-uploader .
```

2. コンテナを実行：

```bash
docker run -v ./upload_target:/app/upload_target \
           -v ./uploaded:/app/uploaded \
           -v ./rclone.conf:/root/.config/rclone/rclone.conf:ro \
           -v ./.env:/app/.env:ro \
           storj-uploader
```

### 開発環境（devcontainer）

VS Codeでプロジェクトを開き、「Reopen in Container」を選択します。

## ディレクトリ構造

```
.
├── upload_target/     # アップロード対象ファイルを配置
├── uploaded/          # アップロード完了後のファイルが移動
├── .devcontainer/     # devcontainer設定
├── storj_uploader.py  # メインアプリケーション
├── requirements.txt   # Python依存関係
├── Dockerfile         # Docker設定
├── docker-compose.yml # Docker Compose設定
├── .env.example       # 環境変数の例
└── rclone.conf        # rclone設定ファイル（要作成）
```

## 処理フロー

1. Storjバケットの存在確認
2. バケットが存在しない場合は自動作成
3. `upload_target`内のファイルを`YYYYMM`形式のディレクトリにアップロード
4. アップロード成功後、ファイルを`uploaded`フォルダに移動

## 注意事項

- rclone.confファイルには認証情報が含まれるため、適切に管理してください
- upload_targetとuploadedディレクトリは自動作成されます
- 同名ファイルがuploaded内に存在する場合は上書きされます