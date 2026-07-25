import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_kit/models/enums.dart';
import 'package:shared_kit/utils/number_formatter.dart';
import 'package:shared_kit/widgets/amount_input_field.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
        home: Scaffold(body: Directionality(textDirection: TextDirection.rtl, child: child)),
      );

  testWidgets('rial unit: typed digits are converted to Toman for onAmountChanged',
      (tester) async {
    final controller = TextEditingController();
    int? lastAmount;

    await tester.pumpWidget(wrap(AmountInputField(
      controller: controller,
      unit: CurrencyUnit.rial,
      onAmountChanged: (amount) => lastAmount = amount,
    )));

    // 10,000,000 Rial typed → 1,000,000 Toman.
    await tester.enterText(find.byType(TextFormField), '10000000');
    await tester.pump();

    expect(lastAmount, 1000000);
  });

  testWidgets('rial unit: suffix shows ریال instead of تومان', (tester) async {
    final controller = TextEditingController();
    await tester.pumpWidget(wrap(AmountInputField(
      controller: controller,
      unit: CurrencyUnit.rial,
    )));

    expect(find.text('ریال'), findsOneWidget);
    expect(find.text('تومان'), findsNothing);
  });

  testWidgets('rial unit: focus loss snaps a non-multiple-of-10 value down',
      (tester) async {
    final controller = TextEditingController();
    int? lastAmount;

    await tester.pumpWidget(wrap(Column(children: [
      AmountInputField(
        controller: controller,
        unit: CurrencyUnit.rial,
        onAmountChanged: (amount) => lastAmount = amount,
      ),
      const TextField(), // somewhere else to move focus to
    ])));

    await tester.enterText(find.byType(TextFormField), '12345');
    await tester.pump();

    // Move focus away to trigger the commit-time snap.
    await tester.tap(find.byType(TextField).last);
    await tester.pumpAndSettle();

    // 12345 Rial floors to 1234 Toman == 12340 Rial displayed.
    expect(lastAmount, 1234);
    expect(NumberFormatter.parse(controller.text), 12340);
  });

  testWidgets('default (toman) unit keeps existing suffix and 1:1 amount',
      (tester) async {
    final controller = TextEditingController();
    int? lastAmount;

    await tester.pumpWidget(wrap(AmountInputField(
      controller: controller,
      onAmountChanged: (amount) => lastAmount = amount,
    )));

    expect(find.text('تومان'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), '1000000');
    await tester.pump();

    expect(lastAmount, 1000000);
  });
}
