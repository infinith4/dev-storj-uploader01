# Storj Uploader Project

このプロジェクトは、Storjクラウドストレージへのファイルアップロードシステムです。

## プロジェクト構成

- **storj_uploader_frontend_container_app** - React + TypeScript フロントエンド
- **storj_uploader_backend_api_container_app** - FastAPI バックエンドAPI
- **storj_container_app** - rcloneベースのコアアップローダー
- **android_storj_uploader** - Android モバイルアプリ (Kotlin)

## Android アプリ

Androidモバイルアプリは `android_storj_uploader` フォルダに配置されています。

### 機能
- Storj APIへの写真・動画アップロード
- アップロード履歴の表示
- バックグラウンドでの自動アップロード

### ドキュメント

- [android_storj_uploader/README.md](android_storj_uploader/README.md) - ビルド方法と使い方
- [android_storj_uploader/SCREEN_DESIGN.md](android_storj_uploader/SCREEN_DESIGN.md) - 画面設計書・画面遷移図
- [android_storj_uploader/RELEASE.md](android_storj_uploader/RELEASE.md) - リリースビルド手順

#### GitHub Actionsでの自動ビルド

プッシュまたはPRで自動的にビルドが実行されます：
- ✅ デバッグAPKのビルド
- ✅ ユニットテストの実行
- ✅ Lintチェック
- ✅ アーティファクトのアップロード

#### リリースビルド

バージョンタグをプッシュすると、署名付きリリースAPKが自動生成されます：

```bash
git tag v1.0
git push origin --tags
```

詳細な手順は [android_storj_uploader/RELEASE.md](android_storj_uploader/RELEASE.md) を参照してください。

## Frontend, Backend 起動

```bash
cd /workspaces/dev-storj-uploader01/storj_uploader_frontend_container_app/
docker compose down
docker rmi storj_uploader_frontend_container_app-backend
docker rmi storj_uploader_frontend_container_app-frontend
docker-compose up --build
```


batch 実行

```
docker run -v ./upload_target:/app/upload_target \
           -v ./uploaded:/app/uploaded \
           -v ./rclone.conf:/root/.config/rclone/rclone.conf:ro \
           -v ./.env:/app/.env:ro \
           storj-uploader
```

```

cd storj_mount_drive/
docker-compose up -d
```

## Flutter SDK の使用

Dev Container 環境では Flutter SDK がインストールされています。

```bash
# Flutter のバージョン確認
flutter --version

# Flutter プロジェクトの依存関係を取得
flutter pub get

# 新規 Flutter プロジェクトを作成
flutter create my_app

# Flutter アプリを実行
flutter run
```

**注意**: 新しいターミナルを開いた際に `flutter` コマンドが見つからない場合は、以下を実行してください：

```bash
export PATH="$HOME/flutter/bin:$PATH"
```

---

## Claude Code 自動承認設定

# ファイル作成のみ自動承認
claude code config set auto-approve-create true

# ファイル編集のみ自動承認
claude code config set auto-approve-edit true

# ファイル削除のみ自動承認
claude code config set auto-approve-delete true

# コマンド実行のみ自動承認
claude code config set auto-approve-run true

# 現在のセッションのみ自動承認
claude code --session-auto-approve

# 危険な操作は除外して自動承認
claude code --auto-approve --exclude-dangerous


# 現在の設定を確認
claude code config list

# 自動承認を無効化
claude code config set auto-approve false

# すべての自動承認設定をリセット
claude code config reset auto-approve

# すべての操作を自動承認する設定
claude code --auto-approve

# または設定ファイルで恒久的に設定
claude code config set auto-approve true