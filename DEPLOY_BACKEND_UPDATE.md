# バックエンド CORS 設定更新のデプロイ手順

Flutter アプリからの接続を許可するため、バックエンドの CORS 設定を更新しました。

## 変更内容

`storj_uploader_backend_api_container_app/main.py` の CORS 設定に以下を追加:
- `http://localhost:8080` - Flutter web-server
- `http://127.0.0.1:8080` - Flutter web-server (localhost)
- Azure Container Apps の URL

## Azure へのデプロイ手順

### オプション 1: Azure CLI で直接デプロイ

```bash
# Azure Container Registry にログイン
az acr login --name stjup2acrudm3tutq7eb7i

# バックエンドイメージをビルド
cd storj_uploader_backend_api_container_app
docker build -t stjup2acrudm3tutq7eb7i.azurecr.io/storj-backend:latest .

# ACR にプッシュ
docker push stjup2acrudm3tutq7eb7i.azurecr.io/storj-backend:latest

# Container App を再起動（新しいイメージを取得）
az containerapp update \
  --name stjup2-backend-udm3tutq7eb7i \
  --resource-group rg-dev-storjup \
  --image stjup2acrudm3tutq7eb7i.azurecr.io/storj-backend:latest
```

### オプション 2: GitHub Actions を使用

1. 変更をコミット:
   ```bash
   git add storj_uploader_backend_api_container_app/main.py
   git commit -m "Update CORS settings for Flutter app support"
   git push
   ```

2. GitHub Actions が自動的にビルド＆デプロイを実行します

## デプロイ後の確認

### 1. バックエンドの health check
```bash
curl https://stjup2-backend-udm3tutq7eb7i.yellowplant-e4c48860.japaneast.azurecontainerapps.io/health
```

### 2. CORS ヘッダーの確認
```bash
curl -X OPTIONS \
  -H "Origin: http://localhost:8080" \
  -H "Access-Control-Request-Method: GET" \
  -i \
  https://stjup2-backend-udm3tutq7eb7i.yellowplant-e4c48860.japaneast.azurecontainerapps.io/health
```

### 3. Flutter アプリで接続テスト

Flutter アプリを起動して接続状態を確認:
```bash
cd flutter_app_storj_uploader
flutter run -d chrome
```

または web-server で:
```bash
flutter run -d web-server --web-port 8080
```

アプリ内で:
1. 設定画面 (⚙️) を開く
2. "Test Connection" ボタンをクリック
3. "✅ Connection successful!" が表示されることを確認

## トラブルシューティング

### CORS エラーが継続する場合

ブラウザの開発者ツール (F12) → Console タブでエラーを確認:

```
Access to XMLHttpRequest at 'https://...' from origin 'http://localhost:8080'
has been blocked by CORS policy: No 'Access-Control-Allow-Origin' header is present
```

このエラーが出る場合:
1. バックエンドが新しいイメージで再起動されたか確認
2. Container App のログを確認:
   ```bash
   az containerapp logs show \
     --name stjup2-backend-udm3tutq7eb7i \
     --resource-group rg-dev-storjup \
     --follow
   ```

### 一時的な回避策（開発時のみ）

すべてのオリジンを許可する（本番環境では非推奨）:

```python
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # ⚠️ 開発時のみ
    allow_credentials=False,  # "*" を使う場合は False にする必要がある
    allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allow_headers=["*"],
)
```

## Flutter アプリのローカルテスト

バックエンドデプロイ後、Flutter アプリで接続確認:

```bash
# .env ファイルの確認
cat flutter_app_storj_uploader/.env
# API_BASE_URL=https://stjup2-backend-udm3tutq7eb7i... であることを確認

# アプリを起動
cd flutter_app_storj_uploader
flutter run -d chrome

# または
flutter run -d web-server --web-port 8080
```

ステータス画面で "Connected to server" と表示されれば成功です。
