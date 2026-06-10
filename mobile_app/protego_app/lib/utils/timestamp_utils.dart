/// Aceita ISO 8601, timestamps com espaço e timezone +00 / +00:00.
///
/// Strings **sem** fuso (ex.: `2026-06-09T21:30:00` do `datetime.now()` da IA)
/// são horário local e não devem receber sufixo `Z`.
DateTime? parseApiTimestamp(String raw) {
  try {
    var s = raw.trim();
    if (s.isEmpty) return null;

    if (s.contains(' ') && !s.contains('T')) {
      s = s.replaceFirst(' ', 'T');
    }

    // Backend às vezes envia "+00" em vez de "+00:00".
    final tzShort = RegExp(r'([+-]\d{2})$');
    if (tzShort.hasMatch(s)) {
      s = s.replaceFirstMapped(tzShort, (m) => '${m.group(1)!}:00');
    }

    final hasOffset =
        s.endsWith('Z') || RegExp(r'[+-]\d{2}:\d{2}$').hasMatch(s);

    if (hasOffset) {
      return DateTime.parse(s).toLocal();
    }

    return DateTime.parse(s);
  } catch (_) {
    return null;
  }
}

String formatApiTimestamp(String raw) {
  final dt = parseApiTimestamp(raw);
  if (dt == null) return raw;
  return '${dt.day.toString().padLeft(2, '0')}/'
      '${dt.month.toString().padLeft(2, '0')}/'
      '${dt.year} '
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}:'
      '${dt.second.toString().padLeft(2, '0')}';
}

bool timestampRecente(String raw, {required int minutos}) {
  final dt = parseApiTimestamp(raw);
  if (dt == null) return false;
  return DateTime.now().difference(dt).inMinutes <= minutos;
}
