# リリースビルドガイド

このドキュメントでは、Androidアプリのリリースビルドを作成する方法を説明します。

## 目次

1. [初回セットアップ](#初回セットアップ)
2. [ローカルでのリリースビルド](#ローカルでのリリースビルド)
3. [GitHub Actionsでの自動ビルド](#github-actionsでの自動ビルド)
4. [リリースの公開](#リリースの公開)

## 初回セットアップ

### 1. キーストアの生成

リリース用のAPKに署名するためのキーストアを生成します。

```bash
./scripts/generate-keystore.sh
```

このスクリプトは以下を実行します：
- `keystore.jks` ファイルを生成
- パスワードと証明書情報を入力
- GitHub Actionsで使用するための情報を表示

**重要**: 生成されたキーストアとパスワードは安全に保管してください！紛失すると、アプリの更新ができなくなります。

### 2. ローカル用の設定ファイル作成

```bash
cp keystore.properties.example keystore.properties
```

`keystore.properties` を編集して、実際の値を入力します：

```properties
storeFile=keystore.jks
storePassword=YOUR_ACTUAL_KEYSTORE_PASSWORD
keyAlias=storjapp
keyPassword=YOUR_ACTUAL_KEY_PASSWORD
```

**注意**: `keystore.properties` はGitにコミットされません（.gitignoreに含まれています）。

## ローカルでのリリースビルド

### 署名付きリリースAPKの生成

```bash
./gradlew assembleRelease
```

生成されたAPKは以下に配置されます：
```
app/build/outputs/apk/release/app-release.apk
```

### ビルドの検証

APKが正しく署名されているか確認：

```bash
jarsigner -verify -verbose -certs app/build/outputs/apk/release/app-release.apk
```

### APKのインストールとテスト

```bash
adb install app/build/outputs/apk/release/app-release.apk
```

## GitHub Actionsでの自動ビルド

### GitHub Secretsの設定

リポジトリの Settings → Secrets and variables → Actions で以下のシークレットを追加：

1. **KEYSTORE_BASE64**
   ```bash
   # キーストアをBase64エンコード
   base64 -w 0 keystore.jks
   # または macOS:
   base64 -i keystore.jks | pbcopy
   ```
   出力された文字列をシークレットとして設定

2. **KEYSTORE_PASSWORD**
   - キーストアのパスワード

3. **KEY_ALIAS**
   - キーのエイリアス（例: `storjapp`）

4. **KEY_PASSWORD**
   - キーのパスワード

### 自動ビルドの動作

#### プッシュ時のビルド

任意のブランチにプッシュすると：
- ✅ ビルドとテストが実行
- ✅ デバッグAPKが生成
- ✅ アーティファクトとしてアップロード
- ✅ Lintチェックが実行

#### タグ作成時のリリース

バージョンタグをプッシュすると、署名付きリリースAPKが自動生成されます：

```bash
# バージョン番号を更新（app/build.gradle）
# versionCode と versionName を変更

# 変更をコミット
git add app/build.gradle
git commit -m "Bump version to 1.1"

# タグを作成
git tag v1.1

# プッシュ
git push origin main --tags
```

これにより：
- 署名付きリリースAPKが生成
- GitHubリリースが自動作成
- APKがリリースに添付

### ワークフロー

プロジェクトには3つのジョブがあります：

1. **build** - すべてのプッシュで実行
   - ビルドとテスト
   - デバッグAPKの生成とアップロード

2. **release** - タグプッシュ時のみ実行
   - 署名付きリリースAPKの生成
   - GitHubリリースの作成

3. **quality** - すべてのプッシュで実行
   - Lintチェック
   - レポートのアップロード

### アーティファクトのダウンロード

GitHub Actionsのワークフロー実行ページから：
1. Actions タブを開く
2. 該当のワークフロー実行を選択
3. Artifacts セクションからAPKをダウンロード

## リリースの公開

### Google Play Storeへのアップロード

1. [Google Play Console](https://play.google.com/console) にアクセス
2. アプリを作成または選択
3. リリース → 製品版 を選択
4. 新しいリリースを作成
5. `app-release.apk` をアップロード
6. リリースノートを記入
7. 審査に提出

### バージョン管理のベストプラクティス

`app/build.gradle` のバージョン番号：

```gradle
defaultConfig {
    versionCode 2        // 整数、毎回増やす
    versionName "1.1"    // ユーザーに表示されるバージョン
}
```

- `versionCode`: リリースごとに必ず増やす（Play Storeの要件）
- `versionName`: セマンティックバージョニングを推奨（例: 1.0.0, 1.1.0, 2.0.0）

## トラブルシューティング

### キーストアが見つからないエラー

```
Execution failed for task ':app:validateSigningRelease'.
> Keystore file not found
```

**解決方法**: `keystore.properties` ファイルを作成し、正しいパスを設定してください。

### 署名の検証エラー

```
jarsigner: unable to sign jar: java.util.zip.ZipException: invalid entry compressed size
```

**解決方法**: キーストアを再生成してください。

### GitHub Actionsでのビルド失敗

シークレットが正しく設定されているか確認：
```bash
# ローカルでテスト
./gradlew assembleRelease \
  -Pandroid.injected.signing.store.file=keystore.jks \
  -Pandroid.injected.signing.store.password=YOUR_PASSWORD \
  -Pandroid.injected.signing.key.alias=storjapp \
  -Pandroid.injected.signing.key.password=YOUR_PASSWORD
```

## セキュリティのベストプラクティス

- ✅ キーストアファイルは絶対にGitにコミットしない
- ✅ パスワードはGitHub Secretsに保存
- ✅ キーストアは複数の安全な場所にバックアップ
- ✅ パスワードマネージャーで管理
- ✅ チームメンバーとの共有は暗号化された方法で

## 参考リンク

- [Android Developer - アプリの署名](https://developer.android.com/studio/publish/app-signing)
- [GitHub Actions - Android CI](https://docs.github.com/en/actions/guides/building-and-testing-java-with-gradle)
- [Google Play Console](https://play.google.com/console)
