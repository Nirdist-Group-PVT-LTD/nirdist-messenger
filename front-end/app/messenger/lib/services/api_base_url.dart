String normalizeApiBaseUrl(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return trimmed;
  }

  final uri = Uri.parse(trimmed);
  final normalizedPath = uri.path.replaceAll(RegExp(r'/+$'), '');
  final pathSegments = normalizedPath.split('/').where((segment) => segment.isNotEmpty).toList();
  final resolvedPath = pathSegments.isEmpty
      ? '/api'
      : (pathSegments.last == 'api' ? normalizedPath : '$normalizedPath/api');

  return uri.replace(path: resolvedPath).toString();
}