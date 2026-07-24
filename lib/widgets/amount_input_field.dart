import 'package:flutter/material.dart';
import '../utils/currency_utils.dart';
import '../utils/number_formatter.dart';

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
  });

  @override
  State<AmountInputField> createState() => _AmountInputFieldState();
}

class _AmountInputFieldState extends State<AmountInputField> {
  // تگ‌های پیش‌فرض (میلیون تومان)
  static const _defaultTagsInMillions = [50, 100, 200, 400, 500, 1000];

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
    if (widget.initialAmount != null) {
      final formatted = NumberFormatter.formatInput(widget.initialAmount!.toString());
      widget.controller.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }
  }

  int? get _currentAmount =>
      NumberFormatter.parse(widget.controller.text);

  void _selectTag(int amount) {
    final formatted = NumberFormatter.formatInput(amount.toString());
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
    final amount = NumberFormatter.parse(formatted);
    if (amount != null) widget.onAmountChanged?.call(amount);
    setState(() {});
  }

  String? _defaultValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'لطفاً مبلغ را وارد کنید';
    }
    final amount = NumberFormatter.parse(value);
    if (amount == null || (!widget.allowNegative && amount <= 0)) {
      return 'مبلغ نامعتبر است';
    }
    if (widget.minAmount != null && amount < widget.minAmount!) {
      return 'حداقل مبلغ ${NumberFormatter.formatToman(widget.minAmount!)} است';
    }
    if (widget.maxAmount != null && amount > widget.maxAmount!) {
      return 'حداکثر مبلغ ${NumberFormatter.formatToman(widget.maxAmount!)} است';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ─── TextFormField ───────────────────────────────────────────────
        TextFormField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          keyboardType: widget.allowNegative
              ? const TextInputType.numberWithOptions(signed: true)
              : TextInputType.number,
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.left,
          textInputAction: widget.textInputAction,
          onFieldSubmitted: widget.onFieldSubmitted,
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
            final amount = parseCurrency(value);
            if (amount != null) widget.onAmountChanged?.call(amount);
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
            suffixText: 'تومان',
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
              NumberFormatter.numberToWords(_currentAmount!),
              textDirection: TextDirection.rtl,
              style: TextStyle(
                fontSize: 13,
                color: neutralText,                           // was Colors.grey.shade600
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

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
                        NumberFormatter.formatShort(amount),
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
