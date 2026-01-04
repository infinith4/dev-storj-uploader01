import 'dart:typed_data';
import 'package:flutter/widgets.dart';

class DropzoneViewController {
  Future<String?> getFilename(dynamic event) async => null;
  Future<int?> getFileSize(dynamic event) async => null;
  Future<String?> getFileMIME(dynamic event) async => null;
  Future<Uint8List?> getFileData(dynamic event) async => null;
}

enum DragOperation { copy }

class DropzoneView extends StatelessWidget {
  const DropzoneView({
    super.key,
    this.onCreated,
    this.onHover,
    this.onLeave,
    this.onDrop,
    this.onDropMultiple,
    this.operation,
  });

  final void Function(DropzoneViewController controller)? onCreated;
  final VoidCallback? onHover;
  final VoidCallback? onLeave;
  final void Function(dynamic event)? onDrop;
  final void Function(List<dynamic>? events)? onDropMultiple;
  final DragOperation? operation;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
