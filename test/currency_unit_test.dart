import 'package:flutter_test/flutter_test.dart';
import 'package:shared_kit/models/enums.dart';
import 'package:shared_kit/utils/currency_utils.dart';
import 'package:shared_kit/utils/number_formatter.dart';

void main() {
  group('CurrencyUnit.fromValue', () {
    test('parses TOMAN/RIAL case-insensitively', () {
      expect(CurrencyUnit.fromValue('TOMAN'), CurrencyUnit.toman);
      expect(CurrencyUnit.fromValue('rial'), CurrencyUnit.rial);
      expect(CurrencyUnit.fromValue('Rial'), CurrencyUnit.rial);
    });

    test('falls back to toman for null/unknown values', () {
      expect(CurrencyUnit.fromValue(null), CurrencyUnit.toman);
      expect(CurrencyUnit.fromValue('USD'), CurrencyUnit.toman);
    });

    test('toJson round-trips through fromValue', () {
      for (final unit in CurrencyUnit.values) {
        expect(CurrencyUnit.fromValue(unit.toJson()), unit);
      }
    });
  });

  group('toDisplayAmount / toTomanAmount', () {
    test('toman unit is an identity conversion', () {
      expect(toDisplayAmount(1234567, CurrencyUnit.toman), 1234567);
      expect(toTomanAmount(1234567, CurrencyUnit.toman), 1234567);
    });

    test('rial unit multiplies/divides by 10', () {
      expect(toDisplayAmount(1000000, CurrencyUnit.rial), 10000000);
      expect(toTomanAmount(10000000, CurrencyUnit.rial), 1000000);
    });

    test('toTomanAmount floors non-multiple-of-10 rial values', () {
      expect(toTomanAmount(12345, CurrencyUnit.rial), 1234);
      expect(toTomanAmount(9, CurrencyUnit.rial), 0);
    });

    test('round trip is stable for exact multiples of 10', () {
      const toman = 42;
      final display = toDisplayAmount(toman, CurrencyUnit.rial);
      expect(toTomanAmount(display, CurrencyUnit.rial), toman);
    });
  });

  group('NumberFormatter unit-aware formatting', () {
    test('formatToman defaults to Toman, unchanged from pre-Rial behavior', () {
      expect(NumberFormatter.formatToman(50000000), '۵۰,۰۰۰,۰۰۰ تومان');
    });

    test('formatToman with rial unit multiplies by 10 and swaps the label', () {
      expect(
        NumberFormatter.formatToman(50000000, unit: CurrencyUnit.rial),
        '۵۰۰,۰۰۰,۰۰۰ ریال',
      );
    });

    test('formatShort omitted-unit output is unchanged (gold-trade regression guard)', () {
      expect(NumberFormatter.formatShort(50000000), '۵۰ میلیون');
      expect(NumberFormatter.formatShort(1500000), '۱.۵ میلیون');
      expect(NumberFormatter.formatShort(500000), '۵۰۰ هزار');
    });

    test('formatShort scales by unit multiplier: 1,000,000 Toman example', () {
      expect(NumberFormatter.formatShort(1000000), '۱ میلیون');
      expect(
        NumberFormatter.formatShort(1000000, unit: CurrencyUnit.rial),
        '۱۰ میلیون',
      );
    });

    test('numberToWords scales by unit and swaps the trailing label', () {
      expect(NumberFormatter.numberToWords(1000000), 'یک میلیون تومان');
      expect(
        NumberFormatter.numberToWords(1000000, unit: CurrencyUnit.rial),
        'ده میلیون ریال',
      );
    });

    test('numberToWords negative amounts keep the منفی prefix under rial', () {
      expect(
        NumberFormatter.numberToWords(-500, unit: CurrencyUnit.rial),
        'منفی پنج هزار ریال',
      );
    });
  });
}
