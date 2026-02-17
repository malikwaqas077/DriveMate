import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

/// Saves receipt image to app documents. Native/mobile only.
Future<String?> saveReceiptToFile(XFile image) async {
  final appDir = await getApplicationDocumentsDirectory();
  final receiptsDir = Directory('${appDir.path}/receipts');
  if (!await receiptsDir.exists()) {
    await receiptsDir.create(recursive: true);
  }
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final ext = image.path.split('.').last;
  final destPath = '${receiptsDir.path}/$timestamp.$ext';
  await File(image.path).copy(destPath);
  return destPath;
}
