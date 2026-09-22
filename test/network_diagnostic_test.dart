import 'package:flutter_test/flutter_test.dart';
import 'package:portfolio_app/models/network_diagnostic.dart';

NetworkDiagnosticResult _result({
  double idlePingMs = 40,
  double downloadSpeedMbps = 24,
  double uploadSpeedMbps = 12,
  double downloadPingMs = 45,
  double uploadPingMs = 48,
  double packetLossPercent = 0,
}) {
  return NetworkDiagnosticResult(
    idlePingMs: idlePingMs,
    downloadSpeedMbps: downloadSpeedMbps,
    uploadSpeedMbps: uploadSpeedMbps,
    downloadPingMs: downloadPingMs,
    uploadPingMs: uploadPingMs,
    packetLossPercent: packetLossPercent,
    timestamp: DateTime(2026),
  );
}

void main() {
  group('classifyNetworkHealth', () {
    test('maps a fast, low-latency link to excellent', () {
      expect(
        classifyNetworkHealth(_result()),
        NetworkHealthTier.excellent,
      );
    });

    test('maps 2 to 10 Mbps to fair', () {
      expect(
        classifyNetworkHealth(_result(downloadSpeedMbps: 6)),
        NetworkHealthTier.fair,
      );
    });

    test('maps below 2 Mbps to poor', () {
      expect(
        classifyNetworkHealth(_result(downloadSpeedMbps: 1.2)),
        NetworkHealthTier.poor,
      );
    });

    test('maps heavy packet loss to degraded even at high speed', () {
      expect(
        classifyNetworkHealth(_result(packetLossPercent: 22)),
        NetworkHealthTier.degraded,
      );
    });

    test('maps an extreme latency spike to degraded', () {
      expect(
        classifyNetworkHealth(
          _result(downloadPingMs: 2400, uploadPingMs: 600),
        ),
        NetworkHealthTier.degraded,
      );
    });

    test('downgrades a fast link with high latency to fair', () {
      expect(
        classifyNetworkHealth(
          _result(downloadSpeedMbps: 35, downloadPingMs: 450),
        ),
        NetworkHealthTier.fair,
      );
    });

    test('boundary: exactly 10 Mbps stays fair (not excellent)', () {
      expect(
        classifyNetworkHealth(_result(downloadSpeedMbps: 10, idlePingMs: 4)),
        NetworkHealthTier.fair,
      );
    });

    test('boundary: just under 2 Mbps flips to poor', () {
      expect(
        classifyNetworkHealth(_result(downloadSpeedMbps: 1.99)),
        NetworkHealthTier.poor,
      );
    });
  });
}
