import 'dart:typed_data';

import 'package:flutter/material.dart';

/// Builds receipt image from bytes. Web only (stub when dart:io not available).
Widget buildReceiptImage({
  required String? path,
  required Uint8List? bytes,
  required Widget Function() errorBuilder,
}) {
  if (bytes == null) return const SizedBox.shrink();
  return Image.memory(
    bytes,
    height: 200,
    width: double.infinity,
    fit: BoxFit.cover,
    errorBuilder: (_, __, ___) => errorBuilder(),
  );
}
