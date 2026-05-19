import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

const int scanUploadMaxDimension = 1024;
const int scanUploadJpegQuality = 70;

Uint8List compressScanImageBytes(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return bytes;

  final oriented = img.bakeOrientation(decoded);
  final longestSide = oriented.width > oriented.height
      ? oriented.width
      : oriented.height;
  final resized = longestSide > scanUploadMaxDimension
      ? img.copyResize(
          oriented,
          width: oriented.width >= oriented.height
              ? scanUploadMaxDimension
              : null,
          height: oriented.height > oriented.width
              ? scanUploadMaxDimension
              : null,
          interpolation: img.Interpolation.average,
        )
      : oriented;

  return Uint8List.fromList(
    img.encodeJpg(resized, quality: scanUploadJpegQuality),
  );
}

Future<Uint8List> compressedScanImageFileForUpload(File image) async {
  final originalBytes = await image.readAsBytes();
  try {
    return await compute(compressScanImageBytes, originalBytes);
  } catch (_) {
    return originalBytes;
  }
}

Future<Uint8List> compressedScanImagePathForUpload(String imagePath) {
  return compressedScanImageFileForUpload(File(imagePath));
}
