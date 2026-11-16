import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../services/location_image_storage.dart';

Future<void> showLocationImageLightbox(
  BuildContext context, {
  String? reference,
  Uint8List? bytes,
  String? title,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close image preview',
    barrierColor: Colors.black,
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (_, _, _) =>
        LocationImageLightbox(reference: reference, bytes: bytes, title: title),
    transitionBuilder: (_, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class LocationImageLightbox extends StatefulWidget {
  final String? reference;
  final Uint8List? bytes;
  final String? title;

  const LocationImageLightbox({
    super.key,
    this.reference,
    this.bytes,
    this.title,
  });

  @override
  State<LocationImageLightbox> createState() => _LocationImageLightboxState();
}

class _LocationImageLightboxState extends State<LocationImageLightbox> {
  late final Future<Uint8List?> _imageFuture;

  @override
  void initState() {
    super.initState();
    _imageFuture = widget.bytes != null
        ? Future<Uint8List?>.value(widget.bytes)
        : LocationImageStorage.read(widget.reference);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: FutureBuilder<Uint8List?>(
                future: _imageFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    );
                  }

                  final bytes = snapshot.data;
                  if (bytes == null) {
                    return Center(
                      child: Text(
                        'Image unavailable',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  }

                  return InteractiveViewer(
                    minScale: 1,
                    maxScale: 5,
                    panEnabled: true,
                    scaleEnabled: true,
                    child: SizedBox.expand(
                      child: Image.memory(
                        bytes,
                        fit: BoxFit.contain,
                        gaplessPlayback: true,
                        errorBuilder: (_, _, _) => Center(
                          child: Text(
                            'Unable to display this image',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.75),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: Material(
                color: Colors.black.withValues(alpha: 0.55),
                shape: const CircleBorder(),
                child: IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                ),
              ),
            ),
            if (widget.title != null && widget.title!.trim().isNotEmpty)
              Positioned(
                left: 16,
                right: 72,
                bottom: 16,
                child: Text(
                  widget.title!.trim(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    shadows: [Shadow(color: Colors.black, blurRadius: 8)],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
