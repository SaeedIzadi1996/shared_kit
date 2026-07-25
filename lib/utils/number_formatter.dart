import 'package:flutter/widgets.dart';

import '../models/enums.dart';
import 'currency_utils.dart';

/// Digit/whitespace helpers on String, merged from both apps.
/// (gold-trade contributed `removeAllSpaces`; trust-chain contributed
/// `formattedPhone`. The digit converters were identical in both.)
extension StringDigitExt on String {
  static const _faDigits = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
  static const _arDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];

  String toEnglishDigits() {
    var result = this;
    for (int i = 0; i < 10; i++) {
      result = result.replaceAll(_faDigits[i], i.toString());
      result = result.replaceAll(_arDigits[i], i.toString());
    }
    return result;
  }

  String toPersianDigits() {
    var result = this;
    for (int i = 0; i < 10; i++) {
      result = result.replaceAll(i.toString(), _faDigits[i]);
    }
    return result;
  }

  String removeAllSpaces() => replaceAll(RegExp(r'\s+'), '');

  /// e.g. "09123456789" → "0912 345 6789"
  String get formattedPhone {
    String raw = replaceAll(RegExp(r'[^0-9]'), '');
    if (raw.length > 11) raw = raw.substring(0, 11);

    final buffer = StringBuffer();
    for (int i = 0; i < raw.length; i++) {
      if (i == 4 || i == 7) buffer.write(' ');
      buffer.write(raw[i]);
    }
    return buffer.toString();
  }
}

extension NumDigitExt on num {
  String toEnglishDigits() => toString().toEnglishDigits();
  String toPersianDigits() => toString().toPersianDigits();
}

class NumberFormatter {
  NumberFormatter._();

  // ─── Persian / English conversion ───────────────────────────────────────

  static const _persianDigits = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
  static const _englishDigits = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];

  static String toPersian(String text) {
    String result = text;
    for (int i = 0; i < 10; i++) {
      result = result.replaceAll(_englishDigits[i], _persianDigits[i]);
    }
    return result;
  }

  static String toEnglish(String text) {
    String result = text;
    for (int i = 0; i < 10; i++) {
      result = result.replaceAll(_persianDigits[i], _englishDigits[i]);
    }
    return result;
  }

  // ─── Format ─────────────────────────────────────────────────────────────

  /// عدد خام → رشته با جداکننده هزار (فارسی)
  /// مثال: 50000000 → '۵۰٬۰۰۰٬۰۰۰'
  static String format(int amount) {
    final formatted = amount.abs().toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
    return toPersian(formatted);
  }

  /// Like [format] but accepts any [num] and preserves a trailing minus sign
  /// (used by gold-trade dashboards where balances can be negative).
  static String formatNum(num amount) {
    final isNegative = amount < 0;
    final formatted = amount.abs().toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
    final result = toPersian(formatted);
    return isNegative ? '$result-' : result;
  }

  // Negative numbers need LTR alignment so the minus sign appears on the left.
  static TextAlign textAlignFor(num amount) =>
      amount < 0 ? TextAlign.left : TextAlign.right;

  /// رشته ورودی کاربر → رشته فرمت‌شده با جداکننده هزار
  /// (برای استفاده در TextFormField)
  static String formatInput(String value) {
    value = toEnglish(value).replaceAll(',', '').replaceAll('٬', '');
    if (value.isEmpty) return '';
    final number = int.tryParse(value);
    if (number == null) return value;
    return toPersian(
      number.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]},',
      ),
    );
  }

  /// رشته فرمت‌شده → عدد خام
  /// مثال: '۵۰٬۰۰۰٬۰۰۰' → 50000000
  static int? parse(String value) {
    final clean = toEnglish(value)
        .replaceAll(',', '')
        .replaceAll('٬', '')
        .trim();
    return int.tryParse(clean);
  }

  /// نمایش مبلغ با واحد پول
  /// مثال (تومان): 50000000 → '۵۰٬۰۰۰٬۰۰۰ تومان'
  /// مثال (ریال): 50000000 → '۵۰۰٬۰۰۰٬۰۰۰ ریال'
  static String formatToman(int amount, {CurrencyUnit unit = CurrencyUnit.toman}) =>
      '${format(toDisplayAmount(amount, unit))} ${unit.label}';

  /// نمایش مختصر مبلغ (amount همیشه به تومان است؛ unit فقط مقیاس نمایش را تغییر می‌دهد)
  /// مثال: 50000000 → '۵۰ میلیون' | 1500000 → '۱.۵ میلیون' | 500000 → '۵۰۰ هزار'
  static String formatShort(int amount, {CurrencyUnit unit = CurrencyUnit.toman}) {
    String formmatedResult;
    bool isNegative = false;
    if (amount < 0) {
      isNegative = true;
      amount = amount * (-1);
    }
    final displayAmount = toDisplayAmount(amount, unit);
    if (displayAmount >= 1000000000) {
      final value = displayAmount / 1000000000;
      final str = value == value.roundToDouble()
          ? value.toInt().toString()
          : value.toStringAsFixed(1);
      formmatedResult = '${toPersian(str)} میلیارد';
    } else if (displayAmount >= 1000000) {
      final value = displayAmount / 1000000;
      final str = value == value.roundToDouble()
          ? value.toInt().toString()
          : value.toStringAsFixed(1);
      formmatedResult = '${toPersian(str)} میلیون';
    } else if (displayAmount >= 1000) {
      final value = displayAmount / 1000;
      final str = value == value.roundToDouble()
          ? value.toInt().toString()
          : value.toStringAsFixed(1);
      formmatedResult = '${toPersian(str)} هزار';
    } else {
      return formatToman(isNegative ? -amount : amount, unit: unit);
    }

    if (isNegative) {
      formmatedResult = '- $formmatedResult';
    }

    return formmatedResult;
  }

  static String numberToWords(int amount, {CurrencyUnit unit = CurrencyUnit.toman}) {
    if (amount == 0) return 'صفر ${unit.label}';
    final isNegative = amount < 0;
    var displayAmount = toDisplayAmount(amount.abs(), unit);
    final parts = <String>[];
    if (displayAmount >= 1000000000) {
      parts.add('${_groupToWords(displayAmount ~/ 1000000000)} میلیارد');
      displayAmount %= 1000000000;
    }
    if (displayAmount >= 1000000) {
      parts.add('${_groupToWords(displayAmount ~/ 1000000)} میلیون');
      displayAmount %= 1000000;
    }
    if (displayAmount >= 1000) {
      parts.add('${_groupToWords(displayAmount ~/ 1000)} هزار');
      displayAmount %= 1000;
    }
    if (displayAmount > 0) parts.add(_groupToWords(displayAmount));
    final words = parts.join(' و ');
    return isNegative ? 'منفی $words ${unit.label}' : '$words ${unit.label}';
  }

  static String _groupToWords(int n) {
    const hundreds = ['', 'صد', 'دویست', 'سیصد', 'چهارصد', 'پانصد', 'ششصد', 'هفتصد', 'هشتصد', 'نهصد'];
    const tens = ['', 'ده', 'بیست', 'سی', 'چهل', 'پنجاه', 'شصت', 'هفتاد', 'هشتاد', 'نود'];
    const teens = ['ده', 'یازده', 'دوازده', 'سیزده', 'چهارده', 'پانزده', 'شانزده', 'هفده', 'هجده', 'نوزده'];
    const units = ['', 'یک', 'دو', 'سه', 'چهار', 'پنج', 'شش', 'هفت', 'هشت', 'نه'];
    final parts = <String>[];
    final h = n ~/ 100;
    final rem = n % 100;
    if (h > 0) parts.add(hundreds[h]);
    if (rem >= 10 && rem < 20) {
      parts.add(teens[rem - 10]);
    } else {
      if (rem ~/ 10 > 0) parts.add(tens[rem ~/ 10]);
      if (rem % 10 > 0) parts.add(units[rem % 10]);
    }
    return parts.join(' و ');
  }

  static String formatBankAccountNumber(String number, BankAccountType bankAccountType, {String spacer = ' ', bool convert2Persian = true}) {
    switch (bankAccountType) {
      case BankAccountType.account:
      case BankAccountType.card:
        return formatCardNumber(number, spacer: spacer, convert2Persian: convert2Persian);
      case BankAccountType.sheba:
        return formatSheba(number, spacer: spacer, convert2Persian: convert2Persian);
    }
  }

  /// Formats a card number with spaces every 4 digits
  /// e.g. "1234567890123456" → "1234 5678 9012 3456"
  static String formatCardNumber(String cardNumber, {String spacer = ' ', bool convert2Persian = true}) {
    final digits = cardNumber.replaceAll(RegExp(r'\D'), '');
    final buffer = StringBuffer();

    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(spacer);
      buffer.write(digits[i]);
    }

    return convert2Persian ? toPersian(buffer.toString()) : buffer.toString();
  }

  /// Formats an Iranian phone number with spaces after the 4th and 7th digits
  /// e.g. "09123456789" → "0912 345 6789"
  static String formatPhoneNumber(String phoneNumber, {bool convert2Persian = false}) {
    String digits = toEnglish(phoneNumber).replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length > 11) digits = digits.substring(0, 11);

    final buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i == 4 || i == 7) buffer.write(' ');
      buffer.write(digits[i]);
    }

    return convert2Persian ? toPersian(buffer.toString()) : buffer.toString();
  }

  /// Formats an Iranian IBAN (Sheba) number
  /// e.g. "IR062960000000100324200001" → "IR06 2960 0000 0010 0324 2000 01"
  static String formatSheba(String sheba, {String spacer = ' ', bool convert2Persian = true}) {
    String cleaned = sheba.toUpperCase().replaceAll(RegExp(r'\s'), '');
    // Auto-prepend IR if missing
    if (!cleaned.startsWith('IR')) {
      cleaned = 'IR$cleaned';
    }

    if (cleaned.length != 26) {
      throw FormatException(
        'Invalid Sheba number: must be 24 digits (or 26 characters with IR prefix).',
      );
    }

    final buffer = StringBuffer();
    for (int i = 0; i < cleaned.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(spacer);
      buffer.write(cleaned[i]);
    }
    return convert2Persian ? toPersian(buffer.toString()) : buffer.toString();
  }
}
