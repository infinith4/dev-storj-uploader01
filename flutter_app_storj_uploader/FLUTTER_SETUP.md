# Flutter開発環境セットアップ手順

このドキュメントは、Flutter開発環境のセットアップ手順を記載しています。

## 前提条件

- Ubuntu 24.04 LTS (WSL2環境)
- インターネット接続

## セットアップ手順

### 1. Java JDKのインストール

Android開発に必要なJava Development Kitをインストールします。

```bash
sudo apt update && sudo apt install -y default-jdk
```

### 2. Android Command-line Toolsのダウンロードと設定

#### 2.1 ディレクトリ作成とダウンロード

```bash
mkdir -p /home/vscode/Android/cmdline-tools
cd /home/vscode/Android/cmdline-tools
wget https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip
```

#### 2.2 解凍と配置

```bash
unzip -q commandlinetools-linux-11076708_latest.zip
mv cmdline-tools latest
rm commandlinetools-linux-11076708_latest.zip
```

### 3. 環境変数の設定

#### 3.1 環境変数を.bashrcに追加

```bash
export ANDROID_HOME=/home/vscode/Android
export PATH=$PATH:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools
echo 'export ANDROID_HOME=/home/vscode/Android' >> ~/.bashrc
echo 'export PATH=$PATH:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools' >> ~/.bashrc
```

#### 3.2 FlutterにAndroid SDKパスを設定

```bash
flutter config --android-sdk /home/vscode/Android
```

### 4. Android SDKコンポーネントのインストール

#### 4.1 ライセンスの承認

```bash
bash -c "export ANDROID_HOME=/home/vscode/Android && export PATH=\$PATH:\$ANDROID_HOME/cmdline-tools/latest/bin:\$ANDROID_HOME/platform-tools && yes | \$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager --licenses"
```

#### 4.2 必要なSDKパッケージのインストール

```bash
bash -c "export ANDROID_HOME=/home/vscode/Android && export PATH=\$PATH:\$ANDROID_HOME/cmdline-tools/latest/bin:\$ANDROID_HOME/platform-tools && \$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager --install 'platform-tools' 'platforms;android-34' 'build-tools;34.0.0' 'cmdline-tools;latest' <<< y"
```

### 5. Google Chromeのインストール

Web開発用にGoogle Chromeをインストールします。

```bash
wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
sudo apt install -y ./google-chrome-stable_current_amd64.deb
rm google-chrome-stable_current_amd64.deb
```

### 6. セットアップの確認

```bash
flutter doctor
```

#### 期待される結果

```
Doctor summary (to see all details, run flutter doctor -v):
[✓] Flutter (Channel stable, 3.24.5, on Ubuntu 24.04.3 LTS 5.15.167.4-microsoft-standard-WSL2, locale en_US)
[✓] Android toolchain - develop for Android devices (Android SDK version 34.0.0)
[✓] Chrome - develop for the web
[✓] Linux toolchain - develop for Linux desktop
[!] Android Studio (not installed)
[✓] Connected device (2 available)
[✓] Network resources

! Doctor found issues in 1 category.
```

**注意**: Android Studioの警告は表示されますが、Android SDK command-line toolsで開発可能なため、インストールは必須ではありません。

## トラブルシューティング

### Android SDKが認識されない場合

環境変数が正しく設定されているか確認してください:

```bash
echo $ANDROID_HOME
echo $PATH
```

新しいターミナルセッションを開くか、以下のコマンドで環境変数を再読み込みしてください:

```bash
source ~/.bashrc
```

### sdkmanagerが見つからない場合

Android command-line toolsが正しく配置されているか確認してください:

```bash
ls -la /home/vscode/Android/cmdline-tools/latest/bin/sdkmanager
```

### パッケージインストールでエラーが発生する場合

aptパッケージマネージャーを修復してください:

```bash
sudo dpkg --configure -a
sudo apt --fix-broken install -y
```

## インストールされたコンポーネント

- Java JDK 21
- Android SDK Command-line Tools (latest)
- Android SDK Platform 34
- Android SDK Build-Tools 34.0.0
- Android SDK Platform-Tools
- Google Chrome (stable)

## 参考リンク

- [Flutter公式ドキュメント](https://flutter.dev/docs)
- [Android Studioセットアップガイド](https://flutter.dev/to/linux-android-setup)
- [Flutter Doctor解説](https://docs.flutter.dev/get-started/install/linux#run-flutter-doctor)
