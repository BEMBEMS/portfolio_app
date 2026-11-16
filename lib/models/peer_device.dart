enum PeerStatus {
  discovered,
  connecting,
  connected,
}

class PeerDevice {
  const PeerDevice({
    required this.id,
    required this.name,
    this.status = PeerStatus.discovered,
    this.lastSeen,
  });

  final String id;
  final String name;
  final PeerStatus status;
  final DateTime? lastSeen;

  bool get isConnected => status == PeerStatus.connected;
  bool get isConnecting => status == PeerStatus.connecting;

  PeerDevice copyWith({
    String? name,
    PeerStatus? status,
    DateTime? lastSeen,
  }) {
    return PeerDevice(
      id: id,
      name: name ?? this.name,
      status: status ?? this.status,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }

  @override
  bool operator ==(Object other) => other is PeerDevice && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'PeerDevice($id, $name, $status)';
}
