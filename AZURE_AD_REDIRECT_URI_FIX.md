# Azure AD リダイレクト URI エラーの修正

## エラー内容

```
AADSTS50011: The redirect URI 'https://stjup2-flutter-udm3tutq7eb7i.yellowplant-e4c48860.japaneast.azurecontainerapps.io/.auth/login/aad/callback'
specified in the request does not match the redirect URIs configured for the application '5688f334-1e0a-421d-a1d7-b951cdffab3a'.
```

Flutter アプリの URL が Azure AD アプリ登録のリダイレクト URI に登録されていません。

## 解決策 1: リダイレクト URI を追加（推奨）

### Azure Portal での手順

1. **Azure Portal にアクセス**
   - https://portal.azure.com にサインイン

2. **Azure Active Directory を開く**
   - 左メニューから「Azure Active Directory」を選択

3. **アプリの登録を開く**
   - 左メニューから「アプリの登録」を選択
   - アプリ ID `5688f334-1e0a-421d-a1d7-b951cdffab3a` を検索

4. **認証設定を開く**
   - 左メニューから「認証」を選択

5. **リダイレクト URI を追加**
   - 「プラットフォームを追加」→「Web」を選択
   - 以下の URI を追加:
     ```
     https://stjup2-flutter-udm3tutq7eb7i.yellowplant-e4c48860.japaneast.azurecontainerapps.io/.auth/login/aad/callback
     ```
   - 「保存」をクリック

### Azure CLI での手順

```bash
# アプリの登録情報を取得
az ad app show --id 5688f334-1e0a-421d-a1d7-b951cdffab3a

# 現在のリダイレクト URI を確認
az ad app show --id 5688f334-1e0a-421d-a1d7-b951cdffab3a --query "web.redirectUris"

# 新しいリダイレクト URI を追加
az ad app update --id 5688f334-1e0a-421d-a1d7-b951cdffab3a \
  --web-redirect-uris \
  "https://stjup2-frontend-udm3tutq7eb7i.yellowplant-e4c48860.japaneast.azurecontainerapps.io/.auth/login/aad/callback" \
  "https://stjup2-flutter-udm3tutq7eb7i.yellowplant-e4c48860.japaneast.azurecontainerapps.io/.auth/login/aad/callback"
```

## 解決策 2: Flutter アプリで認証を無効化（開発時のみ）

Flutter アプリでは認証が不要な場合、Container App の認証設定を無効化できます。

### Azure Portal での手順

1. **Container App を開く**
   - リソースグループ `rg-dev-storjup` を開く
   - `stjup2-flutter-udm3tutq7eb7i` を選択

2. **認証設定を開く**
   - 左メニューから「認証」を選択

3. **認証を無効化**
   - 「App Service 認証」を「オフ」に設定
   - 「保存」をクリック

### Azure CLI での手順

```bash
# Container App の認証を無効化
az containerapp auth update \
  --name stjup2-flutter-udm3tutq7eb7i \
  --resource-group rg-dev-storjup \
  --enabled false
```

## 解決策 3: Flutter アプリ用の別の Azure AD アプリを作成

Flutter アプリ専用の Azure AD アプリ登録を作成する方法:

```bash
# 新しい Azure AD アプリを作成
az ad app create \
  --display-name "Storj Flutter App" \
  --sign-in-audience AzureADMyOrg \
  --web-redirect-uris "https://stjup2-flutter-udm3tutq7eb7i.yellowplant-e4c48860.japaneast.azurecontainerapps.io/.auth/login/aad/callback"

# アプリ ID を取得（出力から確認）
# 例: "appId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

# Container App の認証設定を更新
az containerapp auth microsoft update \
  --name stjup2-flutter-udm3tutq7eb7i \
  --resource-group rg-dev-storjup \
  --client-id <新しいアプリID> \
  --client-secret-setting-name MICROSOFT_PROVIDER_AUTHENTICATION_SECRET \
  --issuer https://sts.windows.net/9c181bf2-8930-409f-9cc2-5651ceb84475/
```

## 推奨アプローチ

### 開発環境の場合
**解決策 2** を使用: Flutter アプリの認証を無効化
- 理由: 開発・テスト時は認証なしでアクセスできる方が便利

### 本番環境の場合
**解決策 1** を使用: リダイレクト URI を追加
- 理由: セキュリティを維持しながら Flutter アプリも認証できる

## 確認方法

設定後、以下の手順で確認:

1. **ブラウザでアクセス**
   ```
   https://stjup2-flutter-udm3tutq7eb7i.yellowplant-e4c48860.japaneast.azurecontainerapps.io
   ```

2. **期待される動作**
   - **認証有効の場合**: Azure AD ログイン画面が表示され、サインイン後にアプリが表示される
   - **認証無効の場合**: 直接アプリが表示される

3. **エラーが出る場合**
   - ブラウザの開発者ツール (F12) → Console タブでエラーを確認
   - Container App のログを確認:
     ```bash
     az containerapp logs show \
       --name stjup2-flutter-udm3tutq7eb7i \
       --resource-group rg-dev-storjup \
       --follow
     ```

## Container App 認証設定の確認

現在の認証設定を確認:

```bash
# 認証設定を表示
az containerapp auth show \
  --name stjup2-flutter-udm3tutq7eb7i \
  --resource-group rg-dev-storjup

# Microsoft プロバイダー設定を表示
az containerapp auth microsoft show \
  --name stjup2-flutter-udm3tutq7eb7i \
  --resource-group rg-dev-storjup
```

## トラブルシューティング

### エラー: "Invalid client secret"

**原因**: クライアントシークレットが期限切れまたは間違っている

**解決策**:
1. Azure Portal で Azure AD アプリの「証明書とシークレット」を開く
2. 新しいクライアントシークレットを作成
3. Container App の環境変数を更新

### エラー: "AADSTS50105: User not assigned to a role"

**原因**: ユーザーがアプリに割り当てられていない

**解決策**:
1. Azure Portal で Azure AD アプリの「エンタープライズ アプリケーション」を開く
2. 「ユーザーとグループ」を選択
3. ユーザーを追加

## 関連ドキュメント

- [AZURE_ENV.md](AZURE_ENV.md) - Azure 環境の全体構成
- [DEPLOY_FLUTTER_TO_AZURE.md](DEPLOY_FLUTTER_TO_AZURE.md) - Flutter アプリのデプロイ手順
- [Azure Container Apps Authentication](https://learn.microsoft.com/azure/container-apps/authentication)
- [Azure AD アプリ登録](https://learn.microsoft.com/azure/active-directory/develop/quickstart-register-app)
