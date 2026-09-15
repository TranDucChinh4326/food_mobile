import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

class AppImage extends StatelessWidget {
  const AppImage({
    super.key,
    required this.source,
    this.fit,
    this.errorBuilder,
    this.loadingBuilder,
  });

  final String source;
  final BoxFit? fit;
  final ImageErrorWidgetBuilder? errorBuilder;
  final ImageLoadingBuilder? loadingBuilder;

  Uint8List? _decodeDataImage() {
    if (!source.startsWith('data:image/')) return null;

    final separator = source.indexOf(',');
    if (separator < 0 || !source.substring(0, separator).endsWith(';base64')) {
      return null;
    }

    try {
      return base64Decode(source.substring(separator + 1));
    } on FormatException {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _decodeDataImage();
    if (bytes != null) {
      return Image.memory(
        bytes,
        fit: fit,
        gaplessPlayback: true,
        errorBuilder: errorBuilder,
      );
    }

    return Image.network(
      source,
      fit: fit,
      errorBuilder: errorBuilder,
      loadingBuilder: loadingBuilder,
    );
  }
}
