import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../providers/name_provider.dart';
import '../widgets/gradient_background.dart';
import '../widgets/glass_card.dart';
import '../widgets/action_button.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final nameProvider = Provider.of<NameProvider>(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'Settings',
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _FadeIn(
                    child: Text(
                      'Global Settings',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _FadeIn(
                    delay: 1,
                    child: GlassCard(
                      padding: EdgeInsets.zero,
                      child: SwitchListTile(
                        activeThumbColor: Colors.white,
                        activeTrackColor: Colors.deepPurpleAccent,
                        title: const Text(
                          'Dark Mode',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          themeProvider.isDarkMode
                              ? 'Dark theme active'
                              : 'Light theme active',
                          style: const TextStyle(color: Colors.white70),
                        ),
                        secondary: Icon(
                          themeProvider.isDarkMode
                              ? Icons.dark_mode
                              : Icons.light_mode,
                          color: Colors.white,
                        ),
                        value: themeProvider.isDarkMode,
                        onChanged: (_) => themeProvider.toggleTheme(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _FadeIn(
                    delay: 2,
                    child: GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'User Profile',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            transitionBuilder: (child, anim) =>
                                FadeTransition(opacity: anim, child: child),
                            child: Text(
                              'Current name: ${nameProvider.userName}',
                              key: ValueKey(nameProvider.userName),
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _NameInput(
                                  onSubmitted: (value) {
                                    if (value.isNotEmpty) {
                                      nameProvider.setUserName(value);
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _FadeIn(
                    delay: 3,
                    child: GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'About',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const Divider(color: Colors.white24),
                          const ListTile(
                            leading: Icon(Icons.flutter_dash,
                                color: Colors.lightBlueAccent),
                            title: Text('Flutter Portfolio App',
                                style: TextStyle(color: Colors.white)),
                            subtitle: Text('Version 1.0.0',
                                style: TextStyle(color: Colors.white70)),
                          ),
                          const ListTile(
                            leading: Icon(Icons.code,
                                color: Colors.deepPurpleAccent),
                            title: Text('State Management',
                                style: TextStyle(color: Colors.white)),
                            subtitle: Text('Provider Package',
                                style: TextStyle(color: Colors.white70)),
                          ),
                        ],
                      ),
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
}

class _FadeIn extends StatefulWidget {
  final Widget child;
  final int delay;

  const _FadeIn({required this.child, this.delay = 0});

  @override
  State<_FadeIn> createState() => _FadeInState();
}

class _FadeInState extends State<_FadeIn> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _offset;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _offset = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
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

class _NameInput extends StatefulWidget {
  final ValueChanged<String> onSubmitted;

  const _NameInput({required this.onSubmitted});

  @override
  State<_NameInput> createState() => _NameInputState();
}

class _NameInputState extends State<_NameInput> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Enter new name',
              hintStyle: const TextStyle(color: Colors.white54),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.12),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    BorderSide(color: Colors.white.withValues(alpha: 0.2)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.white70),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        ActionButton(
          label: 'Update',
          onPressed: () {
            widget.onSubmitted(_controller.text);
            _controller.clear();
          },
        ),
      ],
    );
  }
}
