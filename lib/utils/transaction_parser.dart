// ─────────────────────────────────────────────
// 1. CONTRACTS (Interfaces)
// ─────────────────────────────────────────────

import 'bank_utils.dart';

abstract class ITextNormalizer {
  String normalize(String text);
}

abstract class INumberExtractor {
  /// Returns cleaned account number and detected bank (or null).
  ({String? account, Bank? bank}) extract(String normalizedText);
}

abstract class IAmountExtractor {
  int? extract(String normalizedText, {List<String> exclusions = const []});
}

abstract class INameExtractor {
  String? extract(String rawText);
}

abstract class IBankDetector {
  Bank? detect(String text);
}

// ─────────────────────────────────────────────
// 2. TEXT NORMALIZER  (Single Responsibility)
// ─────────────────────────────────────────────

class PersianTextNormalizer implements ITextNormalizer {
  static const _persianDigits = '۰۱۲۳۴۵۶۷۸۹';
  static const _englishDigits = '0123456789';

  @override
  String normalize(String text) {
    String result = text;
    for (int i = 0; i < _persianDigits.length; i++) {
      result = result.replaceAll(_persianDigits[i], _englishDigits[i]);
    }
    // Remove separators
    return result
        .replaceAll('|', '')
        .replaceAll('،', '')
        .replaceAll(',', '');
  }
}

// ─────────────────────────────────────────────
// 3. BANK DETECTOR  (Single Responsibility)
// ─────────────────────────────────────────────

class BankDetector implements IBankDetector {
  final List<Bank> _banks;

  const BankDetector(this._banks);

  @override
  Bank? detect(String text) {
    final lower = text.toLowerCase();
    for (final bank in _banks) {
      if (lower.contains(bank.name.toLowerCase())) return bank;
    }
    return null;
  }

  Bank? detectByIban(String ibanDigits) {
    if (ibanDigits.length < 7) return null;
    final code = ibanDigits.substring(4, 7); // digits 4-6 = bank code
    return _banks.cast<Bank?>().firstWhere(
          (b) => b!.ibanCode == code,
          orElse: () => null,
        );
  }

  Bank? detectByCardBin(String cardNumber) {
    if (cardNumber.length < 6) return null;
    final bin = cardNumber.substring(0, 6);
    return _banks.cast<Bank?>().firstWhere(
          (b) => b!.cardBins.contains(bin),
          orElse: () => null,
        );
  }
}

// ─────────────────────────────────────────────
// 4. PATTERNS  (Open/Closed — add patterns freely)
// ─────────────────────────────────────────────

class AccountPatterns {
  static final iban = RegExp(
    r'[Ii][Rr][\s\-\.]*(?:\d[\s\-\.]*){23}\d',
    multiLine: true,
  );
  static final sheba = RegExp(r'\b(?:\d[\s\-\.]*){23}\d\b', multiLine: true);
  static final card  = RegExp(r'\b(?:\d[\s\-\.]*){15}\d\b', multiLine: true);
  static final account = RegExp(r'\b(?:\d[\s\-\.]*){6,13}\d\b', multiLine: true);
}

// ─────────────────────────────────────────────
// 5. NUMBER EXTRACTOR  (Single Responsibility)
// ─────────────────────────────────────────────

class AccountNumberExtractor implements INumberExtractor {
  final BankDetector _bankDetector;

  const AccountNumberExtractor(this._bankDetector);

  @override
  ({String? account, Bank? bank}) extract(String normalizedText) {
    final candidates = _collectCandidates(normalizedText);

    String? sheba;
    String? card;

    for (final raw in candidates) {
      final cleaned = raw.replaceAll(RegExp(r'[\s\-\.]'), '');
      final upper   = cleaned.toUpperCase();

      if (_isSheba(cleaned, upper)) {
        final digits = upper.startsWith('IR') ? cleaned.substring(2) : cleaned;
        if (sheba == null || digits.length > sheba.length) sheba = digits;
      } else if (_isCard(cleaned)) {
        card ??= cleaned;
      }
    }

    if (sheba != null) {
      return (account: sheba, bank: _bankDetector.detectByIban(sheba));
    }
    if (card != null) {
      return (account: card, bank: _bankDetector.detectByCardBin(card));
    }
    return (account: null, bank: null);
  }

  /// Gather matched strings from all patterns.
  List<String> _collectCandidates(String text) => [
        ...AccountPatterns.iban.allMatches(text).map((m) => m.group(0)!),
        ...AccountPatterns.sheba.allMatches(text).map((m) => m.group(0)!),
        ...AccountPatterns.card.allMatches(text).map((m) => m.group(0)!),
        ...AccountPatterns.account.allMatches(text).map((m) => m.group(0)!),
      ];

  bool _isSheba(String cleaned, String upper) =>
      cleaned.length == 24 ||
      (cleaned.length == 26 && upper.startsWith('IR'));

  bool _isCard(String cleaned) => cleaned.length == 16;
}

// ─────────────────────────────────────────────
// 6. AMOUNT EXTRACTOR  (Single Responsibility)
//    Constraint: strip runs of >13 consecutive digits before matching.
// ─────────────────────────────────────────────

class AmountExtractor implements IAmountExtractor {
  static final _longNumberStripper = RegExp(r'\d{14,}');

  static final _pattern = RegExp(
    r'(?<![0-9۰-۹])([0-9۰-۹]{1,3}(?:[\/,٬][0-9۰-۹]{3})+|[0-9۰-۹]+(?:[./][0-9۰-۹]+)?)\s*(هزار|میلیون|ملیون|میلیارد|تومان|تومن|تومتن|ملبون)?',
    multiLine: true,
  );

  @override
  int? extract(String normalizedText, {List<String> exclusions = const []}) {
    String text = normalizedText;

    // Remove explicitly excluded tokens (account numbers, bank names, etc.)
    for (final ex in exclusions) {
      text = text.replaceAll(ex, ' ');
    }

    // ── NEW CONSTRAINT: remove digit runs longer than 13 chars ──────────────
    text = text.replaceAll(_longNumberStripper, ' ');
    // ────────────────────────────────────────────────────────────────────────

    final amounts = <_AmountCandidate>[];

    for (final match in _pattern.allMatches(text)) {
      final candidate = _parseMatch(match);
      if (candidate != null) amounts.add(candidate);
    }

    if (amounts.isEmpty) return null;
    amounts.sort((a, b) => b.value.compareTo(a.value));
    return amounts.first.value.floor();
  }

  _AmountCandidate? _parseMatch(RegExpMatch match) {
    String valStr = match.group(1)!.replaceAll(RegExp(r'[\/,٬]'), '');
    final unit    = match.group(2)?.toLowerCase();

    final raw = double.tryParse(valStr);
    if (raw == null || raw <= 0) return null;

    final value = _applyUnit(raw, unit);
    return _AmountCandidate(value);
  }

  double _applyUnit(double value, String? unit) {
    if (unit == null) {
      // Heuristic: small bare numbers are assumed to be in millions
      return (value >= 1 && value < 1000) ? value * 1_000_000 : value;
    }
    if (unit.contains('میلیارد')) {
      return value * 1_000_000_000;
    }
    if (unit.contains('میلیون') || unit.contains('ملیون') ||
        unit.contains('ملبون')) {
      return value * 1_000_000;
    }
    if (unit.contains('هزار'))                                     return value * 1_000;
    // تومان / تومن / تومتن — currency label, apply million heuristic if small
    if (unit.contains('تومان') || unit.contains('تومن') ||
        unit.contains('تومتن')) {
      return (value < 1000) ? value * 1_000_000 : value;
    }
    return value;
  }
}

class _AmountCandidate {
  final double value;
  const _AmountCandidate(this.value);
}

// ─────────────────────────────────────────────
// 7. NAME EXTRACTOR  (Single Responsibility)
// ─────────────────────────────────────────────

class NameExtractor implements INameExtractor {
  static const _skipKeywords = [
    'بانک', 'مبلغ', 'شبا', 'شماره', 'تومان', 'تومن', 'تومتن',
    'حساب', 'کارت', 'میلیون', 'ملیون', 'میلیارد', 'ملبون',
    'ریال', 'سلام', 'پل بزن', 'اینو',
  ];

  static const _explicitMarkers = ['بنام', 'به نام', 'نام'];

  @override
  String? extract(String rawText) {
    final lines = rawText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    for (final line in lines) {
      if (_shouldSkipLine(line)) continue;

      // Try explicit name markers first
      final explicit = _extractExplicitName(line);
      if (explicit != null) return explicit;

      // Fallback: heuristic name detection
      final heuristic = _extractHeuristicName(line);
      if (heuristic != null) return heuristic;
    }
    return null;
  }

  bool _shouldSkipLine(String line) {
    if (line.contains('/') && line.split('/').length > 2) return true;
    if (line.toUpperCase().contains('IR') && line.length > 10) return true;
    if (line.contains('09')) return true;
    if (RegExp(r'\d').allMatches(line).length > line.length / 2) return true;
    return false;
  }

  String? _extractExplicitName(String line) {
    for (final marker in _explicitMarkers) {
      if (!line.contains(marker)) continue;
      final name = line
          .replaceAll(marker, '')
          .replaceAll('صاحب حساب', '')
          .trim();
      if (name.isNotEmpty && name.split(' ').length >= 2) return name;
    }
    return null;
  }

  String? _extractHeuristicName(String line) {
    final words = line.split(' ').where((w) => w.isNotEmpty).toList();
    if (words.length < 2 || words.length > 4) return null;

    final lower = line.toLowerCase();
    if (_skipKeywords.any((kw) => lower.contains(kw))) return null;

    final digitCount = RegExp(r'\d').allMatches(line).length;
    if (digitCount >= line.length / 3) return null;

    return line;
  }
}

// ─────────────────────────────────────────────
// 8. ORCHESTRATOR  (Dependency Inversion)
// ─────────────────────────────────────────────

class PaymentDataExtractor {
  final ITextNormalizer   _normalizer;
  final IBankDetector     _bankDetector;
  final INumberExtractor  _numberExtractor;
  final IAmountExtractor  _amountExtractor;
  final INameExtractor    _nameExtractor;

  const PaymentDataExtractor({
    required ITextNormalizer   normalizer,
    required IBankDetector     bankDetector,
    required INumberExtractor  numberExtractor,
    required IAmountExtractor  amountExtractor,
    required INameExtractor    nameExtractor,
  })  : _normalizer      = normalizer,
        _bankDetector    = bankDetector,
        _numberExtractor = numberExtractor,
        _amountExtractor = amountExtractor,
        _nameExtractor   = nameExtractor;

  Map<String, dynamic> extractData(String rawText) {
    final normalized = _normalizer.normalize(rawText);

    // Bank from text
    Bank? bank = _bankDetector.detect(rawText);

    // Account number + possibly a better bank source
    final (:account, bank: inferredBank) = _numberExtractor.extract(normalized);
    bank ??= inferredBank;

    // Amount — exclude the raw account string to avoid mis-parsing
    final exclusions = account != null ? [account] : <String>[];
    final amount = _amountExtractor.extract(normalized, exclusions: exclusions);

    // Name
    final name = _nameExtractor.extract(rawText);

    return {
      'account': account,
      'amount' : amount,
      'name'   : name,
      'bank'   : bank ?? 'نامشخص',
    };
  }
}

// ─────────────────────────────────────────────
// 9. FACTORY / COMPOSITION ROOT
// ─────────────────────────────────────────────

PaymentDataExtractor buildPaymentDataExtractor() {
  final banks       = BankUtils.banks;
  final bankDetector = BankDetector(banks);

  return PaymentDataExtractor(
    normalizer      : PersianTextNormalizer(),
    bankDetector    : bankDetector,
    numberExtractor : AccountNumberExtractor(bankDetector),
    amountExtractor : AmountExtractor(),
    nameExtractor   : NameExtractor(),
  );
}