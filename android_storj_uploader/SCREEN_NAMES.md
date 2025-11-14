# Storj Photo Uploader - 画面名定義

## 画面一覧

### 1. メイン画面（MainActivity）
- **画面名**: 写真・動画一覧画面
- **英語名**: Media Gallery Screen
- **ファイル**: `MainActivity.kt`, `activity_main.xml`
- **役割**:
  - スマートフォンのカメラで撮影した写真・動画の一覧を表示
  - Storjにアップロード済みのメディアファイルを表示
  - アップロード状態の確認（✓マーク表示）
  - API接続状態の表示
  - 設定画面への遷移

### 2. アップロード設定画面（SettingsActivity）
- **画面名**: アップロード一覧・設定画面
- **英語名**: Upload List & Settings Screen
- **ファイル**: `SettingsActivity.kt`, `activity_settings.xml`
- **役割**:
  - 過去24時間の写真・動画のアップロード一覧表示
  - 手動アップロードの実行
  - アップロード進捗の表示
  - メイン画面への戻る

### 3. 画像ビューア画面（ImageViewerActivity）
- **画面名**: 画像詳細表示画面
- **英語名**: Image Viewer Screen
- **ファイル**: `ImageViewerActivity.kt`, `activity_image_viewer.xml`
- **役割**:
  - Storjに保存された画像のフルサイズ表示
  - ピンチイン・ピンチアウトでズーム
  - 画像のダウンロード（端末への保存）
  - 画像情報の表示（ファイル名、サイズ、日時）

### 4. 動画再生画面（VideoPlayerActivity）
- **画面名**: 動画再生画面
- **英語名**: Video Player Screen
- **ファイル**: `VideoPlayerActivity.kt`, `activity_video_player.xml`, `custom_player_control.xml`
- **役割**:
  - Storjに保存された動画のストリーミング再生
  - ローカルの動画の再生
  - 再生コントロール（再生/一時停止、シーク、巻き戻し、早送り）
  - フルスクリーン表示
  - 動画情報の表示（ファイル名）

## 画面遷移図

```
メイン画面（MainActivity）
├─ [☰メニュー] → アップロード設定画面（SettingsActivity）
│                 └─ [戻る] → メイン画面
├─ [画像タップ（Storj画像）] → 画像ビューア画面（ImageViewerActivity）
│                             └─ [閉じる] → メイン画面
└─ [動画タップ] → 動画再生画面（VideoPlayerActivity）
                 └─ [閉じる] → メイン画面
```

## 画面の特徴

### メイン画面の特徴
- 3カラムのグリッドレイアウト
- アップロード済みファイルに✓マークを表示
- 動画には再生アイコンを表示
- スワイプで画面更新
- ヘッダー部分は画面上部から80dp下に配置

### アップロード設定画面の特徴
- 過去24時間のメディアファイルのみを対象
- カメラフォルダ（Camera、カメラ、Screenshots）のファイルのみ
- 5ファイルずつバッチアップロード
- 進捗バー表示

### 画像ビューア画面の特徴
- PhotoViewライブラリを使用したズーム機能
- DownloadManagerを使用したダウンロード機能
- フルスクリーン表示

### 動画再生画面の特徴
- ExoPlayerを使用したストリーミング再生
- カスタムコントロール（下部から80dp上に配置）
- ヘッダー部分は画面上部から80dp下に配置
- フルスクリーン表示

## カメラフォルダの定義

アプリが対象とするカメラフォルダ（BUCKET_DISPLAY_NAME）:
- **Camera** - メインカメラで撮影した写真・動画
- **カメラ** - 日本語環境でのカメラフォルダ
- **Screenshots** - スクリーンショット（写真のみ）

これ以外のフォルダ（ダウンロード、WhatsApp、LINE等）のファイルは対象外です。

## 自動アップロード機能

- **実行タイミング**: 15分ごと
- **対象期間**: 過去24時間のメディアファイル
- **対象フォルダ**: カメラフォルダのみ
- **バッチサイズ**: 10ファイルずつ
- **実装**: PhotoUploadWorker (WorkManager)
