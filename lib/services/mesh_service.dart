import 'dart:convert';
import 'dart:typed_data';

import 'package:nearby_connections/nearby_connections.dart';

typedef DeviceFoundCallback = void Function(String endpointId, String deviceName);
typedef EndpointCallback = void Function(String endpointId);
typedef ConnectionInitiatedCallback = void Function(
  String endpointId,
  String deviceName,
  bool isIncoming,
);
typedef MessageCallback = void Function(String endpointId, String text);

/// Thin, platform agnostic wrapper around the Google Nearby Connections API.
///
/// All callbacks are plain fields so the state layer ([MeshProvider]) can wire
/// itself up without depending on the plugin types.
class MeshService {
  static const String serviceId = 'com.localmesh.local_mesh_chat';
  static const Strategy strategy = Strategy.P2P_CLUSTER;

  final Nearby _nearby = Nearby();

  DeviceFoundCallback? onDeviceFound;
  EndpointCallback? onDeviceLost;
  ConnectionInitiatedCallback? onConnectionInitiated;
  EndpointCallback? onConnected;
  EndpointCallback? onConnectionFailed;
  EndpointCallback? onDisconnected;
  MessageCallback? onMessageReceived;

  bool isAdvertising = false;
  bool isDiscovering = false;

  Future<void> startAdvertising(String deviceName) async {
    await _nearby.startAdvertising(
      deviceName,
      strategy,
      serviceId: serviceId,
      onConnectionInitiated: _handleConnectionInitiated,
      onConnectionResult: _handleConnectionResult,
      onDisconnected: _handleDisconnected,
    );
    isAdvertising = true;
  }

  Future<void> stopAdvertising() async {
    await _nearby.stopAdvertising();
    isAdvertising = false;
  }

  Future<void> startDiscovery(String deviceName) async {
    await _nearby.startDiscovery(
      deviceName,
      strategy,
      serviceId: serviceId,
      onEndpointFound: (id, name, _) => onDeviceFound?.call(id, name),
      onEndpointLost: (id) {
        if (id != null) onDeviceLost?.call(id);
      },
    );
    isDiscovering = true;
  }

  Future<void> stopDiscovery() async {
    await _nearby.stopDiscovery();
    isDiscovering = false;
  }

  Future<void> requestConnection(String deviceName, String endpointId) async {
    await _nearby.requestConnection(
      deviceName,
      endpointId,
      onConnectionInitiated: _handleConnectionInitiated,
      onConnectionResult: _handleConnectionResult,
      onDisconnected: _handleDisconnected,
    );
  }

  Future<void> acceptConnection(String endpointId) {
    return _nearby.acceptConnection(
      endpointId,
      onPayLoadRecieved: _handlePayload,
    );
  }

  Future<void> rejectConnection(String endpointId) {
    return _nearby.rejectConnection(endpointId);
  }

  Future<void> disconnect(String endpointId) {
    return _nearby.disconnectFromEndpoint(endpointId);
  }

  Future<void> disconnectAll() async {
    await _nearby.stopAllEndpoints();
  }

  Future<void> sendText(String endpointId, String text) {
    return _nearby.sendBytesPayload(
      endpointId,
      Uint8List.fromList(utf8.encode(text)),
    );
  }

  void _handleConnectionInitiated(String endpointId, ConnectionInfo info) {
    onConnectionInitiated?.call(
      endpointId,
      info.endpointName,
      info.isIncomingConnection,
    );
  }

  void _handleConnectionResult(String endpointId, Status status) {
    if (status == Status.CONNECTED) {
      onConnected?.call(endpointId);
    } else {
      onConnectionFailed?.call(endpointId);
    }
  }

  void _handleDisconnected(String endpointId) {
    onDisconnected?.call(endpointId);
  }

  void _handlePayload(String endpointId, Payload payload) {
    if (payload.type != PayloadType.BYTES) return;
    final bytes = payload.bytes;
    if (bytes == null || bytes.isEmpty) return;
    final text = utf8.decode(bytes, allowMalformed: true);
    if (text.isEmpty) return;
    onMessageReceived?.call(endpointId, text);
  }
}
