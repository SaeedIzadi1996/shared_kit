import 'package:flutter/services.dart';
import '../models/enums.dart';
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
    // digitIndex == 0 means "cursor belongs before the first digit" — the
    // loop below only ever matches seen >= 1, so that case must be handled
    // separately or it falls through to the `return text.length` below and
    // the cursor wrongly jumps to the end of the field.
    if (digitIndex <= 0) {
      for (int i = 0; i < text.length; i++) {
        if (RegExp(r'[0-9۰-۹]').hasMatch(text[i])) return i;
      }
      return text.length;
    }
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

    // delete on comma: a plain backspace removes exactly one character from
    // the *displayed* text, which can land on a ',' separator instead of a
    // digit. When that happens we additionally drop the digit just before
    // that comma, so a single backspace always removes exactly one digit.
    // `cursor` is where the caret was *before* the deletion, so the char
    // that was actually removed sits at `cursor - 1`, not `cursor`.
    if (oldValue.text.length > newValue.text.length &&
        oldValue.selection.start == oldValue.selection.end) {
      int cursor = oldValue.selection.start;
      if (cursor > 0 && oldValue.text[cursor - 1] == ',') {
        int digitIndex = _digitsBeforeCursor(oldValue.text, cursor - 1);
        if (digitIndex > 0 && digitIndex - 1 < raw.length) {
          raw = raw.substring(0, digitIndex - 1) + raw.substring(digitIndex);
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

/// Toman (stored/API truth) → value expressed in [unit], for display.
int toDisplayAmount(int tomanValue, CurrencyUnit unit) =>
    tomanValue * unit.multiplierFromToman;

/// Value typed/shown in [unit] → Toman (stored/API truth). Floors when the
/// display value isn't an exact multiple of the unit's multiplier — Toman
/// has no sub-unit, so a fractional Toman amount isn't representable.
int toTomanAmount(int displayValue, CurrencyUnit unit) =>
    displayValue ~/ unit.multiplierFromToman;

int? parseCurrency(String text, {bool allowNegative = true}) {
  if (text.isEmpty) return null;


  String normalized = text.replaceAll(',', '');

  normalized = normalized.toEnglishDigits();

  normalized = normalized.replaceAll(RegExp(r'[^0-9\-]'), '');

  if (!allowNegative && normalized.startsWith('-')) return null;

  return int.tryParse(normalized);
}
