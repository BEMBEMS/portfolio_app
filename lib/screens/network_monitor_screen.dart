import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../widgets/gradient_background.dart';

class NetworkMonitorScreen extends StatefulWidget {
  const NetworkMonitorScreen({super.key});

  @override
  State<NetworkMonitorScreen> createState() => _NetworkMonitorScreenState();
}

class _NetworkMonitorScreenState extends State<NetworkMonitorScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;
  late final StreamSubscription<List<ConnectivityResult>> _subscription;
  ConnectivityResult _status = ConnectivityResult.none;

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
      if (mounted) setState(() => _status = result);
    });

    Connectivity().checkConnectivity().then((results) {
      final result = results.isNotEmpty ? results.last : ConnectivityResult.none;
      if (mounted) setState(() => _status = result);
    });
  }

  @override
  void dispose() {
    _subscription.cancel();
    _pulseController.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'Network Monitor',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
                    child: _buildStatusCard(),
                  ),
                  const SizedBox(height: 24),
                  _FadeSlide(
                    delay: 1,
                    child: _buildInfoTile(
                      icon: Icons.info_outline,
                      title: 'Connection Details',
                      subtitle: _statusDescription,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _FadeSlide(
                    delay: 2,
                    child: _buildInfoTile(
                      icon: Icons.speed,
                      title: 'Connection Type',
                      subtitle: _status == ConnectivityResult.wifi
                          ? 'Wi-Fi — Typically faster and more stable'
                          : _status == ConnectivityResult.mobile
                              ? 'Cellular — Speed depends on signal and carrier'
                              : 'No active connection',
                    ),
                  ),
                  const SizedBox(height: 16),
                  _FadeSlide(
                    delay: 3,
                    child: _buildInfoTile(
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

  Widget _buildStatusCard() {
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
                Colors.white.withValues(alpha: 0.14),
                Colors.white.withValues(alpha: 0.05),
              ],
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.2),
            ),
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
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
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

  Widget _buildInfoTile({
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
            Colors.white.withValues(alpha: 0.10),
            Colors.white.withValues(alpha: 0.03),
          ],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
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
              color: Colors.white.withValues(alpha: 0.1),
            ),
            child: Icon(icon, color: Colors.white70, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.7),
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
