import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

const int maxGeofenceLocations = 5;

final Map<int, IconData> geofenceIconCatalog = {
  Icons.place_rounded.codePoint: Icons.place_rounded,
  Icons.home_rounded.codePoint: Icons.home_rounded,
  Icons.work_rounded.codePoint: Icons.work_rounded,
  Icons.school_rounded.codePoint: Icons.school_rounded,
  Icons.forest_rounded.codePoint: Icons.forest_rounded,
  Icons.park_rounded.codePoint: Icons.park_rounded,
  Icons.water_rounded.codePoint: Icons.water_rounded,
  Icons.landscape_rounded.codePoint: Icons.landscape_rounded,
  Icons.sports_basketball_rounded.codePoint: Icons.sports_basketball_rounded,
  Icons.shopping_bag_rounded.codePoint: Icons.shopping_bag_rounded,
  Icons.local_hospital_rounded.codePoint: Icons.local_hospital_rounded,
  Icons.restaurant_rounded.codePoint: Icons.restaurant_rounded,
  Icons.star_rounded.codePoint: Icons.star_rounded,
  Icons.favorite_rounded.codePoint: Icons.favorite_rounded,
  Icons.flag_rounded.codePoint: Icons.flag_rounded,
  Icons.bolt_rounded.codePoint: Icons.bolt_rounded,
};

class CustomLandmark {
  final String id;
  final String name;
  final String address;
  final String category;
  final String description;
  final LatLng position;
  final double radiusMeters;
  final IconData icon;
  final Color color;
  final bool isPinned;
  final String? imagePath;

  const CustomLandmark({
    required this.id,
    required this.name,
    this.address = '',
    required this.category,
    required this.description,
    required this.position,
    required this.radiusMeters,
    required this.icon,
    required this.color,
    this.isPinned = false,
    this.imagePath,
  });

  String get displayAddress => address.trim().isEmpty ? name : address;

  bool get hasImage => imagePath != null && imagePath!.trim().isNotEmpty;

  CustomLandmark copyWith({
    String? id,
    String? name,
    String? address,
    String? category,
    String? description,
    LatLng? position,
    double? radiusMeters,
    IconData? icon,
    Color? color,
    bool? isPinned,
    String? imagePath,
  }) {
    return CustomLandmark(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      category: category ?? this.category,
      description: description ?? this.description,
      position: position ?? this.position,
      radiusMeters: radiusMeters ?? this.radiusMeters,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      isPinned: isPinned ?? this.isPinned,
      imagePath: imagePath ?? this.imagePath,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'category': category,
      'description': description,
      'latitude': position.latitude,
      'longitude': position.longitude,
      'radiusMeters': radiusMeters,
      'iconCodePoint': icon.codePoint,
      'color': color.toARGB32(),
      'isPinned': isPinned,
      'imagePath': imagePath,
    };
  }

  factory CustomLandmark.fromJson(Map<String, dynamic> json) {
    final colorValue = (json['color'] as num?)?.toInt() ?? 0xFFF57C00;
    final iconCodePoint =
        (json['iconCodePoint'] as num?)?.toInt() ??
        Icons.place_rounded.codePoint;
    final name = json['name'] as String? ?? 'Unnamed Location';

    return CustomLandmark(
      id:
          json['id'] as String? ??
          'location_${DateTime.now().microsecondsSinceEpoch}',
      name: name,
      address: json['address'] as String? ?? '',
      category: json['category'] as String? ?? 'Custom',
      description: json['description'] as String? ?? '',
      position: LatLng(
        (json['latitude'] as num?)?.toDouble() ?? 0,
        (json['longitude'] as num?)?.toDouble() ?? 0,
      ),
      radiusMeters: (json['radiusMeters'] as num?)?.toDouble() ?? 50,
      icon: geofenceIconCatalog[iconCodePoint] ?? Icons.place_rounded,
      color: Color(colorValue),
      isPinned: json['isPinned'] as bool? ?? false,
      imagePath: (json['imagePath'] as String?)?.trim().isEmpty ?? true
          ? null
          : (json['imagePath'] as String).trim(),
    );
  }
}

/// The most recently pinned or edited geofence location. Persisted separately
/// so the app can restore the user's last location on startup.
class PinnedGeofenceLocation {
  final double latitude;
  final double longitude;
  final String address;

  const PinnedGeofenceLocation({
    required this.latitude,
    required this.longitude,
    required this.address,
  });

  LatLng get position => LatLng(latitude, longitude);

  factory PinnedGeofenceLocation.fromLandmark(CustomLandmark landmark) {
    return PinnedGeofenceLocation(
      latitude: landmark.position.latitude,
      longitude: landmark.position.longitude,
      address: landmark.displayAddress,
    );
  }
}

class DelMonteMapConfig {
  static const LatLng center = LatLng(8.4896545, 125.8431692);
  static const LatLng defaultUserLocation = LatLng(8.4894, 125.8431);
  static const double defaultZoom = 15.8;
  static const double minZoom = 13;
  static const double maxZoom = 19;
}

const List<CustomLandmark> defaultGeofenceLandmarks = [
  CustomLandmark(
    id: 'ciloys_home',
    name: "Ciloy's Home",
    address: 'Bah-bah - Talacogon Road, Purok 5, Del Monte, Talacogon',
    category: 'Home',
    description:
        "Ciloy's family home on the right side of Bah-bah - Talacogon Road, "
        'north-east of Purok 5.',
    position: LatLng(8.49275, 125.84400),
    radiusMeters: 60,
    icon: Icons.home_rounded,
    color: Color(0xFFE67E22),
  ),
  CustomLandmark(
    id: 'ivys_home',
    name: "Ivy's Home",
    address: 'Bah-bah - Talacogon Road, Purok 5, Del Monte, Talacogon',
    category: 'Home',
    description:
        "Ivy's family home on the left side of Bah-bah - Talacogon Road, "
        'north-west of Purok 5.',
    position: LatLng(8.49275, 125.84310),
    radiusMeters: 60,
    icon: Icons.home_rounded,
    color: Color(0xFF8E24AA),
  ),
  CustomLandmark(
    id: 'tindahans_mga_chuy',
    name: 'Tindahans mga Chuy',
    address: 'Pisaan-Del Monte Road, Purok 5, Del Monte, Talacogon',
    category: 'Store',
    description:
        'A neighborhood store on Pisaan-Del Monte Road near the '
        'Bah-bah - Talacogon Road junction. Pinned by default.',
    position: LatLng(8.49015, 125.84213),
    radiusMeters: 60,
    icon: Icons.restaurant_rounded,
    color: Color(0xFF43A047),
    isPinned: true,
  ),
  CustomLandmark(
    id: 'kalye58_tamabayanan',
    name: 'Kalye58 Tamabayanan',
    address: 'Pisaan-Del Monte Road (CENRO), Purok 5, Del Monte, Talacogon',
    category: 'Tambayanan',
    description:
        'A tambayanan on Pisaan-Del Monte Road, right at the Community '
        'Environment and Natural Resources Office (CENRO).',
    position: LatLng(8.4892661, 125.8437722),
    radiusMeters: 40,
    icon: Icons.star_rounded,
    color: Color(0xFFF9A825),
  ),
  CustomLandmark(
    id: 'malihao_spot',
    name: 'Malihao Spot',
    address: 'Malihao Road, Purok 8, Del Monte, Talacogon',
    category: 'Water Spot',
    description:
        'A water spot south of Purok 8 along the road extending from '
        'Pisaan-Del Monte Road.',
    position: LatLng(8.48680, 125.84766),
    radiusMeters: 60,
    icon: Icons.water_rounded,
    color: Color(0xFF0277BD),
  ),
];

const Distance _distanceCalculator = Distance(roundResult: false);

double distanceInMeters(LatLng from, LatLng to) {
  return _distanceCalculator.as(LengthUnit.Meter, from, to);
}
