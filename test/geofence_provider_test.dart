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

  Future<GeofenceProvider> createProvider({
    SharedPreferences? preferences,
  }) async {
    final provider = GeofenceProvider(preferences: preferences);
    await provider.ready;
    return provider;
  }

  const extraLandmark = CustomLandmark(
    id: 'extra',
    name: 'New Hideout',
    address: 'Purok 7, Del Monte, Talacogon',
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

  test('seeds the exact Del Monte default layout and saves it', () async {
    final provider = await createProvider();

    expect(provider.locations.map((location) => location.name), [
      "Ciloy's Home",
      "Ivy's Home",
      'Tindahans mga Chuy',
      'Kalye58 Tamabayanan',
      'Malihao Spot',
    ]);
    expect(provider.locations.map((location) => location.radiusMeters), [
      60,
      60,
      60,
      40,
      60,
    ]);

    final pinned = provider.locations
        .where((location) => location.isPinned)
        .toList();
    expect(pinned, hasLength(1));
    expect(pinned.single.name, 'Tindahans mga Chuy');

    final preferences = await SharedPreferences.getInstance();
    final stored = preferences.getString(GeofenceProvider.storageKey);
    expect(stored, isNotNull);
    expect((jsonDecode(stored!) as List<dynamic>), hasLength(5));
  });

  test(
    'migrates the old placeholder defaults to the Del Monte layout',
    () async {
      final preferences = await SharedPreferences.getInstance();
      final legacyDefaults = [
        {'id': 'residence', 'name': "Ciloy's Residence"},
        {'id': 'boardwalk', 'name': 'Hidden Riverbank Boardwalk'},
        {'id': 'sunrise_hill', 'name': 'Del Monte Sunrise Hill'},
        {'id': 'banyan', 'name': 'Old Banyan Tree'},
        {'id': 'lagoon', 'name': 'Secret Fish Pond'},
      ];
      await preferences.setString(
        GeofenceProvider.storageKey,
        jsonEncode(legacyDefaults),
      );

      final provider = await createProvider(preferences: preferences);

      expect(provider.locations.first.name, "Ciloy's Home");
      expect(provider.locations.last.name, 'Malihao Spot');
      expect(
        preferences.getInt(GeofenceProvider.defaultsVersionKey),
        GeofenceProvider.defaultsVersion,
      );
    },
  );

  test('rejects adding a sixth location', () async {
    final provider = await createProvider();

    final added = await provider.addLocation(extraLandmark);

    expect(added, isFalse);
    expect(provider.count, maxGeofenceLocations);
  });

  test('can add after removing a location', () async {
    final provider = await createProvider();
    final removed = provider.locations.first;

    expect(await provider.removeLocation(removed.id), isTrue);
    expect(provider.isFull, isFalse);
    expect(await provider.addLocation(extraLandmark), isTrue);
    expect(provider.count, maxGeofenceLocations);
    expect(provider.locations.last.name, extraLandmark.name);
  });

  test('replace swaps an existing location and keeps the id', () async {
    final provider = await createProvider();
    final target = provider.locations.first;

    expect(await provider.replaceLocation(target.id, extraLandmark), isTrue);

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
      await provider.updateLocation(
        target.id,
        target.copyWith(name: 'Renamed'),
      ),
      isTrue,
    );

    expect(provider.count, maxGeofenceLocations);
    expect(provider.locations.first.name, 'Renamed');
  });

  test('saves last pinned latitude, longitude, and address on add', () async {
    final provider = await createProvider();
    await provider.removeLocation(provider.locations.first.id);

    expect(await provider.addLocation(extraLandmark), isTrue);

    final lastPinned = provider.lastPinnedLocation;
    expect(lastPinned, isNotNull);
    expect(lastPinned!.latitude, extraLandmark.position.latitude);
    expect(lastPinned.longitude, extraLandmark.position.longitude);
    expect(lastPinned.address, extraLandmark.address);
  });

  test('updates the saved last pinned location when editing', () async {
    final provider = await createProvider();
    final target = provider.locations.first;
    final updated = target.copyWith(
      name: 'Edited Spot',
      address: 'New Address, Del Monte',
      position: const LatLng(8.5, 125.85),
    );

    expect(await provider.updateLocation(target.id, updated), isTrue);

    final lastPinned = provider.lastPinnedLocation;
    expect(lastPinned, isNotNull);
    expect(lastPinned!.latitude, updated.position.latitude);
    expect(lastPinned.longitude, updated.position.longitude);
    expect(lastPinned.address, updated.address);
  });

  test('persists changes and last pinned location across instances', () async {
    final preferences = await SharedPreferences.getInstance();
    final provider = await createProvider(preferences: preferences);
    final target = provider.locations.first;
    final updated = target.copyWith(
      name: 'Saved Spot',
      address: '123 Saved Street, Del Monte',
      position: const LatLng(8.51, 125.86),
    );

    await provider.updateLocation(target.id, updated);

    expect(
      preferences.getDouble(GeofenceProvider.lastLatitudeKey),
      updated.position.latitude,
    );
    expect(
      preferences.getDouble(GeofenceProvider.lastLongitudeKey),
      updated.position.longitude,
    );
    expect(
      preferences.getString(GeofenceProvider.lastAddressKey),
      updated.address,
    );

    final reloaded = await createProvider(preferences: preferences);
    expect(reloaded.locations.first.name, 'Saved Spot');
    expect(reloaded.lastPinnedLocation, isNotNull);
    expect(reloaded.lastPinnedLocation!.latitude, updated.position.latitude);
    expect(reloaded.lastPinnedLocation!.longitude, updated.position.longitude);
    expect(reloaded.lastPinnedLocation!.address, updated.address);
  });

  test('persists pin status with the saved list', () async {
    final preferences = await SharedPreferences.getInstance();
    final provider = await createProvider(preferences: preferences);
    await provider.removeLocation(provider.locations.first.id);
    await provider.addLocation(extraLandmark);

    final encoded =
        jsonDecode(preferences.getString(GeofenceProvider.storageKey)!)
            as List<dynamic>;
    final saved = encoded.whereType<Map>().firstWhere(
      (entry) => entry['id'] == 'extra',
    );
    expect(saved['isPinned'], isTrue);
    expect(
      provider.locations.where((location) => location.isPinned),
      hasLength(1),
    );

    final reloaded = await createProvider(preferences: preferences);
    final extra = reloaded.locations.firstWhere(
      (location) => location.id == 'extra',
    );
    expect(extra.isPinned, isTrue);
    expect(
      reloaded.locations.where((location) => location.isPinned),
      hasLength(1),
    );
  });

  test('respects a saved empty list instead of reseeding defaults', () async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(GeofenceProvider.storageKey, '[]');

    final provider = await createProvider(preferences: preferences);

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

    final provider = await createProvider(preferences: preferences);

    expect(provider.locations, hasLength(maxGeofenceLocations));
  });

  test('serializes and restores a location', () {
    final original = defaultGeofenceLandmarks.first.copyWith(isPinned: true);

    final restored = CustomLandmark.fromJson(original.toJson());

    expect(restored.id, original.id);
    expect(restored.name, original.name);
    expect(restored.address, original.address);
    expect(restored.category, original.category);
    expect(restored.description, original.description);
    expect(restored.position.latitude, original.position.latitude);
    expect(restored.position.longitude, original.position.longitude);
    expect(restored.radiusMeters, original.radiusMeters);
    expect(restored.icon.codePoint, original.icon.codePoint);
    expect(restored.color.toARGB32(), original.color.toARGB32());
    expect(restored.isPinned, isTrue);
  });
}
