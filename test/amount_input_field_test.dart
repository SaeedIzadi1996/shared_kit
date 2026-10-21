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

  testWidgets('sideColumn layout: tags sit left of the field in a vertical list and are tappable',
      (tester) async {
    final controller = TextEditingController();
    int? lastAmount;

    await tester.pumpWidget(wrap(AmountInputField(
      controller: controller,
      tagsLayout: AmountTagsLayout.sideColumn,
      customQuickAmounts: const [50000000, 100000000],
      onAmountChanged: (amount) => lastAmount = amount,
    )));

    expect(find.byType(ListView), findsOneWidget);
    final listLeft = tester.getTopLeft(find.byType(ListView)).dx;
    final fieldLeft = tester.getTopLeft(find.byType(TextFormField)).dx;
    expect(listLeft, lessThan(fieldLeft));

    await tester.tap(find.text(NumberFormatter.formatShort(50000000)));
    await tester.pump();
    expect(lastAmount, 50000000);
  });

  testWidgets('horizontal layout (default) has no vertical tag list', (tester) async {
    await tester.pumpWidget(wrap(AmountInputField(controller: TextEditingController())));
    expect(find.byType(ListView), findsNothing);
  });

  testWidgets('sideColumn rail is never taller than the input field and scrolls vertically',
      (tester) async {
    tester.view.physicalSize = const Size(600, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(wrap(AmountInputField(
      controller: TextEditingController(),
      tagsLayout: AmountTagsLayout.sideColumn,
      customQuickAmounts: const [
        10000000, 20000000, 30000000, 40000000, 50000000, 60000000, 70000000, 80000000,
      ],
    )));

    await tester.pump(); // let the rail measure the field after first layout
    final rail = tester.getSize(find.byType(ListView));
    final field = tester.getSize(find.byType(TextFormField));
    expect(rail.height, closeTo(field.height, 0.6));

    // the last chip is not even built (off-screen) until the rail is scrolled
    final last = find.text(NumberFormatter.formatShort(80000000));
    expect(last, findsNothing);
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pump();
    expect(last, findsOneWidget);
    final listTop = tester.getTopLeft(find.byType(ListView)).dy;
    expect(tester.getTopLeft(last).dy, lessThan(listTop + rail.height));
  });

  testWidgets('sideColumnRight puts the rail on the right of the field with the same height',
      (tester) async {
    tester.view.physicalSize = const Size(600, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(wrap(AmountInputField(
      controller: TextEditingController(),
      tagsLayout: AmountTagsLayout.sideColumnRight,
      customQuickAmounts: const [50000000, 100000000],
    )));
    await tester.pump();

    final field = tester.getRect(find.byType(TextFormField));
    final rail = tester.getRect(find.byType(ListView));
    expect(rail.left, greaterThanOrEqualTo(field.right)); // rail to the right of the field
    expect(rail.height, closeTo(field.height, 0.6));
  });
}
