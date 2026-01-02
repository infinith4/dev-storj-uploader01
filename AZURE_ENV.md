# Azure 環境構成情報

このドキュメントは、本プロジェクトの Azure Container Apps 環境の構成と設定情報をまとめたものです。

## 基本情報

| 項目                 | 値               |
| -------------------- | ---------------- |
| **リソースグループ** | `rg-dev-storjup` |
| **リージョン**       | Japan East       |
| **ベース名**         | `stjup2`         |
| **環境サフィックス** | `udm3tutq7eb7i`  |

## デプロイ済みリソース一覧

### Container Apps 環境

- **名前**: `stjup2-env-udm3tutq7eb7i`
- **タイプ**: Container Apps 環境
- **リージョン**: Japan East

### Container Apps (4 個)

#### 1. フロントエンド - React (Frontend)

- **名前**: `stjup2-frontend-udm3tutq7eb7i`
- **タイプ**: コンテナー アプリ
- **URL**: https://stjup2-frontend-udm3tutq7eb7i.yellowplant-e4c48860.japaneast.azurecontainerapps.io
- **コンテナイメージ**: `stjup2acrudm3tutq7eb7i.azurecr.io/storj-frontend:latest`
- **認証**: Azure AD EasyAuth 有効
- **用途**: React + TypeScript フロントエンド（デスクトップ/タブレット向け）

#### 2. フロントエンド - Flutter Web (Flutter App)

- **名前**: `stjup2-flutter-udm3tutq7eb7i`
- **タイプ**: コンテナー アプリ
- **URL**: https://stjup2-flutter-udm3tutq7eb7i.yellowplant-e4c48860.japaneast.azurecontainerapps.io _(要デプロイ)_
- **コンテナイメージ**: `stjup2acrudm3tutq7eb7i.azurecr.io/storj-flutter:latest`
- **用途**: Flutter Web アプリ（モバイル/デスクトップ/Web 対応）
- **設定**:
  - `.env` ファイルで API URL を設定
  - nginx で静的ファイルを配信
  - CORS はバックエンド側で処理

#### 3. バックエンド (Backend API)

- **名前**: `stjup2-backend-udm3tutq7eb7i`
- **タイプ**: コンテナー アプリ
- **URL**: https://stjup2-backend-udm3tutq7eb7i.yellowplant-e4c48860.japaneast.azurecontainerapps.io
- **コンテナイメージ**: `stjup2acrudm3tutq7eb7i.azurecr.io/storj-backend:latest`
- **内部通信**: Container Apps 環境内で他のアプリと通信可能
- **CORS 設定**: React/Flutter フロントエンド、ローカル開発環境からのアクセスを許可

#### 4. Storj アップローダー (Storj Container)

- **名前**: `stjup2-storj-udm3tutq7eb7i`
- **タイプ**: コンテナー アプリ
- **コンテナイメージ**: `stjup2acrudm3tutq7eb7i.azurecr.io/storj-uploader:latest`
- **用途**: rclone を使用した Storj クラウドストレージへのアップロード

### Container Registry (ACR)

- **名前**: `stjup2acrudm3tutq7eb7i`
- **タイプ**: Azure Container Registry
- **リージョン**: Japan East
- **SKU**: Basic
- **Admin User**: 有効
- **レジストリサーバー**: `stjup2acrudm3tutq7eb7i.azurecr.io`
- **ホストイメージ**:
  - `storj-frontend:latest (React)
  - storj-flutter:latest (Flutter Web)` (React)
  - `storj-flutter:latest` (Flutter Web)
  - `storj-backend:latest` (FastAPI)
  - `storj-uploader:latest` (rclone)

### Key Vault

- **名前**: `stjup2-kv-udm3tutq7eb7i`
- **タイプ**: キー コンテナー
- **リージョン**: Japan East
- **用途**: シークレット管理 (rclone.conf, AAD Client Secret など)
- **重要なシークレット**:
  - `rclone-config`: rclone の Storj 認証情報
  - `aad-client-secret`: Azure AD 認証のクライアントシークレット

### Log Analytics Workspace

- **名前**: `stjup2-logs-udm3tutq7eb7i`
- **タイプ**: Log Analytics ワークスペース
- **リージョン**: Japan East
- **用途**: Container Apps のログとメトリクスの収集・分析

### Storage Account

- **名前**: `stjup2studm3tutq7eb7i`
- **タイプ**: ストレージ アカウント
- **リージョン**: Japan East
- **用途**: ファイル共有 (Container Apps 間でのファイル共有)

## Azure AD 認証設定 (Frontend EasyAuth)

| 項目                         | 値                                                                                   |
| ---------------------------- | ------------------------------------------------------------------------------------ |
| **有効/無効**                | 有効                                                                                 |
| **テナント ID**              | `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`                                               |
| **クライアント ID**          | `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`                                               |
| **クライアントシークレット** | `4BXXXXXXXXXX` (Key Vault に保存)                                                    |
| **OpenID Issuer**            | `https://sts.windows.net/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/`                      |
| **許可されたオーディエンス** | `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`, `api://xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx` |

## Managed Identity

| 項目               | 値                                                 |
| ------------------ | -------------------------------------------------- |
| **有効/無効**      | 有効                                               |
| **用途**           | ACR からのコンテナイメージプル、Key Vault アクセス |
| **割り当てロール** | AcrPull (ACR に対して)                             |

## Storj 設定

| 項目               | 値                      |
| ------------------ | ----------------------- |
| **バケット名**     | `stg-storj-uploader-01` |
| **リモート名**     | `storj`                 |
| **ハッシュ長**     | 10                      |
| **最大ワーカー数** | 8                       |

## アプリケーション設定

### Backend API

| 環境変数            | 値                                       |
| ------------------- | ---------------------------------------- |
| `MAX_FILE_SIZE`     | 100000000 (100MB)                        |
| `API_HOST`          | 0.0.0.0                                  |
| `API_PORT`          | 8010                                     |
| `UPLOAD_TARGET_DIR` | `/app/storj_container_app/upload_target` |
| `TEMP_DIR`          | `/app/temp`                              |

### Storj Container App

| 環境変数            | 値                      |
| ------------------- | ----------------------- |
| `STORJ_BUCKET_NAME` | `stg-storj-uploader-01` |
| `STORJ_REMOTE_NAME` | `storj`                 |
| `HASH_LENGTH`       | 10                      |
| `MAX_WORKERS`       | 8                       |

## GitHub Actions CI/CD

| 項目                           | 値                                        |
| ------------------------------ | ----------------------------------------- |
| **Service Principal ObjectId** | `778af043-9537-4f85-8c51-f93d502fda80`    |
| **割り当てロール**             | AcrPush (ACR に対して)                    |
| **デプロイ対象**               | Container Apps (backend, frontend, storj) |

## ネットワーク構成

- **Container Apps 環境**: 内部通信可能（同一環境内のアプリ同士）
- **フロントエンド**: インターネット公開 (HTTPS)
- **バックエンド**: インターネット公開 (HTTPS) ※必要に応じて内部のみに変更可能
- **Storj アップローダー**: 外部からの直接アクセス不可（バックエンド経由で制御）

## アクセス URL

| サービス                       | URL                                                                                             | 用途                  |
| ------------------------------ | ----------------------------------------------------------------------------------------------- | --------------------- |
| **フロントエンド**             | https://stjup2-frontend-udm3tutq7eb7i.yellowplant-e4c48860.japaneast.azurecontainerapps.io      | Web アプリケーション  |
| **バックエンド API**           | https://stjup2-backend-udm3tutq7eb7i.yellowplant-e4c48860.japaneast.azurecontainerapps.io       | REST API (OpenAPI v3) |
| **API ドキュメント (Swagger)** | https://stjup2-backend-udm3tutq7eb7i.yellowplant-e4c48860.japaneast.azurecontainerapps.io/docs  | API 仕様確認          |
| **API ドキュメント (ReDoc)**   | https://stjup2-backend-udm3tutq7eb7i.yellowplant-e4c48860.japaneast.azurecontainerapps.io/redoc | API 仕様確認          |

## デプロイ方法

### 1. Bicep を使った初回デプロイ

```bash
cd infrastructure
az deployment group create \
  --resource-group rg-dev-storjup \
  --template-file main.bicep \
  --parameters main.bicepparam
```

### 2. GitHub Actions による自動デプロイ

- コンテナイメージを ACR にプッシュ
- Container Apps が自動的に新しいイメージを取得してデプロイ

### 3. 手動デプロイ (Azure CLI)

```bash
# コンテナイメージのビルドとプッシュ
az acr build --registry stjup2acrudm3tutq7eb7i \
  --image storj-backend:latest \
  storj_uploader_backend_api_container_app

# Container App の更新
az containerapp update \
  --name stjup2-backend-udm3tutq7eb7i \
  --resource-group rg-dev-storjup \
  --image stjup2acrudm3tutq7eb7i.azurecr.io/storj-backend:latest
```

## Key Vault シークレット設定

rclone.conf を Key Vault に保存する方法:

```bash
# rclone.conf の内容をシークレットとして保存
az keyvault secret set \
  --vault-name stjup2-kv-udm3tutq7eb7i \
  --name rclone-config \
  --file path/to/rclone.conf

# シークレットの確認
az keyvault secret show \
  --vault-name stjup2-kv-udm3tutq7eb7i \
  --name rclone-config
```

## トラブルシューティング

### Container Apps のログ確認

```bash
# ログストリーム表示
az containerapp logs show \
  --name stjup2-backend-udm3tutq7eb7i \
  --resource-group rg-dev-storjup \
  --follow

# Log Analytics でクエリ
az monitor log-analytics query \
  --workspace stjup2-logs-udm3tutq7eb7i \
  --analytics-query "ContainerAppConsoleLogs_CL | where ContainerAppName_s == 'stjup2-backend-udm3tutq7eb7i' | top 100 by TimeGenerated desc"
```

### ACR へのログイン

```bash
az acr login --name stjup2acrudm3tutq7eb7i
```

### Key Vault アクセス確認

```bash
# 現在のユーザーにKey Vaultアクセス権を付与
az keyvault set-policy \
  --name stjup2-kv-udm3tutq7eb7i \
  --upn your-email@example.com \
  --secret-permissions get list set delete
```

## アーキテクチャ変更 (2026-01-02): Azure File Share + KEDA HTTP イベント駆動

### 背景と目的

#### 解決すべき課題

1. **Azure Blob Storage アップロードタイムアウト**
   - 4MB 動画ファイルのアップロードに 60 秒以上かかり、504 Gateway Timeout が発生
   - タイムアウト延長では根本解決にならない

2. **ファイル共有の欠如**
   - Backend API と Storj Container App の間で共有ファイルシステムがない
   - 現状は Blob Storage 経由でファイルを受け渡し（遅延の原因）

3. **常時起動によるコスト**
   - Storj Container App が常時稼働しており、アイドル時もリソースを消費
   - 実際にアップロード処理が必要な時のみ起動すべき

4. **Service Bus のコスト**
   - 初期案の Service Bus は月額約 1,000 円かかるため却下

#### 解決策の方針

**Azure File Share + HTTP Polling + KEDA HTTP Add-on** を使用:
- Azure Blob Storage を完全に排除
- Azure File Share (`/mnt/temp`) でファイルを共有
- JSON ファイルでアップロードキューを管理
- KEDA HTTP Add-on で Storj Container App をオンデマンド起動 (0→N, N→0)
- **追加コスト: ¥0** (既存リソースのみ使用)

### 新アーキテクチャ概要

```
┌─────────────┐
│  Frontend   │
└──────┬──────┘
       │ POST /upload/files/single
       ▼
┌────────────────────────────────────────────────────────────┐
│  Backend API (stjup2-backend-udm3tutq7eb7i)               │
│                                                            │
│  1. Save file to Azure File Share (/mnt/temp)            │
│  2. Create upload request JSON file                       │
│     /mnt/temp/queue/upload-{uuid}.json                    │
│     {                                                      │
│       "file_path": "/mnt/temp/files/xxx.mp4",            │
│       "file_name": "xxx.mp4",                            │
│       "file_size": 4194304,                              │
│       "content_type": "video/mp4",                       │
│       "status": "pending"                                │
│     }                                                      │
│  3. Trigger Storj Container via HTTP endpoint            │
│     POST http://stjup2-storj-udm3tutq7eb7i/process       │
└────────────────────────┬───────────────────────────────────┘
                         │
                         │ HTTP request triggers KEDA
                         │ (scale 0→1)
                         ▼
┌────────────────────────────────────────────────────────────┐
│  Storj Container App (stjup2-storj-udm3tutq7eb7i)         │
│  (with KEDA HTTP Add-on scaler)                           │
│                                                            │
│  HTTP Endpoint: POST /process                             │
│                                                            │
│  1. Scan /mnt/temp/queue/ for pending JSON files         │
│  2. For each pending file:                                │
│     - Read file from /mnt/temp/files/{filename}          │
│     - Upload to Storj using rclone                        │
│     - Update JSON: status = "completed"/"failed"         │
│     - Move JSON to /mnt/temp/processed/                  │
│     - Delete file from /mnt/temp/files/                  │
│  3. Return response                                        │
│                                                            │
│  When no requests for 5 min → KEDA scales to 0           │
└────────────────────────────────────────────────────────────┘
```

### ディレクトリ構造 (/mnt/temp/)

```
/mnt/temp/
├── files/                    # アップロードされたファイル (一時保存)
│   ├── xxx.mp4
│   └── yyy.jpg
├── queue/                    # 未処理のアップロードリクエスト
│   ├── upload-{uuid-1}.json
│   └── upload-{uuid-2}.json
└── processed/               # 処理済みリクエスト (ログ用)
    ├── upload-{uuid-3}.json
    └── upload-{uuid-4}.json
```

### 環境変数の変更

#### Backend API 環境変数 (更新)

| 環境変数                     | 値                                         | 説明                              |
| ---------------------------- | ------------------------------------------ | --------------------------------- |
| `TEMP_DIR`                   | `/mnt/temp`                                | ファイル一時保存先 (File Share)   |
| `STORJ_CONTAINER_URL`        | `http://stjup2-storj-udm3tutq7eb7i/process` | Storj Container エンドポイント    |
| `AZURE_STORAGE_ACCOUNT_NAME` | `` (空: Blob Storage 無効化)               | Blob Storage 無効                 |
| `AZURE_STORAGE_ACCOUNT_KEY`  | `` (空: Blob Storage 無効化)               | Blob Storage 無効                 |
| `UPLOAD_TARGET_DIR`          | (削除予定)                                 | 旧アーキテクチャの設定            |

#### Storj Container App 環境変数 (更新)

| 環境変数            | 値                      | 説明                       |
| ------------------- | ----------------------- | -------------------------- |
| `FILE_SHARE_MOUNT`  | `/mnt/temp`             | ファイル読み取り先         |
| `PORT`              | `8080`                  | HTTP Server ポート         |
| `STORJ_BUCKET_NAME` | `stg-storj-uploader-01` | Storj バケット名           |
| `STORJ_REMOTE_NAME` | `storj`                 | rclone リモート名          |
| `HASH_LENGTH`       | `10`                    | ハッシュ長                 |
| `MAX_WORKERS`       | `8`                     | 並列アップロード数         |

### Volume Mount 設定

#### Container Apps Environment Storage

```bash
# Storage定義を追加 (環境に)
az containerapp env storage set \
  --name stjup2-env-udm3tutq7eb7i \
  --resource-group rg-dev-storjup \
  --storage-name temp \
  --azure-file-account-name stjup2studm3tutq7eb7i \
  --azure-file-account-key <storage_key> \
  --azure-file-share-name temp \
  --access-mode ReadWrite
```

#### Backend API Volume Mount

- Volume Name: `temp`
- Storage Name: `temp`
- Mount Path: `/mnt/temp`
- Access Mode: ReadWrite

#### Storj Container App Volume Mount

- Volume Name: `temp`
- Storage Name: `temp`
- Mount Path: `/mnt/temp`
- Access Mode: ReadWrite

### KEDA HTTP Add-on 設定

Storj Container App に KEDA HTTP Add-on Scaler を追加:

```bash
# Storj Container Appのスケール設定
az containerapp update \
  --name stjup2-storj-udm3tutq7eb7i \
  --resource-group rg-dev-storjup \
  --min-replicas 0 \
  --max-replicas 3 \
  --scale-rule-name http-scaler \
  --scale-rule-type http \
  --scale-rule-http-concurrency 1
```

**KEDA HTTP Scaler 設定内容:**
- **Type**: `http`
- **Min Replicas**: 0 (アイドル時は停止)
- **Max Replicas**: 3 (並列処理用)
- **Target Pending Requests**: 1 (リクエストがあれば起動)

### 実装ステップ概要

1. **Azure File Share の作成/確認**
   - Storage Account: `stjup2studm3tutq7eb7i`
   - File Share: `temp`
   - Quota: 100GB

2. **Backend API の変更**
   - 新規ファイル: `upload_queue.py` (Upload Queue Manager)
   - 変更: `main.py` (Queue への追加、HTTP トリガー)

3. **Storj Container App の変更**
   - 新規ファイル: `http_processor.py` (HTTP Server + Queue Processor)
   - 変更: `storj_uploader.py` (単一ファイルアップロード対応)
   - 変更: `Dockerfile` (CMD を `http_processor.py` に変更、EXPOSE 8080)
   - 追加: `flask==3.0.0` (requirements.txt)

4. **Volume Mount 設定**
   - Container Apps Environment に Storage 追加
   - Backend API に Volume Mount 追加
   - Storj Container App に Volume Mount 追加

5. **KEDA HTTP Add-on 設定**
   - Storj Container App に HTTP scaler 追加
   - min-replicas: 0, max-replicas: 3
   - Internal Ingress 有効化 (port 8080)

6. **デプロイと動作確認**
   - Backend API のビルド・デプロイ
   - Storj Container App のビルド・デプロイ
   - 動作確認 (0→1 スケール、アップロード完了、1→0 スケール)

### メリット

1. **コストゼロ**: 追加コスト ¥0 (既存リソースのみ使用)
2. **シンプル実装**: JSON ファイルベースのキュー (追加の SDK 不要)
3. **スケーラビリティ**: KEDA HTTP Add-on で 0→N、N→0 スケーリング
4. **アイドル時停止**: リクエストがない時は完全停止 (コスト削減)
5. **タイムアウト解消**: Blob Storage を経由しないため高速化

### リスクと対策

#### リスク 1: File Share の容量
- **対策**: アップロード成功後にファイルを削除、processed/ ディレクトリは定期的にクリーンアップ

#### リスク 2: 同時アップロード時の競合
- **対策**: ファイルロック機能を追加、または max-replicas: 1 に制限

#### リスク 3: HTTP トリガーの失敗
- **対策**: Fire-and-forget で実装 (Queue にファイルは残る)、定期ポーリング処理を追加

### 詳細な実装計画

完全な実装プランは以下のファイルを参照してください:
- `/home/vscode/.claude/plans/parsed-sleeping-dusk.md`

このファイルには以下が含まれます:
- 詳細なコード例
- すべての変更ファイルリスト
- デプロイコマンド
- 動作確認手順
- ロールバック手順

## 関連ドキュメント

- [CLAUDE.md](./CLAUDE.md) - プロジェクト全体の構成
- [infrastructure/main.bicep](./infrastructure/main.bicep) - Bicep テンプレート
- [infrastructure/main.bicepparam](./infrastructure/main.bicepparam) - Bicep パラメータファイル
- [.github/workflows/](../.github/workflows/) - GitHub Actions ワークフロー

## 更新履歴

| 日付       | 変更内容                                                                        |
| ---------- | ------------------------------------------------------------------------------- |
| 2025-12-31 | 初版作成 - 現在の Azure 環境の構成を文書化                                      |
| 2026-01-02 | アーキテクチャ変更 - Azure File Share + KEDA HTTP イベント駆動スケーリング導入 |

## コンテナの再起動

### 方法1: リビジョンを直接再起動（推奨）

```bash
# アクティブなリビジョンを取得して再起動
az containerapp revision restart \
  --name stjup2-backend-udm3tutq7eb7i \
  --resource-group rg-dev-storjup \
  --revision $(az containerapp revision list --name stjup2-backend-udm3tutq7eb7i --resource-group rg-dev-storjup --query "[?properties.active].name" -o tsv)

az containerapp revision restart \
  --name stjup2-frontend-udm3tutq7eb7i \
  --resource-group rg-dev-storjup \
  --revision $(az containerapp revision list --name stjup2-frontend-udm3tutq7eb7i --resource-group rg-dev-storjup --query "[?properties.active].name" -o tsv)

az containerapp revision restart \
  --name stjup2-flutter-udm3tutq7eb7i \
  --resource-group rg-dev-storjup \
  --revision $(az containerapp revision list --name stjup2-flutter-udm3tutq7eb7i --resource-group rg-dev-storjup --query "[?properties.active].name" -o tsv)

az containerapp revision restart \
  --name stjup2-storj-udm3tutq7eb7i \
  --resource-group rg-dev-storjup \
  --revision $(az containerapp revision list --name stjup2-storj-udm3tutq7eb7i --resource-group rg-dev-storjup --query "[?properties.active].name" -o tsv)
```

### 方法2: 新しいリビジョンを強制作成（環境変数でトリガー）

```bash
# ダミーの環境変数を更新して新しいリビジョンを作成
az containerapp update \
  --name stjup2-backend-udm3tutq7eb7i \
  --resource-group rg-dev-storjup \
  --set-env-vars RESTART_TRIGGER="$(date +%s)"

az containerapp update \
  --name stjup2-frontend-udm3tutq7eb7i \
  --resource-group rg-dev-storjup \
  --set-env-vars RESTART_TRIGGER="$(date +%s)"

az containerapp update \
  --name stjup2-flutter-udm3tutq7eb7i \
  --resource-group rg-dev-storjup \
  --set-env-vars RESTART_TRIGGER="$(date +%s)"

az containerapp update \
  --name stjup2-storj-udm3tutq7eb7i \
  --resource-group rg-dev-storjup \
  --set-env-vars RESTART_TRIGGER="$(date +%s)"
```

### 全コンテナを一括再起動（ワンライナー）

```bash
# 方法1: リビジョン再起動
for app in stjup2-backend-udm3tutq7eb7i stjup2-frontend-udm3tutq7eb7i stjup2-flutter-udm3tutq7eb7i stjup2-storj-udm3tutq7eb7i; do
  az containerapp revision restart --name $app --resource-group rg-dev-storjup \
    --revision $(az containerapp revision list --name $app --resource-group rg-dev-storjup --query "[?properties.active].name" -o tsv)
done

# 方法2: 新リビジョン作成
for app in stjup2-backend-udm3tutq7eb7i stjup2-frontend-udm3tutq7eb7i stjup2-flutter-udm3tutq7eb7i stjup2-storj-udm3tutq7eb7i; do
  az containerapp update --name $app --resource-group rg-dev-storjup --set-env-vars RESTART_TRIGGER="$(date +%s)"
done
```
