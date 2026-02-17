import 'package:image_picker/image_picker.dart';

/// Stub for web - never called; receipt uses in-memory bytes on web.
Future<String?> saveReceiptToFile(XFile image) async {
  throw UnsupportedError('saveReceiptToFile is not available on web');
}
