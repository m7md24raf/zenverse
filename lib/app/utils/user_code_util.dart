/// Normalizes friend codes to `ZEN-XXXX` (uppercase, trimmed, no spaces).
String normalizeUserCode(String raw) {
  var normalized = raw.trim().toUpperCase().replaceAll(' ', '');
  if (normalized.isEmpty) return '';
  if (!normalized.startsWith('ZEN-')) {
    normalized = 'ZEN-$normalized';
  }
  return normalized;
}
