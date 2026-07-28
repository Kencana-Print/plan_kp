class DateFormatter {
  static final RegExp _yyyyMmDd = RegExp(r'^\d{4}-\d{2}-\d{2}$');
  static final RegExp _ddMmYyyyDash = RegExp(r'^\d{2}-\d{2}-\d{4}$');
  static final RegExp _ddMmYyyySlash = RegExp(r'^\d{2}/\d{2}/\d{4}$');

  static String toDisplay(String? value, {String fallback = '-'}) {
    if (value == null || value.trim().isEmpty) return fallback;
    final raw = value.trim();

    if (_ddMmYyyyDash.hasMatch(raw)) return raw;
    if (_ddMmYyyySlash.hasMatch(raw)) {
      return raw.replaceAll('/', '-');
    }

    final datePart = raw.contains('T') ? raw.split('T').first : raw;
    if (_yyyyMmDd.hasMatch(datePart)) {
      final parts = datePart.split('-');
      return '${parts[2]}-${parts[1]}-${parts[0]}';
    }

    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    return toDisplayFromDate(parsed, fallback: fallback);
  }

  static String toDisplayFull(String? value, {String fallback = '-'}) {
    return toDisplay(value, fallback: fallback);
  }

  static String toDisplayFromDate(DateTime? date, {String fallback = ''}) {
    if (date == null) return fallback;
    final dd = date.day.toString().padLeft(2, '0');
    final mm = date.month.toString().padLeft(2, '0');
    final yyyy = date.year.toString();
    return '$dd-$mm-$yyyy';
  }

  static String getDayNameIndonesian(int weekday) {
    const days = [
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
      'Minggu',
    ];
    if (weekday >= 1 && weekday <= 7) {
      return days[weekday - 1];
    }
    return '';
  }

  static String toDisplayDateTime(DateTime? date, {String fallback = ''}) {
    if (date == null) return fallback;
    final dateLocal = date.toLocal();
    final dayName = getDayNameIndonesian(dateLocal.weekday);
    final dd = dateLocal.day.toString().padLeft(2, '0');
    final mm = dateLocal.month.toString().padLeft(2, '0');
    final yyyy = dateLocal.year.toString();
    return '$dayName, $dd-$mm-$yyyy';
  }

  static String formatMessageDates(String message) {
    if (message.isEmpty) return message;
    var res = message.replaceAllMapped(RegExp(r'\b(\d{4})-(\d{2})-(\d{2})\b'), (match) {
      final yyyy = match.group(1);
      final mm = match.group(2);
      final dd = match.group(3);
      return '$dd-$mm-$yyyy';
    });
    res = res.replaceAllMapped(RegExp(r'\b(\d{2})/(\d{2})/(\d{4})\b'), (match) {
      final dd = match.group(1);
      final mm = match.group(2);
      final yyyy = match.group(3);
      return '$dd-$mm-$yyyy';
    });
    return res;
  }

  static String toApi(DateTime? date, {String fallback = ''}) {
    if (date == null) return fallback;
    final yyyy = date.year.toString();
    final mm = date.month.toString().padLeft(2, '0');
    final dd = date.day.toString().padLeft(2, '0');
    return '$yyyy-$mm-$dd';
  }
}
