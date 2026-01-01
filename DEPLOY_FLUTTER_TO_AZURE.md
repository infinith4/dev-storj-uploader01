# Flutter Web アプリを Azure Container Apps にデプロイ

Flutter Web アプリを Azure Container Apps にデプロイする手順です。

## 前提条件

1. ✅ バックエンド API の CORS 設定が更新済み（`DEPLOY_BACKEND_UPDATE.md` 参照）
2. ✅ `.env` ファイルに Azure バックエンド URL が設定済み
3. ✅ nginx.conf から `host.docker.internal` プロキシ設定を削除済み

## デプロイ手順

### 1. .env ファイルの確認

```bash
cd flutter_app_storj_uploader
cat .env
```

以下のように Azure バックエンド URL が設定されていることを確認:

```env
API_BASE_URL=https://stjup2-backend-udm3tutq7eb7i.yellowplant-e4c48860.japaneast.azurecontainerapps.io
```

### 2. Docker イメージのビルド

```bash
# Azure Container Registry にログイン
az acr login --name stjup2acrudm3tutq7eb7i

# Flutter アプリのディレクトリに移動
cd flutter_app_storj_uploader

# Docker イメージをビルド
docker build -t stjup2acrudm3tutq7eb7i.azurecr.io/storj-flutter:latest .
```

ビルド中に以下が実行されます:
- Flutter の依存関係をインストール
- `.env` ファイルを含めてビルド（.env.example から自動コピー）
- `flutter build web --release` で Web アプリをビルド
- nginx Alpine イメージにコピー

### 3. ACR にプッシュ

```bash
docker push stjup2acrudm3tutq7eb7i.azurecr.io/storj-flutter:latest
```

### 4. Container App の作成/更新

#### 新規作成する場合

```bash
az containerapp create \
  --name stjup2-flutter-udm3tutq7eb7i \
  --resource-group rg-dev-storjup \
  --environment stjup2-env-udm3tutq7eb7i \
  --image stjup2acrudm3tutq7eb7i.azurecr.io/storj-flutter:latest \
  --target-port 80 \
  --ingress external \
  --min-replicas 1 \
  --max-replicas 3 \
  --cpu 0.5 \
  --memory 1.0Gi \
  --registry-server stjup2acrudm3tutq7eb7i.azurecr.io
```

#### 既存のものを更新する場合

```bash
az containerapp update \
  --name stjup2-flutter-udm3tutq7eb7i \
  --resource-group rg-dev-storjup \
  --image stjup2acrudm3tutq7eb7i.azurecr.io/storj-flutter:latest
```

### 5. アプリの URL を取得

```bash
az containerapp show \
  --name stjup2-flutter-udm3tutq7eb7i \
  --resource-group rg-dev-storjup \
  --query properties.configuration.ingress.fqdn \
  --output tsv
```

例: `https://stjup2-flutter-udm3tutq7eb7i.yellowplant-e4c48860.japaneast.azurecontainerapps.io`

## デプロイ後の確認

### 1. アプリにアクセス

ブラウザで Flutter アプリの URL を開く:
```
https://stjup2-flutter-udm3tutq7eb7i.yellowplant-e4c48860.japaneast.azurecontainerapps.io
```

### 2. 接続状態を確認

アプリが起動したら:
1. ステータスバーに "Connected to server" と表示されることを確認
2. Azure バックエンド URL が表示されることを確認
3. Status タブでシステム情報が表示されることを確認

### 3. ログを確認

```bash
az containerapp logs show \
  --name stjup2-flutter-udm3tutq7eb7i \
  --resource-group rg-dev-storjup \
  --follow
```

nginx のエラーがないことを確認（`host not found in upstream "host.docker.internal"` エラーが出ないこと）

## トラブルシューティング

### エラー: nginx が起動しない

**症状:**
```
[emerg] 1#1: host not found in upstream "host.docker.internal"
```

**原因:** nginx.conf に Docker Desktop 用のプロキシ設定が残っている

**解決策:** nginx.conf から `/api/` プロキシ設定を削除してリビルド

### エラー: "Unable to connect to server"

**症状:** Flutter アプリで接続エラー

**確認手順:**

1. **Flutter アプリのビルドに .env が含まれているか確認:**
   ```bash
   # ローカルでイメージをテスト
   docker run -it --rm stjup2acrudm3tutq7eb7i.azurecr.io/storj-flutter:latest sh
   # コンテナ内で
   ls -la /usr/share/nginx/html/
   cat /usr/share/nginx/html/main.dart.js | grep "stjup2-backend"
   ```

2. **バックエンドの CORS 設定を確認:**
   ```bash
   curl -X OPTIONS \
     -H "Origin: https://stjup2-flutter-udm3tutq7eb7i.yellowplant-e4c48860.japaneast.azurecontainerapps.io" \
     -H "Access-Control-Request-Method: GET" \
     -i \
     https://stjup2-backend-udm3tutq7eb7i.yellowplant-e4c48860.japaneast.azurecontainerapps.io/health
   ```

   以下のヘッダーが返ってくることを確認:
   ```
   Access-Control-Allow-Origin: https://stjup2-flutter-udm3tutq7eb7i...
   Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS
   ```

3. **ブラウザの開発者ツールで確認:**
   - F12 → Console タブ
   - Network タブで /health リクエストを確認
   - CORS エラーがないか確認

### .env ファイルが反映されない

**原因:** Dockerfile のビルド時に .env がコピーされていない

**解決策:**

1. `.env` ファイルが存在することを確認:
   ```bash
   cat flutter_app_storj_uploader/.env
   ```

2. Dockerfile の該当部分を確認:
   ```dockerfile
   RUN mkdir -p assets/images assets/icons && \
       if [ ! -f .env ]; then \
         if [ -f .env.example ]; then cp .env.example .env; else touch .env; fi; \
       fi
   ```

3. Docker ビルドキャッシュをクリアして再ビルド:
   ```bash
   docker build --no-cache -t stjup2acrudm3tutq7eb7i.azurecr.io/storj-flutter:latest .
   ```

## GitHub Actions による自動デプロイ（オプション）

`.github/workflows/flutter-deploy.yml` を作成して自動デプロイを設定できます:

```yaml
name: Deploy Flutter to Azure

on:
  push:
    branches: [main]
    paths:
      - 'flutter_app_storj_uploader/**'

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Azure Login
        uses: azure/login@v1
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}

      - name: ACR Login
        run: az acr login --name stjup2acrudm3tutq7eb7i

      - name: Build and Push
        run: |
          cd flutter_app_storj_uploader
          docker build -t stjup2acrudm3tutq7eb7i.azurecr.io/storj-flutter:latest .
          docker push stjup2acrudm3tutq7eb7i.azurecr.io/storj-flutter:latest

      - name: Update Container App
        run: |
          az containerapp update \
            --name stjup2-flutter-udm3tutq7eb7i \
            --resource-group rg-dev-storjup \
            --image stjup2acrudm3tutq7eb7i.azurecr.io/storj-flutter:latest
```

## 環境の確認

デプロイが完了したら、[AZURE_ENV.md](AZURE_ENV.md) を更新して Flutter アプリの情報を追加してください。

## 次のステップ

1. ✅ Flutter アプリをデプロイ
2. ✅ バックエンド API の CORS を更新（`DEPLOY_BACKEND_UPDATE.md`）
3. [ ] フロントエンド URL を DNS に登録（オプション）
4. [ ] カスタムドメインの設定（オプション）
5. [ ] Azure AD 認証の追加（オプション）
