import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/chat_message.dart';
import '../models/peer_device.dart';
import '../services/mesh_service.dart';
import '../services/permission_service.dart';

/// Single source of truth for devices, connections and chat threads.
///
/// Uses [ChangeNotifier] + `provider` so every widget that watches it is
/// rebuilt as soon as a peer connects, disconnects or a message arrives.
class MeshProvider extends ChangeNotifier {
  MeshProvider() {
    _service.onDeviceFound = _handleDeviceFound;
    _service.onDeviceLost = _handleDeviceLost;
    _service.onConnectionInitiated = _handleConnectionInitiated;
    _service.onConnected = _handleConnected;
    _service.onConnectionFailed = _handleConnectionFailed;
    _service.onDisconnected = _handleDisconnected;
    _service.onMessageReceived = _handleMessageReceived;
  }

  /// Maximum number of simultaneous peers, shown as "x/4 Devices Connected".
  static const int maxDevices = 4;

  final MeshService _service = MeshService();
  final List<PeerDevice> _discovered = <PeerDevice>[];
  final Map<String, PeerDevice> _connected = <String, PeerDevice>{};
  final Map<String, String> _pending = <String, String>{};
  final Map<String, List<ChatMessage>> _threads = <String, List<ChatMessage>>{};

  bool _disposed = false;
  int _idSequence = 0;
  String? _activePeerId;

  bool permissionsGranted = false;
  bool isAdvertising = false;
  bool isDiscovering = false;
  bool isBusy = false;
  String? lastError;

  final String localDeviceName = _resolveDeviceName();

  // ---------------------------------------------------------------- state --

  List<PeerDevice> get discoveredDevices => List<PeerDevice>.unmodifiable(_discovered);

  List<PeerDevice> get connectedDevices =>
      List<PeerDevice>.unmodifiable(_connected.values);

  int get connectedCount => connectedDevices.length;

  bool get isConnected => connectedCount > 0;

  bool get isScanning => isDiscovering;

  PeerDevice? get activePeer =>
      _activePeerId == null ? null : _connected[_activePeerId];

  List<ChatMessage> get activeMessages {
    final id = _activePeerId;
    if (id == null) return const <ChatMessage>[];
    return List<ChatMessage>.unmodifiable(_threads[id] ?? const <ChatMessage>[]);
  }

  List<PeerDevice> get chatCandidates => connectedDevices;

  // ------------------------------------------------------------- lifecycle --

  Future<void> bootstrap() async {
    permissionsGranted = await PermissionService.ensureMeshPermissions();
    _notify();
  }

  Future<void> requestPermissions() async {
    permissionsGranted = await PermissionService.ensureMeshPermissions();
    _notify();
  }

  void clearError() {
    if (lastError == null) return;
    lastError = null;
    _notify();
  }

  // -------------------------------------------------------------- actions --

  Future<void> toggleVisibility() async {
    await _run(() async {
      if (isAdvertising) {
        await _service.stopAdvertising();
        isAdvertising = false;
      } else {
        await _ensurePermissions();
        await _service.startAdvertising(localDeviceName);
        isAdvertising = true;
      }
    });
  }

  Future<void> findNearbyDevices() async {
    await _run(() async {
      if (isDiscovering) {
        await _service.stopDiscovery();
        isDiscovering = false;
      } else {
        await _ensurePermissions();
        await _service.startDiscovery(localDeviceName);
        isDiscovering = true;
      }
    });
  }

  Future<void> connectToDevice(PeerDevice device) async {
    if (connectedCount >= maxDevices) {
      lastError = 'Maximum of $maxDevices devices reached.';
      _notify();
      return;
    }
    if (_connected.containsKey(device.id)) {
      selectPeer(device.id);
      return;
    }

    await _run(() async {
      _updateDiscovered(device.copyWith(status: PeerStatus.connecting));
      _pending[device.id] = device.name;
      await _service.requestConnection(localDeviceName, device.id);
    });
  }

  Future<void> disconnectFrom(PeerDevice device) async {
    await _run(() => _service.disconnect(device.id));
  }

  Future<void> disconnectAll() async {
    await _run(() async {
      await _service.disconnectAll();
      _connected.clear();
      _pending.clear();
      _activePeerId = null;
    });
  }

  Future<void> sendMessage(String text) async {
    final peerId = _activePeerId;
    final trimmed = text.trim();
    if (peerId == null || trimmed.isEmpty) return;

    final message = ChatMessage(
      id: _nextId(),
      text: trimmed,
      isMine: true,
      timestamp: DateTime.now(),
      senderName: localDeviceName,
    );

    try {
      await _service.sendText(peerId, trimmed);
    } on Exception {
      lastError = 'Message could not be delivered.';
      _notify();
      return;
    }

    _threadFor(peerId).add(message);
    _notify();
  }

  void selectPeer(String peerId) {
    if (!_connected.containsKey(peerId)) return;
    if (_activePeerId == peerId) return;
    _activePeerId = peerId;
    _notify();
  }

  // ------------------------------------------------------------- internals --

  Future<void> _ensurePermissions() async {
    if (permissionsGranted) return;
    permissionsGranted = await PermissionService.ensureMeshPermissions();
  }

  Future<void> _run(Future<void> Function() action) async {
    isBusy = true;
    _notify();
    try {
      await action();
      lastError = null;
    } on Exception catch (error) {
      lastError = _describe(error);
    } finally {
      isBusy = false;
      _notify();
    }
  }

  String _describe(Object error) {
    final text = error.toString();
    if (text.contains('Location')) {
      return 'Location services are required for nearby discovery.';
    }
    if (text.contains('Bluetooth')) {
      return 'Bluetooth permission or service is unavailable.';
    }
    return 'Nearby connection failed. Please try again.';
  }

  void _handleDeviceFound(String endpointId, String deviceName) {
    if (_connected.containsKey(endpointId) || _pending.containsKey(endpointId)) {
      return;
    }
    final existing = _discovered.where((d) => d.id == endpointId);
    if (existing.isNotEmpty) {
      _updateDiscovered(existing.first.copyWith(lastSeen: DateTime.now()));
      return;
    }
    _discovered.add(
      PeerDevice(
        id: endpointId,
        name: deviceName,
        status: PeerStatus.discovered,
        lastSeen: DateTime.now(),
      ),
    );
    _notify();
  }

  void _handleDeviceLost(String endpointId) {
    final previousLength = _discovered.length;
    _discovered.removeWhere((d) => d.id == endpointId);
    if (_discovered.length != previousLength) _notify();
  }

  void _handleConnectionInitiated(
    String endpointId,
    String deviceName,
    bool isIncoming,
  ) {
    _pending[endpointId] = deviceName;

    if (connectedCount >= maxDevices) {
      _pending.remove(endpointId);
      lastError = 'Maximum of $maxDevices devices reached, request rejected.';
      _service.rejectConnection(endpointId);
      _notify();
      return;
    }

    _service.acceptConnection(endpointId);
  }

  void _handleConnected(String endpointId) {
    final name = _pending.remove(endpointId) ??
        _discovered.where((d) => d.id == endpointId).firstOrNull?.name ??
        'Nearby device';

    _discovered.removeWhere((d) => d.id == endpointId);
    _connected[endpointId] = PeerDevice(
      id: endpointId,
      name: name,
      status: PeerStatus.connected,
      lastSeen: DateTime.now(),
    );
    _threads.putIfAbsent(endpointId, () => <ChatMessage>[]);
    _activePeerId ??= endpointId;

    if (_service.isDiscovering) {
      isDiscovering = false;
      _service.stopDiscovery();
    }
    _notify();
  }

  void _handleConnectionFailed(String endpointId) {
    _pending.remove(endpointId);
    _connected.remove(endpointId);
    _discovered.removeWhere((d) => d.id == endpointId);
    lastError = 'Connection with a nearby device failed.';
    _notify();
  }

  void _handleDisconnected(String endpointId) {
    final wasActive = _activePeerId == endpointId;
    _connected.remove(endpointId);
    _pending.remove(endpointId);
    if (wasActive) {
      _activePeerId = _connected.isNotEmpty ? _connected.keys.first : null;
    }
    _notify();
  }

  void _handleMessageReceived(String endpointId, String text) {
    final name = _connected[endpointId]?.name ?? _pending[endpointId];
    _threadFor(endpointId).add(
      ChatMessage(
        id: _nextId(),
        text: text,
        isMine: false,
        timestamp: DateTime.now(),
        senderName: name,
      ),
    );
    _notify();
  }

  List<ChatMessage> _threadFor(String endpointId) {
    return _threads.putIfAbsent(endpointId, () => <ChatMessage>[]);
  }

  void _updateDiscovered(PeerDevice device) {
    final index = _discovered.indexWhere((d) => d.id == device.id);
    if (index == -1) {
      _discovered.add(device);
    } else {
      _discovered[index] = device;
    }
    _notify();
  }

  String _nextId() => '${DateTime.now().microsecondsSinceEpoch}-${_idSequence++}';

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  static String _resolveDeviceName() {
    try {
      final host = Platform.localHostname;
      if (host.isNotEmpty && host != 'localhost') return host;
    } on Exception {
      // Fall through to the friendly default.
    }
    return 'My Phone';
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
