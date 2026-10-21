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

  /// Same rail, on the right of the field.
  sideColumnRight,
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

  // Side-column tags: scroll state drives the top/bottom fade hints.
  final ScrollController _tagsScroll = ScrollController();
  bool _fadeTop = false;
  bool _fadeBottom = true;

  // Side-column geometry: the tag rail is exactly as tall as the *measured*
  // input field, so it can never stick out above/below it (the amount-in-words
  // line sits under the field only).
  static const double _kTagHeight = 26;
  static const double _kTagGap = 4;
  final GlobalKey _fieldKey = GlobalKey();
  double _fieldHeight = 52; // first-frame guess, corrected right after layout
  bool _fieldHasError = false;

  void _measureField() {
    // While an error line is shown the field is taller than the input itself;
    // keep the last error-free measurement so the rail doesn't stretch.
    if (_fieldHasError) return;
    final box = _fieldKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    final h = box.size.height;
    if ((h - _fieldHeight).abs() > 0.5 && mounted) {
      setState(() => _fieldHeight = h);
    }
  }

  void _updateTagFades() {
    if (!_tagsScroll.hasClients) return;
    final p = _tagsScroll.position;
    final top = p.pixels > 2;
    final bottom = p.pixels < p.maxScrollExtent - 2;
    if (top != _fadeTop || bottom != _fadeBottom) {
      setState(() {
        _fadeTop = top;
        _fadeBottom = bottom;
      });
    }
  }

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
    _tagsScroll.addListener(_updateTagFades);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateTagFades());
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
    _tagsScroll.dispose();
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

  /// Slim vertical tag rail used by [AmountTagsLayout.sideColumn]: fixed height
  /// (field + words line), vertical scroll, soft fade at the clipped edges.
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
        color: selected ? accent : bg,
        shape: StadiumBorder(
          side: BorderSide(color: selected ? accent : border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: _kTagHeight,
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: selected ? onAccent : fg,
                    ),
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

    final railHeight = _fieldHeight;

    return SizedBox(
      width: 92,
      height: railHeight,
      child: ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (rect) => LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _fadeTop ? Colors.transparent : Colors.black,
            Colors.black,
            Colors.black,
            _fadeBottom ? Colors.transparent : Colors.black,
          ],
          stops: const [0.0, 0.18, 0.82, 1.0],
        ).createShader(rect),
        // Scroll indicator hidden on purpose: the edge fade already hints at more tags.
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
          child: ListView.separated(
            controller: _tagsScroll,
            padding: const EdgeInsets.symmetric(vertical: 2),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: _kTagGap),
            itemBuilder: (_, i) => items[i],
          ),
        ),
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
    final accent = cs.primary; // was Colors.blue.shade600
    final onAccent = cs.onPrimary; // was Colors.white
    final accentSoftBg = cs.primary.withValues(
      alpha: 0.10,
    ); // was Colors.blue.shade50
    final accentSoftBorder = cs.primary.withValues(
      alpha: 0.35,
    ); // was Colors.blue.shade200
    final accentText = cs.primary; // was Colors.blue.shade700

    // Neutral "000" chip & helper text — themed surfaces (keeps dark themes legible).
    final neutralBg = cs.surfaceContainerHighest; // was Colors.grey.shade100
    final neutralBorder = cs.outlineVariant; // was Colors.grey.shade300
    final neutralText = cs.onSurfaceVariant; // was Colors.grey.shade500/600

    final fieldColumn = <Widget>[
      // ─── TextFormField ───────────────────────────────────────────────
      KeyedSubtree(
        key: _fieldKey,
        child: TextFormField(
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
              widget.onAmountChanged?.call(
                toTomanAmount(displayAmount, widget.unit),
              );
            }
            setState(() {});
          },

          decoration: InputDecoration(
            labelText: widget.label,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: cs.surface, // was Colors.white
            prefixIcon: const Icon(Icons.attach_money),
            suffixText: widget.unit.label,
            suffixStyle: TextStyle(
              fontSize: 13,
              color: neutralText, // was Colors.grey.shade600
            ),
          ),
          inputFormatters: [
            CurrencyInputFormatter(allowNegative: widget.allowNegative),
          ],
          validator: (v) {
            final result = (widget.validator ?? _defaultValidator)(v);
            _fieldHasError = result != null;
            return result;
          },
        ),
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
              color: neutralText, // was Colors.grey.shade600
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
    ];

    final showTags = widget.showQuickTags && _quickAmounts.isNotEmpty;
    final isSide = layout == AmountTagsLayout.sideColumn ||
        layout == AmountTagsLayout.sideColumnRight;
    if (showTags && isSide) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _measureField());
    }

    if (showTags && isSide) {
      // The rail sits on the physical left/right of the field regardless of the
      // host's text direction (the Row is forced LTR, children keep [dir]).
      final dir = Directionality.of(context);
      final railOnRight = layout == AmountTagsLayout.sideColumnRight;
      final rail = Directionality(
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
      );
      final field = Expanded(
        child: Directionality(
          textDirection: dir,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: fieldColumn,
          ),
        ),
      );
      return Row(
        textDirection: TextDirection.ltr,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: railOnRight
            ? [field, const SizedBox(width: 10), rail]
            : [rail, const SizedBox(width: 10), field],
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
                      border: Border.all(color: neutralBorder),
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
