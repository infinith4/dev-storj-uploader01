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

## 関連ドキュメント

- [CLAUDE.md](./CLAUDE.md) - プロジェクト全体の構成
- [infrastructure/main.bicep](./infrastructure/main.bicep) - Bicep テンプレート
- [infrastructure/main.bicepparam](./infrastructure/main.bicepparam) - Bicep パラメータファイル
- [.github/workflows/](../.github/workflows/) - GitHub Actions ワークフロー

## 更新履歴

| 日付       | 変更内容                                   |
| ---------- | ------------------------------------------ |
| 2025-12-31 | 初版作成 - 現在の Azure 環境の構成を文書化 |

```
# リビジョンを更新して再起動
az containerapp update \
  --name stjup2-backend-udm3tutq7eb7i \
  --resource-group rg-dev-storjup

az containerapp update \
  --name stjup2-frontend-udm3tutq7eb7i \
  --resource-group rg-dev-storjup

az containerapp update \
  --name stjup2-flutter-udm3tutq7eb7i \
  --resource-group rg-dev-storjup

az containerapp update \
  --name stjup2-storj-udm3tutq7eb7i \
  --resource-group rg-dev-storjup

```
