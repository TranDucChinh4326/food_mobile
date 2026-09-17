import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

/// High-performance local cache service for food data and images.
/// Enables offline-first, instant 0ms app startup, and minimal database/network usage.
class LocalCacheService {
  static const int maxImageCacheBytes = 150 * 1024 * 1024;
  static const Duration maxImageAge = Duration(days: 30);

  static Directory? _baseDataCacheDir;
  static Directory? _baseImageCacheDir;

  static Future<void> initialize() async {
    try {
      final support = await getApplicationSupportDirectory();
      final temporary = await getTemporaryDirectory();
      _baseDataCacheDir = Directory('${support.path}/data_cache');
      _baseImageCacheDir = Directory('${temporary.path}/image_cache');
      await _baseDataCacheDir!.create(recursive: true);
      await _baseImageCacheDir!.create(recursive: true);
      await pruneImageCache();
    } catch (_) {
      // The synchronous fallback getters keep the app usable on unsupported
      // platforms or when storage initialization temporarily fails.
    }
  }

  static Directory get _dataCacheDir {
    if (_baseDataCacheDir != null && _baseDataCacheDir!.existsSync()) {
      return _baseDataCacheDir!;
    }
    final dir = Directory(
      '${Directory.systemTemp.path}/food_mobile_data_cache',
    );
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    _baseDataCacheDir = dir;
    return dir;
  }

  static Directory get _imageCacheDir {
    if (_baseImageCacheDir != null && _baseImageCacheDir!.existsSync()) {
      return _baseImageCacheDir!;
    }
    final dir = Directory('${Directory.systemTemp.path}/food_mobile_img_cache');
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    _baseImageCacheDir = dir;
    return dir;
  }

  static File _getDataFile(String key) =>
      File('${_dataCacheDir.path}/$key.json');

  // ================= DATA CACHING (JSON) =================

  /// Save raw JSON data with current timestamp
  static Future<void> save(String key, String rawJson) async {
    try {
      final file = _getDataFile(key);
      final payload = jsonEncode({
        'savedAt': DateTime.now().millisecondsSinceEpoch,
        'data': rawJson,
      });
      await file.writeAsString(payload, flush: true);
    } catch (_) {}
  }

  /// Read cached raw JSON. Returns null if not exists or if maxAge exceeded.
  static String? read(String key, {Duration? maxAge}) {
    try {
      final file = _getDataFile(key);
      if (!file.existsSync()) return null;
      final content = file.readAsStringSync();
      final map = jsonDecode(content);
      if (map is! Map<String, dynamic>) return null;

      if (maxAge != null) {
        final savedAt = int.tryParse('${map['savedAt']}') ?? 0;
        final age = DateTime.now().millisecondsSinceEpoch - savedAt;
        if (age > maxAge.inMilliseconds) return null;
      }

      return map['data']?.toString();
    } catch (_) {
      return null;
    }
  }

  /// Check if cache file exists
  static bool has(String key) {
    try {
      return _getDataFile(key).existsSync();
    } catch (_) {
      return false;
    }
  }

  /// Check if cache is still fresh within maxAge duration
  static bool isFresh(String key, Duration maxAge) {
    try {
      final file = _getDataFile(key);
      if (!file.existsSync()) return false;
      final content = file.readAsStringSync();
      final map = jsonDecode(content);
      if (map is! Map<String, dynamic>) return false;
      final savedAt = int.tryParse('${map['savedAt']}') ?? 0;
      final age = DateTime.now().millisecondsSinceEpoch - savedAt;
      return age < maxAge.inMilliseconds;
    } catch (_) {
      return false;
    }
  }

  /// Check whether newly fetched JSON data differs from what is currently cached
  static bool hasChanged(String key, String newRawJson) {
    try {
      final current = read(key);
      if (current == null) return true;
      return current.trim() != newRawJson.trim();
    } catch (_) {
      return true;
    }
  }

  // ================= DISK IMAGE CACHING =================

  static String _urlToCacheFileName(String url) {
    var hash = 0xcbf29ce484222325;
    for (var i = 0; i < url.length; i++) {
      hash ^= url.codeUnitAt(i);
      hash = (hash * 0x100000001b3) & 0x7FFFFFFFFFFFFFFF;
    }
    final uri = Uri.tryParse(url);
    final segments = uri?.pathSegments ?? [];
    final lastSegment = segments.isNotEmpty ? segments.last : 'img';
    final cleanName = lastSegment.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    return '${hash.toRadixString(16)}_$cleanName';
  }

  static File getCachedImageFile(String url) {
    return File('${_imageCacheDir.path}/${_urlToCacheFileName(url)}');
  }

  static bool isImageCached(String url) {
    try {
      final file = getCachedImageFile(url);
      return file.existsSync() && file.lengthSync() > 0;
    } catch (_) {
      return false;
    }
  }

  static Future<void> saveImageBytes(String url, Uint8List bytes) async {
    try {
      if (bytes.isEmpty) return;
      final file = getCachedImageFile(url);
      await file.writeAsBytes(bytes, flush: true);
    } catch (_) {}
  }

  static Future<void> pruneImageCache() async {
    try {
      final directory = _imageCacheDir;
      final files = directory
          .listSync()
          .whereType<File>()
          .map((file) => (file: file, stat: file.statSync()))
          .toList();
      final cutoff = DateTime.now().subtract(maxImageAge);

      for (final entry in files.where(
        (entry) => entry.stat.modified.isBefore(cutoff),
      )) {
        await entry.file.delete().catchError((_) => entry.file);
      }

      final remaining =
          directory
              .listSync()
              .whereType<File>()
              .map((file) => (file: file, stat: file.statSync()))
              .toList()
            ..sort((a, b) => a.stat.modified.compareTo(b.stat.modified));
      var totalBytes = remaining.fold<int>(
        0,
        (total, entry) => total + entry.stat.size,
      );
      for (final entry in remaining) {
        if (totalBytes <= maxImageCacheBytes) break;
        await entry.file.delete();
        totalBytes -= entry.stat.size;
      }
    } catch (_) {}
  }
}
