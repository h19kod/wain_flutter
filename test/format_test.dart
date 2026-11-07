import 'package:flutter_test/flutter_test.dart';
import 'package:wain/format.dart';

void main() {
  test('numbers use Arabic digits and separators like ar-IQ', () {
    expect(arNumber(0), '٠');
    expect(arNumber(950), '٩٥٠');
    expect(arNumber(1250000), '١٬٢٥٠٬٠٠٠');
    expect(arNumber(2.5), '٢٫٥');
    expect(arNumber(3.0), '٣');
    expect(iqd(12000), '١٢٬٠٠٠ د.ع');
  });

  test('freshness wording', () {
    final now = DateTime(2026, 11, 7, 12);
    expect(freshness(now.subtract(const Duration(minutes: 20)), now: now), 'المحل أكد التوفر قبل أقل من ساعة');
    expect(freshness(now.subtract(const Duration(minutes: 70)), now: now), 'المحل أكد التوفر قبل ساعة');
    expect(freshness(now.subtract(const Duration(hours: 2)), now: now), 'المحل أكد التوفر قبل ساعتين');
    expect(freshness(now.subtract(const Duration(hours: 5)), now: now), 'المحل أكد التوفر قبل ٥ ساعات');
    expect(freshness(now.subtract(const Duration(hours: 13)), now: now), 'المحل أكد التوفر قبل ١٣ ساعة');
    expect(freshness(now.subtract(const Duration(days: 2)), now: now), 'المحل أكد التوفر قبل يومين');
    expect(freshness(now.subtract(const Duration(hours: 30)), now: now), 'المحل أكد التوفر أمس');
    expect(freshness(now.subtract(const Duration(days: 4)), now: now), 'المحل أكد التوفر قبل ٤ أيام');
  });

  test('clock time is 12-hour with ص and م', () {
    expect(clockTime(DateTime(2026, 1, 1, 15, 5)), '٣:٠٥ م');
    expect(clockTime(DateTime(2026, 1, 1, 0, 30)), '١٢:٣٠ ص');
  });
}
