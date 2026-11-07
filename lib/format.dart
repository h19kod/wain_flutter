const _digits = '٠١٢٣٤٥٦٧٨٩';

/// Eastern Arabic digits, as the web app shows them through toLocaleString("ar-IQ").
String arDigits(String value) => value.replaceAllMapped(RegExp('[0-9]'), (m) => _digits[int.parse(m[0]!)]);

String arNumber(num value) {
  final negative = value < 0;
  final text = value.abs() is int || value == value.roundToDouble()
      ? value.abs().round().toString()
      : value.abs().toStringAsFixed(1);
  final [whole, ...fraction] = text.split('.');
  final grouped = whole.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '٬');
  return arDigits('${negative ? '-' : ''}$grouped${fraction.isEmpty ? '' : '٫${fraction.first}'}');
}

String iqd(int value) => '${arNumber(value)} د.ع';

/// "ساعة، ساعتين، ٣ ساعات، ١١ ساعة": Arabic counts change the noun after 1, 2 and 3–10.
String counted(int n, String one, String two, String few, String many) => switch (n) {
      1 => one,
      2 => two,
      >= 3 && <= 10 => '${arNumber(n)} $few',
      _ => '${arNumber(n)} $many',
    };

String ago(DateTime then, {DateTime? now}) {
  final hours = (now ?? DateTime.now()).difference(then).inMinutes / 60;
  if (hours < 1) return 'قبل أقل من ساعة';
  if (hours < 24) return 'قبل ${counted(hours.round(), 'ساعة', 'ساعتين', 'ساعات', 'ساعة')}';
  final days = (hours / 24).round();
  return days == 1 ? 'أمس' : 'قبل ${counted(days, 'يوم', 'يومين', 'أيام', 'يوم')}';
}

String freshness(DateTime confirmed, {DateTime? now}) => 'المحل أكد التوفر ${ago(confirmed, now: now)}';

String clockTime(DateTime time) {
  final local = time.toLocal();
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  return '${arDigits('$hour:$minute')} ${local.hour < 12 ? 'ص' : 'م'}';
}
