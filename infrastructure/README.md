# Azure Container Apps デプロイメント

このディレクトリには、Storj Uploader システムを Azure Container Apps にデプロイするための Bicep テンプレートが含まれています。

## アーキテクチャ

```
┌─────────────────────────────────────────────────────┐
│ Container Apps Environment                          │
│                                                     │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────┐ │
│  │  Frontend    │  │  Backend API │  │  Storj   │ │
│  │  Container   │─▶│  Container   │◀─│ Uploader │ │
│  │              │  │              │  │          │ │
│  └──────────────┘  └──────────────┘  └──────────┘ │
│                           │  ▲           │  ▲      │
│                           ▼  │           ▼  │      │
│                    ┌──────────────────────────┐    │
│                    │  Azure Files Storage     │    │
│                    │  - upload-target         │    │
│                    │  - uploaded              │    │
│                    │  - temp                  │    │
│                    │  - thumbnail-cache       │    │
│                    └──────────────────────────┘    │
└─────────────────────────────────────────────────────┘
                              │
                              ▼
                      ┌──────────────┐
                      │ Storj Cloud  │
                      └──────────────┘
```

## デプロイされるリソース

### インフラストラクチャ

- **Log Analytics Workspace** - コンテナログの収集と分析
- **Container Apps Environment** - コンテナアプリの実行環境
- **Storage Account** - Azure Files による永続化ストレージ
  - `upload-target` - アップロード待ちファイル
  - `uploaded` - アップロード済みファイル
  - `temp` - 一時ファイル
  - `thumbnail-cache` - サムネイルキャッシュ

### アプリケーション

- **Backend API Container App** (最小 SKU: 0.25 vCPU, 0.5Gi メモリ)

  - FastAPI ベースの REST API
  - ポート: 8010
  - 外部アクセス: 有効 (HTTPS)
  - スケール: 1 レプリカ固定

- **Frontend Container App** (最小 SKU: 0.25 vCPU, 0.5Gi メモリ)

  - React + TypeScript フロントエンド
  - ポート: 9010
  - 外部アクセス: 有効 (HTTPS)
  - スケール: 1 レプリカ固定

- **Storj Uploader Container App** (最小 SKU: 0.25 vCPU, 0.5Gi メモリ)
  - Python + rclone アップローダー
  - 外部アクセス: 無効
  - スケール: 1 レプリカ固定

## 前提条件

### 必要なツール

- Azure CLI 2.50.0 以上
- Bicep CLI (Azure CLI に含まれる)
- Docker (コンテナイメージのビルド用)
- Azure Container Registry (ACR) または Docker Hub

### Azure サブスクリプション

- Azure サブスクリプションへのアクセス
- リソースグループ作成権限
- Container Apps のデプロイ権限

## デプロイ手順

### 1. Azure Container Registry (ACR) の作成

```bash
# リソースグループ作成
az group create \
  --name rg-dev-storjup \
  --location japaneast

# ACR 作成 (Basic SKU - 最小コスト)
az acr create \
  --resource-group rg-dev-storjup \
  --name <your-acr-name> \
  --sku Basic \
  --location japaneast

# ACR にログイン
az acr login --name <your-acr-name>
```

### 2. コンテナイメージのビルドとプッシュ

```bash
# ACRの名前を環境変数に設定
export ACR_NAME=<your-acr-name>

# Backend API イメージのビルドとプッシュ
cd storj_uploader_backend_api_container_app
az acr build \
  --registry $ACR_NAME \
  --image storj-backend:latest \
  --file Dockerfile \
  .

# Frontend イメージのビルドとプッシュ
cd ../storj_uploader_frontend_container_app
az acr build \
  --registry $ACR_NAME \
  --image storj-frontend:latest \
  --file Dockerfile \
  .

# Storj Uploader イメージのビルドとプッシュ
cd ../storj_container_app
az acr build \
  --registry $ACR_NAME \
  --image storj-uploader:latest \
  --file Dockerfile \
  .
```

### 3. パラメータファイルの編集

`infrastructure/main.bicepparam` を編集して、以下の値を設定します：

```bicep
// ACR名を設定（パブリックイメージの場合は空のままでも可）
param backendContainerImage = '<your-acr-name>.azurecr.io/storj-backend:latest'
param frontendContainerImage = '<your-acr-name>.azurecr.io/storj-frontend:latest'
param storjContainerImage = '<your-acr-name>.azurecr.io/storj-uploader:latest'
param containerRegistryServer = '<your-acr-name>.azurecr.io'
param containerRegistryUsername = '<acr-username>'
@secure()
param containerRegistryPassword = '<acr-password>'
param enableManagedIdentity = false

// Storj設定
param storjBucketName = 'your-storj-bucket-name'

// rclone.confの内容を設定
param rcloneConfig = '''
[storj]
type = storj
access_grant = your-storj-access-grant-here
'''
```

**セキュリティ推奨**: 本番環境では `rcloneConfig` を直接パラメータファイルに記載せず、Azure Key Vault を使用してください。
Backend API も Storj の画像一覧取得に rclone 設定が必要なため、同じシークレットを参照します。

### 4. Bicep デプロイの実行

```bash
cd infrastructure

# デプロイメントの検証 (Dry run)
az deployment group what-if \
  --resource-group rg-dev-storjup \
  --template-file main.bicep \
  --parameters main.bicepparam

# デプロイメント実行
az deployment group create \
  --resource-group rg-dev-storjup \
  --template-file main.bicep \
  --parameters main.bicepparam \
  --name storj-uploader-deployment
```

### 5. デプロイ結果の確認

```bash
# デプロイメント出力の取得
az deployment group show \
  --resource-group rg-dev-storjup \
  --name storj-uploader-deployment \
  --query properties.outputs

# Frontend URL
az deployment group show \
  --resource-group rg-dev-storjup \
  --name storj-uploader-deployment \
  --query properties.outputs.frontendUrl.value \
  --output tsv

# Backend API URL
az deployment group show \
  --resource-group rg-dev-storjup \
  --name storj-uploader-deployment \
  --query properties.outputs.backendApiUrl.value \
  --output tsv
```

### 6. Container Apps へのアクセス権限設定

ACR からイメージをプルする方法は 2 通りです：

1. **パラメータに ACR 認証情報を設定する方法（簡単）**

   - `containerRegistryServer`, `containerRegistryUsername`, `containerRegistryPassword` に ACR の管理ユーザーまたはサービスプリンシパルの資格情報を設定します。
   - 特別なロール付与は不要です。

2. **Managed Identity + AcrPull ロールを使う方法（推奨）**
   - パラメータ `enableManagedIdentity = true` とし、`containerRegistry*` は空のままで構いません。
   - デプロイ後に Container Apps の SystemAssigned ID に ACR の `AcrPull` を付与します。

```bash
# Container Apps の Managed Identity を有効化 (デプロイ時に自動設定済み)
# ACR への AcrPull 権限を付与

ACR_ID=$(az acr show --name $ACR_NAME --query id --output tsv)

# Backend API
BACKEND_PRINCIPAL_ID=$(az containerapp show \
  --resource-group rg-dev-storjup \
  --name <backend-app-name> \
  --query identity.principalId \
  --output tsv)

az role assignment create \
  --assignee $BACKEND_PRINCIPAL_ID \
  --role AcrPull \
  --scope $ACR_ID

# Frontend (同様に実行)
# Storj Uploader (同様に実行)
```

**注**: Bicep テンプレートで Managed Identity を有効にする必要がある場合は、各モジュールに以下を追加してください：

```bicep
identity: {
  type: 'SystemAssigned'
}
```

## 運用

### ログの確認

```bash
# Backend API のログ
az containerapp logs show \
  --resource-group rg-dev-storjup \
  --name <backend-app-name> \
  --follow

# Storj Uploader のログ
az containerapp logs show \
  --resource-group rg-dev-storjup \
  --name <storj-app-name> \
  --follow
```

### コンテナイメージの更新

```bash
# 新しいイメージをビルド
az acr build \
  --registry $ACR_NAME \
  --image storj-backend:v2 \
  --file Dockerfile \
  .

# Container App を更新
az containerapp update \
  --resource-group rg-dev-storjup \
  --name <backend-app-name> \
  --image $ACR_NAME.azurecr.io/storj-backend:v2
```

### スケーリング

最小 SKU から必要に応じてスケールアップ：

```bash
az containerapp update \
  --resource-group rg-dev-storjup \
  --name <backend-app-name> \
  --cpu 0.5 \
  --memory 1.0Gi
```

### ストレージの確認

```bash
# Azure Files の使用状況確認
az storage share stats \
  --name upload-target \
  --account-name <storage-account-name>
```

## トラブルシューティング

### Container が起動しない場合

```bash
# Container App の詳細を確認
az containerapp show \
  --resource-group rg-dev-storjup \
  --name <app-name>

# リビジョン履歴を確認
az containerapp revision list \
  --resource-group rg-dev-storjup \
  --name <app-name>

# 失敗したリビジョンの詳細
az containerapp revision show \
  --resource-group rg-dev-storjup \
  --name <app-name> \
  --revision <revision-name>
```

### Storage マウントエラー

- Storage Account のアクセスキーが正しいか確認
- File Share が作成されているか確認
- Container Apps Environment の Storage 設定を確認

```bash
az containerapp env storage list \
  --resource-group rg-dev-storjup \
  --name <environment-name>
```

### rclone.conf の問題

- rclone.conf の内容が正しくエンコードされているか確認
- Storj のアクセスグラントが有効か確認
- Container 内で rclone が正しくインストールされているか確認

## コスト最適化

### 最小構成のコスト見積もり (月額、概算)

- Container Apps Environment: 無料
- Container Apps (0.25 vCPU, 0.5Gi メモリ × 3): 約 ¥3,000-5,000
- Storage Account (Basic): 約 ¥200-500
- Log Analytics Workspace: 約 ¥500-1,000
- Azure Container Registry (Basic): 約 ¥700

**合計**: 約 ¥4,400-7,200/月

### さらなるコスト削減

1. **使用しない時間帯にスケールダウン**

   ```bash
   az containerapp update \
     --resource-group rg-dev-storjup \
     --name <app-name> \
     --min-replicas 0 \
     --max-replicas 1
   ```

2. **Log Analytics の保持期間を短縮**

   ```bash
   az monitor log-analytics workspace update \
     --resource-group rg-dev-storjup \
     --workspace-name <workspace-name> \
     --retention-time 7
   ```

3. **不要なファイルを定期的に削除**
   - `uploaded/` ディレクトリのファイルを定期削除
   - `thumbnail-cache/` を定期的にクリア

## セキュリティ

### Azure Key Vault との統合 (推奨)

```bash
# Key Vault の作成
az keyvault create \
  --resource-group rg-dev-storjup \
  --name <keyvault-name> \
  --location japaneast

# rclone.conf をシークレットとして保存
az keyvault secret set \
  --vault-name <keyvault-name> \
  --name rclone-config \
  --file path/to/rclone.conf

# Container App から Key Vault へのアクセス権限を付与
# (Managed Identity を使用)
```
Backend API と Storj Uploader の両方が `rclone-config` を参照します。

### ネットワークセキュリティ

- Backend API と Frontend は外部公開、Storj Uploader は内部のみ
- 必要に応じて Virtual Network 統合を検討
- カスタムドメインと SSL 証明書の設定

## GitHub Actions CI/CD

### GitHub Actions で必要な権限

GitHub Actions からデプロイを自動化するには、Service Principal に以下の権限が必要です：

#### 1. ACR への権限

```bash
# 環境変数の設定
ACR_NAME=stjup2acrudm3tutq7eb7i
SERVICE_PRINCIPAL_OBJECT_ID=778af043-9537-4f85-8c51-f93d502fda80

# ACR ID の取得
ACR_ID=$(az acr show --name $ACR_NAME --query id -o tsv)

# AcrPush ロールを付与（イメージの push に必要）
az role assignment create \
  --assignee $SERVICE_PRINCIPAL_OBJECT_ID \
  --role AcrPush \
  --scope $ACR_ID

# 権限の確認
az role assignment list \
  --assignee $SERVICE_PRINCIPAL_OBJECT_ID \
  --scope $ACR_ID \
  --query "[].{role:roleDefinitionName,scope:scope}" -o table
```

#### 2. Container Apps への権限

```bash
# 環境変数の設定
RESOURCE_GROUP=rg-dev-storjup
SERVICE_PRINCIPAL_OBJECT_ID=778af043-9537-4f85-8c51-f93d502fda80

# リソースグループ ID の取得
RG_ID=$(az group show --name $RESOURCE_GROUP --query id -o tsv)

# Contributor ロールを付与（Container Apps の更新に必要）
az role assignment create \
  --assignee $SERVICE_PRINCIPAL_OBJECT_ID \
  --role Contributor \
  --scope $RG_ID

# 権限の確認
az role assignment list \
  --assignee $SERVICE_PRINCIPAL_OBJECT_ID \
  --scope $RG_ID \
  --query "[].{role:roleDefinitionName,scope:scope}" -o table
```

#### 3. Bicep による自動権限付与（推奨）

Bicep デプロイ時に自動的に権限を付与することもできます。[main.bicepparam](main.bicepparam) で以下のパラメータを設定してください：

```bicep
// GitHub Actions の Service Principal Object ID
param acrPushPrincipalId = '778af043-9537-4f85-8c51-f93d502fda80'
param contributorPrincipalId = '778af043-9537-4f85-8c51-f93d502fda80'
```

これらのパラメータが設定されていれば、Bicep デプロイ時に以下のロールが自動的に付与されます：
- **ACR**: AcrPush ロール（イメージの push 権限）
- **Resource Group**: Contributor ロール（Container Apps の読み取り・更新権限）

### GitHub Secrets の設定

GitHub リポジトリに以下の Secrets を設定してください：

1. **認証情報（必須）**
   - `AZURE_CLIENT_ID`: Service Principal の Application (Client) ID
   - `AZURE_TENANT_ID`: Azure AD テナント ID
   - `AZURE_SUBSCRIPTION_ID`: Azure サブスクリプション ID

2. **環境変数（Variables として設定）**
   - `ACR_NAME`: `stjup2acrudm3tutq7eb7i`
   - `RESOURCE_GROUP`: `rg-dev-storjup`

### ワークフローの動作

`.github/workflows/build-and-push-acr.yml` ワークフローは以下を自動実行します：

1. **build-and-push ジョブ**
   - Docker イメージのビルド
   - ACR へのイメージ push（並列実行）

2. **update-container-apps ジョブ**
   - Container Apps のイメージ更新
   - 自動再起動とデプロイ（並列実行）

main ブランチへの push で自動的に実行されます。

## 参考資料

- [Azure Container Apps ドキュメント](https://learn.microsoft.com/ja-jp/azure/container-apps/)
- [Bicep ドキュメント](https://learn.microsoft.com/ja-jp/azure/azure-resource-manager/bicep/)
- [Azure Files ドキュメント](https://learn.microsoft.com/ja-jp/azure/storage/files/)
- [rclone ドキュメント](https://rclone.org/docs/)
- [GitHub Actions と Azure の連携](https://learn.microsoft.com/ja-jp/azure/developer/github/connect-from-azure)
