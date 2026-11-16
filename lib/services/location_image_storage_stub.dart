import 'dart:convert';
import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

/// Web fallback: store the image inline because browsers cannot write to an
/// application documents directory.
Future<String> saveLocationImage(XFile file, String locationId) async {
  final bytes = await file.readAsBytes();
  return 'data:${_mimeTypeForName(file.name)};base64,${base64Encode(bytes)}';
}

Future<Uint8List?> readLocationImage(String? reference) async {
  if (reference == null || !reference.startsWith('data:')) return null;

  final comma = reference.indexOf(',');
  if (comma == -1) return null;

  try {
    return base64Decode(reference.substring(comma + 1));
  } catch (_) {
    return null;
  }
}

Future<void> deleteLocationImage(String? reference) async {}

String _mimeTypeForName(String name) {
  final lower = name.toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.gif')) return 'image/gif';
  if (lower.endsWith('.webp')) return 'image/webp';
  if (lower.endsWith('.bmp')) return 'image/bmp';
  if (lower.endsWith('.heic')) return 'image/heic';
  return 'image/jpeg';
}
