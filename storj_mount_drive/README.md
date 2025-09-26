# Storj Virtual Drive Container

Storjバケットの構造を仮想的に再現するDockerコンテナです。実際のファイルをダウンロードせずに、ファイル構造とメタデータのみを取得してローカルでアクセス可能にします。

## 機能

- **コスト効率**: 実際のファイルをダウンロードせずにバケット構造を確認
- **ローカルアクセス**: `virtual_files`ディレクトリを通じてホストからアクセス可能
- **メタデータ保存**: ファイルサイズ、変更日時、Storj上の場所などの情報を保持
- **自動同期**: コマンド一つでStorjバケットと同期

## セットアップ

### 1. 設定ファイルの準備

既存の`storj_container_app`の設定を使用するか、独立した設定を作成：

```bash
# 独立した設定を使用する場合
cp .env.example .env
cp rclone.conf.example rclone.conf

# .envファイルを編集
vi .env

# rclone.confファイルを編集
vi rclone.conf
```

### 2. コンテナの起動

```bash
# コンテナをビルドして起動
cd storj_mount_drive/
docker-compose up -d

# ログを確認
docker-compose logs storj-virtual-drive
```

### 3. Storjバケットとの同期

```bash
# 同期実行（仮想ファイル構造を作成）
docker-compose --profile sync up storj-sync

# または、実行中のコンテナ内で直接実行
docker-compose exec storj-virtual-drive python storj_virtual_drive.py sync
```

## 使用方法

### 基本コマンド

```bash
# ステータス確認
docker-compose exec storj-virtual-drive python storj_virtual_drive.py status

# 仮想ファイル一覧表示
docker-compose exec storj-virtual-drive python storj_virtual_drive.py list

# 同期実行
docker-compose exec storj-virtual-drive python storj_virtual_drive.py sync
```

### ローカルからのアクセス

仮想ファイルはホストの`./virtual_files`ディレクトリからアクセス可能：

```bash
# ディレクトリ構造を確認
ls -la virtual_files/

# 特定の月のファイルを確認
ls -la virtual_files/202509/

# 仮想ファイルの内容（メタデータ）を確認
cat virtual_files/202509/IMG_1090_5f75d221c3.MOV
```

## 仮想ファイルの形式

各仮想ファイルには以下の情報が含まれます：

```
# Virtual file placeholder
# Original file: 202509/IMG_1090_5f75d221c3.MOV
# Size: 15629790 bytes
# Modified: 2025-09-23T12:47:04.085050300Z
# Bucket: prd-storj-uploader
# Remote: storj:prd-storj-uploader/202509/IMG_1090_5f75d221c3.MOV
```

## Docker Compose設定

### メインサービス
- `storj-virtual-drive`: 常駐サービス（ステータス確認・管理用）
- `storj-sync`: 同期専用サービス（`--profile sync`で実行）

### ボリュームマウント
- `./virtual_files:/app/virtual_files` - 仮想ファイル（ホストからアクセス可能）
- `../storj_container_app/rclone.conf:/app/config/rclone.conf:ro` - rclone設定（読み取り専用）
- `../storj_container_app/.env:/app/.env:ro` - 環境変数（読み取り専用）

## トラブルシューティング

### 権限エラー
```bash
# virtual_filesディレクトリの権限を修正
sudo chown -R $USER:$USER virtual_files/
```

### 設定ファイルが見つからない
```bash
# 設定ファイルのパスを確認
docker-compose exec storj-virtual-drive ls -la /app/config/
docker-compose exec storj-virtual-drive ls -la /app/
```

### 同期エラー
```bash
# rclone設定をテスト
docker-compose exec storj-virtual-drive rclone --config /app/config/rclone.conf lsd storj:

# ログを詳細表示
docker-compose logs -f storj-virtual-drive
```

## 開発・カスタマイズ

### ローカル開発
```bash
# Python環境で直接実行
python storj_virtual_drive.py status

# 依存関係インストール
pip install -r requirements.txt
```

### 設定の変更
- `.env`: 環境変数の設定
- `rclone.conf`: Storj接続設定
- `docker-compose.yml`: コンテナとボリューム設定

## 注意事項

- 仮想ファイルは実際のデータを含みません
- 実際のファイルが必要な場合は、Storjから別途ダウンロードが必要
- 大量のファイルがある場合、同期に時間がかかる場合があります
- `virtual_files`ディレクトリのサイズは実際のファイルよりもはるかに小さくなります