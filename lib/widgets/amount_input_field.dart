import 'package:flutter/material.dart';
import '../models/enums.dart';
import '../utils/currency_utils.dart';
import '../utils/number_formatter.dart';

/// How the quick-amount chips are laid out around the field.
enum AmountTagsLayout {
  /// Horizontal scrolling row under the field (default, original behaviour).
  horizontal,

  /// Slim vertically-scrollable column of tags on the left of the field.
  sideColumn,
}

/// Amount input with quick-amount chips and an "amount in words" helper.
///
/// Theming: colors are read from `Theme.of(context).colorScheme` so the widget
/// adapts to each host app's theme — the accent becomes gold in gold-trade and
/// blue in trust-chain automatically. The trust-chain color that each role
/// replaces is noted in a comment as the reference/fallback value.
class AmountInputField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final int? minAmount;
  final int? maxAmount;
  final bool showQuickTags;
  final List<int>? customQuickAmounts; // اگر null بود، خودکار تولید می‌شود
  final String? Function(String?)? validator;
  final void Function(int amount)? onAmountChanged;
  final int? initialAmount;
  final FocusNode? focusNode;
  final TextInputAction textInputAction;
  final void Function(String)? onFieldSubmitted;
  final bool allowNegative;

  /// Display/input unit. `minAmount`, `maxAmount`, `initialAmount`,
  /// `customQuickAmounts` and the value passed to `onAmountChanged` always
  /// stay in Toman regardless of [unit] — [unit] only changes what's shown
  /// and typed on screen. Defaults to Toman, matching all existing behavior.
  final CurrencyUnit unit;

  /// Where the quick-amount chips are shown. When null the app-wide
  /// [defaultTagsLayout] is used (lets a host app expose it as a user setting
  /// without touching every call site).
  final AmountTagsLayout? tagsLayout;

  /// App-wide default, set once by the host app (like `BankAccountForm.dataSource`).
  static final ValueNotifier<AmountTagsLayout> defaultTagsLayout =
      ValueNotifier(AmountTagsLayout.horizontal);

  const AmountInputField({
    super.key,
    required this.controller,
    this.label = 'مبلغ (تومان)',
    this.minAmount,
    this.maxAmount,
    this.showQuickTags = true,
    this.customQuickAmounts,
    this.validator,
    this.onAmountChanged,
    this.initialAmount,
    this.focusNode,
    this.textInputAction = TextInputAction.done,
    this.onFieldSubmitted,
    this.allowNegative = false,
    this.unit = CurrencyUnit.toman,
    this.tagsLayout,
  });

  @override
  State<AmountInputField> createState() => _AmountInputFieldState();
}

class _AmountInputFieldState extends State<AmountInputField> {
  // تگ‌های پیش‌فرض (میلیون تومان)
  static const _defaultTagsInMillions = [50, 100, 200, 400, 500, 1000];

  late final FocusNode _focusNode;
  late final bool _ownsFocusNode;

  List<int> get _quickAmounts {
    // اگر custom بود
    if (widget.customQuickAmounts != null) {
      return widget.customQuickAmounts!;
    }

    // تولید خودکار بر اساس maxAmount
    final amounts = _defaultTagsInMillions.map((m) => m * 1000000).toList();

    if (widget.maxAmount != null) {
      final filtered = amounts.where((a) => a <= widget.maxAmount!).toList();
      // اگر هیچ تگی در محدوده نبود، maxAmount را به عنوان تگ نشان بده
      if (filtered.isEmpty && widget.maxAmount! > 0) {
        return [widget.maxAmount!];
      }
      if (!filtered.contains(widget.maxAmount!)) {
        filtered.add(widget.maxAmount!);
      }
      return filtered;
    }

    return amounts;
  }

  @override
  void initState() {
    super.initState();
    _ownsFocusNode = widget.focusNode == null;
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_onFocusChange);
    if (widget.initialAmount != null) {
      final display = toDisplayAmount(widget.initialAmount!, widget.unit);
      final formatted = NumberFormatter.formatInput(display.toString());
      widget.controller.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    if (_ownsFocusNode) _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus) _snapToValidUnit();
  }

  /// Toman has no sub-unit, so when [widget.unit] is Rial a typed value that
  /// isn't a multiple of 10 has no exact Toman equivalent. Rather than fight
  /// the user mid-typing, this only runs on commit (focus loss / submit) and
  /// floors the visible amount down to the nearest value with an exact
  /// Toman equivalent.
  void _snapToValidUnit() {
    final displayAmount = NumberFormatter.parse(widget.controller.text);
    if (displayAmount == null) return;
    final tomanAmount = toTomanAmount(displayAmount, widget.unit);
    final snappedDisplay = toDisplayAmount(tomanAmount, widget.unit);
    if (snappedDisplay == displayAmount) return;
    final formatted = NumberFormatter.formatInput(snappedDisplay.toString());
    widget.controller.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
    widget.onAmountChanged?.call(tomanAmount);
    setState(() {});
  }

  /// Current amount in Toman (converted from whatever's displayed/typed).
  int? get _currentAmount {
    final displayAmount = NumberFormatter.parse(widget.controller.text);
    if (displayAmount == null) return null;
    return toTomanAmount(displayAmount, widget.unit);
  }

  void _selectTag(int amount) {
    final display = toDisplayAmount(amount, widget.unit);
    final formatted = NumberFormatter.formatInput(display.toString());
    widget.controller.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
    widget.onAmountChanged?.call(amount);
    setState(() {});
  }

  void _appendZeros() {
    final currentText = widget.controller.text;
    final newText = '${currentText}000';
    final formatted = NumberFormatter.formatInput(newText);
    widget.controller.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
    final displayAmount = NumberFormatter.parse(formatted);
    if (displayAmount != null) {
      widget.onAmountChanged?.call(toTomanAmount(displayAmount, widget.unit));
    }
    setState(() {});
  }

  String? _defaultValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'لطفاً مبلغ را وارد کنید';
    }
    final displayAmount = NumberFormatter.parse(value);
    if (displayAmount == null) {
      return 'مبلغ نامعتبر است';
    }
    final amount = toTomanAmount(displayAmount, widget.unit);
    if (!widget.allowNegative && amount <= 0) {
      return 'مبلغ نامعتبر است';
    }
    if (widget.minAmount != null && amount < widget.minAmount!) {
      return 'حداقل مبلغ ${NumberFormatter.formatToman(widget.minAmount!, unit: widget.unit)} است';
    }
    if (widget.maxAmount != null && amount > widget.maxAmount!) {
      return 'حداکثر مبلغ ${NumberFormatter.formatToman(widget.maxAmount!, unit: widget.unit)} است';
    }
    return null;
  }

  /// Slim, vertically scrollable tag column used by [AmountTagsLayout.sideColumn].
  Widget _buildSideTags({
    required ColorScheme cs,
    required Color accent,
    required Color onAccent,
    required Color accentSoftBg,
    required Color accentSoftBorder,
    required Color accentText,
    required Color neutralBg,
    required Color neutralBorder,
    required Color neutralText,
  }) {
    Widget chip({
      required String label,
      required VoidCallback onTap,
      required bool selected,
      required Color bg,
      required Color border,
      required Color fg,
    }) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            alignment: Alignment.center,
            height: 34,
            decoration: BoxDecoration(
              color: selected ? accent : bg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: selected ? accent : border),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: selected ? onAccent : fg,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    final items = <Widget>[
      chip(
        label: '000'.toPersianDigits(),
        onTap: _appendZeros,
        selected: false,
        bg: neutralBg,
        border: neutralBorder,
        fg: neutralText,
      ),
      for (final amount in _quickAmounts)
        chip(
          label: NumberFormatter.formatShort(amount, unit: widget.unit),
          onTap: () => _selectTag(amount),
          selected: _currentAmount == amount,
          bg: accentSoftBg,
          border: accentSoftBorder,
          fg: accentText,
        ),
    ];

    // About four chips are visible; the rest scroll vertically.
    const chipHeight = 34.0;
    const gap = 6.0;
    const maxVisible = 4;
    final visible = items.length < maxVisible ? items.length : maxVisible;
    final height = visible * chipHeight + (visible - 1) * gap + 12;

    return Container(
      width: 84,
      height: height,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 5),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: ListView.separated(
        padding: EdgeInsets.zero,
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(height: gap),
        itemBuilder: (_, i) => items[i],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final explicit = widget.tagsLayout;
    if (explicit != null) return _buildWith(context, explicit);
    return ValueListenableBuilder<AmountTagsLayout>(
      valueListenable: AmountInputField.defaultTagsLayout,
      builder: (context, layout, _) => _buildWith(context, layout),
    );
  }

  Widget _buildWith(BuildContext context, AmountTagsLayout layout) {
    final cs = Theme.of(context).colorScheme;

    // Accent — themed (trust-chain: blue #1976D2, gold-trade: gold). Falls back
    // to the host theme's primary, which is trust-chain's blue in that app.
    final accent = cs.primary;                                // was Colors.blue.shade600
    final onAccent = cs.onPrimary;                            // was Colors.white
    final accentSoftBg = cs.primary.withValues(alpha: 0.10);  // was Colors.blue.shade50
    final accentSoftBorder = cs.primary.withValues(alpha: 0.35); // was Colors.blue.shade200
    final accentText = cs.primary;                            // was Colors.blue.shade700

    // Neutral "000" chip & helper text — themed surfaces (keeps dark themes legible).
    final neutralBg = cs.surfaceContainerHighest;             // was Colors.grey.shade100
    final neutralBorder = cs.outlineVariant;                  // was Colors.grey.shade300
    final neutralText = cs.onSurfaceVariant;                  // was Colors.grey.shade500/600

    final fieldColumn = <Widget>[
        // ─── TextFormField ───────────────────────────────────────────────
        TextFormField(
          controller: widget.controller,
          focusNode: _focusNode,
          keyboardType: widget.allowNegative
              ? const TextInputType.numberWithOptions(signed: true)
              : TextInputType.number,
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.left,
          textInputAction: widget.textInputAction,
          onFieldSubmitted: (value) {
            _snapToValidUnit();
            widget.onFieldSubmitted?.call(value);
          },
          autovalidateMode: AutovalidateMode.onUserInteraction,
          // Keeps the amount-in-words helper and the quick tags visible
          // above the keyboard when the field is focused.
          scrollPadding: const EdgeInsets.only(bottom: 120),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
          onChanged: (value) {
            final displayAmount = parseCurrency(value);
            if (displayAmount != null) {
              widget.onAmountChanged?.call(toTomanAmount(displayAmount, widget.unit));
            }
            setState(() {});
          },

          decoration: InputDecoration(
            labelText: widget.label,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: cs.surface,                            // was Colors.white
            prefixIcon: const Icon(Icons.attach_money),
            suffixText: widget.unit.label,
            suffixStyle: TextStyle(
              fontSize: 13,
              color: neutralText,                             // was Colors.grey.shade600
            ),
          ),
          inputFormatters: [
            CurrencyInputFormatter(allowNegative: widget.allowNegative),
          ],
          validator: widget.validator ?? _defaultValidator,
        ),

        // ─── Amount in words ─────────────────────────────────────────────
        if (_currentAmount != null && _currentAmount != 0)
          Padding(
            padding: const EdgeInsets.only(top: 6, right: 4),
            child: Text(
              NumberFormatter.numberToWords(_currentAmount!, unit: widget.unit),
              textDirection: TextDirection.rtl,
              style: TextStyle(
                fontSize: 13,
                color: neutralText,                           // was Colors.grey.shade600
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
    ];

    final showTags = widget.showQuickTags && _quickAmounts.isNotEmpty;

    if (showTags && layout == AmountTagsLayout.sideColumn) {
      // Tags on the physical left of the field regardless of host direction.
      final dir = Directionality.of(context);
      return Row(
        textDirection: TextDirection.ltr,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Directionality(
            textDirection: dir,
            child: _buildSideTags(
              cs: cs,
              accent: accent,
              onAccent: onAccent,
              accentSoftBg: accentSoftBg,
              accentSoftBorder: accentSoftBorder,
              accentText: accentText,
              neutralBg: neutralBg,
              neutralBorder: neutralBorder,
              neutralText: neutralText,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Directionality(
              textDirection: dir,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: fieldColumn,
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...fieldColumn,
        // ─── Quick Tags ──────────────────────────────────────────────────
        if (widget.showQuickTags && _quickAmounts.isNotEmpty) ...[
          const SizedBox(height: 10),

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // تگ 000
                GestureDetector(
                  onTap: _appendZeros,
                  child: Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: neutralBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: neutralBorder,
                      ),
                    ),
                    child: Text(
                      '000'.toPersianDigits(),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: neutralText,
                      ),
                    ),
                  ),
                ),

                // تگ‌های مبلغ
                ..._quickAmounts.map((amount) {
                  final isSelected = _currentAmount == amount;
                  return GestureDetector(
                    onTap: () => _selectTag(amount),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected ? accent : accentSoftBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? accent : accentSoftBorder,
                        ),
                      ),
                      child: Text(
                        NumberFormatter.formatShort(amount, unit: widget.unit),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? onAccent : accentText,
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ],

    );
  }
}
