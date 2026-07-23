import 'package:flutter/services.dart';

import 'number_formatter.dart';

class PhoneNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;

    String raw = newValue.text.toEnglishDigits();
    raw = raw.replaceAll(RegExp(r'[^0-9]'), '');

    // Limit to 11 digits
    if (raw.length > 11) raw = raw.substring(0, 11);

    // Track cursor by digit index
    int digitCursor = _digitsBeforeCursor(newValue.text, newValue.selection.end);

    // Handle delete-on-separator (space)
    if (oldValue.text.length > newValue.text.length &&
        oldValue.selection.start == oldValue.selection.end) {
      int cursor = oldValue.selection.start;
      if (cursor < oldValue.text.length && oldValue.text[cursor] == ' ') {
        int digitIndex = _digitsBeforeCursor(oldValue.text, cursor);
        if (digitIndex < raw.length) {
          raw = raw.substring(0, digitIndex) + raw.substring(digitIndex + 1);
        }
      }
    }

    final formatted = _formatPhone(raw);

    final newCursor = _cursorFromDigitIndex(formatted, digitCursor);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: newCursor),
    );
  }

  String _formatPhone(String digits) {
    if (digits.isEmpty) return '';

    final buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i == 4 || i == 7) buffer.write(' ');
      buffer.write(digits[i]);
    }
    return buffer.toString();
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
}