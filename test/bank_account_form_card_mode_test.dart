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

  testWidgets('required hint turns into an error only after the user leaves the fields', (tester) async {
    await tester.pumpWidget(host(CardDisplayMode.always));
    Color hintColor() => tester
        .widget<Text>(find.text('* حداقل یکی از شماره شبا یا کارت الزامی است'))
        .style!
        .color!;
    final errorColor = Theme.of(tester.element(find.byType(BankAccountForm))).colorScheme.error;

    expect(hintColor(), isNot(errorColor)); // calm before interaction

    // focus the sheba field, then move away -> touched with both empty
    await tester.tap(find.byType(TextFormField).at(1));
    await tester.pump();
    await tester.tap(find.byType(TextFormField).at(0));
    await tester.pump();
    await tester.pump();
    expect(hintColor(), errorColor);
  });
}
