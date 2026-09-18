import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

enum BrowserConnType { unknown, none, wifi, cellular, ethernet }

class BrowserNetworkInfo {
  final BrowserConnType type;
  const BrowserNetworkInfo(this.type);
}

class BrowserConnectivity {
  static final BrowserConnectivity _instance = BrowserConnectivity._();
  factory BrowserConnectivity() => _instance;

  static const bool isWeb = true;

  final StreamController<BrowserNetworkInfo> _controller =
      StreamController.broadcast();
  late final JSFunction _onlineCallback;
  late final JSFunction _offlineCallback;
  late final JSFunction _changeCallback;
  late final JSFunction _focusCallback;

  static const Duration _reachabilityTimeout = Duration(seconds: 6);

  JSObject get _window => globalContext;

  JSObject? get _navigator =>
      _window.getProperty('navigator'.toJS) as JSObject?;

  JSObject? get _connection {
    final navigator = _navigator;
    if (navigator == null) return null;
    return navigator.getProperty('connection'.toJS) as JSObject?;
  }

  BrowserConnectivity._() {
    // Window-level network events: these fire when the OS interface goes
    // up/down and are read via package:web interop (the JS equivalent of
    // html.window.onOnline / html.window.onOffline).
    _onlineCallback = ((JSAny _) => _emit()).toJS;
    _offlineCallback = ((JSAny _) => _emit()).toJS;
    _focusCallback = ((JSAny _) => _emit()).toJS;
    _window.callMethod(
      'addEventListener'.toJS,
      'online'.toJS,
      _onlineCallback,
    );
    _window.callMethod(
      'addEventListener'.toJS,
      'offline'.toJS,
      _offlineCallback,
    );
    // Re-emit on focus: browsers often only refresh their connectivity
    // awareness once the tab regains focus after an interface toggle.
    _window.callMethod(
      'addEventListener'.toJS,
      'focus'.toJS,
      _focusCallback,
    );
    try {
      final connection = _connection;
      if (connection != null) {
        _changeCallback = ((JSAny _) => _emit()).toJS;
        connection.callMethod(
          'addEventListener'.toJS,
          'change'.toJS,
          _changeCallback,
        );
      }
    } catch (_) {
      // Network Information API not supported by this browser.
    }
  }

  /// Browser-native online state (`window.navigator.onLine`).
  ///
  /// Graceful fallback: if the value cannot be read at all, assume online so
  /// the UI never traps itself in a false offline state.
  bool get isOnLine {
    try {
      final navigator = _navigator;
      final value = navigator?.getProperty('onLine'.toJS)?.dartify();
      if (value == null) return true;
      return value == true;
    } catch (_) {
      return true;
    }
  }

  BrowserNetworkInfo get current {
    final navigator = _navigator;
    if (navigator == null ||
        navigator.getProperty('onLine'.toJS)?.dartify() != true) {
      return const BrowserNetworkInfo(BrowserConnType.none);
    }
    try {
      final connection = _connection;
      if (connection == null) {
        return const BrowserNetworkInfo(BrowserConnType.unknown);
      }
      final type = connection.getProperty('type'.toJS)?.dartify() as String?;
      switch (type) {
        case 'wifi':
          return const BrowserNetworkInfo(BrowserConnType.wifi);
        case 'cellular':
          return const BrowserNetworkInfo(BrowserConnType.cellular);
        case 'ethernet':
          return const BrowserNetworkInfo(BrowserConnType.ethernet);
        case 'none':
          return const BrowserNetworkInfo(BrowserConnType.none);
        default:
          return const BrowserNetworkInfo(BrowserConnType.unknown);
      }
    } catch (_) {
      return const BrowserNetworkInfo(BrowserConnType.unknown);
    }
  }

  Stream<BrowserNetworkInfo> get onChanged => _controller.stream;

  /// Performs an actual internet reachability check that is immune to CORS.
  ///
  /// Uses `fetch` with `mode: 'no-cors'`, so the browser never blocks reading
  /// the response regardless of the target server's CORS policy. The promise
  /// resolves when the network request completes (i.e. there really is a
  /// route to the server) and rejects when the network is unreachable.
  Future<bool> checkReachability(List<Uri> uris) async {
    for (final uri in uris) {
      try {
        final init = JSObject();
        init.setProperty('mode'.toJS, 'no-cors'.toJS);
        init.setProperty('cache'.toJS, 'no-store'.toJS);
        init.setProperty('redirect'.toJS, 'follow'.toJS);
        final promise = globalContext.callMethod<JSPromise<JSAny?>>(
          'fetch'.toJS,
          uri.toString().toJS,
          init,
        );
        await promise.toDart.timeout(_reachabilityTimeout);
        return true;
      } catch (_) {
        // Try the next endpoint.
      }
    }
    return false;
  }

  void _emit() => _controller.add(current);
}