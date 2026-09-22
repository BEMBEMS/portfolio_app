import 'dart:math' as math;

/// Overall health of the connection, derived from the latest diagnostic run.
enum NetworkHealthTier {
  excellent,
  fair,
  poor,
  degraded;

  String get label {
    switch (this) {
      case NetworkHealthTier.excellent:
        return 'Excellent';
      case NetworkHealthTier.fair:
        return 'Fair';
      case NetworkHealthTier.poor:
        return 'Poor';
      case NetworkHealthTier.degraded:
        return 'Degraded';
    }
  }
}

/// Immutable snapshot of a completed diagnostic run.
class NetworkDiagnosticResult {
  final double idlePingMs;
  final double downloadSpeedMbps;
  final double uploadSpeedMbps;
  final double downloadPingMs;
  final double uploadPingMs;
  final double packetLossPercent;
  final DateTime timestamp;

  const NetworkDiagnosticResult({
    required this.idlePingMs,
    required this.downloadSpeedMbps,
    required this.uploadSpeedMbps,
    required this.downloadPingMs,
    required this.uploadPingMs,
    required this.packetLossPercent,
    required this.timestamp,
  });
}

/// Speed threshold for the [NetworkHealthTier.excellent] tier.
const double excellentMinMbps = 10.0;

/// Speed threshold for the [NetworkHealthTier.fair] tier.
const double fairMinMbps = 2.0;

/// Latency above which a fast link is still only considered fair.
const double highLatencyMs = 250.0;

/// Latency above which the link is considered [NetworkHealthTier.degraded].
const double degradedLatencyMs = 1000.0;

/// Packet loss above which the link is considered [NetworkHealthTier.degraded].
const double degradedPacketLossPercent = 20.0;

/// Pure, dependency-free classifier mapping raw diagnostics to a health tier.
///
/// * Degraded: heavy packet loss or extreme latency spikes anywhere in the run.
/// * Excellent: >10 Mbps download with low latency and no meaningful loss.
/// * Poor: under 2 Mbps.
/// * Fair: everything in between.
NetworkHealthTier classifyNetworkHealth(NetworkDiagnosticResult result) {
  final highestTransferPing =
      math.max(result.downloadPingMs, result.uploadPingMs);
  final maxPingMs =
      highestTransferPing.isFinite ? highestTransferPing : result.idlePingMs;
  final loss = result.packetLossPercent;

  if (loss >= degradedPacketLossPercent || maxPingMs >= degradedLatencyMs) {
    return NetworkHealthTier.degraded;
  }
  if (result.downloadSpeedMbps > excellentMinMbps &&
      maxPingMs <= highLatencyMs) {
    return NetworkHealthTier.excellent;
  }
  if (result.downloadSpeedMbps >= fairMinMbps) {
    return NetworkHealthTier.fair;
  }
  return NetworkHealthTier.poor;
}