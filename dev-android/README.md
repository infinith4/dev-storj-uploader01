# MyApp - Android Template

シンプルなAndroidアプリのテンプレートです。GitHub Actionsによる自動ビルド・リリースに対応しています。

## 機能

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
emulator -avd 'Pixel 9a'
```

2. アプリをインストールして実行
```bash
./gradlew installDebug
adb shell am start -n com.example.myapp/.MainActivity
```

または

```bash
./gradlew installDebug && adb shell am start -n com.example.myapp/.MainActivity
```

## プロジェクト構成

- `app/src/main/java/` - Kotlinソースコード
- `app/src/main/res/` - リソースファイル（レイアウト、文字列、色など）
- `app/src/main/AndroidManifest.xml` - アプリのマニフェストファイル
- `app/build.gradle` - アプリモジュールのビルド設定
- `build.gradle` - プロジェクトレベルのビルド設定

## 機能

- Kotlin を使用した基本的なActivity
- ConstraintLayoutを使った簡単なUI
- Material Designテーマ

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
