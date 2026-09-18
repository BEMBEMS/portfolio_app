import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../services/network_service.dart';
import '../widgets/gradient_background.dart';

class NetworkMonitorScreen extends StatefulWidget {
  const NetworkMonitorScreen({super.key});

  @override
  State<NetworkMonitorScreen> createState() => _NetworkMonitorScreenState();
}

class _NetworkMonitorScreenState extends State<NetworkMonitorScreen>
    with SingleTickerProviderStateMixin {
  static final Uri _pingUri =
      Uri.parse('https://jsonplaceholder.typicode.com/todos/1');
  static const Duration _pingInterval = Duration(seconds: 2);
  static const Duration _pingTimeout = Duration(seconds: 5);

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;
  late final NetworkService _networkService;
  NetworkStatus? _lastStatus;

  Timer? _pingTimer;
  bool _pingInFlight = false;
  bool _pingErrored = false;
  double? _lastPingSeconds;

  final Set<OverlayEntry> _activeToasts = {};

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _networkService = NetworkService()..addListener(_handleNetworkChange);
    _networkService.start();

    unawaited(_performPing());
    _pingTimer = Timer.periodic(_pingInterval, (_) => _performPing());
  }

  @override
  void dispose() {
    for (final entry in _activeToasts) {
      entry.remove();
    }
    _activeToasts.clear();
    _networkService.removeListener(_handleNetworkChange);
    _networkService.dispose();
    _pingTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _showToast(String message, Color accentColor, IconData icon) {
    if (!mounted) return;
    final overlay = Overlay.of(context);
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _ToastOverlay(
        message: message,
        accentColor: accentColor,
        icon: icon,
        onDismissed: () {
          _activeToasts.remove(entry);
          entry.remove();
        },
      ),
    );
    _activeToasts.add(entry);
    overlay.insert(entry);
  }

  void _handleNetworkChange() {
    if (!mounted) return;
    final current = _networkService.status;
    final previous = _lastStatus;
    _lastStatus = current;
    setState(() {});
    if (previous == null) return;
    _showStatusToast(current);
  }

  void _showStatusToast(NetworkStatus next) {
    if (next.isOnline) {
      switch (next.type) {
        case NetworkType.wifi:
          _showToast('Connected to Wi-Fi', const Color(0xFF4CAF50), Icons.wifi);
          break;
        case NetworkType.mobile:
          _showToast(
            'Switched to Cellular',
            const Color(0xFF4CAF50),
            Icons.signal_cellular_alt,
          );
          break;
        case NetworkType.ethernet:
          _showToast(
            'Connected via Ethernet',
            const Color(0xFF4CAF50),
            Icons.lan_outlined,
          );
          break;
        case NetworkType.none:
        case NetworkType.unknown:
          break;
      }
    } else if (next.type == NetworkType.none ||
        next.type == NetworkType.unknown) {
      _showToast(
        'Connection Lost - Offline',
        const Color(0xFFE53935),
        Icons.wifi_off,
      );
    } else {
      _showToast(
        'No Internet Connection',
        const Color(0xFFE53935),
        Icons.cloud_off,
      );
    }
  }

  NetworkType get _networkType => _networkService.status.type;

  bool get _isOnline => _networkService.isOnline;

  bool get _isResolved => _networkService.isResolved;

  Color get _statusColor {
    if (!_isResolved) return const Color(0xFF9E9E9E);
    return _isOnline ? const Color(0xFF4CAF50) : const Color(0xFFE53935);
  }

  IconData get _statusIcon {
    if (!_isResolved) return Icons.network_check;
    if (!_isOnline) return Icons.cloud_off;
    switch (_networkType) {
      case NetworkType.wifi:
        return Icons.wifi;
      case NetworkType.mobile:
        return Icons.signal_cellular_alt;
      case NetworkType.ethernet:
        return Icons.lan_outlined;
      case NetworkType.none:
      case NetworkType.unknown:
        return Icons.wifi;
    }
  }

  String get _statusLabel {
    if (!_isResolved) return 'Checking connection\u2026';
    if (_isOnline) {
      switch (_networkType) {
        case NetworkType.wifi:
          return 'Wi-Fi Connected';
        case NetworkType.mobile:
          return 'Cellular Data Connected';
        case NetworkType.ethernet:
          return 'Ethernet Connected';
        case NetworkType.none:
        case NetworkType.unknown:
          break;
      }
    }
    return 'No Internet Connection';
  }

  Future<void> _performPing() async {
    if (_pingInFlight) return;
    _pingInFlight = true;
    final stopwatch = Stopwatch()..start();
    try {
      await http.get(_pingUri).timeout(_pingTimeout);
      stopwatch.stop();
      if (!mounted) return;
      setState(() {
        _lastPingSeconds = stopwatch.elapsedMilliseconds / 1000.0;
        _pingErrored = false;
      });
    } catch (_) {
      stopwatch.stop();
      if (!mounted) return;
      setState(() => _pingErrored = true);
    } finally {
      _pingInFlight = false;
    }
  }

  String get _pingLabel {
    if (_pingErrored) return 'Response Time (Ping): Unavailable';
    final seconds = _lastPingSeconds;
    if (seconds == null) return 'Response Time (Ping): Measuring\u2026';
    return 'Response Time (Ping): ${seconds.toStringAsFixed(2)} seconds';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'Network Monitor',
          style: TextStyle(
            color: theme.textColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: GradientBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  _FadeSlide(
                    delay: 0,
                    child: _buildStatusCard(theme),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard(ThemeProvider theme) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                theme.textColor.withValues(alpha: 0.14),
                theme.textColor.withValues(alpha: 0.05),
              ],
            ),
            border: Border.all(color: theme.borderColor),
            boxShadow: [
              BoxShadow(
                color: _statusColor.withValues(
                  alpha: 0.25 * _pulseAnimation.value,
                ),
                blurRadius: 32 * _pulseAnimation.value,
                spreadRadius: 4 * _pulseAnimation.value,
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _statusColor.withValues(alpha: 0.2),
                  border: Border.all(
                    color: _statusColor.withValues(alpha: 0.5),
                    width: 2,
                  ),
                ),
                child: Icon(
                  _statusIcon,
                  size: 40,
                  color: _statusColor,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                _statusLabel,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: theme.textColor,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: _statusColor.withValues(alpha: 0.2),
                ),
                child: Text(
                  _isResolved
                      ? (_isOnline ? 'CONNECTED' : 'NO INTERNET')
                      : 'CHECKING',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: _statusColor,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _pingLabel,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: theme.textColor.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ToastOverlay extends StatefulWidget {
  final String message;
  final Color accentColor;
  final IconData icon;
  final VoidCallback onDismissed;

  const _ToastOverlay({
    required this.message,
    required this.accentColor,
    required this.icon,
    required this.onDismissed,
  });

  @override
  State<_ToastOverlay> createState() => _ToastOverlayState();
}

class _ToastOverlayState extends State<_ToastOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, -0.35),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _controller.forward();
    _dismissTimer = Timer(const Duration(seconds: 5), _dismiss);
  }

  void _dismiss() {
    if (!mounted) return;
    _controller.reverse().then((_) {
      if (mounted) widget.onDismissed();
    });
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);

    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: FadeTransition(
            opacity: _opacity,
            child: SlideTransition(
              position: _slide,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: theme.isDarkMode
                      ? const Color(0xFF1C1C1C)
                      : Colors.white,
                  border: Border.all(color: theme.borderColor),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(widget.icon, color: widget.accentColor, size: 20),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        widget.message,
                        style: TextStyle(
                          color: theme.textColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FadeSlide extends StatefulWidget {
  final Widget child;
  final int delay;

  const _FadeSlide({required this.child, required this.delay});

  @override
  State<_FadeSlide> createState() => _FadeSlideState();
}

class _FadeSlideState extends State<_FadeSlide>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _offset;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _offset = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    Future.delayed(Duration(milliseconds: widget.delay * 200), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _offset, child: widget.child),
    );
  }
}