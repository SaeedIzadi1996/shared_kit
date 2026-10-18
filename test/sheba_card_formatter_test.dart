import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_kit/utils/bank_utils.dart';

void main() {
  final f = ShebaCardInputFormatter(outputPersian: false);

  TextEditingValue v(String t, int c) =>
      TextEditingValue(text: t, selection: TextSelection.collapsed(offset: c));

  // 16-digit card, formatted as 4-4-4-4.
  const card = '6037 9912 3456 7890';

  test('deleting a digit in the middle keeps the caret there', () {
    // caret after the 6th digit ("6037 99|12 ..."), backspace removes a 9
    final res = f.formatEditUpdate(v(card, 7), v('6037 912 3456 7890', 6));
    expect(res.text.replaceAll(' ', ''), '60379123456789' '0');
    expect(res.selection.baseOffset, 6);
  });

  test('typing at the end keeps the caret at the end', () {
    final res = f.formatEditUpdate(v('6037 9912 3456 789', 18), v('6037 9912 3456 7890', 19));
    expect(res.text.replaceAll(' ', ''), '6037991234567890');
    expect(res.selection.baseOffset, res.text.length);
  });

  test('backspace over a separator removes the previous digit', () {
    // caret right after the first space; backspace removes only the space
    final res = f.formatEditUpdate(v(card, 5), v('60379912 3456 7890', 4));
    expect(res.text.replaceAll(' ', ''), '6039912345678' '90');
    expect(res.selection.baseOffset, 4);
  });

  test('persian digits are counted', () {
    final res = f.formatEditUpdate(
        v('۶۰۳۷ ۹۹۱۲ ۳۴۵۶ ۷۸۹۰', 7), v('۶۰۳۷ ۹۱۲ ۳۴۵۶ ۷۸۹۰', 6));
    expect(res.selection.baseOffset, 6);
  });
}
