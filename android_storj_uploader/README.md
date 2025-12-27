# Storj Photo Uploader - Android App

スマートフォンの写真を自動的にStorjにアップロードするAndroidアプリです。GitHub Actionsによる自動ビルド・リリースに対応しています。

## 機能

- ✅ **写真の自動アップロード** - バックグラウンドで15分ごとに新しい写真を自動アップロード
- ✅ **Storj画像一覧表示** - Storjに保存された画像をサムネイル表示
- ✅ **画像ビューア** - タップしてフルサイズ画像を表示、ズーム・ダウンロード機能
- ✅ **手動アップロード** - ボタンをタップして即座に写真をアップロード
- ✅ **Storj Backend API連携** - `storj_uploader_backend_api_container_app` と連携
- ✅ Kotlinベースの基本的なAndroidアプリ
- ✅ Material Designテーマ
- ✅ GitHub Actions CI/CD
- ✅ 自動テスト・ビルド
- ✅ リリースAPKの自動生成
- ✅ 署名付きビルド対応

## 必要な環境

### Windows環境
- **JDK 17以上**
  - 確認: `java -version`
  - インストール: https://adoptium.net/ から Temurin JDK 17をダウンロード
- **Android SDK**
  - Android Studio経由でインストール推奨
- **Android Studio** (推奨)
  - ダウンロード: https://developer.android.com/studio

### 環境変数の設定（コマンドライン使用時）
```cmd
set ANDROID_HOME=C:\Users\<YourUsername>\AppData\Local\Android\Sdk
set PATH=%PATH%;%ANDROID_HOME%\platform-tools;%ANDROID_HOME%\tools;%ANDROID_HOME%\cmdline-tools\latest\bin
```

## ビルド方法（Windows）

### コマンドプロンプト / PowerShellでビルド

**コマンドプロンプト:**
```cmd
cd android_storj_uploader
gradlew.bat build
```

**PowerShell:**
```powershell
cd android_storj_uploader
.\gradlew.bat build
```

### APKの生成

**デバッグAPKの生成:**
```cmd
gradlew.bat assembleDebug
```

生成されたAPK: `app\build\outputs\apk\debug\app-debug.apk`

**リリースAPKの生成:**
```cmd
.\gradlew.bat assembleRelease
```

生成されたAPK: `app\build\outputs\apk\release\app-release.apk`

## エミュレータでの実行（Windows）

### Android Studioを使用する場合（推奨）

1. Android Studioを起動
2. 「Open」→ `android_storj_uploader` フォルダを選択
3. Gradle同期が完了するまで待つ
4. ツールバーの「Device Manager」アイコンをクリック
5. エミュレータを作成（例: Pixel 9a, API 33）
6. ツールバーの「▶」（Run）ボタンをクリック
7. エミュレータを選択して実行

### コマンドラインを使用する場合

**1. 利用可能なエミュレータを確認:**
```cmd
emulator -list-avds
```

**2. エミュレータを起動（別のコマンドプロンプトで）:**
```cmd
emulator -avd Pixel_9a_API_33
```

**3. アプリをインストールして実行:**
```cmd
.\gradlew.bat installDebug
adb shell am start -n com.example.storjapp.debug/com.example.storjapp.MainActivity
```

## 実機での実行（Windows）

### USBデバッグの有効化

1. **Android端末の設定:**
   - 設定 → デバイス情報 → ビルド番号を7回タップ
   - 開発者向けオプションが有効になる
   - 設定 → システム → 開発者向けオプション → USBデバッグをON

2. **端末をPCに接続:**
   ```cmd
   adb devices
   ```
   端末のシリアル番号が表示されることを確認

3. **アプリをインストール:**
   ```cmd
   gradlew.bat installDebug
   ```

4. **端末でアプリを起動**

## アプリの使い方

### 初期設定

#### 1. Backend APIの起動

**Docker Desktopを使用する場合（推奨）:**

```cmd
cd ..\storj_uploader_backend_api_container_app
docker-compose up --build
```

APIは `http://localhost:8010` で起動します。

**直接Python実行する場合:**

```cmd
cd ..\storj_uploader_backend_api_container_app
pip install -r requirements.txt
python main.py
```

#### 2. API接続設定

API Base URLは `local.properties` ファイルで設定します。

**エミュレータの場合（デフォルト）:**
- `local.properties` の `api.base.url` をコメントアウトするか、削除
- デフォルトで `http://10.0.2.2:8010/` が使用されます
- 特別なIP: エミュレータからホストの localhost にアクセスするため

**実機の場合:**
1. PCのローカルIPアドレスを確認:
   ```cmd
   ipconfig
   ```
   例: `192.168.0.242`

2. `android_storj_uploader/local.properties` を編集:
   ```properties
   api.base.url=http://192.168.0.242:8010/
   ```
   （YOUR_PC_IPの部分を実際のIPアドレスに置き換え）

3. アプリを再ビルド・インストール:
   ```cmd
   gradlew.bat assembleDebug
   gradlew.bat installDebug
   ```

**注意事項:**
- PCと実機が同じWi-Fiネットワークに接続されている必要があります
- `local.properties` はgitignore済みなので、チーム開発でも各自が独自に設定可能
- テンプレートは `local.properties.example` を参照

#### 3. アプリの初回起動

1. アプリを起動
2. 写真アクセス権限の許可を求められたら「許可」をタップ
3. メイン画面が表示されます

### 機能説明

#### メイン画面（写真グリッド表示）
- ✅マーク付き: Storjにアップロード済み
- ✅マークなし: ローカルのみ（未アップロード）
- 下にスワイプ: 画面を更新

#### 写真のアップロード
- **自動アップロード**: 15分ごとに過去24時間の写真を自動アップロード
- **手動アップロード**: メニュー → 「アップロード一覧」→ 「Upload Now」ボタン

#### 画像一覧機能
- Storjに保存された画像をサムネイル表示
- タップでフルサイズ画像を表示
- ピンチイン/アウトでズーム
- ダウンロードボタンで端末に保存

### APIヘルスチェック

画面上部に「API: Connected ✓」または「API: Disconnected ✗」が表示されます。
- ✓ 緑色: API接続正常
- ✗ 赤色: API接続エラー → Backend APIの起動を確認

## トラブルシューティング

### ビルドエラー

**エラー: `JAVA_HOME is not set`**
```cmd
set JAVA_HOME=C:\Program Files\Eclipse Adoptium\jdk-17.0.x-hotspot
set PATH=%JAVA_HOME%\bin;%PATH%
```

**エラー: `SDK location not found`**
- `local.properties` ファイルを作成:
```properties
sdk.dir=C:\\Users\\<YourUsername>\\AppData\\Local\\Android\\Sdk
```

### エミュレータ起動エラー

**エラー: `emulator: ERROR: x86 emulation currently requires hardware acceleration!`**
- BIOSでIntel VT-x / AMD-Vを有効化
- Windows Hypervisor Platformを有効化:
  ```cmd
  bcdedit /set hypervisorlaunchtype auto
  ```
  （管理者権限のコマンドプロンプトで実行後、再起動）

### API接続エラー

**エミュレータでAPI: Disconnected**
1. Backend APIが起動しているか確認:
   ```cmd
   curl http://localhost:8010/health
   ```
2. Dockerコンテナが起動しているか確認:
   ```cmd
   docker ps
   ```

**実機でAPI: Disconnected**
1. PCと実機が同じWi-Fiネットワークに接続されているか確認
2. PCのファイアウォールでポート8010が許可されているか確認
3. BASE_URLが正しいIPアドレスに設定されているか確認

### adbコマンドが見つからない

```cmd
set PATH=%PATH%;%ANDROID_HOME%\platform-tools
```

または、フルパスで実行:
```cmd
%ANDROID_HOME%\platform-tools\adb.exe devices
```

## プロジェクト構成

```
android_storj_uploader/
├── app/
│   ├── src/
│   │   ├── main/
│   │   │   ├── java/com/example/storjapp/
│   │   │   │   ├── MainActivity.kt           # メイン画面
│   │   │   │   ├── SettingsActivity.kt       # 設定・アップロード画面
│   │   │   │   ├── ImageViewerActivity.kt    # 画像ビューア
│   │   │   │   ├── api/
│   │   │   │   │   ├── RetrofitClient.kt     # HTTP客户端
│   │   │   │   │   └── StorjApiService.kt    # API定義
│   │   │   │   ├── model/
│   │   │   │   │   ├── PhotoItem.kt          # 写真データモデル
│   │   │   │   │   ├── StorjImageItem.kt     # Storj画像モデル
│   │   │   │   │   └── UploadResponse.kt     # APIレスポンスモデル
│   │   │   │   ├── adapter/
│   │   │   │   │   └── PhotoGridAdapter.kt   # 写真グリッド表示
│   │   │   │   ├── repository/
│   │   │   │   │   └── PhotoRepository.kt    # データ操作
│   │   │   │   └── worker/
│   │   │   │       └── PhotoUploadWorker.kt  # バックグラウンドアップロード
│   │   │   ├── res/                           # リソースファイル
│   │   │   └── AndroidManifest.xml
│   │   └── test/                              # ユニットテスト
│   └── build.gradle                           # アプリモジュール設定
├── build.gradle                               # プロジェクト設定
├── settings.gradle                            # プロジェクト構成
├── gradlew.bat                                # Gradle Wrapper (Windows)
└── README.md                                  # このファイル
```

## 技術スタック

- **言語**: Kotlin 1.9.25
- **UIフレームワーク**: Android Views (Material Design 3)
- **画像表示**: Glide 4.16.0
- **画像ズーム**: PhotoView 2.3.0
- **HTTPクライアント**: Retrofit 2.9.0 + OkHttp 4.12.0
- **JSONパーサー**: Gson 2.10.1
- **非同期処理**: Kotlin Coroutines 1.7.3
- **バックグラウンド処理**: WorkManager 2.9.0
- **アーキテクチャ**: Repository Pattern

## GitHub Actions CI/CD

このプロジェクトはGitHub Actionsによる自動ビルドとリリースをサポートしています。

### 自動実行されるタスク

- コードプッシュ時：ビルド、テスト、Lintチェック
- Pull Request時：同上
- タグプッシュ時：署名付きリリースAPKの生成とGitHubリリース作成

### リリースの作成方法

```cmd
REM バージョンを更新
REM app\build.gradle の versionCode と versionName を変更

REM タグを作成してプッシュ
git tag v1.0.0
git push origin main --tags
```

詳しくは [RELEASE.md](RELEASE.md) を参照してください。

## リリースビルド（署名付きAPK）

### Windows PowerShellでキーストアを生成

```powershell
$keystorePath = "$PWD\upload-keystore.jks"
$alias = "upload"
$keyPassword = "your-secure-password"  # 変更してください
$storePassword = "your-secure-password"  # 変更してください

keytool -genkeypair -v `
  -storetype PKCS12 `
  -keystore $keystorePath `
  -alias $alias `
  -keyalg RSA `
  -keysize 2048 `
  -validity 10000 `
  -storepass $storePassword `
  -keypass $keyPassword `
  -dname "CN=Your Name, OU=Your Unit, O=Your Company, L=Your City, ST=Your State, C=JP"
```

### キーストア設定ファイルの作成

`keystore.properties` ファイルを作成:

```properties
storeFile=upload-keystore.jks
storePassword=your-secure-password
keyAlias=upload
keyPassword=your-secure-password
```

**⚠️ 注意**: `keystore.properties` と `upload-keystore.jks` は絶対に Git にコミットしないでください！

### リリースAPKのビルド

```cmd
gradlew.bat assembleRelease
```

生成されたAPK: `app\build\outputs\apk\release\app-release.apk`

詳細なガイドは [RELEASE.md](RELEASE.md) を参照してください。

## カスタマイズ

### パッケージ名の変更
`app\build.gradle` の `applicationId` を変更:
```gradle
applicationId "com.yourcompany.yourapp"
```

### アプリ名の変更
`app\src\main\res\values\strings.xml` の `app_name` を変更:
```xml
<string name="app_name">Your App Name</string>
```

### APIエンドポイントの変更
`app\src\main\java\com\example\storjapp\api\RetrofitClient.kt`:
```kotlin
const val BASE_URL = "http://your-api-server:8010/"
```

## ログの確認

### リアルタイムログ
```cmd
adb logcat -s MainActivity:D PhotoRepository:D ImageViewerActivity:D
```

### 特定のエラーを検索
```cmd
adb logcat | findstr /i "error exception"
```

### ログをファイルに保存
```cmd
adb logcat > app_log.txt
```

## ドキュメント

- [SCREEN_DESIGN.md](SCREEN_DESIGN.md) - 画面設計書・画面遷移図・UIフロー図
- [RELEASE.md](RELEASE.md) - リリースビルドとデプロイの詳細ガイド
- [.github/workflows/android-build.yml](../.github/workflows/android-build.yml) - CI/CD設定

## ライセンス

このプロジェクトのライセンスについては、ルートディレクトリのLICENSEファイルを参照してください。
