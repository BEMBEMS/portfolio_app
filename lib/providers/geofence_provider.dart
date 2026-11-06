import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/custom_landmark.dart';

class GeofenceProvider extends ChangeNotifier {
  GeofenceProvider(this._preferences) {
    _load();
  }

  static const String storageKey = 'geofence_locations_v1';

  final SharedPreferences _preferences;
  List<CustomLandmark> _locations = const [];

  List<CustomLandmark> get locations =>
      List<CustomLandmark>.unmodifiable(_locations);

  int get count => _locations.length;
  int get limit => maxGeofenceLocations;
  bool get isFull => _locations.length >= maxGeofenceLocations;

  void _load() {
    final stored = _preferences.getString(storageKey);
    if (stored == null) {
      _locations = List<CustomLandmark>.from(defaultGeofenceLandmarks);
      _persist();
      return;
    }

    try {
      final decoded = jsonDecode(stored);
      if (decoded is! List) {
        _locations = List<CustomLandmark>.from(defaultGeofenceLandmarks);
        _persist();
        return;
      }

      _locations = decoded
          .whereType<Map>()
          .map(
            (json) => CustomLandmark.fromJson(Map<String, dynamic>.from(json)),
          )
          .take(maxGeofenceLocations)
          .toList();
    } catch (_) {
      _locations = List<CustomLandmark>.from(defaultGeofenceLandmarks);
      _persist();
    }
  }

  bool addLocation(CustomLandmark location) {
    if (isFull) return false;
    _locations = [..._locations, location];
    _commit();
    return true;
  }

  bool updateLocation(String id, CustomLandmark updated) {
    final index = _locations.indexWhere((location) => location.id == id);
    if (index == -1) return false;
    _locations = [..._locations]..[index] = updated.copyWith(id: id);
    _commit();
    return true;
  }

  bool replaceLocation(String id, CustomLandmark replacement) {
    return updateLocation(id, replacement);
  }

  bool removeLocation(String id) {
    final index = _locations.indexWhere((location) => location.id == id);
    if (index == -1) return false;
    _locations = [..._locations]..removeAt(index);
    _commit();
    return true;
  }

  void _commit() {
    _persist();
    notifyListeners();
  }

  void _persist() {
    final encoded = jsonEncode(
      _locations.map((location) => location.toJson()).toList(),
    );
    unawaited(_preferences.setString(storageKey, encoded));
  }
}
