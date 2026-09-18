import 'dart:async';

enum BrowserConnType { unknown, none, wifi, cellular, ethernet }

class BrowserNetworkInfo {
  final BrowserConnType type;
  const BrowserNetworkInfo(this.type);
}

class BrowserConnectivity {
  const BrowserConnectivity();

  static const bool isWeb = false;

  bool get isOnLine => false;

  BrowserNetworkInfo get current =>
      const BrowserNetworkInfo(BrowserConnType.unknown);

  Stream<BrowserNetworkInfo> get onChanged => const Stream.empty();

  Future<bool> checkReachability(List<Uri> uris) async => false;
}