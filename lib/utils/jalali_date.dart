// lib/utils/jalali_date.dart
//
// تبدیل و محاسباتِ تقویمِ شمسی (جلالی) ↔ میلادی.
//
// به‌جای پیاده‌سازیِ الگوریتمِ نجومیِ سال‌کبیسه (که دستی نوشتنش پرخطاست)، از یک
// جدولِ lookup برای «۱ فروردینِ هر سال» استفاده می‌شود — این جدول مستقیماً از
// کتابخانه‌ی پایتونِ `jdatetime` (که پیاده‌سازیِ تست‌شده و مرجع دارد) تولید شده و
// سال‌های شمسیِ ۱۲۰۰ تا ۱۵۰۰ (میلادیِ حدودِ ۱۸۲۱ تا ۲۱۲۱) را می‌پوشاند — حدود ۳۰۰
// سال، بیشتر از هر نیازِ عملیِ این اپ. طولِ ماه‌های ۱ تا ۱۱ همیشه ثابت است
// (۳۱،۳۱،۳۱،۳۱،۳۱،۳۱،۳۰،۳۰،۳۰،۳۰،۳۰)؛ فقط ماهِ ۱۲ بسته به کبیسه‌بودنِ سال ۲۹ یا
// ۳۰ روز دارد، که خودش از تفاضلِ دو ردیفِ متوالیِ جدول محاسبه می‌شود (نه یک قاعده‌ی
// جداگانه) — پس این پیاده‌سازی نمی‌تواند با قاعده‌ی کبیسه ناسازگار شود.
//
// این ماژول فقط برای *نمایش*/انتخابِ تاریخ در UI است. تصمیمِ نهاییِ «آیا الان
// زمانِ اجرای پاک‌سازیِ خودکار است» همیشه سمتِ بک‌اند (Python + jdatetime) گرفته
// می‌شود — همان کتابخانه‌ای که این جدول از آن تولید شده، پس دو طرف هرگز روی
// مرزِ یک روز اختلاف پیدا نمی‌کنند.

/// (gregorianYear, gregorianMonth, gregorianDay) برای ۱ فروردینِ سال‌های شمسیِ
/// ۱۲۰۰ تا ۱۵۰۰، به‌ترتیب. ایندکس ۰ = سالِ ۱۲۰۰.
const List<int> _nowruzTable = [
  1821,3,21, 1822,3,21, 1823,3,22, 1824,3,21, 1825,3,21, 1826,3,21, 1827,3,22, 1828,3,21, 1829,3,21, 1830,3,21,
  1831,3,21, 1832,3,21, 1833,3,21, 1834,3,21, 1835,3,21, 1836,3,21, 1837,3,21, 1838,3,21, 1839,3,21, 1840,3,21,
  1841,3,21, 1842,3,21, 1843,3,21, 1844,3,21, 1845,3,21, 1846,3,21, 1847,3,21, 1848,3,21, 1849,3,21, 1850,3,21,
  1851,3,21, 1852,3,21, 1853,3,21, 1854,3,21, 1855,3,21, 1856,3,21, 1857,3,21, 1858,3,21, 1859,3,21, 1860,3,21,
  1861,3,21, 1862,3,21, 1863,3,21, 1864,3,20, 1865,3,21, 1866,3,21, 1867,3,21, 1868,3,20, 1869,3,21, 1870,3,21,
  1871,3,21, 1872,3,20, 1873,3,21, 1874,3,21, 1875,3,21, 1876,3,20, 1877,3,21, 1878,3,21, 1879,3,21, 1880,3,20,
  1881,3,21, 1882,3,21, 1883,3,21, 1884,3,20, 1885,3,21, 1886,3,21, 1887,3,21, 1888,3,20, 1889,3,21, 1890,3,21,
  1891,3,21, 1892,3,20, 1893,3,21, 1894,3,21, 1895,3,21, 1896,3,20, 1897,3,20, 1898,3,21, 1899,3,21, 1900,3,21,
  1901,3,21, 1902,3,22, 1903,3,22, 1904,3,21, 1905,3,21, 1906,3,22, 1907,3,22, 1908,3,21, 1909,3,21, 1910,3,22,
  1911,3,22, 1912,3,21, 1913,3,21, 1914,3,22, 1915,3,22, 1916,3,21, 1917,3,21, 1918,3,22, 1919,3,22, 1920,3,21,
  1921,3,21, 1922,3,22, 1923,3,22, 1924,3,21, 1925,3,21, 1926,3,22, 1927,3,22, 1928,3,21, 1929,3,21, 1930,3,21,
  1931,3,22, 1932,3,21, 1933,3,21, 1934,3,21, 1935,3,22, 1936,3,21, 1937,3,21, 1938,3,21, 1939,3,22, 1940,3,21,
  1941,3,21, 1942,3,21, 1943,3,22, 1944,3,21, 1945,3,21, 1946,3,21, 1947,3,22, 1948,3,21, 1949,3,21, 1950,3,21,
  1951,3,22, 1952,3,21, 1953,3,21, 1954,3,21, 1955,3,22, 1956,3,21, 1957,3,21, 1958,3,21, 1959,3,22, 1960,3,21,
  1961,3,21, 1962,3,21, 1963,3,21, 1964,3,21, 1965,3,21, 1966,3,21, 1967,3,21, 1968,3,21, 1969,3,21, 1970,3,21,
  1971,3,21, 1972,3,21, 1973,3,21, 1974,3,21, 1975,3,21, 1976,3,21, 1977,3,21, 1978,3,21, 1979,3,21, 1980,3,21,
  1981,3,21, 1982,3,21, 1983,3,21, 1984,3,21, 1985,3,21, 1986,3,21, 1987,3,21, 1988,3,21, 1989,3,21, 1990,3,21,
  1991,3,21, 1992,3,21, 1993,3,21, 1994,3,21, 1995,3,21, 1996,3,20, 1997,3,21, 1998,3,21, 1999,3,21, 2000,3,20,
  2001,3,21, 2002,3,21, 2003,3,21, 2004,3,20, 2005,3,21, 2006,3,21, 2007,3,21, 2008,3,20, 2009,3,21, 2010,3,21,
  2011,3,21, 2012,3,20, 2013,3,21, 2014,3,21, 2015,3,21, 2016,3,20, 2017,3,21, 2018,3,21, 2019,3,21, 2020,3,20,
  2021,3,21, 2022,3,21, 2023,3,21, 2024,3,20, 2025,3,21, 2026,3,21, 2027,3,21, 2028,3,20, 2029,3,20, 2030,3,21,
  2031,3,21, 2032,3,20, 2033,3,20, 2034,3,21, 2035,3,21, 2036,3,20, 2037,3,20, 2038,3,21, 2039,3,21, 2040,3,20,
  2041,3,20, 2042,3,21, 2043,3,21, 2044,3,20, 2045,3,20, 2046,3,21, 2047,3,21, 2048,3,20, 2049,3,20, 2050,3,21,
  2051,3,21, 2052,3,20, 2053,3,20, 2054,3,21, 2055,3,21, 2056,3,20, 2057,3,20, 2058,3,21, 2059,3,21, 2060,3,20,
  2061,3,20, 2062,3,20, 2063,3,21, 2064,3,20, 2065,3,20, 2066,3,20, 2067,3,21, 2068,3,20, 2069,3,20, 2070,3,20,
  2071,3,21, 2072,3,20, 2073,3,20, 2074,3,20, 2075,3,21, 2076,3,20, 2077,3,20, 2078,3,20, 2079,3,21, 2080,3,20,
  2081,3,20, 2082,3,20, 2083,3,21, 2084,3,20, 2085,3,20, 2086,3,20, 2087,3,21, 2088,3,20, 2089,3,20, 2090,3,20,
  2091,3,21, 2092,3,20, 2093,3,20, 2094,3,20, 2095,3,20, 2096,3,20, 2097,3,20, 2098,3,20, 2099,3,20, 2100,3,21,
  2101,3,21, 2102,3,21, 2103,3,21, 2104,3,21, 2105,3,21, 2106,3,21, 2107,3,21, 2108,3,21, 2109,3,21, 2110,3,21,
  2111,3,21, 2112,3,21, 2113,3,21, 2114,3,21, 2115,3,21, 2116,3,21, 2117,3,21, 2118,3,21, 2119,3,21, 2120,3,21,
  2121,3,21,
];

const int _tableStartJalaliYear = 1200;

const List<String> jalaliMonthNames = [
  'فروردین', 'اردیبهشت', 'خرداد', 'تیر', 'مرداد', 'شهریور',
  'مهر', 'آبان', 'آذر', 'دی', 'بهمن', 'اسفند',
];

/// ۰=شنبه..۶=جمعه (مطابقِ همان قراردادی که سمتِ بک‌اند برای
/// amount_shred_weekday/account_info_shred_weekday استفاده می‌شود).
const List<String> jalaliWeekdayNames = [
  'شنبه', 'یکشنبه', 'دوشنبه', 'سه‌شنبه', 'چهارشنبه', 'پنجشنبه', 'جمعه',
];

class JalaliDate implements Comparable<JalaliDate> {
  final int year;
  final int month; // 1..12
  final int day; // 1..daysInMonth

  const JalaliDate(this.year, this.month, this.day);

  static DateTime _nowruzGregorian(int jalaliYear) {
    final idx = jalaliYear - _tableStartJalaliYear;
    if (idx < 0 || idx * 3 + 2 >= _nowruzTable.length) {
      throw RangeError('سالِ شمسیِ $jalaliYear خارج از بازهٔ پشتیبانی‌شده (۱۲۰۰-۱۵۰۰) است');
    }
    return DateTime.utc(
      _nowruzTable[idx * 3],
      _nowruzTable[idx * 3 + 1],
      _nowruzTable[idx * 3 + 2],
    );
  }

  /// طولِ روزهایِ سالِ شمسیِ [jalaliYear] (۳۶۵ یا ۳۶۶) — از تفاضلِ ۱ فروردینِ
  /// این سال و سالِ بعد، نه یک قاعده‌ی جداگانه.
  static int _yearLength(int jalaliYear) =>
      _nowruzGregorian(jalaliYear + 1).difference(_nowruzGregorian(jalaliYear)).inDays;

  static bool isLeapYear(int jalaliYear) => _yearLength(jalaliYear) == 366;

  /// طولِ ماهِ [month] (۱..۱۲) در سالِ [year].
  static int daysInMonth(int year, int month) {
    if (month <= 6) return 31;
    if (month <= 11) return 30;
    return isLeapYear(year) ? 30 : 29;
  }

  factory JalaliDate.fromGregorian(DateTime g) {
    final gUtc = DateTime.utc(g.year, g.month, g.day);
    // حدسِ اولیه: سالِ شمسی معمولاً برابرِ gregorianYear - 621 یا 622 است.
    int guess = gUtc.year - 622;
    while (_nowruzGregorian(guess).isAfter(gUtc)) {
      guess--;
    }
    while (!_nowruzGregorian(guess + 1).isAfter(gUtc)) {
      guess++;
    }
    final dayOfYear = gUtc.difference(_nowruzGregorian(guess)).inDays; // 0-based
    int month = 1;
    int remaining = dayOfYear;
    while (true) {
      final len = daysInMonth(guess, month);
      if (remaining < len) break;
      remaining -= len;
      month++;
    }
    return JalaliDate(guess, month, remaining + 1);
  }

  static JalaliDate now() => JalaliDate.fromGregorian(DateTime.now());

  DateTime toGregorian() {
    var offset = 0;
    for (var m = 1; m < month; m++) {
      offset += daysInMonth(year, m);
    }
    offset += day - 1;
    return _nowruzGregorian(year).add(Duration(days: offset)).toLocal();
  }

  /// ۰=شنبه..۶=جمعه.
  int get weekday {
    // DateTime.weekday: 1=دوشنبه..7=یکشنبه (میلادی/ISO). تبدیل به قراردادِ شمسی:
    final dwIso = toGregorian().weekday; // 1=Mon..7=Sun
    // Sat=0 => Mon=2, Tue=3, Wed=4, Thu=5, Fri=6, Sat=0(=7%7), Sun=1
    return (dwIso + 1) % 7;
  }

  String get weekdayName => jalaliWeekdayNames[weekday];
  String get monthName => jalaliMonthNames[month - 1];

  JalaliDate addDays(int days) => JalaliDate.fromGregorian(toGregorian().add(Duration(days: days)));

  int differenceInDays(JalaliDate other) => toGregorian().difference(other.toGregorian()).inDays;

  /// ۱ فروردینِ همین سال.
  JalaliDate get startOfYear => JalaliDate(year, 1, 1);

  @override
  int compareTo(JalaliDate other) => toGregorian().compareTo(other.toGregorian());

  bool isBefore(JalaliDate other) => compareTo(other) < 0;
  bool isAfter(JalaliDate other) => compareTo(other) > 0;

  @override
  bool operator ==(Object other) =>
      other is JalaliDate && year == other.year && month == other.month && day == other.day;

  @override
  int get hashCode => Object.hash(year, month, day);

  /// مثلاً «۲۳ مرداد ۱۴۰۵».
  String format() => '$day $monthName $year';

  @override
  String toString() =>
      '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
}
