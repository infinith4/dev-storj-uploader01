import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;

Future<Map<String, dynamic>> uploadBrowserFile({
  required Uri url,
  required Object file,
  Function(int sent, int total)? onSendProgress,
}) async {
  final request = html.HttpRequest();
  request.open('POST', url.toString());
  request.setRequestHeader('Accept', 'application/json');

  if (onSendProgress != null) {
    request.upload.onProgress.listen((event) {
      if (event.lengthComputable) {
        onSendProgress(event.loaded, event.total);
      }
    });
  }

  final formData = html.FormData();
  final browserFile = file as html.File;
  formData.appendBlob('file', browserFile, browserFile.name);

  final completer = Completer<Map<String, dynamic>>();

  request.onLoadEnd.listen((_) {
    final status = request.status ?? 0;
    if (status >= 200 && status < 300) {
      final responseText = request.responseText ?? '';
      if (responseText.isEmpty) {
        completer.complete({});
        return;
      }

      try {
        final decoded = jsonDecode(responseText);
        if (decoded is Map<String, dynamic>) {
          completer.complete(decoded);
          return;
        }
        completer.complete({'data': decoded});
      } catch (e) {
        completer.completeError(Exception('Invalid response: $e'));
      }
      return;
    }

    completer.completeError(
      Exception('Upload failed with status $status: ${request.responseText}'),
    );
  });

  request.onError.listen((_) {
    completer.completeError(Exception('Upload failed due to a network error.'));
  });

  request.send(formData);
  return completer.future;
}
