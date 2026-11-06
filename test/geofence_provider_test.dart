import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:portfolio_app/models/custom_landmark.dart';
import 'package:portfolio_app/providers/geofence_provider.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<GeofenceProvider> createProvider() async {
    final preferences = await SharedPreferences.getInstance();
    return GeofenceProvider(preferences);
  }

  const extraLandmark = CustomLandmark(
    id: 'extra',
    name: 'New Hideout',
    category: 'Custom',
    description: 'A newly added geofence.',
    position: LatLng(8.49, 125.84),
    radiusMeters: 40,
    icon: Icons.star_rounded,
    color: Color(0xFF3949AB),
  );

  test('seeds five default locations on first run', () async {
    final provider = await createProvider();

    expect(provider.locations, hasLength(maxGeofenceLocations));
    expect(provider.isFull, isTrue);
    expect(provider.limit, maxGeofenceLocations);
  });

  test('rejects adding a sixth location', () async {
    final provider = await createProvider();

    final added = provider.addLocation(extraLandmark);

    expect(added, isFalse);
    expect(provider.count, maxGeofenceLocations);
  });

  test('can add after removing a location', () async {
    final provider = await createProvider();
    final removed = provider.locations.first;

    expect(provider.removeLocation(removed.id), isTrue);
    expect(provider.isFull, isFalse);
    expect(provider.addLocation(extraLandmark), isTrue);
    expect(provider.count, maxGeofenceLocations);
    expect(provider.locations.last.name, extraLandmark.name);
  });

  test('replace swaps an existing location and keeps the id', () async {
    final provider = await createProvider();
    final target = provider.locations.first;

    expect(provider.replaceLocation(target.id, extraLandmark), isTrue);

    final replaced = provider.locations.firstWhere(
      (location) => location.id == target.id,
    );
    expect(provider.count, maxGeofenceLocations);
    expect(replaced.name, extraLandmark.name);
    expect(replaced.position.latitude, extraLandmark.position.latitude);
  });

  test('update edits the selected location without changing count', () async {
    final provider = await createProvider();
    final target = provider.locations.first;

    expect(
      provider.updateLocation(target.id, target.copyWith(name: 'Renamed')),
      isTrue,
    );

    expect(provider.count, maxGeofenceLocations);
    expect(provider.locations.first.name, 'Renamed');
  });

  test('persists changes across provider instances', () async {
    final preferences = await SharedPreferences.getInstance();
    final provider = GeofenceProvider(preferences);
    final target = provider.locations.first;

    provider.updateLocation(target.id, target.copyWith(name: 'Saved Spot'));
    await Future<void>.delayed(Duration.zero);

    final reloaded = GeofenceProvider(preferences);
    expect(reloaded.locations.first.name, 'Saved Spot');
  });

  test('respects a saved empty list instead of reseeding defaults', () async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(GeofenceProvider.storageKey, '[]');

    final provider = GeofenceProvider(preferences);

    expect(provider.locations, isEmpty);
    expect(provider.isFull, isFalse);
  });

  test('trims oversized saved lists to the maximum', () async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = List.generate(
      7,
      (index) => extraLandmark
          .copyWith(id: 'extra_$index', name: 'Extra $index')
          .toJson(),
    );
    await preferences.setString(
      GeofenceProvider.storageKey,
      jsonEncode(encoded),
    );

    final provider = GeofenceProvider(preferences);

    expect(provider.locations, hasLength(maxGeofenceLocations));
  });

  test('serializes and restores a location', () {
    final original = defaultGeofenceLandmarks.first;

    final restored = CustomLandmark.fromJson(original.toJson());

    expect(restored.id, original.id);
    expect(restored.name, original.name);
    expect(restored.category, original.category);
    expect(restored.description, original.description);
    expect(restored.position.latitude, original.position.latitude);
    expect(restored.position.longitude, original.position.longitude);
    expect(restored.radiusMeters, original.radiusMeters);
    expect(restored.icon.codePoint, original.icon.codePoint);
    expect(restored.color.toARGB32(), original.color.toARGB32());
  });
}
