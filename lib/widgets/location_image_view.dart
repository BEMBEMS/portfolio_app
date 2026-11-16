import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../services/location_image_storage.dart';

class LocationImageView extends StatefulWidget {
  final String? reference;
  final BoxFit fit;
  final AlignmentGeometry alignment;
  final Widget? placeholder;

  const LocationImageView({
    super.key,
    required this.reference,
    this.fit = BoxFit.contain,
    this.alignment = Alignment.center,
    this.placeholder,
  });

  @override
  State<LocationImageView> createState() => _LocationImageViewState();
}

class _LocationImageViewState extends State<LocationImageView> {
  Future<Uint8List?>? _imageFuture;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(covariant LocationImageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reference != widget.reference) _loadImage();
  }

  void _loadImage() {
    _imageFuture = LocationImageStorage.read(widget.reference);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _imageFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            snapshot.data != null) {
          return Image.memory(
            snapshot.data!,
            fit: widget.fit,
            alignment: widget.alignment,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => _buildPlaceholder(context),
          );
        }
        return _buildPlaceholder(context);
      },
    );
  }

  Widget _buildPlaceholder(BuildContext context) {
    return widget.placeholder ??
        Container(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          alignment: Alignment.center,
          child: Icon(
            Icons.landscape_rounded,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        );
  }
}
