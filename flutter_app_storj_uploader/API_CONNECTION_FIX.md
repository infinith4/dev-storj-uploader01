# Flutter Web → Backend API 接続修正ガイド

## 問題

Flutter WebアプリからバックエンドAPI (`http://localhost:8010`) への接続が失敗していました。

### 原因

1. **CORS設定の不足**: バックエンドAPIのCORS設定に、Flutter Web開発環境のオリジン (`http://localhost:8080`) が含まれていなかった
2. **誤ったAPI URL**: Flutter側のAPI URLがDockerコンテナ名 (`http://storj_uploader_frontend_container_app-backend-1:8010`) になっていた

## 修正内容

### 1. バックエンドAPIのCORS設定修正

**ファイル**: `storj_uploader_backend_api_container_app/main.py`

**変更箇所**: 86-100行目

```python
# CORS設定
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost:9010",
        "http://localhost:3000",  # 開発環境
        "http://localhost:8080",  # Flutter Web開発環境 ← 追加
        "http://127.0.0.1:9010",
        "http://127.0.0.1:3000",
        "http://127.0.0.1:8080"   # ← 追加
    ],
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allow_headers=["*"],
)
```

### 2. Flutter WebのAPI URL修正

**ファイル**: `storj_uploader_flutter_app/lib/utils/constants.dart`

**変更箇所**: 3行目

```dart
// API Constants
class ApiConstants {
  // 修正前: static const String defaultBaseUrl = 'http://storj_uploader_frontend_container_app-backend-1:8010';
  static const String defaultBaseUrl = 'http://localhost:8010';  // 修正後
```

**重要**: Flutter Webはブラウザで実行されるため、Dockerコンテナ名ではなく `localhost` を使用する必要があります。

## 適用手順

### 1. バックエンドAPIコンテナの再起動

```bash
# 既存コンテナの停止
cd /workspaces/dev-storj-uploader01/storj_uploader_backend_api_container_app
docker-compose down

# コンテナの再ビルドと起動
docker-compose up --build -d
```

### 2. Flutter Webアプリの再起動

```bash
# 現在実行中のFlutterプロセスを停止（Ctrl+C または q）
# その後、再起動
cd /workspaces/dev-storj-uploader01/storj_uploader_flutter_app
flutter run -d web-server --web-port 8080
```

## 動作確認

### 1. バックエンドAPIのヘルスチェック

```bash
curl http://localhost:8010/health
```

**期待される結果**:
```json
{
  "status": "healthy",
  "timestamp": "2025-09-30T...",
  "upload_target_dir": "../storj_container_app/upload_target",
  "upload_target_exists": true
}
```

### 2. CORS設定の確認

```bash
curl -v -H "Origin: http://localhost:8080" \
     -H "Access-Control-Request-Method: GET" \
     -X OPTIONS http://localhost:8010/health
```

**期待される結果**:
```
< access-control-allow-origin: http://localhost:8080
< access-control-allow-methods: GET, POST, PUT, DELETE, OPTIONS
< access-control-allow-credentials: true
```

### 3. Flutter Webアプリからの接続確認

1. ブラウザで http://localhost:8080 にアクセス
2. 接続ステータスが「接続済み」(Connected) になることを確認
3. ヘルスチェックが正常に動作することを確認

## トラブルシューティング

### CORS エラーが継続する場合

1. バックエンドコンテナが正しく再起動されているか確認:
   ```bash
   docker ps | grep backend
   ```

2. バックエンドのログを確認:
   ```bash
   docker logs storj_uploader_backend_api_container_app-storj-uploader-api-1
   ```

3. ブラウザのキャッシュをクリアして再度アクセス

### Flutter Webアプリが古いURLを使用している場合

1. Flutter開発サーバーを完全に停止
2. ビルドキャッシュをクリア:
   ```bash
   flutter clean
   flutter pub get
   ```
3. 再度起動:
   ```bash
   flutter run -d web-server --web-port 8080
   ```

## 注意事項

### WSL環境での開発

WSL環境では、Chromeをダイレクトに起動できないため、`web-server`モードを使用します:

```bash
# ✓ 推奨
flutter run -d web-server --web-port 8080

# ✗ WSL環境では動作しない
flutter run -d chrome
```

### 本番環境への展開

本番環境では、適切なドメイン名やIPアドレスをCORS設定に追加してください:

```python
allow_origins=[
    "https://your-production-domain.com",
    "http://localhost:8080",  # 開発環境用（本番では削除推奨）
    # ...
]
```

## アーキテクチャ図

```
┌─────────────────────┐
│   Browser           │
│   (localhost:8080)  │
└──────────┬──────────┘
           │
           │ HTTP Request
           │ Origin: http://localhost:8080
           ↓
┌─────────────────────┐
│  Backend API        │
│  (localhost:8010)   │
│                     │
│  CORS Middleware    │
│  - Allow Origin     │
│  - Allow Methods    │
│  - Allow Headers    │
└─────────────────────┘
```

## 参考リンク

- [Flutter Web Documentation](https://docs.flutter.dev/platform-integration/web)
- [FastAPI CORS Middleware](https://fastapi.tiangolo.com/tutorial/cors/)
- [MDN Web Docs: CORS](https://developer.mozilla.org/en-US/docs/Web/HTTP/CORS)
