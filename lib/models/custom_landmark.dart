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
  final String category;
  final String description;
  final LatLng position;
  final double radiusMeters;
  final IconData icon;
  final Color color;

  const CustomLandmark({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.position,
    required this.radiusMeters,
    required this.icon,
    required this.color,
  });

  CustomLandmark copyWith({
    String? id,
    String? name,
    String? category,
    String? description,
    LatLng? position,
    double? radiusMeters,
    IconData? icon,
    Color? color,
  }) {
    return CustomLandmark(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      description: description ?? this.description,
      position: position ?? this.position,
      radiusMeters: radiusMeters ?? this.radiusMeters,
      icon: icon ?? this.icon,
      color: color ?? this.color,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'description': description,
      'latitude': position.latitude,
      'longitude': position.longitude,
      'radiusMeters': radiusMeters,
      'iconCodePoint': icon.codePoint,
      'color': color.toARGB32(),
    };
  }

  factory CustomLandmark.fromJson(Map<String, dynamic> json) {
    final colorValue = (json['color'] as num?)?.toInt() ?? 0xFFF57C00;
    final iconCodePoint =
        (json['iconCodePoint'] as num?)?.toInt() ??
        Icons.place_rounded.codePoint;

    return CustomLandmark(
      id:
          json['id'] as String? ??
          'location_${DateTime.now().microsecondsSinceEpoch}',
      name: json['name'] as String? ?? 'Unnamed Location',
      category: json['category'] as String? ?? 'Custom',
      description: json['description'] as String? ?? '',
      position: LatLng(
        (json['latitude'] as num?)?.toDouble() ?? 0,
        (json['longitude'] as num?)?.toDouble() ?? 0,
      ),
      radiusMeters: (json['radiusMeters'] as num?)?.toDouble() ?? 50,
      icon: geofenceIconCatalog[iconCodePoint] ?? Icons.place_rounded,
      color: Color(colorValue),
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
    id: 'residence',
    name: "Ciloy's Residence",
    category: 'Residence',
    description:
        'A private family home along a quiet lane in Del Monte. This spot is '
        'not pinned on public map services.',
    position: LatLng(8.49070, 125.84285),
    radiusMeters: 55,
    icon: Icons.home_rounded,
    color: Color(0xFFE67E22),
  ),
  CustomLandmark(
    id: 'boardwalk',
    name: 'Hidden Riverbank Boardwalk',
    category: 'Nature',
    description:
        'A short wooden walkway along the Agusan River bank that locals use '
        'early in the morning. Not marked on public maps.',
    position: LatLng(8.48770, 125.84500),
    radiusMeters: 70,
    icon: Icons.forest_rounded,
    color: Color(0xFF2E7D32),
  ),
  CustomLandmark(
    id: 'sunrise_hill',
    name: 'Del Monte Sunrise Hill',
    category: 'Viewpoint',
    description:
        'A grassy ridge overlooking the fields of Del Monte. A favorite secret '
        'spot for watching the sun rise over Agusan del Sur.',
    position: LatLng(8.49330, 125.84560),
    radiusMeters: 80,
    icon: Icons.landscape_rounded,
    color: Color(0xFFF9A825),
  ),
  CustomLandmark(
    id: 'banyan',
    name: 'Old Banyan Tree',
    category: 'Heritage',
    description:
        'A century-old balete tree where neighbors gather in the afternoon '
        'shade. Its exact location is only known to locals.',
    position: LatLng(8.48840, 125.84070),
    radiusMeters: 50,
    icon: Icons.park_rounded,
    color: Color(0xFF6D4C41),
  ),
  CustomLandmark(
    id: 'lagoon',
    name: 'Secret Fish Pond',
    category: 'Hidden Spot',
    description:
        'A small fish pond tucked behind the rice fields. Reachable on foot '
        'through a narrow trail at the edge of the barangay.',
    position: LatLng(8.48630, 125.84600),
    radiusMeters: 65,
    icon: Icons.water_rounded,
    color: Color(0xFF0277BD),
  ),
];

const Distance _distanceCalculator = Distance(roundResult: false);

double distanceInMeters(LatLng from, LatLng to) {
  return _distanceCalculator.as(LengthUnit.Meter, from, to);
}
