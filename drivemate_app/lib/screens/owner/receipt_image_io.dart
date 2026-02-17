import 'dart:io';

import 'package:flutter/material.dart';

/// Builds receipt image from file path. Native/mobile only.
Widget buildReceiptImage({
  required String? path,
  required dynamic bytes,
  required Widget Function() errorBuilder,
}) {
  if (path == null) return const SizedBox.shrink();
  return Image.file(
    File(path),
    height: 200,
    width: double.infinity,
    fit: BoxFit.cover,
    errorBuilder: (_, __, ___) => errorBuilder(),
  );
}
