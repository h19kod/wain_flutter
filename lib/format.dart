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

String freshness(DateTime confirmed, {DateTime? now}) {
  final hours = (now ?? DateTime.now()).difference(confirmed).inMinutes / 60;
  if (hours < 1) return 'المحل أكد التوفر قبل أقل من ساعة';
  if (hours < 24) return 'المحل أكد التوفر قبل ${arNumber(hours.round())} ساعة';
  final days = (hours / 24).round();
  return days == 1 ? 'المحل أكد التوفر أمس' : 'المحل أكد التوفر قبل ${arNumber(days)} أيام';
}

String clockTime(DateTime time) {
  final local = time.toLocal();
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  return '${arDigits('$hour:$minute')} ${local.hour < 12 ? 'ص' : 'م'}';
}
