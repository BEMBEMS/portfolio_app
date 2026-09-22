import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../providers/name_provider.dart';
import '../widgets/gradient_background.dart';
import '../widgets/glass_card.dart';
import '../widgets/action_button.dart';

class Activity1Profile extends StatefulWidget {
  const Activity1Profile({super.key});

  @override
  State<Activity1Profile> createState() => _Activity1ProfileState();
}

class _Activity1ProfileState extends State<Activity1Profile> {
  final TextEditingController _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final nameProvider = Provider.of<NameProvider>(context);
    final theme = Provider.of<ThemeProvider>(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'Student Information',
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
                  _ScaleIn(
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Colors.white, Color(0xFFE0E0E0)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Icon(
                          Icons.person,
                          size: 90,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    transitionBuilder: (child, animation) =>
                        FadeTransition(opacity: animation, child: child),
                    child: Text(
                      nameProvider.userName,
                      key: ValueKey(nameProvider.userName),
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: theme.textColor,
                        fontWeight: FontWeight.bold,
                        shadows: const [
                          Shadow(
                            color: Colors.black45,
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Student - Flutter Portfolio',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: theme.textColor.withValues(alpha: 0.95),
                    ),
                  ),
                  const SizedBox(height: 32),
                  _FadeIn(
                    child: GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Update Name',
                            style: TextStyle(
                              color: theme.textColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _nameController,
                                  style: TextStyle(color: theme.textColor),
                                  decoration: InputDecoration(
                                    hintText: 'Enter your name',
                                    hintStyle:
                                        TextStyle(color: theme.mutedTextColor),
                                    filled: true,
                                    fillColor: theme.textColor
                                        .withValues(alpha: 0.12),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide:
                                          BorderSide(color: theme.borderColor),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: theme.accentColor,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              ActionButton(
                                label: 'Save',
                                onPressed: () {
                                  if (_nameController.text.isNotEmpty) {
                                    nameProvider.setUserName(
                                      _nameController.text,
                                    );
                                    _nameController.clear();
                                  }
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _FadeIn(
                    delay: 1,
                    child: GlassCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          ListTile(
                            leading: _IconBadge(
                              icon: Icons.email,
                              gradient: const LinearGradient(
                                colors: [Colors.blue, Colors.lightBlueAccent],
                              ),
                            ),
                            title: Text('Email',
                                style: TextStyle(
                                    color: theme.textColor,
                                    fontWeight: FontWeight.w600)),
                            subtitle: Text('student@example.com',
                                style: TextStyle(
                                    color: theme.secondaryTextColor)),
                          ),
                          Divider(color: theme.dividerColor, height: 1),
                          ListTile(
                            leading: _IconBadge(
                              icon: Icons.school,
                              gradient: const LinearGradient(
                                colors: [Colors.orange, Colors.deepOrange],
                              ),
                            ),
                            title: Text('Course',
                                style: TextStyle(
                                    color: theme.textColor,
                                    fontWeight: FontWeight.w600)),
                            subtitle: Text('Flutter Development',
                                style: TextStyle(
                                    color: theme.secondaryTextColor)),
                          ),
                          Divider(color: theme.dividerColor, height: 1),
                          ListTile(
                            leading: _IconBadge(
                              icon: Icons.star,
                              gradient: const LinearGradient(
                                colors: [Colors.purple, Colors.pink],
                              ),
                            ),
                            title: Text('Activity',
                                style: TextStyle(
                                    color: theme.textColor,
                                    fontWeight: FontWeight.w600)),
                            subtitle: Text(
                                'Portfolio & State Management',
                                style: TextStyle(
                                    color: theme.secondaryTextColor)),
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

class _IconBadge extends StatelessWidget {
  final IconData icon;
  final Gradient gradient;

  const _IconBadge({required this.icon, required this.gradient});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: gradient,
      ),
      child: Icon(icon, color: Colors.white),
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

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    Future.delayed(Duration(milliseconds: widget.delay * 300), () {
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
    return FadeTransition(opacity: _opacity, child: widget.child);
  }
}

class _ScaleIn extends StatefulWidget {
  final Widget child;

  const _ScaleIn({required this.child});

  @override
  State<_ScaleIn> createState() => _ScaleInState();
}

class _ScaleInState extends State<_ScaleIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _scale = CurvedAnimation(parent: _controller, curve: Curves.elasticOut);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(scale: _scale, child: widget.child);
  }
}
