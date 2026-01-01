Future<Map<String, dynamic>> uploadBrowserFile({
  required Uri url,
  required Object file,
  Function(int sent, int total)? onSendProgress,
}) async {
  throw UnsupportedError('Browser uploads are only supported on web.');
}
