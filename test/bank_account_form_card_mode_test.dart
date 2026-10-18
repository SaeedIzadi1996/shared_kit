import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_kit/models/enums.dart';
import 'package:shared_kit/widgets/bank_account_form.dart';

void main() {
  Widget host(CardDisplayMode mode) => MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: BankAccountForm(
                showSavedAccounts: false,
                cardDisplayMode: mode,
              ),
            ),
          ),
        ),
      );

  testWidgets('always: name + sheba + card fields', (tester) async {
    await tester.pumpWidget(host(CardDisplayMode.always));
    expect(find.byType(TextFormField), findsNWidgets(3));
    expect(find.text('افزودن شماره کارت (اختیاری)'), findsNothing);
  });

  testWidgets('collapsed: card field appears only after tapping the expander', (tester) async {
    await tester.pumpWidget(host(CardDisplayMode.collapsed));
    expect(find.byType(TextFormField), findsNWidgets(2));
    await tester.tap(find.text('افزودن شماره کارت (اختیاری)'));
    await tester.pump();
    expect(find.byType(TextFormField), findsNWidgets(3));
  });

  testWidgets('hidden: no card field and no expander', (tester) async {
    await tester.pumpWidget(host(CardDisplayMode.hidden));
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.text('افزودن شماره کارت (اختیاری)'), findsNothing);
  });

  test('CardDisplayMode.fromValue falls back to collapsed', () {
    expect(CardDisplayMode.fromValue(null), CardDisplayMode.collapsed);
    expect(CardDisplayMode.fromValue('HIDDEN'), CardDisplayMode.hidden);
    expect(CardDisplayMode.fromValue('bogus'), CardDisplayMode.collapsed);
  });
}
