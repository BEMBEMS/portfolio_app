import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:provider/provider.dart';

import '../models/custom_landmark.dart';
import '../providers/geofence_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/gradient_background.dart';

class Activity5GeofenceMap extends StatefulWidget {
  const Activity5GeofenceMap({super.key});

  @override
  State<Activity5GeofenceMap> createState() => _Activity5GeofenceMapState();
}

class _Activity5GeofenceMapState extends State<Activity5GeofenceMap>
    with SingleTickerProviderStateMixin {
  static const LatLng _defaultLocation = DelMonteMapConfig.defaultUserLocation;
  static const Duration _simulationTick = Duration(milliseconds: 90);
  static const double _simulationStepMeters = 10;

  static const List<LatLng> _simulationRoute = [
    LatLng(8.49180, 125.84140),
    LatLng(8.49070, 125.84285),
    LatLng(8.48840, 125.84070),
    LatLng(8.48630, 125.84600),
    LatLng(8.48770, 125.84500),
    LatLng(8.49330, 125.84560),
  ];

  late final AnimationController _pulseController;
  final MapController _mapController = MapController();
  final Set<String> _insideIds = <String>{};
  final List<_GeofenceEvent> _events = <_GeofenceEvent>[];

  GeofenceProvider? _geofence;
  bool _hasEvaluated = false;
  bool _addingLocation = false;
  LatLng _userLocation = _defaultLocation;
  Timer? _walkTimer;
  bool _simulating = false;
  bool _suppressMapTap = false;
  int _waypointIndex = 0;
  LatLng? _walkTarget;

  List<CustomLandmark> get _landmarks =>
      _geofence?.locations ?? const <CustomLandmark>[];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = Provider.of<GeofenceProvider>(context, listen: false);
    if (!identical(_geofence, provider)) {
      _geofence?.removeListener(_handleLocationsChanged);
      _geofence = provider;
      _geofence!.addListener(_handleLocationsChanged);
    }
    if (!_hasEvaluated) {
      _hasEvaluated = true;
      _evaluateGeofences(initial: true);
    }
  }

  @override
  void dispose() {
    _geofence?.removeListener(_handleLocationsChanged);
    _walkTimer?.cancel();
    _pulseController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _handleLocationsChanged() {
    if (!mounted) return;
    setState(() {
      final ids = _landmarks.map((landmark) => landmark.id).toSet();
      _insideIds.removeWhere((id) => !ids.contains(id));
      _evaluateGeofences();
    });
  }

  void _evaluateGeofences({bool initial = false}) {
    for (final landmark in _landmarks) {
      final inside =
          distanceInMeters(_userLocation, landmark.position) <=
          landmark.radiusMeters;
      final wasInside = _insideIds.contains(landmark.id);

      if (inside && !wasInside) {
        _insideIds.add(landmark.id);
        if (!initial) _recordEvent(landmark, true);
      } else if (!inside && wasInside) {
        _insideIds.remove(landmark.id);
        if (!initial) _recordEvent(landmark, false);
      }
    }
  }

  void _recordEvent(CustomLandmark landmark, bool entered) {
    _events.insert(
      0,
      _GeofenceEvent(
        landmark: landmark,
        entered: entered,
        time: DateTime.now(),
      ),
    );
    if (_events.length > 8) {
      _events.removeRange(8, _events.length);
    }
  }

  void _setUserLocation(LatLng point) {
    setState(() {
      _walkTimer?.cancel();
      _simulating = false;
      _walkTarget = null;
      _userLocation = point;
      _evaluateGeofences();
    });
  }

  void _handleMapTap(TapPosition tapPosition, LatLng point) {
    if (_suppressMapTap) return;
    if (_addingLocation) {
      _openLocationForm(position: point);
      return;
    }
    _setUserLocation(point);
  }

  void _markMarkerTapped() {
    _suppressMapTap = true;
    Future<void>.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _suppressMapTap = false;
    });
  }

  void _reset() {
    _walkTimer?.cancel();
    _mapController.move(
      DelMonteMapConfig.center,
      DelMonteMapConfig.defaultZoom,
    );
    setState(() {
      _simulating = false;
      _walkTarget = null;
      _waypointIndex = 0;
      _userLocation = _defaultLocation;
      _insideIds.clear();
      _events.clear();
      _evaluateGeofences(initial: true);
    });
  }

  void _toggleSimulation() {
    if (_simulating) {
      _walkTimer?.cancel();
      setState(() => _simulating = false);
      return;
    }

    _mapController.move(
      DelMonteMapConfig.center,
      DelMonteMapConfig.defaultZoom,
    );
    _waypointIndex = 0;
    _walkTarget = _simulationRoute.first;
    _walkTimer?.cancel();
    setState(() => _simulating = true);
    _walkTimer = Timer.periodic(_simulationTick, (_) => _advanceSimulation());
  }

  void _advanceSimulation() {
    if (!mounted || !_simulating) return;
    final target = _walkTarget;
    if (target == null) return;

    final distance = distanceInMeters(_userLocation, target);
    if (distance <= 6) {
      _waypointIndex++;
      if (_waypointIndex >= _simulationRoute.length) {
        _walkTimer?.cancel();
        setState(() {
          _simulating = false;
          _walkTarget = null;
        });
        return;
      }
      setState(() => _walkTarget = _simulationRoute[_waypointIndex]);
      return;
    }

    final fraction = (_simulationStepMeters / distance)
        .clamp(0.0, 1.0)
        .toDouble();
    final next = LatLng(
      _userLocation.latitude +
          (target.latitude - _userLocation.latitude) * fraction,
      _userLocation.longitude +
          (target.longitude - _userLocation.longitude) * fraction,
    );

    setState(() {
      _userLocation = next;
      _evaluateGeofences();
    });
  }

  CustomLandmark? _nearestLandmark() {
    final locations = _landmarks;
    if (locations.isEmpty) return null;
    var nearest = locations.first;
    var bestDistance = distanceInMeters(_userLocation, nearest.position);
    for (final landmark in locations.skip(1)) {
      final distance = distanceInMeters(_userLocation, landmark.position);
      if (distance < bestDistance) {
        nearest = landmark;
        bestDistance = distance;
      }
    }
    return nearest;
  }

  void _recenterOnUser() {
    _mapController.move(_userLocation, _mapController.camera.zoom);
  }

  void _startAddLocation() {
    setState(() => _addingLocation = true);
    _showSnack('Tap the map to place your new location.');
  }

  void _cancelAddLocation() {
    setState(() => _addingLocation = false);
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openLocationForm({
    CustomLandmark? existing,
    LatLng? position,
  }) async {
    final provider = Provider.of<GeofenceProvider>(context, listen: false);
    setState(() => _addingLocation = false);

    final result = await showModalBottomSheet<CustomLandmark>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _LocationFormSheet(
        existing: existing,
        initialPosition: position ?? existing?.position ?? _userLocation,
        limitReached: existing == null && provider.isFull,
      ),
    );

    if (result == null || !mounted) return;

    if (existing != null) {
      if (provider.updateLocation(existing.id, result)) {
        _mapController.move(result.position, _mapController.camera.zoom);
        _showSnack('${result.name} updated.');
      }
      return;
    }

    if (provider.isFull) {
      await _promptReplaceLocation(result);
      return;
    }

    if (provider.addLocation(result)) {
      _mapController.move(result.position, _mapController.camera.zoom);
      _showSnack('${result.name} added.');
    }
  }

  Future<void> _promptReplaceLocation(CustomLandmark newLocation) async {
    final provider = Provider.of<GeofenceProvider>(context, listen: false);
    if (provider.locations.isEmpty) return;

    final theme = Provider.of<ThemeProvider>(context, listen: false);
    var selectedId = provider.locations.first.id;

    final replacedId = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Location limit reached'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'You can keep up to ${provider.limit} locations. '
                      'Choose one to replace with "${newLocation.name}".',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: theme.secondaryTextColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (final location in provider.locations)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          selectedId == location.id
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          color: selectedId == location.id
                              ? theme.accentColor
                              : theme.mutedTextColor,
                        ),
                        title: Text(
                          location.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(location.category),
                        onTap: () =>
                            setDialogState(() => selectedId = location.id),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(selectedId),
                  child: const Text('Replace'),
                ),
              ],
            );
          },
        );
      },
    );

    if (replacedId == null || !mounted) return;

    final replacedName = provider.locations
        .firstWhere((location) => location.id == replacedId)
        .name;

    if (provider.replaceLocation(replacedId, newLocation)) {
      _mapController.move(newLocation.position, _mapController.camera.zoom);
      _showSnack('${newLocation.name} replaced $replacedName.');
    }
  }

  Future<void> _confirmDeleteLandmark(CustomLandmark landmark) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete location?'),
          content: Text(
            'Remove "${landmark.name}" from your geofences? '
            'This cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFE53935),
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    final provider = Provider.of<GeofenceProvider>(context, listen: false);
    if (provider.removeLocation(landmark.id)) {
      _insideIds.remove(landmark.id);
      _showSnack('${landmark.name} deleted.');
    }
  }

  void _showLandmarkDetails(CustomLandmark landmark) {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    final distance = distanceInMeters(_userLocation, landmark.position);
    final inside = _insideIds.contains(landmark.id);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          decoration: BoxDecoration(
            color: theme.isDarkMode ? const Color(0xFF161616) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.dividerColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: landmark.color.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        landmark.icon,
                        color: landmark.color,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            landmark.name,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: theme.textColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            landmark.category,
                            style: TextStyle(
                              color: landmark.color,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  landmark.description,
                  style: TextStyle(
                    color: theme.secondaryTextColor,
                    height: 1.45,
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _DetailChip(
                      theme: theme,
                      icon: Icons.radio_button_checked,
                      label: '${landmark.radiusMeters.round()} m geofence',
                    ),
                    _DetailChip(
                      theme: theme,
                      icon: Icons.near_me,
                      label: '${distance.round()} m away',
                    ),
                    _DetailChip(
                      theme: theme,
                      icon: inside ? Icons.check_circle : Icons.cancel,
                      label: inside ? 'Inside' : 'Outside',
                      color: inside ? const Color(0xFF43A047) : null,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: landmark.color,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      _mapController.move(
                        landmark.position,
                        _mapController.camera.zoom,
                      );
                      _setUserLocation(landmark.position);
                    },
                    icon: const Icon(Icons.my_location, size: 18),
                    label: const Text('Move my location here'),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: theme.textColor,
                          side: BorderSide(color: theme.borderColor),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () {
                          Navigator.of(sheetContext).pop();
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            _openLocationForm(existing: landmark);
                          });
                        },
                        icon: const Icon(Icons.edit_rounded, size: 18),
                        label: const Text('Edit'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFE53935),
                          side: const BorderSide(color: Color(0xFFE53935)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () {
                          Navigator.of(sheetContext).pop();
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            _confirmDeleteLandmark(landmark);
                          });
                        },
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          size: 18,
                        ),
                        label: const Text('Delete'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final geofence = Provider.of<GeofenceProvider>(context);
    final landmarks = geofence.locations;
    final nearest = _nearestLandmark();
    final active = landmarks
        .where((landmark) => _insideIds.contains(landmark.id))
        .toList();

    return Scaffold(
      extendBodyBehindAppBar: true,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _startAddLocation,
        backgroundColor: theme.accentColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_location_alt_rounded),
        label: const Text('Add Location'),
      ),
      appBar: AppBar(
        title: Text(
          'Geofence Map',
          style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: GradientBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Custom Geofence Map',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: theme.textColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Del Monte, Talacogon, Agusan del Sur \u2022 '
                  '${landmarks.length} of ${geofence.limit} locations',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: theme.secondaryTextColor,
                  ),
                ),
                const SizedBox(height: 16),
                _buildMapCard(theme),
                if (_addingLocation) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: theme.accentColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: theme.accentColor.withValues(alpha: 0.45),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.add_location_alt_rounded,
                          size: 18,
                          color: theme.accentColor,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Tap the map to place your new location.',
                            style: TextStyle(
                              color: theme.textColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: _cancelAddLocation,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            minimumSize: const Size(0, 30),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text('Cancel'),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Text(
                  'Powered by OpenStreetMap \u2022 Tap the map to move your '
                  'tracker, or run the walk simulation. Use Add Location to '
                  'create up to ${geofence.limit} geofences.',
                  style: TextStyle(
                    color: theme.mutedTextColor,
                    fontSize: 11.5,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                _buildActions(theme),
                const SizedBox(height: 16),
                _buildStatusCard(theme, active, nearest),
                const SizedBox(height: 16),
                _buildEventLog(theme),
                const SizedBox(height: 16),
                _buildLandmarkList(theme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMapCard(ThemeProvider theme) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: theme.isDarkMode
                ? const Color(0xFF151515)
                : Colors.white.withValues(alpha: 0.85),
            child: Row(
              children: [
                Icon(Icons.map_rounded, color: theme.accentColor, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Del Monte, Talacogon',
                        style: TextStyle(
                          color: theme.textColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        'OpenStreetMap \u2022 real map tiles',
                        style: TextStyle(
                          color: theme.mutedTextColor,
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: theme.accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_landmarks.length} / $maxGeofenceLocations',
                    style: TextStyle(
                      color: theme.accentColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 430,
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: DelMonteMapConfig.center,
                initialZoom: DelMonteMapConfig.defaultZoom,
                minZoom: DelMonteMapConfig.minZoom,
                maxZoom: DelMonteMapConfig.maxZoom,
                backgroundColor: theme.isDarkMode
                    ? const Color(0xFF151515)
                    : const Color(0xFFE9E2D0),
                onTap: _handleMapTap,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.pair.portfolio_app',
                  maxNativeZoom: 19,
                ),
                CircleLayer(
                  optimizeRadiusInMeters: true,
                  circles: [
                    for (final landmark in _landmarks)
                      CircleMarker(
                        point: landmark.position,
                        radius: landmark.radiusMeters,
                        useRadiusInMeter: true,
                        color: landmark.color.withValues(
                          alpha: _insideIds.contains(landmark.id) ? 0.30 : 0.14,
                        ),
                        borderColor: landmark.color.withValues(
                          alpha: _insideIds.contains(landmark.id) ? 0.95 : 0.55,
                        ),
                        borderStrokeWidth: _insideIds.contains(landmark.id)
                            ? 2.6
                            : 1.4,
                      ),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    for (final landmark in _landmarks)
                      Marker(
                        point: landmark.position,
                        width: 44,
                        height: 50,
                        alignment: Alignment.topCenter,
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: _MapMarker(
                            landmark: landmark,
                            isInside: _insideIds.contains(landmark.id),
                            onTap: () => _showLandmarkDetails(landmark),
                            onTapDown: _markMarkerTapped,
                          ),
                        ),
                      ),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _userLocation,
                      width: 52,
                      height: 52,
                      child: AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          return _UserLocationMarker(
                            pulse: _pulseController.value,
                          );
                        },
                      ),
                    ),
                  ],
                ),
                Scalebar(
                  alignment: Alignment.bottomLeft,
                  textStyle: const TextStyle(
                    color: Color(0xFF263238),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                  lineColor: const Color(0xFF263238),
                  strokeWidth: 2,
                  lineHeight: 4,
                  padding: const EdgeInsets.fromLTRB(12, 0, 0, 34),
                ),
                Positioned(
                  left: 12,
                  top: 12,
                  child: _buildMapChip(
                    theme,
                    _addingLocation
                        ? Icons.add_location_alt_rounded
                        : Icons.touch_app_rounded,
                    _addingLocation ? 'Tap map to place' : 'Tap map to move',
                  ),
                ),
                Positioned(
                  right: 12,
                  top: 12,
                  child: _buildRecenterButton(theme),
                ),
                Positioned(right: 8, bottom: 8, child: _buildAttributionChip()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapChip(ThemeProvider theme, IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: (theme.isDarkMode ? Colors.black : Colors.white).withValues(
          alpha: 0.78,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: theme.accentColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: theme.textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecenterButton(ThemeProvider theme) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: _recenterOnUser,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: (theme.isDarkMode ? Colors.black : Colors.white).withValues(
              alpha: 0.82,
            ),
            border: Border.all(color: theme.borderColor),
          ),
          child: Icon(
            Icons.my_location_rounded,
            size: 18,
            color: theme.accentColor,
          ),
        ),
      ),
    );
  }

  Widget _buildAttributionChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text(
        '\u00A9 OpenStreetMap contributors',
        style: TextStyle(
          color: Color(0xFF263238),
          fontSize: 8,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildActions(ThemeProvider theme) {
    return Row(
      children: [
        Expanded(
          child: _MapActionButton(
            icon: _simulating
                ? Icons.stop_circle_rounded
                : Icons.directions_walk_rounded,
            label: _simulating ? 'Stop Walk' : 'Simulate Walk',
            onPressed: _toggleSimulation,
            filled: true,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MapActionButton(
            icon: Icons.refresh_rounded,
            label: 'Reset',
            onPressed: _reset,
            filled: false,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusCard(
    ThemeProvider theme,
    List<CustomLandmark> active,
    CustomLandmark? nearest,
  ) {
    final insideCount = active.length;
    final statusColor = insideCount > 0
        ? const Color(0xFF43A047)
        : theme.accentColor;
    final nearestDistance = nearest == null
        ? null
        : distanceInMeters(_userLocation, nearest.position);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.textColor.withValues(alpha: 0.10),
            theme.textColor.withValues(alpha: 0.03),
          ],
        ),
        border: Border.all(color: theme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: statusColor.withValues(alpha: 0.16),
                ),
                child: Icon(
                  insideCount > 0
                      ? Icons.shield_rounded
                      : Icons.shield_outlined,
                  color: statusColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Geofence Status',
                      style: TextStyle(
                        color: theme.textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      insideCount > 0
                          ? 'Inside ${active.map((item) => item.name).join(', ')}'
                          : _landmarks.isEmpty
                          ? 'No locations configured'
                          : 'Outside all geofences',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$insideCount INSIDE',
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(color: theme.dividerColor, height: 1),
          const SizedBox(height: 12),
          if (nearest == null)
            Row(
              children: [
                Icon(
                  Icons.add_location_alt_outlined,
                  size: 16,
                  color: theme.mutedTextColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'No locations yet. Add one to start geofencing.',
                    style: TextStyle(
                      color: theme.secondaryTextColor,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                Icon(
                  Icons.near_me_rounded,
                  size: 16,
                  color: theme.mutedTextColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Nearest: ${nearest.name}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: theme.secondaryTextColor,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Text(
                  '${nearestDistance!.round()} m',
                  style: TextStyle(
                    color: theme.textColor,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.gps_fixed_rounded,
                size: 16,
                color: theme.mutedTextColor,
              ),
              const SizedBox(width: 8),
              Text(
                'Lat ${_userLocation.latitude.toStringAsFixed(5)}, '
                'Lng ${_userLocation.longitude.toStringAsFixed(5)}',
                style: TextStyle(color: theme.mutedTextColor, fontSize: 11.5),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEventLog(ThemeProvider theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.textColor.withValues(alpha: 0.10),
            theme.textColor.withValues(alpha: 0.03),
          ],
        ),
        border: Border.all(color: theme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.history_rounded, size: 18, color: theme.accentColor),
              const SizedBox(width: 8),
              Text(
                'Geofence Events',
                style: TextStyle(
                  color: theme.textColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const Spacer(),
              if (_events.isNotEmpty)
                TextButton(
                  onPressed: () => setState(_events.clear),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 30),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'Clear',
                    style: TextStyle(color: theme.mutedTextColor, fontSize: 12),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (_events.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
              decoration: BoxDecoration(
                color: theme.textColor.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: theme.borderColor),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.sensors_rounded,
                    size: 26,
                    color: theme.mutedTextColor,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No events yet. Tap the map or run the walk '
                    'simulation to trigger a geofence.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: theme.mutedTextColor,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            )
          else
            ..._events
                .take(6)
                .map((event) => _EventTile(event: event, theme: theme)),
        ],
      ),
    );
  }

  Widget _buildEmptyLocations(ThemeProvider theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: theme.textColor.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.borderColor),
      ),
      child: Column(
        children: [
          Icon(
            Icons.add_location_alt_outlined,
            size: 30,
            color: theme.mutedTextColor,
          ),
          const SizedBox(height: 8),
          Text(
            'No locations yet',
            style: TextStyle(
              color: theme.textColor,
              fontWeight: FontWeight.w700,
              fontSize: 13.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Create up to $maxGeofenceLocations custom geofences and keep '
            'track of the places that matter.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: theme.mutedTextColor,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _startAddLocation,
            icon: const Icon(Icons.add_location_alt_rounded, size: 18),
            label: const Text('Add Location'),
          ),
        ],
      ),
    );
  }

  Widget _buildLandmarkList(ThemeProvider theme) {
    final landmarks = _landmarks;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'My Locations',
              style: TextStyle(
                color: theme.textColor,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const Spacer(),
            Text(
              '${landmarks.length} / $maxGeofenceLocations',
              style: TextStyle(color: theme.mutedTextColor, fontSize: 12),
            ),
            const SizedBox(width: 4),
            IconButton(
              onPressed: _startAddLocation,
              tooltip: 'Add Location',
              iconSize: 20,
              visualDensity: VisualDensity.compact,
              color: theme.accentColor,
              icon: const Icon(Icons.add_location_alt_rounded),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (landmarks.isEmpty) _buildEmptyLocations(theme),
        ...landmarks.map((landmark) {
          final inside = _insideIds.contains(landmark.id);
          final distance = distanceInMeters(_userLocation, landmark.position);
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _showLandmarkDetails(landmark),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: theme.textColor.withValues(alpha: 0.05),
                    border: Border.all(
                      color: inside
                          ? landmark.color.withValues(alpha: 0.55)
                          : theme.borderColor,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: landmark.color.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          landmark.icon,
                          color: landmark.color,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    landmark.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: theme.textColor,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13.5,
                                    ),
                                  ),
                                ),
                                if (inside) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFF43A047,
                                      ).withValues(alpha: 0.16),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      'INSIDE',
                                      style: TextStyle(
                                        color: Color(0xFF43A047),
                                        fontSize: 8,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${landmark.category} \u2022 '
                              '${landmark.radiusMeters.round()} m radius',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: theme.mutedTextColor,
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${distance.round()} m',
                            style: TextStyle(
                              color: theme.textColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 18,
                            color: theme.mutedTextColor,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _LocationFormSheet extends StatefulWidget {
  final CustomLandmark? existing;
  final LatLng initialPosition;
  final bool limitReached;

  const _LocationFormSheet({
    required this.existing,
    required this.initialPosition,
    required this.limitReached,
  });

  @override
  State<_LocationFormSheet> createState() => _LocationFormSheetState();
}

class _LocationFormSheetState extends State<_LocationFormSheet> {
  static final List<IconData> _iconOptions = geofenceIconCatalog.values.toList(
    growable: false,
  );

  static const List<Color> _colorOptions = [
    Color(0xFFE67E22),
    Color(0xFF2E7D32),
    Color(0xFFF9A825),
    Color(0xFF6D4C41),
    Color(0xFF0277BD),
    Color(0xFF8E24AA),
    Color(0xFFE53935),
    Color(0xFF00897B),
    Color(0xFF3949AB),
    Color(0xFFD81B60),
    Color(0xFF43A047),
    Color(0xFFF4511E),
  ];

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _categoryController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _latitudeController;
  late final TextEditingController _longitudeController;
  late double _radius;
  late IconData _icon;
  late Color _color;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _categoryController = TextEditingController(
      text: existing?.category ?? 'Custom',
    );
    _descriptionController = TextEditingController(
      text: existing?.description ?? '',
    );
    final position = existing?.position ?? widget.initialPosition;
    _latitudeController = TextEditingController(
      text: position.latitude.toStringAsFixed(5),
    );
    _longitudeController = TextEditingController(
      text: position.longitude.toStringAsFixed(5),
    );
    _radius = (existing?.radiusMeters ?? 60).clamp(20, 300).toDouble();
    _icon = existing?.icon ?? _iconOptions.first;
    _color = existing?.color ?? _colorOptions.first;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    _descriptionController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }

  String? _validateRequired(String? value) {
    if (value == null || value.trim().isEmpty) return 'Required';
    return null;
  }

  String? _validateLatitude(String? value) {
    final parsed = double.tryParse(value?.trim() ?? '');
    if (parsed == null) return 'Enter a number';
    if (parsed < -90 || parsed > 90) return 'Must be -90 to 90';
    return null;
  }

  String? _validateLongitude(String? value) {
    final parsed = double.tryParse(value?.trim() ?? '');
    if (parsed == null) return 'Enter a number';
    if (parsed < -180 || parsed > 180) return 'Must be -180 to 180';
    return null;
  }

  void _submit() {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    final existing = widget.existing;
    final category = _categoryController.text.trim();
    final location = CustomLandmark(
      id: existing?.id ?? 'location_${DateTime.now().microsecondsSinceEpoch}',
      name: _nameController.text.trim(),
      category: category.isEmpty ? 'Custom' : category,
      description: _descriptionController.text.trim(),
      position: LatLng(
        double.parse(_latitudeController.text.trim()),
        double.parse(_longitudeController.text.trim()),
      ),
      radiusMeters: _radius,
      icon: _icon,
      color: _color,
    );

    Navigator.of(context).pop(location);
  }

  InputDecoration _decoration(String label, {String? helperText}) {
    return InputDecoration(
      labelText: label,
      helperText: helperText,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      isDense: true,
    );
  }

  Widget _sectionLabel(String text, ThemeProvider theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          color: theme.textColor,
          fontWeight: FontWeight.w700,
          fontSize: 12.5,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final editing = widget.existing != null;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        decoration: BoxDecoration(
          color: theme.isDarkMode ? const Color(0xFF161616) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.dividerColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          editing ? 'Edit Location' : 'New Location',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: theme.textColor,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(
                          Icons.close_rounded,
                          color: theme.mutedTextColor,
                        ),
                      ),
                    ],
                  ),
                  if (!editing) ...[
                    Text(
                      widget.limitReached
                          ? 'You already have $maxGeofenceLocations '
                                'locations. Saving will ask you to replace one.'
                          : 'Customize the pin, then save it to this map.',
                      style: TextStyle(
                        color: widget.limitReached
                            ? theme.accentColor
                            : theme.mutedTextColor,
                        fontSize: 12,
                        height: 1.4,
                        fontWeight: widget.limitReached
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  TextFormField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    decoration: _decoration('Location name'),
                    validator: _validateRequired,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _categoryController,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    decoration: _decoration('Category'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _descriptionController,
                    minLines: 2,
                    maxLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: _decoration('Description'),
                  ),
                  const SizedBox(height: 16),
                  _sectionLabel('Coordinates', theme),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _latitudeController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                            signed: true,
                          ),
                          textInputAction: TextInputAction.next,
                          decoration: _decoration('Latitude'),
                          validator: _validateLatitude,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _longitudeController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                            signed: true,
                          ),
                          decoration: _decoration('Longitude'),
                          validator: _validateLongitude,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _sectionLabel('Geofence radius', theme),
                      const Spacer(),
                      Text(
                        '${_radius.round()} m',
                        style: TextStyle(
                          color: theme.accentColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: _radius,
                    min: 20,
                    max: 300,
                    divisions: 28,
                    label: '${_radius.round()} m',
                    onChanged: (value) => setState(() => _radius = value),
                  ),
                  const SizedBox(height: 8),
                  _sectionLabel('Icon', theme),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final icon in _iconOptions)
                        GestureDetector(
                          onTap: () => setState(() => _icon = icon),
                          child: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: _icon == icon
                                  ? _color
                                  : theme.textColor.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _icon == icon
                                    ? _color
                                    : theme.borderColor,
                              ),
                            ),
                            child: Icon(
                              icon,
                              size: 20,
                              color: _icon == icon
                                  ? Colors.white
                                  : theme.secondaryTextColor,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _sectionLabel('Color', theme),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final color in _colorOptions)
                        GestureDetector(
                          onTap: () => setState(() => _color = color),
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: color,
                              border: Border.all(
                                color: _color == color
                                    ? theme.textColor
                                    : Colors.transparent,
                                width: 2.5,
                              ),
                            ),
                            child: _color == color
                                ? const Icon(
                                    Icons.check_rounded,
                                    size: 18,
                                    color: Colors.white,
                                  )
                                : null,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: theme.accentColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: Icon(
                        editing
                            ? Icons.save_rounded
                            : Icons.add_location_alt_rounded,
                        size: 18,
                      ),
                      label: Text(editing ? 'Save Changes' : 'Add Location'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MapActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool filled;

  const _MapActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.filled,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: filled
                ? theme.accentColor.withValues(alpha: 0.18)
                : theme.textColor.withValues(alpha: 0.06),
            border: Border.all(
              color: filled
                  ? theme.accentColor.withValues(alpha: 0.55)
                  : theme.borderColor,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: filled ? theme.accentColor : theme.textColor,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: filled ? theme.accentColor : theme.textColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapMarker extends StatelessWidget {
  final CustomLandmark landmark;
  final bool isInside;
  final VoidCallback onTap;
  final VoidCallback onTapDown;

  const _MapMarker({
    required this.landmark,
    required this.isInside,
    required this.onTap,
    required this.onTapDown,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => onTapDown(),
      onTap: onTap,
      child: AnimatedScale(
        scale: isInside ? 1.08 : 1.0,
        duration: const Duration(milliseconds: 250),
        child: SizedBox(
          width: 38,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: landmark.color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.95),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: landmark.color.withValues(alpha: 0.45),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(landmark.icon, color: Colors.white, size: 18),
                  ),
                  if (isInside)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        width: 11,
                        height: 11,
                        decoration: BoxDecoration(
                          color: const Color(0xFF43A047),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                      ),
                    ),
                ],
              ),
              CustomPaint(
                size: const Size(10, 7),
                painter: _MarkerTipPainter(color: landmark.color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MarkerTipPainter extends CustomPainter {
  final Color color;

  _MarkerTipPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _MarkerTipPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _UserLocationMarker extends StatelessWidget {
  final double pulse;

  const _UserLocationMarker({required this.pulse});

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFF2196F3);
    final glowSize = 38 + pulse * 12;

    return SizedBox(
      width: 52,
      height: 52,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: glowSize,
            height: glowSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.16 * (1 - pulse) + 0.05),
            ),
          ),
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              border: Border.all(color: Colors.white, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.55),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Icon(
              Icons.navigation_rounded,
              size: 15,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _EventTile extends StatelessWidget {
  final _GeofenceEvent event;
  final ThemeProvider theme;

  const _EventTile({required this.event, required this.theme});

  @override
  Widget build(BuildContext context) {
    final color = event.entered
        ? const Color(0xFF43A047)
        : const Color(0xFFE53935);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.16),
            ),
            child: Icon(
              event.entered ? Icons.login_rounded : Icons.logout_rounded,
              color: color,
              size: 17,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${event.entered ? 'Entered' : 'Exited'} ${event.landmark.name}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: theme.textColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${event.landmark.category} \u2022 ${_formatTime(event.time)}',
                  style: TextStyle(color: theme.mutedTextColor, fontSize: 10.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailChip extends StatelessWidget {
  final ThemeProvider theme;
  final IconData icon;
  final String label;
  final Color? color;

  const _DetailChip({
    required this.theme,
    required this.icon,
    required this.label,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final tint = color ?? theme.secondaryTextColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tint.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: tint),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: tint,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _GeofenceEvent {
  final CustomLandmark landmark;
  final bool entered;
  final DateTime time;

  _GeofenceEvent({
    required this.landmark,
    required this.entered,
    required this.time,
  });
}

String _formatTime(DateTime time) {
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(time.hour)}:${two(time.minute)}:${two(time.second)}';
}
