import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

import 'location_image_storage_stub.dart'
    if (dart.library.io) 'location_image_storage_io.dart'
    as platform;

/// Persists geofence location images so they survive app restarts.
///
/// Mobile and desktop builds copy the selected image into the app documents
/// directory. Web builds keep the image inline as a data URI because there is
/// no application filesystem available.
class LocationImageStorage {
  const LocationImageStorage._();

  static Future<String> save(XFile file, {required String locationId}) {
    return platform.saveLocationImage(file, locationId);
  }

  static Future<Uint8List?> read(String? reference) {
    return platform.readLocationImage(reference);
  }

  static Future<void> delete(String? reference) {
    return platform.deleteLocationImage(reference);
  }
}
