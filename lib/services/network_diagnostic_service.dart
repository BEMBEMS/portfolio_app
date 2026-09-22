import 'dart:async';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../models/network_diagnostic.dart';

/// Steps a diagnostic run goes through, reported via the `onStage` callback.
enum NetworkDiagnosticStage { idlePing, download, upload }

/// Thrown when any step of a diagnostic run cannot complete.
class NetworkDiagnosticException implements Exception {
  final String message;
  const NetworkDiagnosticException(this.message);

  @override
  String toString() => message;
}

/// Runs the full diagnostic sequence:
///
/// 1. Baseline idle ping (average of a few lightweight requests).
/// 2. Download bandwidth while pings are tracked concurrently as the link is
///    saturated by the download.
/// 3. Upload bandwidth while pings are tracked concurrently during the upload.
///
/// Transfers and pings run on the same [http.Client], so real network
/// contention shows up in the concurrently measured pings.
class NetworkDiagnosticService {
  NetworkDiagnosticService({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  /// CORS-enabled endpoints usable from both native and Flutter Web.
  static final List<Uri> _pingUris = [
    Uri.parse('https://jsonplaceholder.typicode.com/todos/1'),
    Uri.parse('https://connectivitycheck.gstatic.com/generate_204'),
    Uri.parse('https://httpbin.org/get'),
  ];

  static final Uri _downloadUri =
      Uri.parse('https://speed.cloudflare.com/__down?bytes=$downloadBytes');
  static final Uri _uploadUri = Uri.parse('https://speed.cloudflare.com/__up');

  static const int downloadBytes = 5 * 1024 * 1024; // 5 MB
  static const int uploadBytes = 2 * 1024 * 1024; // 2 MB
  static const int idlePingSamples = 3;
  static const Duration pingTimeout = Duration(seconds: 5);
  static const Duration stepTimeout = Duration(seconds: 30);
  static const Duration pingDuringTransferInterval =
      Duration(milliseconds: 300);

  /// Runs the full sequence and collects one [NetworkDiagnosticResult].
  Future<NetworkDiagnosticResult> runFullDiagnostic({
    void Function(NetworkDiagnosticStage stage)? onStage,
  }) async {
    onStage?.call(NetworkDiagnosticStage.idlePing);
    final idle = await _measureIdlePing();

    onStage?.call(NetworkDiagnosticStage.download);
    final download = await _measureDownload();

    onStage?.call(NetworkDiagnosticStage.upload);
    final upload = await _measureUpload();

    final totalAttempts = idle.attempts + download.attempts + upload.attempts;
    final totalFailures = idle.failures + download.failures + upload.failures;
    final packetLossPercent =
        totalAttempts == 0 ? 0.0 : totalFailures / totalAttempts * 100.0;

    return NetworkDiagnosticResult(
      idlePingMs: idle.pingMs,
      downloadSpeedMbps: download.speedMbps,
      uploadSpeedMbps: upload.speedMbps,
      downloadPingMs: download.pingMs,
      uploadPingMs: upload.pingMs,
      packetLossPercent: packetLossPercent,
      timestamp: DateTime.now(),
    );
  }

  /// Single round-trip latency in milliseconds, falling back through the
  /// candidate endpoints until one responds.
  Future<double> _pingOnce() async {
    for (final uri in _pingUris) {
      try {
        final stopwatch = Stopwatch()..start();
        await _client.get(uri).timeout(pingTimeout);
        stopwatch.stop();
        return stopwatch.elapsedMilliseconds.toDouble();
      } on TimeoutException {
        continue;
      } catch (_) {
        continue;
      }
    }
    throw const NetworkDiagnosticException('Ping endpoint unreachable');
  }

  Future<({double pingMs, int attempts, int failures})>
      _measureIdlePing() async {
    final latencies = <double>[];
    var failures = 0;
    for (var i = 0; i < idlePingSamples; i++) {
      try {
        latencies.add(await _pingOnce());
      } catch (_) {
        failures++;
      }
    }
    if (latencies.isEmpty) {
      throw const NetworkDiagnosticException('No ping endpoint reachable');
    }
    return (
      pingMs: _mean(latencies),
      attempts: idlePingSamples,
      failures: failures,
    );
  }

  Future<({double speedMbps, double pingMs, int attempts, int failures})>
      _measureDownload() async {
    final tracker = _TransferPingTracker(_pingOnce);
    tracker.start();
    try {
      final stopwatch = Stopwatch()..start();
      final request = http.Request('GET', _downloadUri);
      final response = await _client.send(request).timeout(stepTimeout);
      if (response.statusCode != 200) {
        throw NetworkDiagnosticException(
          'Download failed (HTTP ${response.statusCode})',
        );
      }
      var receivedBytes = 0;
      await for (final chunk in response.stream.timeout(stepTimeout)) {
        receivedBytes += chunk.length;
      }
      stopwatch.stop();
      return (
        speedMbps: _mbps(receivedBytes, stopwatch.elapsedMilliseconds),
        pingMs: tracker.meanPingMs,
        attempts: tracker.attempts,
        failures: tracker.failures,
      );
    } on TimeoutException {
      throw const NetworkDiagnosticException('Download timed out');
    } finally {
      await tracker.stop();
    }
  }

  Future<({double speedMbps, double pingMs, int attempts, int failures})>
      _measureUpload() async {
    final tracker = _TransferPingTracker(_pingOnce);
    tracker.start();
    try {
      final payload = Uint8List(uploadBytes);
      for (var i = 0; i < payload.length; i++) {
        payload[i] = (i * 31 + 7) & 0xFF;
      }
      final stopwatch = Stopwatch()..start();
      final request = http.Request('POST', _uploadUri)
        ..headers['Content-Type'] = 'application/octet-stream'
        ..bodyBytes = payload;
      final response = await _client.send(request).timeout(stepTimeout);
      if (response.statusCode != 200) {
        throw NetworkDiagnosticException(
          'Upload failed (HTTP ${response.statusCode})',
        );
      }
      await response.stream.drain<void>().timeout(stepTimeout);
      stopwatch.stop();
      return (
        speedMbps: _mbps(uploadBytes, stopwatch.elapsedMilliseconds),
        pingMs: tracker.meanPingMs,
        attempts: tracker.attempts,
        failures: tracker.failures,
      );
    } on TimeoutException {
      throw const NetworkDiagnosticException('Upload timed out');
    } finally {
      await tracker.stop();
    }
  }

  static double _mean(List<double> values) {
    var sum = 0.0;
    for (final value in values) {
      sum += value;
    }
    return sum / values.length;
  }

  static double _mbps(int bytes, int elapsedMilliseconds) {
    if (elapsedMilliseconds <= 0) return 0.0;
    final seconds = elapsedMilliseconds / 1000.0;
    return bytes * 8.0 / seconds / 1000000.0;
  }
}

/// Fires lightweight pings on a timer while a transfer saturates the link,
/// collecting latencies and loss so a ping metric can be reported for the
/// duration of the transfer. Pings never overlap with one another.
class _TransferPingTracker {
  _TransferPingTracker(this._pingOnce);

  final Future<double> Function() _pingOnce;

  Timer? _timer;
  Future<double>? _current;
  bool _inFlight = false;
  int attempts = 0;
  int failures = 0;
  final List<double> _latencies = [];

  double get meanPingMs {
    if (_latencies.isEmpty) return double.nan;
    var sum = 0.0;
    for (final latency in _latencies) {
      sum += latency;
    }
    return sum / _latencies.length;
  }

  void start() {
    _timer = Timer.periodic(
      NetworkDiagnosticService.pingDuringTransferInterval,
      (_) => unawaited(_recordPing()),
    );
    unawaited(_recordPing());
  }

  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    final current = _current;
    if (current != null) {
      try {
        await current;
      } catch (_) {
        // Ignored: the failure was already counted.
      }
    }
  }

  Future<void> _recordPing() async {
    if (_inFlight) return;
    _inFlight = true;
    attempts++;
    final future = _pingOnce();
    _current = future;
    try {
      final latency = await future;
      _latencies.add(latency);
    } catch (_) {
      failures++;
    } finally {
      _inFlight = false;
      _current = null;
    }
  }
}