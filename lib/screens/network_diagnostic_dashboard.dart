import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'
    hide Provider, ChangeNotifierProvider;
import 'package:provider/provider.dart';

import '../models/network_diagnostic.dart';
import '../providers/theme_provider.dart';
import '../providers/network_diagnostic_provider.dart';
import '../services/network_diagnostic_service.dart';
import '../widgets/action_button.dart';
import '../widgets/gradient_background.dart';

class NetworkDiagnosticDashboard extends ConsumerStatefulWidget {
  const NetworkDiagnosticDashboard({super.key});

  @override
  ConsumerState<NetworkDiagnosticDashboard> createState() =>
      _NetworkDiagnosticDashboardState();
}

class _NetworkDiagnosticDashboardState
    extends ConsumerState<NetworkDiagnosticDashboard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _kickOffInitialTest();
  }

  void _kickOffInitialTest() {
    if (ref.read(networkHealthProvider).status == DiagnosticStatus.idle) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(networkHealthProvider.notifier).runTest();
        }
      });
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _runTest() {
    ref.read(networkHealthProvider.notifier).runTest();
  }

  Color _tierColor(NetworkHealthTier tier) {
    switch (tier) {
      case NetworkHealthTier.excellent:
        return const Color(0xFF4CAF50);
      case NetworkHealthTier.fair:
        return const Color(0xFFFFB74D);
      case NetworkHealthTier.poor:
        return const Color(0xFFEF6C00);
      case NetworkHealthTier.degraded:
        return const Color(0xFFE53935);
    }
  }

  IconData _tierIcon(NetworkHealthTier tier) {
    switch (tier) {
      case NetworkHealthTier.excellent:
        return Icons.speed;
      case NetworkHealthTier.fair:
        return Icons.network_check;
      case NetworkHealthTier.poor:
        return Icons.warning_amber_rounded;
      case NetworkHealthTier.degraded:
        return Icons.error_outline;
    }
  }

  String _stageLabel(NetworkDiagnosticStage? stage) {
    switch (stage) {
      case NetworkDiagnosticStage.idlePing:
        return 'Step 1/3 \u00b7 Measuring idle ping\u2026';
      case NetworkDiagnosticStage.download:
        return 'Step 2/3 \u00b7 Download speed + live ping\u2026';
      case NetworkDiagnosticStage.upload:
        return 'Step 3/3 \u00b7 Upload speed + live ping\u2026';
      case null:
        return 'Starting\u2026';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final health = ref.watch(networkHealthProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'Network Diagnostics',
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),
                  _FadeSlide(
                    delay: 0,
                    child: _buildHealthCard(theme, health),
                  ),
                  if (health.hasResult) ...[
                    const SizedBox(height: 16),
                    _FadeSlide(
                      delay: 1,
                      child: _buildMetricsCard(theme, health.result!),
                    ),
                  ],
                  const SizedBox(height: 16),
                  _FadeSlide(
                    delay: 2,
                    child: _buildRunTestButton(theme, health),
                  ),
                  ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHealthCard(ThemeProvider theme, NetworkDiagnosticState health) {
    final isRunning = health.isRunning;
    final tierColor =
        isRunning || health.status == DiagnosticStatus.idle
            ? theme.accentColor
            : _tierColor(health.tier);

    final String title;
    final String subtitle;
    if (health.isRunning) {
      title = 'Testing Network';
      subtitle = _stageLabel(health.stage);
    } else if (health.status == DiagnosticStatus.idle) {
      title = 'Ready';
      subtitle = 'Run a test to measure your connection';
    } else if (health.status == DiagnosticStatus.failed) {
      title = 'Test Failed';
      subtitle = health.errorMessage ?? 'Could not complete the diagnostic';
    } else {
      final result = health.result!;
      title = 'Network ${health.tier.label}';
      subtitle =
          '${result.downloadSpeedMbps.toStringAsFixed(1)} Mbps down \u00b7 '
          '${result.uploadSpeedMbps.toStringAsFixed(1)} Mbps up';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
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
            color: theme.textColor.withValues(alpha: 0.1),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              final pulse = isRunning ? _pulseAnimation.value : 1.0;
              return Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: tierColor.withValues(alpha: 0.18 * pulse),
                  border: Border.all(
                    color: tierColor.withValues(alpha: 0.5 * pulse),
                    width: 2,
                  ),
                  boxShadow: isRunning
                      ? [
                          BoxShadow(
                            color: tierColor.withValues(
                              alpha: 0.3 * _pulseAnimation.value,
                            ),
                            blurRadius: 28 * _pulseAnimation.value,
                            spreadRadius: 4 * _pulseAnimation.value,
                          ),
                        ]
                      : null,
                ),
                child: isRunning
                    ? SizedBox(
                        width: 32,
                        height: 32,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation(tierColor),
                        ),
                      )
                    : Icon(
                        health.status == DiagnosticStatus.failed
                            ? Icons.cloud_off
                            : _tierIcon(health.tier),
                        size: 42,
                        color: tierColor,
                      ),
              );
            },
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: theme.textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: theme.secondaryTextColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsCard(ThemeProvider theme, NetworkDiagnosticResult result) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.textColor.withValues(alpha: 0.1),
            theme.textColor.withValues(alpha: 0.04),
          ],
        ),
        border: Border.all(color: theme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Latest Results',
            style: TextStyle(
              color: theme.textColor,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.7,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            children: [
              _MetricTile(
                label: 'Idle Ping',
                value: '${_ms(result.idlePingMs)} ms',
                icon: Icons.timer_outlined,
                theme: theme,
              ),
              _MetricTile(
                label: 'Download',
                value: _mbps(result.downloadSpeedMbps),
                icon: Icons.arrow_downward,
                theme: theme,
              ),
              _MetricTile(
                label: 'Upload',
                value: _mbps(result.uploadSpeedMbps),
                icon: Icons.arrow_upward,
                theme: theme,
              ),
              _MetricTile(
                label: 'Ping @ Download',
                value: '${_ms(result.downloadPingMs)} ms',
                icon: Icons.speed,
                theme: theme,
              ),
              _MetricTile(
                label: 'Ping @ Upload',
                value: '${_ms(result.uploadPingMs)} ms',
                icon: Icons.speed,
                theme: theme,
              ),
              _MetricTile(
                label: 'Packet Loss',
                value: '${result.packetLossPercent.toStringAsFixed(1)} %',
                icon: Icons.stacked_bar_chart,
                theme: theme,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRunTestButton(ThemeProvider theme, NetworkDiagnosticState health) {
    if (health.isRunning) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: theme.textColor.withValues(alpha: 0.08),
          border: Border.all(color: theme.borderColor),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Text(
              'Running test\u2026',
              style: TextStyle(
                color: theme.secondaryTextColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }
    return Row(
      children: [
        Expanded(
          child: Center(
            child: ActionButton(
              label: health.status == DiagnosticStatus.idle
                  ? 'Run Test'
                  : 'Run Test Again',
              onPressed: _runTest,
            ),
          ),
        ),
      ],
    );
  }

  static String _ms(double value) =>
      value.isFinite ? value.toStringAsFixed(0) : '\u2014';

  static String _mbps(double value) =>
      value.isFinite ? '${value.toStringAsFixed(2)} Mbps' : '\u2014 Mbps';
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final ThemeProvider theme;

  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: theme.textColor.withValues(alpha: 0.06),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: theme.accentColor),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: theme.secondaryTextColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: theme.textColor,
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