
import '../models/enums.dart';
import 'number_formatter.dart';
import 'package:flutter/services.dart';

class Bank {
  final String name;
  final String? ibanCode;
  final List<String> cardBins;
  final String? logo;

  const Bank({
    required this.name,
    this.ibanCode,
    this.cardBins = const [],
    this.logo,
  });

  bool validateCard(String cardNumber) {
    final digits = cardNumber.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.length < 6) return false;
    return cardBins.contains(digits.substring(0, 6));
  }

  bool validateIban(String iban) {
    iban = iban.replaceAll(RegExp(r'\s+'), '').toUpperCase();

    // اگر IR نداشت ولی 24 رقم بود
    if (!iban.startsWith('IR') && RegExp(r'^\d{24}$').hasMatch(iban)) {
      iban = 'IR$iban';
    }

    // بررسی ساختار
    if (!RegExp(r'^IR\d{24}$').hasMatch(iban)) return false;

    // بررسی کد بانک
    if (ibanCode != null && iban.substring(4, 7) != ibanCode) {
      return false;
    }

    // انتقال 4 کاراکتر اول به انتها
    final rearranged = iban.substring(4) + iban.substring(0, 4);

    // تبدیل حروف به عدد
    final numeric = rearranged.replaceAllMapped(
      RegExp(r'[A-Z]'),
      (match) => (match.group(0)!.codeUnitAt(0) - 55).toString(),
    );

    // محاسبه mod 97
    BigInt remainder = BigInt.zero;
    for (int i = 0; i < numeric.length; i += 9) {
      final part = remainder.toString() +
          numeric.substring(i, i + 9 > numeric.length ? numeric.length : i + 9);
      remainder = BigInt.parse(part) % BigInt.from(97);
    }

    return remainder == BigInt.one;
  }
}

class BankUtils {
  BankUtils._();

  static const List<Bank> banks = [
    Bank(name: 'مرکزی', ibanCode: '010', cardBins: ['636795'], logo: 'markazi'),
    Bank(name: 'صنعت و معدن', ibanCode: '011', cardBins: ['627961']),
    Bank(name: 'ملت', ibanCode: '012', cardBins: ['610433','991975'], logo: 'mellat'),
    Bank(name: 'رفاه', ibanCode: '013', cardBins: ['589463'], logo: 'refah'),
    Bank(name: 'مسکن', ibanCode: '014', cardBins: ['628023'], logo: 'maskan'),
    Bank(name: 'سپه', ibanCode: '015', cardBins: ['589210','639607'], logo: 'sepah'),
    Bank(name: 'کشاورزی', ibanCode: '016', cardBins: ['603770','639217','627488'], logo: 'keshavarzi'),
    Bank(name: 'ملی', ibanCode: '017', cardBins: ['603799'], logo: 'melli'),
    Bank(name: 'تجارت', ibanCode: '018', cardBins: ['627353','585983'], logo: 'tejarat'),
    Bank(name: 'صادرات', ibanCode: '019', cardBins: ['627843','603769'], logo: 'saderat'),
    Bank(name: 'توسعه صادرات', ibanCode: '020', cardBins: ['627648','207177']),
    Bank(name: 'پست', ibanCode: '021', cardBins: ['627760']),
    Bank(name: 'توسعه تعاون', ibanCode: '022', cardBins: ['502908']),
    Bank(name: 'موسسه اعتباری توسعه', ibanCode: '051', cardBins: ['628157']),
    Bank(name: 'قرض‌الحسنه رسالت', ibanCode: '053'),
    Bank(name: 'پارسیان', ibanCode: '054', cardBins: ['622106'], logo: 'parsian'),
    Bank(name: 'اقتصاد نوین', ibanCode: '055', cardBins: ['627412']),
    Bank(name: 'سامان', ibanCode: '056', cardBins: ['621986'], logo: 'saman'),
    Bank(name: 'پاسارگاد', ibanCode: '057', cardBins: ['639347','502229'], logo: 'pasargad'),
    Bank(name: 'سرمایه', ibanCode: '058', cardBins: ['639606'], logo: 'sarmaye'),
    Bank(name: 'سینا', ibanCode: '059', cardBins: ['639346']),
    Bank(name: 'قرض‌الحسنه مهر', ibanCode: '060', cardBins: ['606373']),
    Bank(name: 'شهر', ibanCode: '061', cardBins: ['502806','504706'], logo: 'shahr'),
    Bank(name: 'آینده', ibanCode: '062', cardBins: ['636214']),
    Bank(name: 'دی', ibanCode: '063', cardBins: ['502908']),
    Bank(name: 'گردشگری', ibanCode: '064', cardBins: ['505416']),
    Bank(name: 'صنعت و معدن', ibanCode: '065', cardBins: ['636949']),
    Bank(name: 'دی', ibanCode: '066', cardBins: ['505801','502938']),
    Bank(name: 'ایران زمین', ibanCode: '069'),
    Bank(name: 'رسالت', ibanCode: '070'),
    Bank(name: 'زاگرس', ibanCode: '073'),
    Bank(name: 'موسسه اعتباری ملل', ibanCode: '075'),
    Bank(name: 'موسسه اعتباری کوثر', ibanCode: '080'),
  ];

  /// سریع‌ترین lookup برای کارت
  static final Map<String, Bank> _binLookup = {
    for (final bank in banks)
      for (final bin in bank.cardBins) bin: bank
  };

  /// سریع‌ترین lookup برای شبا
  static final Map<String, Bank> _ibanLookup = {
    for (final bank in banks)
      if (bank.ibanCode != null) bank.ibanCode!: bank
  };

  static Bank? getBankFromCard(String cardNumber) {
    final digits = cardNumber.removeAllSpaces().replaceAll(RegExp(r'[^\d]'), '');
    if (digits.length < 6) return null;
    return _binLookup[digits.substring(0, 6)];
  }


  static Bank? getBankFromSheba(String sheba) {
    sheba = sheba.removeAllSpaces().toUpperCase();
    if (!sheba.startsWith('IR')) {
      sheba = 'IR$sheba';
    }
    if (sheba.length < 7) return null;
    return _ibanLookup[sheba.substring(4, 7)];
  }
  static ({BankAccountType type, Bank? bank}) detectAccount(String rawInput) {
    rawInput = rawInput.removeAllSpaces().toEnglishDigits();
    Bank? result = getBankFromCard(rawInput);
    if (result != null) {
        return (
          type: BankAccountType.card,
          bank: result);
      }

    result = getBankFromSheba(rawInput);
      if (result != null) {
        return (
          type: BankAccountType.sheba,
          bank: result);
      }

    return (
          type: BankAccountType.account,
          bank: result);

  }
  static bool validateCard(String cardNumber) {
    cardNumber = cardNumber.removeAllSpaces().replaceAll(RegExp(r'[^\d]'), '');
    if (cardNumber.length != 16) return false;

    int sum = 0;
    bool alt = false;

    for (int i = cardNumber.length - 1; i >= 0; i--) {
      int digit = int.parse(cardNumber[i]);

      if (alt) {
        digit *= 2;
        if (digit > 9) digit -= 9;
      }

      sum += digit;
      alt = !alt;
    }

    return sum % 10 == 0;
  }

  static bool validateSheba(String sheba) {
    sheba = sheba.removeAllSpaces().replaceAll(RegExp(r'\s+'), '').toUpperCase();

    // اگر IR نداشت ولی 24 رقم بود
    if (!sheba.startsWith('IR') && RegExp(r'^\d{24}$').hasMatch(sheba)) {
      sheba = 'IR$sheba';
    }

    // بررسی ساختار
    if (!RegExp(r'^IR\d{24}$').hasMatch(sheba)) return false;

    // انتقال 4 کاراکتر اول به انتها
    final rearranged = sheba.substring(4) + sheba.substring(0, 4);

    // تبدیل حروف به عدد
    final numeric = rearranged.replaceAllMapped(
      RegExp(r'[A-Z]'),
      (match) => (match.group(0)!.codeUnitAt(0) - 55).toString(),
    );

    // محاسبه mod 97
    BigInt remainder = BigInt.zero;
    for (int i = 0; i < numeric.length; i += 9) {
      final part = remainder.toString() +
          numeric.substring(i, i + 9 > numeric.length ? numeric.length : i + 9);
      remainder = BigInt.parse(part) % BigInt.from(97);
    }

    return remainder == BigInt.one;
  }

  static String formatCardNumber(String cardNumber) {
    cardNumber = cardNumber.replaceAll(RegExp(r'[^\d]'), '');

    if (cardNumber.length <= 4) return cardNumber;

    final buffer = StringBuffer();

    for (int i = 0; i < cardNumber.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write('-');
      buffer.write(cardNumber[i]);
    }

    return buffer.toString();
  }

  static String maskAccountNumber(String number) {
    number = number.trim();

    if (number.length <= 4) return number;

    final last4 = number.substring(number.length - 4);

    return '...${NumberFormatter.toPersian(last4)}';
  }
}


class BankExt {
  /// تبدیل شماره‌حساب به شبا
  static String? accountToSheba({
    required String account,
    required String ibanCode,
    int requiredLength = 18,
  }) {
    account = account.trim();

    if (account.isEmpty) return null;

    // شماره حساب باید تا طول 16 رقم صفرگذاری شود
    final padded =
        account.padLeft(requiredLength, '0'); // بستگی به بانک: بعضی‌ها 13، 16، 18

    final base = ibanCode + padded;

    final rearranged = '${base}IR00';

    final numeric = rearranged.replaceAllMapped(
      RegExp("[A-Z]"),
      (match) => (match.group(0)!.codeUnitAt(0) - 55).toString(),
    );

    final mod = 98 - (BigInt.parse(numeric) % BigInt.from(97)).toInt();

    final check = mod.toString().padLeft(2, '0');

    return "IR$check$base";
  }

  /// تبدیل شبا به شماره‌حساب اگر بانک اجازه دهد
  static String? shebaToAccount(String sheba) {
    sheba = sheba.trim().replaceAll(" ", "").toUpperCase();

    if (sheba.length != 26) return null;

    return sheba.substring(7); // بعد از IR + 2 رقم کنترل + 3 رقم کد بانک
  }
}


class ShebaFormatter {
  final bool outputPersian;

  const ShebaFormatter({this.outputPersian = true});

  String formatRawAccount(String rawAccount) {
    final cleanAccount = rawAccount.replaceFirst(RegExp(r'^IR', caseSensitive: false), '');
    return format(cleanAccount);
  }

  String format(String rawText) {
    // دقیقاً همان منطق formatEditUpdate
    String text = rawText.toEnglishDigits().toUpperCase();
    text = _sanitizeIR(text);

    final hasIR = text.startsWith("IR");
    String rawDigits = text.replaceAll(RegExp(r'[^0-9]'), '');

    final detected = BankUtils.detectAccount(rawDigits);
    final isCard = detected.type == BankAccountType.card;

    String formatted;
    if (isCard) {
      formatted = _formatCard(rawDigits);
    } else {
      formatted = hasIR
        ? _formatShebaWithIR(rawDigits)
        : _formatShebaNoIR(rawDigits);
    }

    return outputPersian ? formatted.toPersianDigits() : formatted;
  }

  String _formatCard(String digits) {
    final buf = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i != 0 && i % 4 == 0) buf.write(' ');
      buf.write(digits[i]);
    }
    return buf.toString();
  }

  String _formatShebaWithIR(String rawDigits) {
    final buf = StringBuffer();
    buf.write("IR");
    for (int i = 0; i < rawDigits.length; i++) {
      if (i != 0 && i % 4 == 0) buf.write(' ');
      buf.write(rawDigits[i]);
    }
    return buf.toString();
  }

  String _formatShebaNoIR(String digits) {
    if (digits.length <= 2) return digits;

    final buf = StringBuffer();
    buf.write(digits.substring(0, 2)); // دو رقم اول

    final remain = digits.substring(2);
    for (int i = 0; i < remain.length; i++) {
      if (i % 4 == 0) buf.write(' ');
      buf.write(remain[i]);
    }

    return buf.toString();
  }

  String _sanitizeIR(String text) {
    text = text.toUpperCase();

    if (text.startsWith("IR")) {
      // IR فقط در ابتدای متن مجاز است
      // بقیه IRها حذف می‌شوند
      final rest = text.substring(2).replaceAll("IR", "");
      return "IR$rest";
    } else {
      // اگر کاربر وسط متن IR پیست کرد → حذف
      return text.replaceAll("IR", "");
    }
  }

}


class ShebaCardInputFormatter extends TextInputFormatter {

  final ShebaFormatter _formatter;

  ShebaCardInputFormatter({bool outputPersian = true})
      : _formatter = ShebaFormatter(outputPersian: outputPersian);


  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {

    final formattedText = _formatter.format(newValue.text);

    return TextEditingValue(
      text: formattedText,
      selection: TextSelection.collapsed(offset: formattedText.length),
    );
  }
}
