import 'api_config.dart';

String? normalizeRasterImageUrl(Object? rawValue) {
  final value = rawValue?.toString().trim() ?? '';
  if (value.isEmpty || value.toLowerCase().endsWith('.svg')) return null;

  final uri = Uri.tryParse(value);
  if (uri != null &&
      (uri.scheme == 'http' || uri.scheme == 'https') &&
      uri.host.isNotEmpty) {
    return value;
  }

  final normalizedPath = value.startsWith('/') ? value : '/$value';
  if (normalizedPath.startsWith('/uploads/')) {
    return '${ApiConfig.originUrl}$normalizedPath';
  }

  return null;
}
