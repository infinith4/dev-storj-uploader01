# 複数ビデオアップロード機能

## 追加機能

Flutter Webアプリで複数の動画ファイルを一度に選択してアップロードできるようになりました。

## 実装内容

### 1. FileServiceに複数ビデオ選択メソッドを追加

**ファイル**: `lib/services/file_service.dart`

```dart
// Pick multiple videos from gallery
Future<List<LocalFile>> pickMultipleVideos() async {
  try {
    // Use file picker for multiple video selection
    return await pickFiles(
      type: FileType.video,
      allowMultiple: true,
    );
  } catch (e) {
    print('Error picking multiple videos: $e');
    return [];
  }
}
```

### 2. UIウィジェットに複数ビデオ選択ハンドラーを追加

**ファイル**: `lib/widgets/file_upload_area.dart`

```dart
Future<void> _pickMultipleVideos() async {
  if (!widget.isEnabled) return;

  try {
    HapticFeedback.lightImpact();
    final files = await FileService().pickMultipleVideos();
    if (files.isNotEmpty) {
      widget.onFilesSelected(files);
      _showSuccessAnimation();
    }
  } catch (e) {
    _showErrorSnackBar('Failed to pick videos: $e');
  }
}
```

### 3. UIボタンの更新

アップロードエリアのボタンを以下のように変更しました：

**変更前**:
- Gallery (画像のみ)
- Camera (写真撮影)
- Video (動画録画)

**変更後**:
- **Images** - 複数画像選択
- **Videos** - 複数動画選択（新機能）
- **Camera** - 写真撮影
- **Record** - 動画録画

```dart
Widget _buildActionButtons() {
  return Wrap(
    spacing: UIConstants.smallPadding,
    runSpacing: UIConstants.smallPadding,
    alignment: WrapAlignment.center,
    children: [
      ElevatedButton.icon(
        onPressed: _pickImages,
        icon: const Icon(Icons.photo_library, size: UIConstants.smallIconSize),
        label: const Text('Images'),
        // ...
      ),
      ElevatedButton.icon(
        onPressed: _pickMultipleVideos,  // 新しいメソッド
        icon: const Icon(Icons.video_library, size: UIConstants.smallIconSize),
        label: const Text('Videos'),
        // ...
      ),
      ElevatedButton.icon(
        onPressed: _pickImageFromCamera,
        icon: const Icon(Icons.camera_alt, size: UIConstants.smallIconSize),
        label: const Text('Camera'),
        // ...
      ),
      ElevatedButton.icon(
        onPressed: _pickVideoFromCamera,
        icon: const Icon(Icons.videocam, size: UIConstants.smallIconSize),
        label: const Text('Record'),
        // ...
      ),
    ],
  );
}
```

## 使用方法

### 複数動画ファイルのアップロード

1. ブラウザで http://localhost:8080 にアクセス
2. **Videos** ボタンをクリック
3. ファイル選択ダイアログで複数の動画ファイルを選択
   - Ctrl/Command + クリックで複数選択
   - Shift + クリックで範囲選択
4. 「開く」をクリック
5. 選択したすべての動画がアップロードキューに追加される

### ドラッグ&ドロップ

動画ファイルもドラッグ&ドロップでアップロード可能です：

1. デスクトップから動画ファイルをドラッグ
2. アップロードエリアにドロップ
3. 自動的にアップロードキューに追加される

## 対応動画形式

以下の動画形式がサポートされています：

- MP4
- MOV
- AVI
- MKV
- WebM
- FLV
- 3GP
- その他の一般的な動画形式

## ボタン一覧

### Images ボタン
- **アイコン**: 📷 photo_library
- **機能**: 複数の画像ファイルを選択
- **対応形式**: JPEG, PNG, HEIC, HEIF, WebP, BMP, TIFF等

### Videos ボタン
- **アイコン**: 🎬 video_library
- **機能**: 複数の動画ファイルを選択
- **対応形式**: MP4, MOV, AVI, MKV, WebM等

### Camera ボタン
- **アイコン**: 📸 camera_alt
- **機能**: カメラで写真を撮影
- **プラットフォーム**: モバイル、カメラ対応デバイス

### Record ボタン
- **アイコン**: 🎥 videocam
- **機能**: カメラで動画を録画
- **プラットフォーム**: モバイル、カメラ対応デバイス

## ファイルサイズ制限

- **画像ファイル**: 最大 50MB
- **動画ファイル**: 最大 500MB
- **その他ファイル**: 最大 500MB

サイズ制限を超えるファイルはエラーメッセージが表示され、アップロードキューに追加されません。

## Web版での制限事項

### カメラ・録画機能
Web版では以下のボタンは動作しない場合があります：
- **Camera**: Webカメラを使用した写真撮影
- **Record**: Webカメラを使用した動画録画

これらの機能はモバイルアプリやデスクトップアプリで完全にサポートされます。

### 推奨の使用方法（Web版）
- **Images** ボタン - ファイルシステムから画像を選択
- **Videos** ボタン - ファイルシステムから動画を選択
- **ドラッグ&ドロップ** - すべてのファイルタイプ対応

## トラブルシューティング

### 動画が選択できない

1. **ブラウザのファイル選択ダイアログを確認**
   - ファイルタイプが「Video Files」または「All Files」になっているか確認

2. **ファイルサイズを確認**
   - 500MBを超える動画はアップロードできません

3. **対応形式を確認**
   - 一般的な動画形式（MP4, MOV等）を使用してください

### 複数選択ができない

- **Windows**: Ctrl + クリック
- **Mac**: Command + クリック
- **範囲選択**: Shift + クリック

## まとめ

複数動画アップロード機能により、以下が可能になりました：

✅ 複数の動画ファイルを一度に選択してアップロード
✅ ドラッグ&ドロップでの動画アップロード
✅ 画像と動画を明確に区別したUI
✅ Web環境でも快適な動画アップロード体験

これにより、大量の動画ファイルを効率的にStorjストレージにアップロードできます。
