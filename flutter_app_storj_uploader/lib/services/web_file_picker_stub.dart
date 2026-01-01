class WebPickedFile {
  final Object file;
  final String name;
  final int size;
  final String? mimeType;

  WebPickedFile({
    required this.file,
    required this.name,
    required this.size,
    this.mimeType,
  });
}

Future<List<WebPickedFile>> pickWebFiles({
  bool allowMultiple = true,
  String? accept,
}) async {
  return [];
}
