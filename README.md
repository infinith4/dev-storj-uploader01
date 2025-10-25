Frontend, Backend 起動

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