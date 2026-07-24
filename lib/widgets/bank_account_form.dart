import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/enums.dart';
import '../models/bank_account_model.dart';
import '../services/bank_account_data_source.dart';
import '../utils/app_toast.dart';
import '../utils/bank_utils.dart';
import '../utils/number_formatter.dart';
import '../utils/transaction_parser.dart';

// Accent fallbacks for roles that have no standard ColorScheme slot. Values are
// trust-chain's AppColors; the themed roles (primary/error/surface/…) come from
// Theme.of(context).colorScheme so the widget adapts to each host app.
const Color _kGold = Color(0xFFFFC600); // AppColors.primaryGold
const Color _kSuccess = Color(0xFF4CAF50); // AppColors.success
const Color _kWarning = Color(0xFFFF9800); // AppColors.warning

/// نتیجه فرم حساب بانکی
class BankAccountResult {
  final String accountId;
  final String accountHolderName;
  final String? bankName;

  /// Raw entered numbers. Populated in validate-only mode (no data source) so
  /// callers that persist the bank details inline (e.g. gold-trade withdrawals)
  /// can read them directly; null-safe for the callback-only callers.
  final String? shebaNumber;
  final String? cardNumber;

  const BankAccountResult({
    required this.accountId,
    required this.accountHolderName,
    this.bankName,
    this.shebaNumber,
    this.cardNumber,
  });
}

class BankAccountForm extends StatefulWidget {
  /// Injected once per app (like `AppToast.overlayResolver`). When null, the
  /// form runs in validate-only mode: it never loads or persists accounts and
  /// `validateAndSubmit` reports the entered data via [onAccountSelected].
  static BankAccountDataSource? dataSource;

  final void Function(BankAccountResult result)? onAccountSelected;
  final void Function()? onAccountCleared;
  final void Function(int amount)? onAmountDetected;
  final VoidCallback? onLastFieldSubmitted;

  /// Fired whenever the manual-entry fields change, so callers can mirror
  /// the raw (unvalidated) text for their own purposes (e.g. draft caching).
  final void Function(String holderName, String? shebaNumber, String? cardNumber)?
      onManualEntryChanged;

  final BankAccountBase? initialAccount;
  final bool showSavedAccounts;
  final bool enabled;
  const BankAccountForm({
    super.key,
    this.onAccountSelected,
    this.onAccountCleared,
    this.onAmountDetected,
    this.onLastFieldSubmitted,
    this.onManualEntryChanged,
    this.initialAccount,
    this.showSavedAccounts = true,
    this.enabled = true,
  });

  bool get isEditMode => initialAccount != null;

  @override
  State<BankAccountForm> createState() => BankAccountFormState();
}

class BankAccountFormState extends State<BankAccountForm>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // ─── Saved accounts ───────────────────────────────────────────────────────
  List<BankAccountModel> _bankAccounts = [];
  String? _selectedAccountId;
  bool _isLoadingAccounts = false;

  // ─── Manual entry ─────────────────────────────────────────────────────────
  final ShebaFormatter _shebaFormatter = ShebaFormatter();
  final _manualFormKey = GlobalKey<FormState>();

  final _accountHolderController = TextEditingController();
  final _shebaController = TextEditingController();
  final _cardController = TextEditingController();

  final _accountHolderFocus = FocusNode();
  final _shebaFocus = FocusNode();
  final _cardFocus = FocusNode();

  FocusNode get accountHolderFocusNode => _accountHolderFocus;

  String? _shebaDetectedBank;
  String? _cardDetectedBank;
  bool _bankMismatch = false;

  bool _saveNewAccount = false;
  bool _isEditMode = false;

  // ─── Lifecycle ────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.isEditMode;
    _tabController = TabController(length: 2, vsync: this);
    _selectedAccountId = widget.initialAccount?.id;
    _tabController.index = 1;
    if (widget.showSavedAccounts) {
      _loadBankAccounts();
    } else {
      _focusAccountHolder();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _accountHolderController.dispose();
    _shebaController.dispose();
    _cardController.dispose();
    _accountHolderFocus.dispose();
    _shebaFocus.dispose();
    _cardFocus.dispose();
    super.dispose();
  }

  void _focusAccountHolder() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _accountHolderFocus.requestFocus();
    });
  }

  // ─── Public API ───────────────────────────────────────────────────────────

  void prefillManual({
    required String holderName,
    String? shebaNumber,
    String? cardNumber,
  }) {
    _accountHolderController.text = holderName;
    if (shebaNumber != null && shebaNumber.isNotEmpty) {
      _shebaController.text = shebaNumber;
      final raw = shebaNumber
          .replaceFirst(RegExp(r'^IR', caseSensitive: false), '')
          .removeAllSpaces();
      _shebaDetectedBank = BankUtils.getBankFromSheba(raw)?.name ??
          BankUtils.detectAccount(raw).bank?.name;
    }
    if (cardNumber != null && cardNumber.isNotEmpty) {
      _cardController.text = cardNumber;
      final raw = cardNumber.removeAllSpaces();
      _cardDetectedBank = BankUtils.getBankFromCard(raw)?.name ??
          BankUtils.detectAccount(raw).bank?.name;
    }
    _tabController.index = 1;
    setState(() {});
  }

  void _notifyManualChanged() {
    widget.onManualEntryChanged?.call(
      _accountHolderController.text,
      _shebaController.text.isEmpty ? null : _shebaController.text,
      _cardController.text.isEmpty ? null : _cardController.text,
    );
  }

  Future<bool> validateAndSubmit() async {
    if (_tabController.index == 0) {
      if (_selectedAccountId == null) return false;
      return true;
    } else {
      return await _submitManual();
    }
  }

  String? get selectedAccountId => _selectedAccountId;

  void clear() {
    setState(() {
      _selectedAccountId = null;
      _accountHolderController.clear();
      _shebaController.clear();
      _cardController.clear();
      _shebaDetectedBank = null;
      _cardDetectedBank = null;
      _bankMismatch = false;
      _saveNewAccount = false;
    });
    widget.onAccountCleared?.call();
  }

  // ─── Private ──────────────────────────────────────────────────────────────

  Future<void> _loadBankAccounts() async {
    final ds = BankAccountForm.dataSource;
    if (ds == null) return; // validate-only mode: nothing to load
    setState(() => _isLoadingAccounts = true);
    try {
      final result = await ds.getBankAccounts(isSavedByUser: true);
      if (result['success'] == true) {
        setState(() {
          _bankAccounts = result['items'] as List<BankAccountModel>;

          if (_isEditMode) {
            _prefillForEdit();
          } else if (_selectedAccountId == null) {
            final defaultAcc =
                _bankAccounts.where((a) => a.isDefault).firstOrNull;
            if (defaultAcc != null) {
              _selectedAccountId = defaultAcc.id;
              widget.onAccountSelected?.call(BankAccountResult(
                accountId: defaultAcc.id,
                accountHolderName: defaultAcc.accountHolderName,
                bankName: defaultAcc.bankName,
              ));
            }
          }
        });
      }
    } finally {
      setState(() => _isLoadingAccounts = false);
    }
  }

  void _prefillForEdit() {
    final b = widget.initialAccount!;
    _accountHolderController.text = b.accountHolderName;

    if (b.shebaNumber != null && b.shebaNumber!.isNotEmpty) {
      _shebaController.text = b.shebaNumber!;
      final raw = b.shebaNumber!
          .replaceFirst(RegExp(r'^IR', caseSensitive: false), '')
          .removeAllSpaces();
      _shebaDetectedBank = BankUtils.getBankFromSheba(raw)?.name ??
          BankUtils.detectAccount(raw).bank?.name;
    }

    if (b.cardNumber != null && b.cardNumber!.isNotEmpty) {
      _cardController.text = b.cardNumber!;
      final raw = b.cardNumber!.removeAllSpaces();
      _cardDetectedBank = BankUtils.getBankFromCard(raw)?.name ??
          BankUtils.detectAccount(raw).bank?.name;
    }

    final exists = _bankAccounts.any((a) => a.id == b.id);
    if (exists) {
      _selectedAccountId = b.id;
      _saveNewAccount = true;
    }
    _tabController.index = exists ? 0 : 1;
  }

  void _onPaste() async {
    ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text == null) {
      AppToast.warning('کلیپ‌بورد خالی است.');
      return;
    }

    final text = data!.text!;
    final result = buildPaymentDataExtractor().extractData(text);

    final rawAccount =
        (result['account'] ?? '').toString().removeAllSpaces().toEnglishDigits();

    String extractedInfo = '';

    if (rawAccount.isNotEmpty) {
      final formatted = _shebaFormatter.formatRawAccount(rawAccount);
      final detected = BankUtils.detectAccount(
          rawAccount.replaceFirst(RegExp(r'^IR', caseSensitive: false), ''));

      if (detected.type == BankAccountType.card) {
        _cardController.text = formatted;
        setState(() => _cardDetectedBank = detected.bank?.name);
      } else {
        _shebaController.text = formatted;
        setState(() => _shebaDetectedBank = detected.bank?.name);
      }
      extractedInfo += formatted;
    }

    if (result['name'] != null) {
      _accountHolderController.text = result['name'];
      extractedInfo += '\n${result['name']}';
    }

    if (result['amount'] != null && widget.onAmountDetected != null) {
      widget.onAmountDetected!(result['amount'] as int);
      extractedInfo += '\nمبلغ: ${result['amount']}';
    }

    _manualFormKey.currentState?.validate();
    setState(() => _bankMismatch = false);
    _notifyManualChanged();

    if (extractedInfo.isNotEmpty) {
      AppToast.info(extractedInfo.trim());
    } else {
      AppToast.warning('اطلاعاتی از کلیپ‌بورد استخراج نشد.');
    }
  }

  void _selectSavedAccount(BankAccountModel account) {
    setState(() => _selectedAccountId = account.id);
    widget.onAccountSelected?.call(BankAccountResult(
      accountId: account.id,
      accountHolderName: account.accountHolderName,
      bankName: account.bankName,
    ));
  }

  Future<bool> _submitManual() async {
    if (!_manualFormKey.currentState!.validate()) return false;

    final shebaRaw = NumberFormatter.toEnglish(
        _shebaController.text.removeAllSpaces());
    final cardRaw = _cardController.text
        .removeAllSpaces()
        .toEnglishDigits()
        .replaceAll(RegExp(r'[^\d]'), '');

    final shebaFilled = shebaRaw.isNotEmpty;
    final cardFilled = cardRaw.isNotEmpty;

    if (!shebaFilled && !cardFilled) {
      AppToast.error('حداقل یکی از شماره شبا یا کارت را وارد کنید.');
      return false;
    }

    // Cross-bank validation
    if (shebaFilled && cardFilled &&
        _shebaDetectedBank != null && _cardDetectedBank != null) {
      if (_shebaDetectedBank != _cardDetectedBank) {
        setState(() => _bankMismatch = true);
        AppToast.error('شماره شبا و کارت به یک بانک تعلق ندارند.');
        return false;
      }
    }
    setState(() => _bankMismatch = false);

    final bankName = _shebaDetectedBank ?? _cardDetectedBank;
    if (bankName == null) {
      AppToast.error('بانک شناسایی نشد. شماره معتبر وارد کنید.');
      return false;
    }

    final shebaValue = shebaFilled ? shebaRaw.toUpperCase() : null;
    final cardValue = cardFilled ? cardRaw : null;

    try {
      BankAccountBase bank = BankAccountBase(
        id: _isEditMode ? widget.initialAccount!.id : 'new_account',
        accountHolderName: _accountHolderController.text.trim(),
        shebaNumber: shebaValue,
        cardNumber: cardValue,
        bankName: bankName,
      );

      final validation = bank.isValid;
      final isValid = validation.keys.first;
      final message = validation.values.first;
      if (!isValid) {
        AppToast.error(
            'خطا در ${_isEditMode ? "آپدیت" : "ذخیره"} حساب: $message');
        return false;
      }

      // ── Validate-only mode (no data source injected) ──────────────────────
      // The host persists the bank details itself (e.g. inline in a withdrawal
      // request), so just hand back the entered values.
      final ds = BankAccountForm.dataSource;
      if (ds == null) {
        setState(() => _selectedAccountId = bank.id);
        widget.onAccountSelected?.call(BankAccountResult(
          accountId: bank.id,
          accountHolderName: bank.accountHolderName,
          bankName: bank.bankName,
          shebaNumber: shebaValue,
          cardNumber: cardValue,
        ));
        return true;
      }

      // ── Persisting mode ───────────────────────────────────────────────────
      bool isAccountChanged = true;
      if (_isEditMode) {
        isAccountChanged =
            widget.initialAccount!.accountHolderName != bank.accountHolderName ||
            widget.initialAccount!.shebaNumber != bank.shebaNumber ||
            widget.initialAccount!.cardNumber != bank.cardNumber;
      }

      if (!isAccountChanged) {
        setState(() => _selectedAccountId = bank.id);
        widget.onAccountSelected?.call(BankAccountResult(
          accountId: bank.id,
          accountHolderName: bank.accountHolderName,
          bankName: bank.bankName,
          shebaNumber: shebaValue,
          cardNumber: cardValue,
        ));
        return true;
      }

      final Map<String, dynamic> result = await ds.createBankAccount(
        accountHolderName: bank.accountHolderName,
        shebaNumber: bank.shebaNumber,
        cardNumber: bank.cardNumber,
        bankName: bank.bankName,
        isSavedByUser: _saveNewAccount,
      );

      if (result['success'] == true) {
        final account = result['account'] as BankAccountModel;
        setState(() => _selectedAccountId = account.id);
        widget.onAccountSelected?.call(BankAccountResult(
          accountId: account.id,
          accountHolderName: account.accountHolderName,
          bankName: account.bankName,
          shebaNumber: account.shebaNumber,
          cardNumber: account.cardNumber,
        ));
        return true;
      } else {
        if (mounted) {
          AppToast.error(result['message'] ??
              'خطا در ${_isEditMode ? "آپدیت" : "ذخیره"} حساب');
        }
        return false;
      }
    } catch (e) {
      AppToast.error(e.toString());
      return false;
    }
  }

  // ─── Validators ───────────────────────────────────────────────────────────

  String? _shebaValidator(String? value) {
    final text =
        NumberFormatter.toEnglish((value ?? '').removeAllSpaces());
    if (text.isEmpty) return null;

    if (text.toUpperCase().startsWith('IR')) {
      if (text.length != 26) {
        return 'شبا باید IR + ۲۴ رقم باشد'.toPersianDigits();
      }
    } else {
      if (text.length != 24) return 'شبا باید ۲۴ رقم باشد'.toPersianDigits();
    }
    if (!BankUtils.validateSheba(text)) return 'شماره شبا معتبر نیست';
    if (_shebaDetectedBank == null) return 'شبا به هیچ بانکی تعلق ندارد';
    return null;
  }

  String? _cardValidator(String? value) {
    final text =
        NumberFormatter.toEnglish(value ?? '').removeAllSpaces().replaceAll(RegExp(r'[^\d]'), '');
    if (text.isEmpty) return null;
    if (text.length != 16) return 'شماره کارت باید ۱۶ رقم باشد'.toPersianDigits();
    if (!BankUtils.validateCard(text)) return 'شماره کارت معتبر نیست';
    if (_cardDetectedBank == null) return 'کارت به هیچ بانکی تعلق ندارد';
    return null;
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (!widget.showSavedAccounts) {
      return _buildManualEntry();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTabToggle(),
        const SizedBox(height: 14),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: _tabController.index == 0
              ? _buildSavedAccounts()
              : _buildManualEntry(),
        ),
      ],
    );
  }

  Widget _buildTabToggle() {
    final cs = Theme.of(context).colorScheme;
    return IgnorePointer(
      ignoring: !widget.enabled,
      child: Opacity(
        opacity: widget.enabled ? 1 : 0.6,
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              _buildToggleOption(
                index: 0,
                label: 'حساب‌های ذخیره شده',
                icon: Icons.bookmark_rounded,
              ),
              _buildToggleOption(
                index: 1,
                label: 'حساب جدید',
                icon: Icons.add_circle_outline,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToggleOption({
    required int index,
    required String label,
    required IconData icon,
  }) {
    final cs = Theme.of(context).colorScheme;
    final isSelected = _tabController.index == index;
    return Expanded(
      child: GestureDetector(
        onTap: widget.enabled
            ? () {
                setState(() => _tabController.index = index);
                if (index == 1) _focusAccountHolder();
              }
            : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: isSelected ? cs.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 15,
                  color: isSelected ? cs.primary : cs.onSurfaceVariant),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? cs.primary : cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSavedAccounts() {
    final cs = Theme.of(context).colorScheme;
    if (_isLoadingAccounts) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_bankAccounts.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Column(
          children: [
            Icon(Icons.account_balance_outlined,
                size: 40, color: cs.onSurfaceVariant.withValues(alpha: 0.4)),
            const SizedBox(height: 8),
            Text(
              'هیچ حساب ذخیره شده‌ای وجود ندارد',
              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () =>
                  setState(() => _tabController.index = 1),
              style: TextButton.styleFrom(foregroundColor: cs.primary),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('افزودن حساب جدید'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: _bankAccounts.map((account) {
        final isSelected = _selectedAccountId == account.id;
        return GestureDetector(
          onTap: widget.enabled ? () => _selectSavedAccount(account) : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? cs.primary : cs.outlineVariant,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    account.isDefault
                        ? Icons.star_rounded
                        : Icons.account_balance,
                    color: isSelected
                        ? cs.primary
                        : (account.isDefault ? _kGold : cs.onSurfaceVariant),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            account.accountHolderName,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: cs.onSurface,
                            ),
                          ),
                          Text(
                            ' | ${account.bankName}',
                            style: TextStyle(
                                fontSize: 12, color: cs.onSurfaceVariant),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${account.displayType}: ${account.displayText}',
                        style: TextStyle(
                            fontSize: 12, color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                        color: cs.primary, shape: BoxShape.circle),
                    child: const Icon(Icons.check,
                        color: Colors.white, size: 14),
                  ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ─── Manual Entry ─────────────────────────────────────────────────────────

  Widget _buildManualEntry() {
    final cs = Theme.of(context).colorScheme;
    return Form(
      key: _manualFormKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─ Name row + paste button ─────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  enabled: widget.enabled,
                  controller: _accountHolderController,
                  focusNode: _accountHolderFocus,
                  textInputAction: TextInputAction.next,
                  scrollPadding: const EdgeInsets.only(bottom: 120),
                  onFieldSubmitted: (_) => _shebaFocus.requestFocus(),
                  onChanged: (_) => _notifyManualChanged(),
                  decoration: InputDecoration(
                    labelText: 'نام صاحب حساب *',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    prefixIcon:
                        const Icon(Icons.person_outline, size: 20),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    filled: true,
                    fillColor: cs.surface,
                    isDense: true,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'نام الزامی است';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 8),
              Tooltip(
                message: 'وارد کردن اطلاعات از کلیپ‌بورد',
                child: InkWell(
                  onTap: _onPaste,
                  borderRadius: BorderRadius.circular(8),
                  child: const Padding(
                    padding: EdgeInsets.all(10),
                    child: Icon(Icons.auto_awesome, size: 18, color: _kGold),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ─ Sheba field ─────────────────────────────────────────────────
          _buildNumberField(
            controller: _shebaController,
            label: 'شماره شبا',
            hintText: 'IR ________________________',
            icon: Icons.account_balance_outlined,
            detectedBank: _shebaDetectedBank,
            hasMismatch: _bankMismatch && _shebaDetectedBank != null,
            focusNode: _shebaFocus,
            textInputAction: TextInputAction.next,
            onFieldSubmitted: (_) => _cardFocus.requestFocus(),
            onChanged: (value) {
              if (value.isEmpty) {
                setState(() {
                  _shebaDetectedBank = _cardDetectedBank;
                  _bankMismatch = false;
                });
                _notifyManualChanged();
                return;
              }
              final raw = value
                  .removeAllSpaces()
                  .toEnglishDigits()
                  .replaceFirst(
                      RegExp(r'^IR', caseSensitive: false), '');
              final detected = BankUtils.detectAccount(raw);
              setState(() {
                _shebaDetectedBank = detected.bank?.name;
                if (_cardController.text.isEmpty) _cardDetectedBank = _shebaDetectedBank;
                _bankMismatch = _shebaDetectedBank != _cardDetectedBank;
              });
              _notifyManualChanged();
            },
            validator: _shebaValidator,
          ),

          const SizedBox(height: 16),

          // ─ Card field ──────────────────────────────────────────────────
          _buildNumberField(
            controller: _cardController,
            label: 'شماره کارت',
            hintText: '____ ____ ____ ____',
            icon: Icons.credit_card_outlined,
            detectedBank: _cardDetectedBank,
            hasMismatch: _bankMismatch && _cardDetectedBank != null,
            focusNode: _cardFocus,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => widget.onLastFieldSubmitted?.call(),
            onChanged: (value) {
              if (value.isEmpty) {
                setState(() {
                  _cardDetectedBank = _shebaDetectedBank;
                  _bankMismatch = false;
                });
                _notifyManualChanged();
                return;
              }
              final raw =
                  value.toEnglishDigits().replaceAll(RegExp(r'[^\d]'), '');
              final detected = BankUtils.detectAccount(raw);
              setState(() {
                _cardDetectedBank = detected.bank?.name;
                if (_shebaController.text.isEmpty) _shebaDetectedBank = _cardDetectedBank;
                _bankMismatch = _shebaDetectedBank != _cardDetectedBank;
              });
              _notifyManualChanged();
            },
            validator: _cardValidator,
          ),

          // ─ Required hint ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(top: 6, right: 4),
            child: Text(
              '* حداقل یکی از شماره شبا یا کارت الزامی است',
              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
            ),
          ),

          // ─ Bank mismatch warning ────────────────────────────────────────
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: cs.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: cs.onErrorContainer, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'شماره شبا و کارت به یک بانک تعلق ندارند',
                        style: TextStyle(
                            fontSize: 12, color: cs.onErrorContainer),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            crossFadeState: _bankMismatch
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),

          const SizedBox(height: 8),

          // ─ Save checkbox ────────────────────────────────────────────────
          Row(
            children: [
              SizedBox(
                width: 32,
                height: 32,
                child: Checkbox(
                  value: _saveNewAccount,
                  activeColor: cs.primary,
                  onChanged: (v) =>
                      setState(() => _saveNewAccount = v ?? false),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(
                      () => _saveNewAccount = !_saveNewAccount),
                  child: Text(
                    'ذخیره حساب',
                    style: TextStyle(fontSize: 13, color: cs.onSurface),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNumberField({
    required TextEditingController controller,
    required String label,
    required String hintText,
    required IconData icon,
    required String? detectedBank,
    required bool hasMismatch,
    required void Function(String) onChanged,
    required String? Function(String?) validator,
    FocusNode? focusNode,
    TextInputAction textInputAction = TextInputAction.next,
    void Function(String)? onFieldSubmitted,
  }) {
    final cs = Theme.of(context).colorScheme;
    final hasContent = controller.text.removeAllSpaces().isNotEmpty;
    final isDetected = detectedBank != null && hasContent;

    return TextFormField(
      enabled: widget.enabled,
      controller: controller,
      focusNode: focusNode,
      textInputAction: textInputAction,
      onFieldSubmitted: onFieldSubmitted,
      scrollPadding: const EdgeInsets.only(bottom: 120),
      textDirection: TextDirection.ltr,
      inputFormatters: [ShebaCardInputFormatter()],
      buildCounter: (context,
          {required currentLength,
          required isFocused,
          required maxLength}) {
        if (!hasContent) return null;
        final counterText = Text(
          controller.text.removeAllSpaces().length
              .toString()
              .toPersianDigits(),
          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11),
        );
        if (isDetected) {
          final color = hasMismatch ? _kWarning : _kSuccess;
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                hasMismatch
                    ? Icons.warning_amber_rounded
                    : Icons.account_balance_rounded,
                size: 11,
                color: color.withValues(alpha: 0.8),
              ),
              const SizedBox(width: 3),
              Text(
                detectedBank,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: color.withValues(alpha: 0.85),
                ),
              ),
              const SizedBox(width: 6),
              counterText,
            ],
          );
        }
        return counterText;
      },
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        hintTextDirection: TextDirection.ltr,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12)),
        prefixIcon: Icon(icon, size: 20),
        suffixIcon: !hasContent
            ? null
            : validator(controller.text) == null
                ? Icon(Icons.check_circle_outline_rounded,
                    color: _kSuccess.withValues(alpha: 0.7), size: 18)
                : Icon(Icons.cancel_outlined,
                    color: cs.error.withValues(alpha: 0.7), size: 18),
        filled: true,
        fillColor: cs.surface,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: 12),
        isDense: true,
      ),
      onChanged: onChanged,
      validator: validator,
    );
  }
}
