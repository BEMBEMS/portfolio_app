import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'browser_connectivity.dart'
    if (dart.library.js_interop) 'browser_connectivity_web.dart' as browser;

enum NetworkType { unknown, none, wifi, mobile, ethernet }

class NetworkStatus {
  final NetworkType type;
  final bool hasInternet;

  const NetworkStatus({required this.type, required this.hasInternet});

  bool get isOnline => hasInternet && type != NetworkType.none;
}

/// Monitors the device's connection state and exposes it as a
/// [ChangeNotifier], with dedicated handling for Flutter Web.
///
/// Behavior by platform:
///  * Web: the browser's `onLine`/`offline`/`connection` events (exposed via
///    [browser.BrowserConnectivity]) provide fast reaction times, while a
///    [Timer] re-checks every [_monitorInterval]. Because `navigator.onLine`
///    is unreliable (Chrome often keeps reporting online right after a Wi-Fi
///    interface drops), the authoritative source is a CORS-safe reachability
///    probe that ALWAYS runs - including while `navigator.onLine` reports
///    online - so disconnected interfaces flip the UI to offline live.
///  * Native: connectivity_plus reports the interface type and a real HTTP
///    ping verifies that the internet is actually reachable.
class NetworkService extends ChangeNotifier {
  /// CORS-enabled endpoints, safe to probe directly from a browser.
  static final List<Uri> _webPingUris = [
    Uri.parse('https://jsonplaceholder.typicode.com/todos/1'),
    Uri.parse('https://httpbin.org/get'),
  ];

  /// Native (non-browser) endpoints - CORS does not apply there.
  static final List<Uri> _nativePingUris = [
    ..._webPingUris,
    Uri.parse('https://connectivitycheck.gstatic.com/generate_204'),
  ];
  static const Duration _pingTimeout = Duration(seconds: 5);
  static const Duration _monitorInterval = Duration(seconds: 5);

  final browser.BrowserConnectivity _browser = browser.BrowserConnectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  StreamSubscription<browser.BrowserNetworkInfo>? _browserSub;
  Timer? _monitorTimer;

  NetworkType _interfaceType = NetworkType.unknown;
  browser.BrowserConnType _browserType = browser.BrowserConnType.unknown;

  bool _running = false;
  bool _checkInProgress = false;
  bool _pendingCheck = false;
  bool _resolved = false;

  NetworkStatus _status =
      const NetworkStatus(type: NetworkType.unknown, hasInternet: false);

  NetworkStatus get status => _status;

  bool get isOnline => _status.isOnline;

  /// True once the first confirmed check has completed, so the UI can show a
  /// neutural "checking" state instead of assuming offline up front.
  bool get isResolved => _resolved;

  void start() {
    if (_running) return;
    _running = true;

    if (kIsWeb) {
      _browserType = _browser.current.type;
      _browserSub = _browser.onChanged.listen((info) {
        _browserType = info.type;
        _scheduleCheck();
      });
    } else {
      _connectivitySub =
          Connectivity().onConnectivityChanged.listen((results) {
        _applyConnectivityResults(results);
        _scheduleCheck();
      });
      Connectivity().checkConnectivity().then((results) {
        if (!_running) return;
        _applyConnectivityResults(results);
        _scheduleCheck();
      });
    }

    _monitorTimer = Timer.periodic(_monitorInterval, (_) => _scheduleCheck());
    _scheduleCheck();
  }

  @override
  void dispose() {
    _running = false;
    _connectivitySub?.cancel();
    _browserSub?.cancel();
    _monitorTimer?.cancel();
    super.dispose();
  }

  void _scheduleCheck() {
    if (!_running) return;
    if (_checkInProgress) {
      _pendingCheck = true;
      return;
    }
    unawaited(_performCheck());
  }

  Future<void> _performCheck() async {
    _checkInProgress = true;
    if (kIsWeb) {
      await _checkWeb();
    } else {
      await _checkNative();
    }
    final pending = _pendingCheck;
    _pendingCheck = false;
    _checkInProgress = false;
    if (pending && _running) {
      _scheduleCheck();
    }
  }

  Future<void> _checkWeb() async {
    // Browser events (onLine/offline/connection/focus) trigger this check, as
    // does the periodic timer. The reachability probe runs unconditionally:
    // navigator.onLine alone is not trustworthy for live interface toggles,
    // so a real CORS-safe probe decides the state every time.
    final reachable = await _pingOk(_webPingUris);
    _publish(NetworkStatus(type: _webType(reachable), hasInternet: reachable));
  }

  Future<void> _checkNative() async {
    final type = _effectiveType;
    final hasInternet =
        type != NetworkType.none ? await _pingOk(_nativePingUris) : false;
    _publish(NetworkStatus(type: type, hasInternet: hasInternet));
  }

  NetworkType _webType(bool hasInternet) {
    if (!hasInternet) return NetworkType.none;
    switch (_browserType) {
      case browser.BrowserConnType.wifi:
        return NetworkType.wifi;
      case browser.BrowserConnType.cellular:
        return NetworkType.mobile;
      case browser.BrowserConnType.ethernet:
        return NetworkType.ethernet;
      case browser.BrowserConnType.none:
      case browser.BrowserConnType.unknown:
        return NetworkType.wifi;
    }
  }

  NetworkType get _effectiveType {
    switch (_browserType) {
      case browser.BrowserConnType.none:
        return NetworkType.none;
      case browser.BrowserConnType.wifi:
        return NetworkType.wifi;
      case browser.BrowserConnType.cellular:
        return NetworkType.mobile;
      case browser.BrowserConnType.ethernet:
        return NetworkType.ethernet;
      case browser.BrowserConnType.unknown:
        break;
    }
    return _interfaceType;
  }

  void _applyConnectivityResults(List<ConnectivityResult> results) {
    for (final result in results) {
      switch (result) {
        case ConnectivityResult.wifi:
          _interfaceType = NetworkType.wifi;
          return;
        case ConnectivityResult.mobile:
          _interfaceType = NetworkType.mobile;
          return;
        case ConnectivityResult.ethernet:
          _interfaceType = NetworkType.ethernet;
          return;
        case ConnectivityResult.none:
        case ConnectivityResult.bluetooth:
        case ConnectivityResult.vpn:
        case ConnectivityResult.satellite:
        case ConnectivityResult.other:
          continue;
      }
    }
    _interfaceType = NetworkType.none;
  }

  /// Best-effort, list-ordered reachability ping. Any HTTP response counts as
  /// "reachable" (connectivity exists). Timeouts/errors for one endpoint just
  /// fall through to the next, and a total failure reports offline cleanly.
  Future<bool> _pingOk(List<Uri> uris) async {
    for (final uri in uris) {
      try {
        final response = await http.get(uri).timeout(_pingTimeout);
        return response.statusCode >= 200;
      } catch (_) {
        // Endpoint unreachable; try the next one.
      }
    }
    return false;
  }

  void _publish(NetworkStatus next) {
    if (!_running) return;
    final wasResolved = _resolved;
    _resolved = true;
    final changed = !wasResolved ||
        _status.type != next.type ||
        _status.hasInternet != next.hasInternet;
    _status = next;
    if (changed) {
      notifyListeners();
    }
  }
}