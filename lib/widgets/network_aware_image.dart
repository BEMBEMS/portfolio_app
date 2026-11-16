import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:provider/provider.dart';

import '../models/network_diagnostic.dart';
import '../providers/network_diagnostic_provider.dart';
import '../providers/theme_provider.dart';

/// Demonstrates adaptive media rendering driven by the global
/// [networkHealthProvider] tier:
///
/// * Excellent / Fair: load the high-resolution image.
/// * Poor: fall back to a tiny thumbnail so the app stays responsive.
/// * Degraded: skip the network entirely and show an offline placeholder.
class NetworkAwareImage extends ConsumerWidget {
  final String highResUrl;
  final String lowResUrl;
  final double height;
  final String placeholderLabel;

  const NetworkAwareImage({
    super.key,
    required this.highResUrl,
    required this.lowResUrl,
    this.height = 160,
    this.placeholderLabel = 'Offline',
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Provider.of<ThemeProvider>(context);
    final health = ref.watch(networkHealthProvider);
    final tier = health.tier;

    final Widget child = switch (tier) {
      NetworkHealthTier.excellent || NetworkHealthTier.fair =>
        _NetworkImage(
          url: highResUrl,
          qualityLabel: 'High res',
          theme: theme,
          height: height,
        ),
      NetworkHealthTier.poor =>
        _NetworkImage(
          url: lowResUrl,
          qualityLabel: 'Low res',
          theme: theme,
          height: height,
        ),
      NetworkHealthTier.degraded => _MediaPlaceholder(
          label: placeholderLabel,
          theme: theme,
        ),
    };

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(height: height, width: double.infinity, child: child),
    );
  }
}

class _NetworkImage extends StatelessWidget {
  final String url;
  final String qualityLabel;
  final ThemeProvider theme;
  final double height;

  const _NetworkImage({
    required this.url,
    required this.qualityLabel,
    required this.theme,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _MediaPlaceholder(
            label: 'Unavailable',
            theme: theme,
          ),
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return ColoredBox(
              color: theme.textColor.withValues(alpha: 0.06),
            );
          },
        ),
        Positioned(
          left: 12,
          bottom: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.black.withValues(alpha: 0.55),
            ),
            child: Text(
              qualityLabel,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MediaPlaceholder extends StatelessWidget {
  final String label;
  final ThemeProvider theme;

  const _MediaPlaceholder({required this.label, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.textColor.withValues(alpha: 0.12),
            theme.textColor.withValues(alpha: 0.04),
          ],
        ),
        border: Border.all(color: theme.borderColor),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              color: theme.secondaryTextColor,
              size: 40,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: theme.secondaryTextColor,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
