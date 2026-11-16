import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/custom_landmark.dart';

class GeofenceProvider extends ChangeNotifier {
  factory GeofenceProvider({SharedPreferences? preferences}) {
    return GeofenceProvider._(preferences);
  }

  GeofenceProvider._(this._preferences) {
    _ready = _initialize();
  }

  static const String storageKey = 'geofence_locations_v1';
  static const String lastLatitudeKey = 'last_geofence_latitude';
  static const String lastLongitudeKey = 'last_geofence_longitude';
  static const String lastAddressKey = 'last_geofence_address';
  static const String defaultsVersionKey = 'geofence_defaults_version';
  static const int defaultsVersion = 2;

  static const Map<String, String> _legacyDefaultNames = {
    'residence': "Ciloy's Residence",
    'boardwalk': 'Hidden Riverbank Boardwalk',
    'sunrise_hill': 'Del Monte Sunrise Hill',
    'banyan': 'Old Banyan Tree',
    'lagoon': 'Secret Fish Pond',
  };

  final SharedPreferences? _preferences;
  late final Future<void> _ready;
  late final SharedPreferences _prefs;
  List<CustomLandmark> _locations = const [];
  PinnedGeofenceLocation? _lastPinnedLocation;
  bool _isLoaded = false;

  /// Completes after the saved locations have been loaded from disk.
  Future<void> get ready => _ready;
  bool get isLoaded => _isLoaded;

  List<CustomLandmark> get locations =>
      List<CustomLandmark>.unmodifiable(_locations);

  PinnedGeofenceLocation? get lastPinnedLocation {
    for (final location in _locations) {
      if (location.isPinned) {
        return PinnedGeofenceLocation.fromLandmark(location);
      }
    }
    return _lastPinnedLocation;
  }

  int get count => _locations.length;
  int get limit => maxGeofenceLocations;
  bool get isFull => _locations.length >= maxGeofenceLocations;

  Future<void> _initialize() async {
    _prefs = _preferences ?? await SharedPreferences.getInstance();
    _load();

    final storedVersion = _prefs.getInt(defaultsVersionKey) ?? 1;
    if (storedVersion < defaultsVersion && _isUnmodifiedLegacyDefaultList()) {
      _locations = List<CustomLandmark>.from(defaultGeofenceLandmarks);
      _lastPinnedLocation = null;
    }

    _isLoaded = true;
    await _prefs.setInt(defaultsVersionKey, defaultsVersion);
    await _persistSnapshot();
    notifyListeners();
  }

  void _load() {
    final stored = _prefs.getString(storageKey);
    if (stored == null) {
      _locations = List<CustomLandmark>.from(defaultGeofenceLandmarks);
      return;
    }

    try {
      final decoded = jsonDecode(stored);
      if (decoded is! List) {
        _locations = List<CustomLandmark>.from(defaultGeofenceLandmarks);
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
      return;
    }

    _restoreLegacyPinState();
  }

  bool _isUnmodifiedLegacyDefaultList() {
    if (_locations.length != _legacyDefaultNames.length) return false;
    for (final location in _locations) {
      if (_legacyDefaultNames[location.id] != location.name) return false;
    }
    return true;
  }

  /// Older installs stored the last pinned coordinates in separate keys.
  /// Promote them into the serialized list so pin status is restored too.
  void _restoreLegacyPinState() {
    final latitude = _prefs.getDouble(lastLatitudeKey);
    final longitude = _prefs.getDouble(lastLongitudeKey);
    final address = _prefs.getString(lastAddressKey);

    if (latitude != null && longitude != null && address != null) {
      _lastPinnedLocation = PinnedGeofenceLocation(
        latitude: latitude,
        longitude: longitude,
        address: address,
      );
    }

    if (_locations.any((location) => location.isPinned)) return;

    final index = _locations.indexWhere(
      (location) =>
          location.position.latitude == latitude &&
          location.position.longitude == longitude &&
          location.displayAddress == address,
    );

    if (index != -1) {
      _locations = [..._locations];
      _locations[index] = _locations[index].copyWith(isPinned: true);
    }
  }

  Future<bool> addLocation(CustomLandmark location) async {
    await _ready;
    if (isFull) return false;

    _locations = [
      for (final item in _locations) item.copyWith(isPinned: false),
      location.copyWith(isPinned: true),
    ];
    _lastPinnedLocation = PinnedGeofenceLocation.fromLandmark(location);
    await _commit();
    return true;
  }

  Future<bool> updateLocation(String id, CustomLandmark updated) async {
    await _ready;
    final index = _locations.indexWhere((location) => location.id == id);
    if (index == -1) return false;

    final saved = updated.copyWith(id: id, isPinned: true);
    _locations = [
      for (var i = 0; i < _locations.length; i++)
        if (i == index) saved else _locations[i].copyWith(isPinned: false),
    ];
    _lastPinnedLocation = PinnedGeofenceLocation.fromLandmark(saved);
    await _commit();
    return true;
  }

  Future<bool> replaceLocation(String id, CustomLandmark replacement) {
    return updateLocation(id, replacement);
  }

  Future<bool> removeLocation(String id) async {
    await _ready;
    final index = _locations.indexWhere((location) => location.id == id);
    if (index == -1) return false;

    final removed = _locations[index];
    final last = _lastPinnedLocation;
    final removedWasLast =
        last != null &&
        last.latitude == removed.position.latitude &&
        last.longitude == removed.position.longitude &&
        last.address == removed.displayAddress;

    _locations = [..._locations]..removeAt(index);

    if (removed.isPinned || removedWasLast) {
      if (_locations.isEmpty) {
        _lastPinnedLocation = null;
      } else {
        _locations = [..._locations];
        _locations[0] = _locations[0].copyWith(isPinned: true);
        _lastPinnedLocation = PinnedGeofenceLocation.fromLandmark(
          _locations[0],
        );
      }
    }

    await _commit();
    return true;
  }

  Future<void> _commit() async {
    await _persistSnapshot();
    notifyListeners();
  }

  Future<void> _persistSnapshot() async {
    final encoded = jsonEncode(
      _locations.map((location) => location.toJson()).toList(),
    );
    await _prefs.setString(storageKey, encoded);

    final pinned = lastPinnedLocation;
    if (pinned == null) {
      await _prefs.remove(lastLatitudeKey);
      await _prefs.remove(lastLongitudeKey);
      await _prefs.remove(lastAddressKey);
      return;
    }

    await _prefs.setDouble(lastLatitudeKey, pinned.latitude);
    await _prefs.setDouble(lastLongitudeKey, pinned.longitude);
    await _prefs.setString(lastAddressKey, pinned.address);
  }
}
