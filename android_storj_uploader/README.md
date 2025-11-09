# Storj Photo Uploader - Android App

スマートフォンの写真を自動的にStorjにアップロードするAndroidアプリです。GitHub Actionsによる自動ビルド・リリースに対応しています。

## 機能

- ✅ **写真の自動アップロード** - バックグラウンドで15分ごとに新しい写真を自動アップロード
- ✅ **手動アップロード** - ボタンをタップして即座に写真をアップロード
- ✅ **Bearer Token認証** - セキュアなAPI認証
- ✅ **Storj Backend API連携** - `storj_uploader_backend_api_container_app` と連携
- ✅ Kotlinベースの基本的なAndroidアプリ
- ✅ Material Designテーマ
- ✅ GitHub Actions CI/CD
- ✅ 自動テスト・ビルド
- ✅ リリースAPKの自動生成
- ✅ 署名付きビルド対応

## 必要な環境

- JDK 17以上
- Android SDK
- Android Studio (推奨) または Android Command Line Tools

## ビルド方法

### コマンドラインでビルド

```bash
./gradlew build
```

### APKの生成

```bash
./gradlew assembleDebug
```

APKは `app/build/outputs/apk/debug/app-debug.apk` に生成されます。

## エミュレータでの実行

### Android Studioを使用する場合

1. Android Studioでこのプロジェクトを開く
2. ツールバーの「Run」ボタンをクリック
3. エミュレータまたは接続されたデバイスを選択

### コマンドラインを使用する場合

1. エミュレータを起動
```bash
emulator -avd 'Pixel_9a'
```

2. アプリをインストールして実行
```bash
./gradlew installDebug
adb shell am start -n com.example.storjapp/.MainActivity
```

または

```bash
./gradlew installDebug && adb shell am start -n com.example.storjapp/.MainActivity
```

## アプリの使い方

### 初期設定

1. **Backend APIの起動**
   ```bash
   cd ../dev-storj-uploader01/storj_uploader_backend_api_container_app
   docker-compose up --build
   ```
   APIは `http://localhost:8010` で起動します。

2. **アプリのインストール**
   - エミュレータまたは実機にアプリをインストール
   ```bash
   ./gradlew installDebug
   ```

3. **Bearer Tokenの設定**
   - アプリを起動
   - Bearer Token入力欄にAPIトークンを入力
   - 「Save Token」ボタンをタップ
   - 写真アクセス権限の許可を求められたら「許可」をタップ

### 自動アップロード

- Tokenを保存すると自動的にバックグラウンドアップロードが有効になります
- 15分ごとに過去24時間以内に追加された写真が自動的にアップロードされます
- ネットワークに接続されている場合のみ動作します

### 手動アップロード

- 「Upload Photos Now」ボタンをタップすると、即座に写真のアップロードが開始されます
- 過去24時間以内に追加された写真がアップロードされます

### 注意事項

- エミュレータでテストする場合、APIのURLは `http://10.0.2.2:8010` に設定されています（エミュレータから localhost にアクセスするための特別なIP）
- 実機でテストする場合は、`app/src/main/java/com/example/storjapp/api/RetrofitClient.kt` の BASE_URL を実際のIPアドレスに変更してください

## プロジェクト構成

- `app/src/main/java/com/example/storjapp/` - Kotlinソースコード
  - `MainActivity.kt` - メインアクティビティ
  - `api/` - API関連クラス（Retrofit, APIサービス）
  - `model/` - データモデル（レスポンス、リクエスト）
  - `repository/` - データ操作（写真取得、アップロード）
  - `worker/` - バックグラウンドタスク（WorkManager）
- `app/src/main/res/` - リソースファイル（レイアウト、文字列、色など）
- `app/src/main/AndroidManifest.xml` - アプリのマニフェストファイル
- `app/build.gradle` - アプリモジュールのビルド設定
- `build.gradle` - プロジェクトレベルのビルド設定

## 技術スタック

- **言語**: Kotlin
- **UIフレームワーク**: Android Views (Material Design Components)
- **HTTPクライアント**: Retrofit + OkHttp
- **JSONパーサー**: Gson
- **非同期処理**: Kotlin Coroutines
- **バックグラウンド処理**: WorkManager
- **アーキテクチャ**: Repository Pattern

## GitHub Actions CI/CD

このプロジェクトはGitHub Actionsによる自動ビルドとリリースをサポートしています。

### 自動実行されるタスク

- コードプッシュ時：ビルド、テスト、Lintチェック
- Pull Request時：同上
- タグプッシュ時：署名付きリリースAPKの生成とGitHubリリース作成

### リリースの作成方法

```bash
# バージョンを更新
# app/build.gradle の versionCode と versionName を変更

# タグを作成してプッシュ
git tag v1.0
git push origin main --tags
```

詳しくは [RELEASE.md](RELEASE.md) を参照してください。

## リリースビルド

リリース用の署名付きAPKを作成する方法：

1. キーストアを生成
   ```bash
   ./scripts/generate-keystore.sh
   ```

2. 設定ファイルを作成
   ```bash
   cp keystore.properties.example keystore.properties
   # keystore.properties を編集して実際の値を入力
   ```

3. リリースAPKをビルド
   ```bash
   ./gradlew assembleRelease
   ```

詳細なガイドは [RELEASE.md](RELEASE.md) を参照してください。

## カスタマイズ

- パッケージ名を変更する場合は、`app/build.gradle`の`applicationId`を変更してください
- アプリ名を変更する場合は、`app/src/main/res/values/strings.xml`の`app_name`を変更してください

## ドキュメント

- [RELEASE.md](RELEASE.md) - リリースビルドとデプロイの詳細ガイド
- [.github/workflows/android-build.yml](.github/workflows/android-build.yml) - CI/CD設定
