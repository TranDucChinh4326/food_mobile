import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../services/local_cache_service.dart';
import 'skeleton_loader.dart';

class AppImage extends StatelessWidget {
  const AppImage({
    super.key,
    this.source,
    this.url,
    this.fit,
    this.cacheWidth = 450,
    this.errorBuilder,
    this.loadingBuilder,
  }) : assert(
         source != null || url != null,
         'Either source or url must be provided',
       );

  final String? source;
  final String? url;
  final BoxFit? fit;
  final int? cacheWidth;
  final ImageErrorWidgetBuilder? errorBuilder;
  final ImageLoadingBuilder? loadingBuilder;

  String get _effectiveSource => (source ?? url ?? '').trim();

  Uint8List? _decodeDataImage() {
    final s = _effectiveSource;
    if (!s.startsWith('data:image/')) return null;

    final separator = s.indexOf(',');
    if (separator < 0 || !s.substring(0, separator).endsWith(';base64')) {
      return null;
    }

    try {
      return base64Decode(s.substring(separator + 1));
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

    final s = _effectiveSource;
    if (!s.startsWith('http')) {
      return errorBuilder?.call(context, 'Invalid source', null) ??
          const SizedBox.shrink();
    }

    return _DiskCachedNetworkImage(
      source: s,
      fit: fit,
      cacheWidth: cacheWidth,
      errorBuilder: errorBuilder,
      loadingBuilder: loadingBuilder,
    );
  }
}

class _DiskCachedNetworkImage extends StatefulWidget {
  const _DiskCachedNetworkImage({
    required this.source,
    this.fit,
    this.cacheWidth,
    this.errorBuilder,
    this.loadingBuilder,
  });

  final String source;
  final BoxFit? fit;
  final int? cacheWidth;
  final ImageErrorWidgetBuilder? errorBuilder;
  final ImageLoadingBuilder? loadingBuilder;

  @override
  State<_DiskCachedNetworkImage> createState() =>
      _DiskCachedNetworkImageState();
}

class _DiskCachedNetworkImageState extends State<_DiskCachedNetworkImage> {
  static final Map<String, Future<File?>> _downloads = {};

  File? _cachedFile;
  bool _isDownloading = false;
  bool _downloadFailed = false;

  @override
  void initState() {
    super.initState();
    _checkAndLoad();
  }

  @override
  void didUpdateWidget(_DiskCachedNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source) {
      _checkAndLoad();
    }
  }

  void _checkAndLoad() {
    _downloadFailed = false;
    if (LocalCacheService.isImageCached(widget.source)) {
      _cachedFile = LocalCacheService.getCachedImageFile(widget.source);
    } else {
      _cachedFile = null;
      _downloadToCache();
    }
  }

  Future<void> _downloadToCache() async {
    if (_isDownloading) return;
    _isDownloading = true;
    try {
      final file = await _downloads.putIfAbsent(
        widget.source,
        () => _download(widget.source),
      );
      if (mounted) {
        setState(() {
          _cachedFile = file;
          _downloadFailed = file == null;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _downloadFailed = true);
    } finally {
      _downloads.remove(widget.source);
      _isDownloading = false;
    }
  }

  static Future<File?> _download(String source) async {
    final response = await http
        .get(Uri.parse(source))
        .timeout(const Duration(seconds: 25));
    if (response.statusCode < 200 || response.statusCode >= 300) return null;
    await LocalCacheService.saveImageBytes(source, response.bodyBytes);
    final file = LocalCacheService.getCachedImageFile(source);
    return file.existsSync() && file.lengthSync() > 0 ? file : null;
  }

  @override
  Widget build(BuildContext context) {
    if (_cachedFile != null && _cachedFile!.existsSync()) {
      return Image.file(
        _cachedFile!,
        fit: widget.fit,
        cacheWidth: widget.cacheWidth,
        gaplessPlayback: true,
        errorBuilder: widget.errorBuilder,
      );
    }

    if (!_downloadFailed) {
      return const ImageShimmerSkeleton();
    }

    return Image.network(
      widget.source,
      fit: widget.fit,
      cacheWidth: widget.cacheWidth,
      gaplessPlayback: true,
      errorBuilder: widget.errorBuilder,
      loadingBuilder:
          widget.loadingBuilder ??
          (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return const ImageShimmerSkeleton();
          },
    );
  }
}
