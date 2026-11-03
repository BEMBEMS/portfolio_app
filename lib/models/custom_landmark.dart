import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

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
}

class DelMonteMapConfig {
  static const LatLng center = LatLng(8.4896545, 125.8431692);
  static const LatLng defaultUserLocation = LatLng(8.4894, 125.8431);
  static const double defaultZoom = 15.8;
  static const double minZoom = 13;
  static const double maxZoom = 19;
}

const List<CustomLandmark> delMonteLandmarks = [
  CustomLandmark(
    id: 'residence',
    name: "Carlo's Residence",
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
  CustomLandmark(
    id: 'court',
    name: 'Barangay Basketball Court',
    category: 'Community',
    description:
        'The neighborhood court and covered hall where weekend games and '
        'community events happen.',
    position: LatLng(8.49180, 125.84140),
    radiusMeters: 60,
    icon: Icons.sports_basketball_rounded,
    color: Color(0xFF8E24AA),
  ),
];

const Distance _distanceCalculator = Distance(roundResult: false);

double distanceInMeters(LatLng from, LatLng to) {
  return _distanceCalculator.as(LengthUnit.Meter, from, to);
}
