import 'package:flutter/services.dart';
import 'number_formatter.dart';

class CurrencyInputFormatter extends TextInputFormatter {
  final bool allowNegative;
  final bool outputPersian;

  CurrencyInputFormatter({
    this.allowNegative = true,
    this.outputPersian = true,
  });


  String _formatDigits(String digits) {
    if (digits.isEmpty) return '';

    final rev = digits.split('').reversed.toList();
    final buf = StringBuffer();
    for (int i = 0; i < rev.length; i++) {
      if (i != 0 && i % 3 == 0) buf.write(',');
      buf.write(rev[i]);
    }
    return buf.toString().split('').reversed.join();
  }

  int _digitsBeforeCursor(String text, int cursor) {
    int count = 0;
    for (int i = 0; i < cursor && i < text.length; i++) {
      if (RegExp(r'[0-9۰-۹٠-٩]').hasMatch(text[i])) count++;
    }
    return count;
  }

  int _cursorFromDigitIndex(String text, int digitIndex) {
    int seen = 0;
    for (int i = 0; i < text.length; i++) {
      if (RegExp(r'[0-9۰-۹]').hasMatch(text[i])) {
        seen++;
        if (seen == digitIndex) return i + 1;
      }
    }
    return text.length;
  }

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue;

    final newRaw = newValue.text.toEnglishDigits();
    final oldRaw = oldValue.text.toEnglishDigits();
    final oldWasNegative = oldRaw.contains('-');

    // در برخی صفحه‌کلیدهای عددی (مثلاً کیبورد سامسونگ) دکمه علامت منفی با
    // نقطه‌ی اعشار ترکیب شده و در عمل کاراکتر «.» ارسال می‌شود. چون این فیلد
    // اعشار را پشتیبانی نمی‌کند، نقطه‌ی تازه‌واردشده را به‌عنوان toggle کردن
    // علامت منفی تفسیر می‌کنیم.
    final dotJustTyped = allowNegative &&
        newRaw.contains('.') &&
        !oldRaw.contains('.');

    bool negative;
    if (!allowNegative) {
      negative = false;
    } else if (dotJustTyped) {
      negative = !oldWasNegative;
    } else {
      negative = newRaw.startsWith('-');
    }

    String raw = newRaw.replaceAll(RegExp(r'[^0-9]'), '');

    int digitCursor =
        _digitsBeforeCursor(newValue.text, newValue.selection.end);

    // delete on comma
    if (oldValue.text.length > newValue.text.length &&
        oldValue.selection.start == oldValue.selection.end) {
      int cursor = oldValue.selection.start;
      if (cursor < oldValue.text.length && oldValue.text[cursor] == ',') {
        int digitIndex = _digitsBeforeCursor(oldValue.text, cursor);
        if (digitIndex < raw.length) {
          raw = raw.substring(0, digitIndex) + raw.substring(digitIndex + 1);
        }
      }
    }

    String formatted = _formatDigits(raw);
    String finalText = negative ? "-$formatted" : formatted;

    if (outputPersian) {
      finalText = finalText.toPersianDigits();
    }

    final newCursor = _cursorFromDigitIndex(finalText, digitCursor);

    return TextEditingValue(
      text: finalText,
      selection: TextSelection.collapsed(offset: newCursor),
    );
  }
}

/// برای مقداردهی اولیه فرم (نمایش فارسی)
String formatCurrency(
  int value, {
  bool allowNegative = true,
  bool persian = true,
}) {
  final f = CurrencyInputFormatter(
    allowNegative: allowNegative,
    outputPersian: persian,
  );
  return f
      .formatEditUpdate(
        const TextEditingValue(),
        TextEditingValue(text: value.toString()),
      )
      .text;
}

int? parseCurrency(String text, {bool allowNegative = true}) {
  if (text.isEmpty) return null;


  String normalized = text.replaceAll(',', '');

  normalized = normalized.toEnglishDigits();

  normalized = normalized.replaceAll(RegExp(r'[^0-9\-]'), '');

  if (!allowNegative && normalized.startsWith('-')) return null;

  return int.tryParse(normalized);
}
