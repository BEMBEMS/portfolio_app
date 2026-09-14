import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import '../providers/theme_provider.dart';
import '../widgets/gradient_background.dart';

class NetworkMonitorScreen extends StatefulWidget {
  const NetworkMonitorScreen({super.key});

  @override
  State<NetworkMonitorScreen> createState() => _NetworkMonitorScreenState();
}

class _NetworkMonitorScreenState extends State<NetworkMonitorScreen>
    with SingleTickerProviderStateMixin {
  static final Uri _photosUri =
      Uri.parse('https://jsonplaceholder.typicode.com/photos');

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;
  late final StreamSubscription<List<ConnectivityResult>> _subscription;
  ConnectivityResult _status = ConnectivityResult.none;

  final List<_PendingRequest> _queuedRequests = [];
  final Set<OverlayEntry> _activeToasts = {};
  int _requestCounter = 0;
  bool _isFetching = false;
  bool _isRetrying = false;
  String? _lastResult;

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

    _subscription = Connectivity().onConnectivityChanged.listen((results) {
      final result = results.isNotEmpty ? results.last : ConnectivityResult.none;
      final previous = _status;
      final connectionRestored =
          previous == ConnectivityResult.none && result != ConnectivityResult.none;
      if (mounted) setState(() => _status = result);
      _showConnectivityToasts(previous, result);
      if (result != ConnectivityResult.none) {
        _resumeQueuedRequests(showRecoverySnackbar: connectionRestored);
      }
    });

    Connectivity().checkConnectivity().then((results) {
      final result = results.isNotEmpty ? results.last : ConnectivityResult.none;
      if (mounted) setState(() => _status = result);
    });
  }

  @override
  void dispose() {
    for (final entry in _activeToasts) {
      entry.remove();
    }
    _activeToasts.clear();
    _subscription.cancel();
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

  void _showConnectivityToasts(
    ConnectivityResult previous,
    ConnectivityResult current,
  ) {
    if (previous == current) return;
    switch (current) {
      case ConnectivityResult.wifi:
        _showToast('Connected to Wi-Fi', const Color(0xFF4CAF50), Icons.wifi);
        break;
      case ConnectivityResult.mobile:
        _showToast(
          'Switched to Cellular',
          const Color(0xFF2196F3),
          Icons.signal_cellular_alt,
        );
        break;
      case ConnectivityResult.none:
        _showToast(
          'Connection Lost - Offline',
          const Color(0xFFE53935),
          Icons.wifi_off,
        );
        break;
      default:
        break;
    }
  }

  Color get _statusColor {
    switch (_status) {
      case ConnectivityResult.wifi:
        return const Color(0xFF4CAF50);
      case ConnectivityResult.mobile:
        return const Color(0xFF2196F3);
      default:
        return const Color(0xFF9E9E9E);
    }
  }

  IconData get _statusIcon {
    switch (_status) {
      case ConnectivityResult.wifi:
        return Icons.wifi;
      case ConnectivityResult.mobile:
        return Icons.signal_cellular_alt;
      default:
        return Icons.wifi_off;
    }
  }

  String get _statusLabel {
    switch (_status) {
      case ConnectivityResult.wifi:
        return 'Wi-Fi Connected';
      case ConnectivityResult.mobile:
        return 'Cellular Connected';
      default:
        return 'Offline';
    }
  }

  String get _statusDescription {
    switch (_status) {
      case ConnectivityResult.wifi:
        return 'Your device is connected to a Wi-Fi network. Enjoy high-speed internet access.';
      case ConnectivityResult.mobile:
        return 'Your device is using cellular data. Standard data rates may apply.';
      default:
        return 'No network connection detected. Please check your settings.';
    }
  }

  Future<void> _performRequest() async {
    await Future.wait([
      http.get(_photosUri).timeout(const Duration(seconds: 10)),
      Future.delayed(const Duration(seconds: 8)),
    ]);
  }

  Future<void> _fetchDataset() async {
    if (_isFetching) return;
    final id = ++_requestCounter;
    setState(() {
      _isFetching = true;
      _lastResult = null;
    });

    bool succeeded = false;
    try {
      await _performRequest();
      succeeded = _status != ConnectivityResult.none;
    } catch (_) {
      succeeded = false;
    }

    if (!mounted) return;
    setState(() {
      _isFetching = false;
      if (succeeded) {
        _lastResult =
            'Dataset #$id fetched successfully \u2014 ${_photosUri.host} responded.';
      } else {
        _queuedRequests.add(_PendingRequest(id: id, timestamp: DateTime.now()));
      }
    });

    if (!succeeded) {
      _showToast(
        'Request Queued - Waiting for Connection',
        const Color(0xFFF57C00),
        Icons.hourglass_top,
      );
    }

    if (succeeded) {
      await _flushQueue();
    }
  }

  Future<void> _resumeQueuedRequests({bool showRecoverySnackbar = false}) async {
    if (_isRetrying || _queuedRequests.isEmpty) return;

    final delivered = await _flushQueue();
    if (delivered > 0 && showRecoverySnackbar && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Recovered $delivered queued request(s) \u2014 network restored.',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF4CAF50),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<int> _flushQueue() async {
    if (_isRetrying || _queuedRequests.isEmpty) return 0;

    _isRetrying = true;
    if (mounted) setState(() {});

    final pending = List<_PendingRequest>.from(_queuedRequests);
    _queuedRequests.clear();

    var delivered = 0;
    for (final request in pending) {
      try {
        await _performRequest();
        delivered++;
      } catch (_) {
        _queuedRequests.insert(0, request);
        break;
      }
    }

    _isRetrying = false;
    if (!mounted) return delivered;
    setState(() {
      if (delivered > 0) {
        _lastResult =
            'Retried and delivered $delivered queued dataset request(s).';
      }
    });
    if (delivered > 0) {
      _showToast(
        'Queued Request Recovered Successfully',
        const Color(0xFF4CAF50),
        Icons.check_circle,
      );
    }
    return delivered;
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
                  const SizedBox(height: 16),
                  _FadeSlide(
                    delay: 1,
                    child: _buildFetchCard(theme),
                  ),
                  if (_queuedRequests.isNotEmpty || _isRetrying) ...[
                    const SizedBox(height: 16),
                    _FadeSlide(
                      delay: 2,
                      child: _buildQueuedBanner(theme),
                    ),
                  ],
                  if (_lastResult != null) ...[
                    const SizedBox(height: 16),
                    _FadeSlide(
                      delay: 3,
                      child: _buildResultCard(theme),
                    ),
                  ],
                  const SizedBox(height: 16),
                  _FadeSlide(
                    delay: 4,
                    child: _buildInfoTile(
                      theme: theme,
                      icon: Icons.info_outline,
                      title: 'Connection Details',
                      subtitle: _statusDescription,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _FadeSlide(
                    delay: 5,
                    child: _buildInfoTile(
                      theme: theme,
                      icon: Icons.speed,
                      title: 'Connection Type',
                      subtitle: _status == ConnectivityResult.wifi
                          ? 'Wi-Fi \u2014 Typically faster and more stable'
                          : _status == ConnectivityResult.mobile
                              ? 'Cellular \u2014 Speed depends on signal and carrier'
                              : 'No active connection',
                    ),
                  ),
                  const SizedBox(height: 16),
                  _FadeSlide(
                    delay: 6,
                    child: _buildInfoTile(
                      theme: theme,
                      icon: Icons.update,
                      title: 'Live Monitoring',
                      subtitle: 'This screen updates automatically whenever your network status changes. No refresh needed.',
                    ),
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
                color: _statusColor.withValues(alpha: 0.25 * _pulseAnimation.value),
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: _statusColor.withValues(alpha: 0.2),
                ),
                child: Text(
                  _status == ConnectivityResult.none ? 'NO CONNECTION' : 'CONNECTED',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: _statusColor,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFetchCard(ThemeProvider theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.textColor.withValues(alpha: 0.10),
            theme.textColor.withValues(alpha: 0.03),
          ],
        ),
        border: Border.all(color: theme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Dataset Download',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: theme.textColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Downloads the full photo album to test long-running network requests.',
            style: TextStyle(
              fontSize: 14,
              color: theme.textColor.withValues(alpha: 0.7),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: AnimatedScale(
              scale: 1.0,
              duration: const Duration(milliseconds: 150),
              child: Material(
                color: Colors.deepPurpleAccent,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: _isFetching ? null : _fetchDataset,
                  borderRadius: BorderRadius.circular(12),
                  splashColor: Colors.white.withValues(alpha: 0.2),
                  highlightColor: Colors.white.withValues(alpha: 0.1),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_isFetching) ...[
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        Text(
                          _isFetching
                              ? 'Fetching...'
                              : 'Fetch Large Dataset',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_isFetching) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.deepPurpleAccent,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Fetching from ${_photosUri.host}... this may take a few seconds.',
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.textColor.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQueuedBanner(ThemeProvider theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFFFB74D).withValues(alpha: 0.22),
            const Color(0xFFF57C00).withValues(alpha: 0.10),
          ],
        ),
        border: Border.all(
          color: const Color(0xFFFFB74D).withValues(alpha: 0.45),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: const Color(0xFFFFB74D).withValues(alpha: 0.25),
            ),
            child: const Icon(Icons.pending, color: Color(0xFFFFB74D)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Queued \u2014 waiting for connection',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFFFB74D),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _isRetrying
                      ? 'Retrying queued request(s) now that a connection is available...'
                      : '${_queuedRequests.length} dataset request(s) failed and are queued. They will retry automatically once the connection is restored.',
                  style: TextStyle(
                    fontSize: 14,
                    color: theme.textColor.withValues(alpha: 0.85),
                    height: 1.4,
                  ),
                ),
                if (_queuedRequests.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ..._queuedRequests.map(
                    (request) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        'Request #${request.id} \u00b7 failed at '
                        '${_formatTime(request.timestamp)}',
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.secondaryTextColor,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard(ThemeProvider theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF4CAF50).withValues(alpha: 0.18),
            const Color(0xFF2E7D32).withValues(alpha: 0.08),
          ],
        ),
        border: Border.all(
          color: const Color(0xFF4CAF50).withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: const Color(0xFF4CAF50).withValues(alpha: 0.2),
            ),
            child: const Icon(Icons.check_circle, color: Color(0xFF4CAF50)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              _lastResult!,
              style: TextStyle(
                fontSize: 14,
                color: theme.textColor.withValues(alpha: 0.9),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    final s = time.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  Widget _buildInfoTile({
    required ThemeProvider theme,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.textColor.withValues(alpha: 0.10),
            theme.textColor.withValues(alpha: 0.03),
          ],
        ),
        border: Border.all(color: theme.borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: theme.textColor.withValues(alpha: 0.1),
            ),
            child: Icon(
              icon,
              color: theme.secondaryTextColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: theme.textColor,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: theme.textColor.withValues(alpha: 0.7),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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

class _PendingRequest {
  final int id;
  final DateTime timestamp;

  const _PendingRequest({required this.id, required this.timestamp});
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