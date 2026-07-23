import 'package:flutter/services.dart';

class NoPersianCharsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Check if the new value contains any Persian characters
    if (containsPersianChars(newValue.text)) {
      // If it does, return the old value to prevent the change
      return oldValue;
    }
    // Otherwise, allow the change
    return newValue;
  }

  bool containsPersianChars(String text) {
    // Regular expression to match Persian characters (Unicode range U+0600 to U+06FF)
    // This range includes Arabic characters as well, which are often used interchangeably or are present in Persian text.
    // If you need to be *strictly* Persian and exclude all Arabic, a more complex regex might be needed,
    // but this is usually sufficient for practical purposes.
    final persianRegex = RegExp(r'[\u0600-\u06FF]');
    return persianRegex.hasMatch(text);
  }
}