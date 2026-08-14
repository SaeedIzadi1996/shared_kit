// test/jalali_date_test.dart
//
// مقادیرِ مرجع مستقیماً از کتابخانه‌ی پایتونِ `jdatetime` (تست‌شده) گرفته شده‌اند
// تا JalaliDate با یک منبعِ مستقل و معتبر تطبیق داده شود، نه فقط با خودش.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_kit/utils/jalali_date.dart';

void main() {
  group('JalaliDate.fromGregorian — تطبیق با jdatetime', () {
    final cases = <(DateTime, int, int, int, int)>[
      // (gregorian, jYear, jMonth, jDay, weekday 0=Sat..6=Fri)
      (DateTime.utc(2026, 8, 14), 1405, 5, 23, 6),
      (DateTime.utc(2024, 3, 20), 1403, 1, 1, 4),
      (DateTime.utc(2025, 3, 20), 1403, 12, 30, 5),
      (DateTime.utc(2020, 3, 20), 1399, 1, 1, 6),
      (DateTime.utc(2021, 3, 21), 1400, 1, 1, 1),
      (DateTime.utc(2024, 1, 1), 1402, 10, 11, 2),
      (DateTime.utc(2000, 1, 1), 1378, 10, 11, 0),
      (DateTime.utc(2099, 12, 31), 1478, 10, 11, 5),
      (DateTime.utc(2026, 12, 21), 1405, 9, 30, 2),
      (DateTime.utc(2027, 3, 20), 1405, 12, 29, 0),
    ];

    for (final (g, jy, jm, jd, wd) in cases) {
      test('${g.toIso8601String().split('T').first} -> $jy-$jm-$jd (weekday=$wd)', () {
        final j = JalaliDate.fromGregorian(g);
        expect(j.year, jy);
        expect(j.month, jm);
        expect(j.day, jd);
        expect(j.weekday, wd);
      });
    }
  });

  test('round-trip: Gregorian -> Jalali -> Gregorian', () {
    for (final g in [
      DateTime.utc(2026, 8, 14),
      DateTime.utc(2024, 2, 29), // leap-year Gregorian date
      DateTime.utc(2000, 1, 1),
      DateTime.utc(2099, 12, 31),
    ]) {
      final back = JalaliDate.fromGregorian(g).toGregorian().toUtc();
      expect(DateTime.utc(back.year, back.month, back.day), g);
    }
  });

  test('leap year: 1403 is leap (esfand=30), 1404 is not (esfand=29)', () {
    // 1403-12-30 exists (2025-03-20 above maps to it) => 1403 leap.
    expect(JalaliDate.isLeapYear(1403), isTrue);
    expect(JalaliDate.daysInMonth(1403, 12), 30);
    expect(JalaliDate.isLeapYear(1404), isFalse);
    expect(JalaliDate.daysInMonth(1404, 12), 29);
  });

  test('daysInMonth: months 1-6 = 31, 7-11 = 30', () {
    for (var m = 1; m <= 6; m++) {
      expect(JalaliDate.daysInMonth(1405, m), 31);
    }
    for (var m = 7; m <= 11; m++) {
      expect(JalaliDate.daysInMonth(1405, m), 30);
    }
  });

  test('addDays crosses month/year boundary correctly', () {
    final j = JalaliDate(1403, 12, 28); // near leap year-end
    final plus5 = j.addDays(5);
    expect(plus5, JalaliDate(1404, 1, 3));
  });

  test('compareTo / isBefore / isAfter', () {
    final a = JalaliDate(1405, 5, 23);
    final b = JalaliDate(1405, 6, 1);
    expect(a.isBefore(b), isTrue);
    expect(b.isAfter(a), isTrue);
  });
}
