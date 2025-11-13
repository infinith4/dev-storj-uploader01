# Flutter Web Drag and Drop 実装ガイド

## 問題

Flutter Webアプリでドラッグ&ドロップ機能が動作していませんでした。

## 原因

- `flutter_dropzone`パッケージは既にインストールされていたが、実際のウィジェット実装がされていなかった
- ドラッグ&ドロップイベントを処理するコードが不完全だった

## 解決方法

### 1. 必要なパッケージのインポート

**ファイル**: `lib/widgets/file_upload_area.dart`

```dart
import 'package:flutter_dropzone/flutter_dropzone.dart';
```

### 2. DropzoneViewControllerの追加

```dart
class _FileUploadAreaState extends State<FileUploadArea>
    with TickerProviderStateMixin {
  bool _isDragOver = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late DropzoneViewController _dropzoneController;  // 追加
```

### 3. ドロップイベントハンドラーの実装

```dart
Future<void> _onDrop(dynamic event) async {
  if (!widget.isEnabled) return;

  setState(() {
    _isDragOver = false;
  });
  _animationController.reverse();

  try {
    // Get file name
    final name = await _dropzoneController.getFilename(event);
    final size = await _dropzoneController.getFileSize(event);
    final mimeType = await _dropzoneController.getFileMIME(event);

    // Create LocalFile instance
    final localFile = LocalFile(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      path: name, // For web, we use the filename as path
      size: size,
      type: _getFileTypeFromMime(mimeType),
      dateAdded: DateTime.now(),
    );

    widget.onFilesSelected([localFile]);
    _showSuccessAnimation();
  } catch (e) {
    _showErrorSnackBar('Failed to process dropped file: $e');
  }
}

String _getFileTypeFromMime(String mimeType) {
  if (mimeType.startsWith('image/')) return 'image';
  if (mimeType.startsWith('video/')) return 'video';
  if (mimeType.startsWith('application/pdf') ||
      mimeType.contains('document') ||
      mimeType.contains('text')) return 'document';
  return 'file';
}
```

### 4. DropzoneViewウィジェットの統合

Web環境でのみ`DropzoneView`を使用し、その他のプラットフォームでは通常の`InkWell`を使用します。

```dart
Widget _buildEnabledContent() {
  // For web platform, use DropzoneView for drag and drop
  if (kIsWeb) {
    return Stack(
      children: [
        DropzoneView(
          onCreated: (controller) => _dropzoneController = controller,
          onHover: () => _onDragEnter(),
          onLeave: () => _onDragLeave(),
          onDrop: _onDrop,
          operation: DragOperation.copy,
        ),
        InkWell(
          onTap: _pickFiles,
          borderRadius: BorderRadius.circular(UIConstants.largeBorderRadius),
          child: Container(
            // ... UI content
          ),
        ),
      ],
    );
  }

  // For non-web platforms, use standard InkWell
  return InkWell(
    onTap: _pickFiles,
    // ... UI content
  );
}
```

## 実装のポイント

### 1. プラットフォーム判定

`kIsWeb`を使用してWeb環境を判定し、Web環境でのみ`DropzoneView`を使用します。

```dart
if (kIsWeb) {
  // Web用のドラッグ&ドロップ実装
} else {
  // モバイル/デスクトップ用の実装
}
```

### 2. Stackウィジェットの使用

`DropzoneView`を背景に配置し、その上に通常のUIを重ねることで、ドラッグ&ドロップとタップ選択の両方を実現します。

```dart
Stack(
  children: [
    DropzoneView(...),  // ドラッグ&ドロップ処理
    InkWell(...),       // タップ処理とUI表示
  ],
)
```

### 3. ファイル情報の取得

`flutter_dropzone`は以下のメソッドでファイル情報を取得します：

- `getFilename(event)`: ファイル名
- `getFileSize(event)`: ファイルサイズ（バイト）
- `getFileMIME(event)`: MIMEタイプ
- `getFileData(event)`: ファイルデータ（Uint8List）

### 4. アニメーション連携

ドラッグオーバー時にアニメーションを実行して、ユーザーにフィードバックを提供します。

```dart
onHover: () => _onDragEnter(),    // ドラッグ開始
onLeave: () => _onDragLeave(),    // ドラッグ離脱
onDrop: _onDrop,                  // ドロップ完了
```

## 使用方法

### ドラッグ&ドロップでファイルをアップロード

1. ブラウザで http://localhost:8080 にアクセス
2. デスクトップからファイルをドラッグ
3. アップロードエリアにドロップ
4. ファイルが自動的にアップロードキューに追加される

### 視覚的フィードバック

- **通常状態**: グレーのボーダー、アップロードアイコン表示
- **ドラッグオーバー**: 青いボーダー、背景が青くハイライト、アイコンが塗りつぶし表示
- **ドロップ完了**: スケールアニメーション実行

## トラブルシューティング

### ドラッグ&ドロップが動作しない場合

1. **Web環境で実行されているか確認**:
   ```bash
   flutter run -d web-server --web-port 8080
   ```

2. **ブラウザのコンソールでエラー確認**:
   F12キーを押して、Console タブでエラーメッセージを確認

3. **flutter_dropzoneパッケージのバージョン確認**:
   ```yaml
   # pubspec.yaml
   dependencies:
     flutter_dropzone: ^4.0.1
   ```

4. **キャッシュクリア後に再ビルド**:
   ```bash
   flutter clean
   flutter pub get
   flutter run -d web-server --web-port 8080
   ```

### ファイルが選択されない場合

- `_dropzoneController`が正しく初期化されているか確認
- `onCreated`コールバックが呼ばれているか確認
- ブラウザのセキュリティ設定を確認

## 対応ファイル形式

### 画像ファイル
- JPEG, PNG, GIF, WebP, BMP, HEIC, HEIF

### 動画ファイル
- MP4, MOV, AVI, MKV, WebM, FLV, 3GP

### ドキュメントファイル
- PDF, DOC, DOCX, XLS, XLSX, PPT, PPTX, TXT

### その他
- すべてのファイル形式がサポートされています

## 技術スタック

- **Flutter**: 3.24.5
- **flutter_dropzone**: ^4.0.1
- **プラットフォーム**: Web (HTML5 Drag and Drop API)

## 参考リンク

- [flutter_dropzone Package](https://pub.dev/packages/flutter_dropzone)
- [HTML5 Drag and Drop API](https://developer.mozilla.org/en-US/docs/Web/API/HTML_Drag_and_Drop_API)
- [Flutter Web Documentation](https://docs.flutter.dev/platform-integration/web)

## まとめ

Flutter Webでのドラッグ&ドロップ機能は、`flutter_dropzone`パッケージを使用することで簡単に実装できます。Web専用機能のため、プラットフォーム判定を適切に行い、Web環境でのみ有効化することが重要です。
