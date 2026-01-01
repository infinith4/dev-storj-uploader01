import 'dart:async';
import 'dart:html' as html;
export 'web_file_picker_stub.dart' show WebPickedFile;
import 'web_file_picker_stub.dart';

Future<List<WebPickedFile>> pickWebFiles({
  bool allowMultiple = true,
  String? accept,
}) async {
  final input = html.FileUploadInputElement();
  input.multiple = allowMultiple;
  if (accept != null && accept.isNotEmpty) {
    input.accept = accept;
  }

  final completer = Completer<List<WebPickedFile>>();

  void completeWithFiles() {
    final files = input.files;
    if (files == null || files.isEmpty) {
      if (!completer.isCompleted) {
        completer.complete([]);
      }
      return;
    }

    final picked = <WebPickedFile>[];
    for (final file in files) {
      picked.add(
        WebPickedFile(
          file: file,
          name: file.name,
          size: file.size,
          mimeType: file.type.isNotEmpty ? file.type : null,
        ),
      );
    }

    if (!completer.isCompleted) {
      completer.complete(picked);
    }
  }

  input.onChange.listen((_) => completeWithFiles());
  input.onError.listen((_) {
    if (!completer.isCompleted) {
      completer.completeError(Exception('File selection failed'));
    }
  });

  input.click();
  return completer.future;
}
