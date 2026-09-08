import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/gradient_background.dart';

class Activity2Counter extends StatefulWidget {
  const Activity2Counter({super.key});

  @override
  State<Activity2Counter> createState() => _Activity2CounterState();
}

class _Activity2CounterState extends State<Activity2Counter> {
  int _counter = 0;

  void _increment() => setState(() => _counter++);
  void _decrement() => setState(() {
    if (_counter > 0) _counter--;
  });
  void _reset() => setState(() => _counter = 0);

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'Counter Module',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: GradientBackground(
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Local State Counter',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This screen uses StatefulWidget for local state.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.95),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  _AnimatedCounter(value: _counter, accent: theme.accentColor),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _CounterButton(
                        icon: Icons.remove,
                        label: 'Decrement',
                        gradient: const LinearGradient(
                          colors: [Colors.redAccent, Colors.deepOrange],
                        ),
                        onPressed: _decrement,
                      ),
                      const SizedBox(width: 16),
                      _CounterButton(
                        icon: Icons.refresh,
                        label: 'Reset',
                        gradient: const LinearGradient(
                          colors: [Colors.grey, Colors.blueGrey],
                        ),
                        onPressed: _reset,
                      ),
                      const SizedBox(width: 16),
                      _CounterButton(
                        icon: Icons.add,
                        label: 'Increment',
                        gradient: const LinearGradient(
                          colors: [Colors.greenAccent, Colors.teal],
                        ),
                        onPressed: _increment,
                      ),
                    ],
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

class _AnimatedCounter extends StatelessWidget {
  final int value;
  final Color accent;

  const _AnimatedCounter({required this.value, required this.accent});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      transitionBuilder: (child, animation) => ScaleTransition(
        scale: animation,
        child: FadeTransition(opacity: animation, child: child),
      ),
      child: Text(
        '$value',
        key: ValueKey(value),
        style: Theme.of(context).textTheme.displayLarge?.copyWith(
          fontWeight: FontWeight.bold,
          color: accent,
          shadows: [
            Shadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 10),
          ],
        ),
      ),
    );
  }
}

class _CounterButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final Gradient gradient;

  const _CounterButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.gradient,
  });

  @override
  State<_CounterButton> createState() => _CounterButtonState();
}

class _CounterButtonState extends State<_CounterButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          onTap: widget.onPressed,
          child: AnimatedScale(
            scale: _pressed ? 0.85 : 1.0,
            duration: const Duration(milliseconds: 120),
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: widget.gradient,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Icon(widget.icon, size: 30, color: Colors.white),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          widget.label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
