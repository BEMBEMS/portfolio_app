import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

const String _imageDirectoryName = 'geofence_images';

Future<String> saveLocationImage(XFile file, String locationId) async {
  final documents = await getApplicationDocumentsDirectory();
  final directory = Directory(
    '${documents.path}${Platform.pathSeparator}$_imageDirectoryName',
  );
  await directory.create(recursive: true);

  final safeId = locationId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
  final fileName =
      '${safeId}_${DateTime.now().microsecondsSinceEpoch}'
      '${_extensionFor(file.name)}';
  final destination = File(
    '${directory.path}${Platform.pathSeparator}$fileName',
  );

  await destination.writeAsBytes(await file.readAsBytes(), flush: true);
  return destination.path;
}

Future<Uint8List?> readLocationImage(String? reference) async {
  if (reference == null || reference.trim().isEmpty) return null;
  if (reference.startsWith('data:')) return _decodeDataReference(reference);

  try {
    final file = File(reference);
    if (!await file.exists()) return null;
    return await file.readAsBytes();
  } catch (_) {
    return null;
  }
}

Future<void> deleteLocationImage(String? reference) async {
  if (reference == null || reference.trim().isEmpty) return;
  if (reference.startsWith('data:')) return;

  try {
    final file = File(reference);
    if (await file.exists()) {
      await file.delete();
    }
  } catch (_) {
    // Deleting a stale image should never block the location update.
  }
}

Uint8List? _decodeDataReference(String reference) {
  final comma = reference.indexOf(',');
  if (comma == -1) return null;

  try {
    return base64Decode(reference.substring(comma + 1));
  } catch (_) {
    return null;
  }
}

String _extensionFor(String name) {
  final dot = name.lastIndexOf('.');
  if (dot == -1 || dot == name.length - 1) return '.jpg';

  final extension = name.substring(dot).toLowerCase();
  const allowed = {'.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp', '.heic'};
  return allowed.contains(extension) ? extension : '.jpg';
}
