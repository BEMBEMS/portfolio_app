import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../providers/name_provider.dart';
import '../widgets/custom_card.dart';
import '../widgets/gradient_background.dart';

import 'activity1_profile.dart';
import 'activity2_counter.dart';
import 'network_diagnostic_dashboard.dart';
import 'network_monitor_screen.dart';
import 'settings_screen.dart';

class HomeDashboard extends StatelessWidget {
  const HomeDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final nameProvider = Provider.of<NameProvider>(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'Portfolio Dashboard',
          style: TextStyle(
            color: themeProvider.textColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              themeProvider.isDarkMode ? Icons.light_mode : Icons.dark_mode,
              color: themeProvider.textColor,
            ),
            onPressed: () => themeProvider.toggleTheme(),
            tooltip: 'Toggle Theme',
          ),
          IconButton(
            icon: Icon(Icons.settings, color: themeProvider.textColor),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
            tooltip: 'Settings',
          ),
        ],
      ),
      body: GradientBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  _FadeSlide(
                    delay: 0,
                    child: Text(
                      'Welcome, ${nameProvider.userName}!',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: themeProvider.textColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _FadeSlide(
                    delay: 3,
                    child: Row(
                      children: [
                        Expanded(
                          child: CustomCard(
                            title: 'Student Information',
                            subtitle: 'Profile Screen',
                            icon: Icons.person,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const Activity1Profile(),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _FadeSlide(
                    delay: 4,
                    child: Row(
                      children: [
                        Expanded(
                          child: CustomCard(
                            title: 'Counter Module',
                            subtitle: 'Counter with State',
                            icon: Icons.calculate,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const Activity2Counter(),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _FadeSlide(
                    delay: 5,
                    child: Row(
                      children: [
                        Expanded(
                          child: CustomCard(
                            title: 'Network Monitor',
                            subtitle: 'Real-time connection status',
                            icon: Icons.network_check,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const NetworkMonitorScreen(),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _FadeSlide(
                    delay: 6,
                    child: Row(
                      children: [
                        Expanded(
                          child: CustomCard(
                            title: 'Network Diagnostics',
                            subtitle: 'Ping & speed test with health tier',
                            icon: Icons.speed,
                            onTap: () => _openDashboard(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _FadeSlide(
                    delay: 7,
                    child: Row(
                      children: [
                        Expanded(
                          child: CustomCard(
                            title: 'Settings',
                            subtitle: 'App configuration',
                            icon: Icons.tune,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const SettingsScreen(),
                              ),
                            ),
                          ),
                        ),
                      ],
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

  static void _openDashboard(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NetworkDiagnosticDashboard()),
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
