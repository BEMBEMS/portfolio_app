import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

class CustomCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final String? activityLabel;
  final IconData icon;
  final VoidCallback? onTap;

  const CustomCard({
    super.key,
    required this.title,
    required this.subtitle,
    this.activityLabel,
    required this.icon,
    this.onTap,
  });

  @override
  State<CustomCard> createState() => _CustomCardState();
}

class _CustomCardState extends State<CustomCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);

    return AnimatedScale(
      scale: _pressed ? 0.96 : 1.0,
      duration: const Duration(milliseconds: 150),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.textColor.withValues(alpha: 0.12),
              theme.textColor.withValues(alpha: 0.04),
            ],
          ),
          border: Border.all(color: theme.borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            onTap: widget.onTap,
            onTapDown: (_) => setState(() => _pressed = true),
            onTapCancel: () => setState(() => _pressed = false),
            onTapUp: (_) => setState(() => _pressed = false),
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: theme.textColor.withValues(alpha: 0.2),
                    ),
                    child: Icon(widget.icon, size: 32, color: theme.textColor),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (widget.activityLabel != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: theme.accentColor.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: theme.accentColor.withValues(alpha: 0.35),
                              ),
                            ),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                widget.activityLabel!,
                                style: TextStyle(
                                  fontSize: 18,
                                  height: 1.15,
                                  letterSpacing: 0.9,
                                  fontWeight: FontWeight.w800,
                                  color: theme.textColor,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            widget.title,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: theme.textColor.withValues(alpha: 0.8),
                            ),
                          ),
                          if (widget.subtitle.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              widget.subtitle,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: theme.mutedTextColor,
                              ),
                            ),
                          ],
                        ] else ...[
                          Text(
                            widget.title,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: theme.textColor,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.subtitle,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: theme.textColor.withValues(alpha: 0.9),
                                ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: theme.textColor),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
