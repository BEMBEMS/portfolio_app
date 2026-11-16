import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/network_diagnostic.dart';
import '../services/network_diagnostic_service.dart';

/// Lifecycle of the most recent diagnostic run.
enum DiagnosticStatus { idle, running, succeeded, failed }

/// Immutable state exposed by [networkHealthProvider].
class NetworkDiagnosticState {
  final DiagnosticStatus status;
  final NetworkDiagnosticResult? result;
  final NetworkHealthTier tier;
  final NetworkDiagnosticStage? stage;
  final String? errorMessage;

  const NetworkDiagnosticState({
    this.status = DiagnosticStatus.idle,
    this.result,
    this.tier = NetworkHealthTier.fair,
    this.stage,
    this.errorMessage,
  });

  const NetworkDiagnosticState.initial() : this();

  NetworkDiagnosticState.running([this.stage])
      : status = DiagnosticStatus.running,
        result = null,
        tier = NetworkHealthTier.fair,
        errorMessage = null;

  NetworkDiagnosticState.succeeded(NetworkDiagnosticResult value)
      : status = DiagnosticStatus.succeeded,
        result = value,
        tier = classifyNetworkHealth(value),
        stage = null,
        errorMessage = null;

  NetworkDiagnosticState.failed(
    String message, {
    required NetworkHealthTier fallbackTier,
  })  : status = DiagnosticStatus.failed,
        result = null,
        tier = fallbackTier,
        stage = null,
        errorMessage = message;

  bool get isRunning => status == DiagnosticStatus.running;
  bool get hasResult => result != null;
}

/// Holds the global network health and runs full diagnostics on demand.
/// Any widget can watch [networkHealthProvider] to react to the current
/// [NetworkHealthTier] (e.g. swapping media quality).
class NetworkDiagnosticNotifier extends Notifier<NetworkDiagnosticState> {
  final NetworkDiagnosticService _service = NetworkDiagnosticService();

  @override
  NetworkDiagnosticState build() => const NetworkDiagnosticState.initial();

  Future<void> runTest() async {
    if (state.isRunning) return;
    state = NetworkDiagnosticState.running();

    try {
      final result = await _service.runFullDiagnostic(
        onStage: (stage) {
          if (state.isRunning) {
            state = NetworkDiagnosticState.running(stage);
          }
        },
      );
      state = NetworkDiagnosticState.succeeded(result);
    } catch (error) {
      state = NetworkDiagnosticState.failed(
        '$error',
        fallbackTier: NetworkHealthTier.degraded,
      );
    }
  }
}

/// Global providers. Watch [networkHealthProvider] anywhere to read the
/// current tier and the raw metrics of the last run.
final networkHealthProvider = NotifierProvider<NetworkDiagnosticNotifier,
    NetworkDiagnosticState>(NetworkDiagnosticNotifier.new);