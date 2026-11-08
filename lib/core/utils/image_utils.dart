import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Firestore documents max out at 1 MiB, so receipts are capped at 700 KB.
const maxReceiptBytes = 700 * 1024;

Uint8List? _shrink(Uint8List input) {
  final decoded = img.decodeImage(input);
  if (decoded == null) return null;
  var image = img.bakeOrientation(decoded);
  if (image.width > 1280 || image.height > 1280) {
    image = image.width >= image.height
        ? img.copyResize(image, width: 1280)
        : img.copyResize(image, height: 1280);
  }
  var quality = 70;
  var out = Uint8List.fromList(img.encodeJpg(image, quality: quality));
  while (out.length > maxReceiptBytes && quality > 30) {
    quality -= 10;
    out = Uint8List.fromList(img.encodeJpg(image, quality: quality));
  }
  if (out.length > maxReceiptBytes) {
    image = img.copyResize(image, width: (image.width * 0.7).round());
    out = Uint8List.fromList(img.encodeJpg(image, quality: 50));
  }
  return out.length <= maxReceiptBytes ? out : null;
}

/// Resizes and re-encodes a photo as JPEG (typically 100-300 KB). Null if unreadable.
Future<Uint8List?> compressReceiptImage(Uint8List bytes) => compute(_shrink, bytes);
