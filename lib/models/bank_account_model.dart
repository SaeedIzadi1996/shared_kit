// lib/models/bank_account_model.dart

import '../utils/number_formatter.dart';

import '../utils/bank_utils.dart';


class BankAccountBase {
  final String id;
  final String accountHolderName;
  final String? shebaNumber;
  final String? cardNumber;
  final String? accountNumber;
  final String bankName;

  BankAccountBase({
    required this.id,
    required this.accountHolderName,
    this.shebaNumber,
    this.cardNumber,
    this.accountNumber,
    required this.bankName,
  });

  static ({
    String id,
    String accountHolderName,
    String? shebaNumber,
    String? cardNumber,
    String? accountNumber,
    String bankName,
  }) parseBase(Map<String, dynamic> json) {
    return (
      id: json['id'] as String,
      accountHolderName: json['account_holder_name'] as String,
      shebaNumber: json['sheba_number'] as String?,
      cardNumber: json['card_number'] as String?,
      accountNumber: json['account_number'] as String?,
      bankName: json['bank_name'] as String,
    );
  }

  factory BankAccountBase.fromJson(Map<String, dynamic> json) {
    final base = parseBase(json);
    return BankAccountBase(
      id: base.id,
      accountHolderName: base.accountHolderName,
      shebaNumber: base.shebaNumber,
      cardNumber: base.cardNumber,
      accountNumber: base.accountNumber,
      bankName: base.bankName,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'account_holder_name': accountHolderName,
        'sheba_number': shebaNumber,
        'card_number': cardNumber,
        'account_number': accountNumber,
        'bank_name': bankName,
      };

  String get displayNumber {
    if (shebaNumber != null) return shebaNumber!;
    if (cardNumber != null) return cardNumber!;
    if (accountNumber != null) return accountNumber!;
    return '';
  }

  String get shortDisplayData {
    String result = accountHolderName;
    if (shebaNumber != null) {
      result += " | ${NumberFormatter.formatSheba(shebaNumber!)}";
    }
    if (cardNumber != null) {
      result += " | ${NumberFormatter.formatCardNumber(cardNumber!)}";
    }
    if (accountNumber != null) {
      result += " | ${NumberFormatter.toPersian(accountNumber!)}";
    }
    return result;
  }

  String get clipboardData {
  String result = accountHolderName;
  result += " \n $bankName";
  if (shebaNumber != null) {
    // result += " |${NumberFormatter.formatSheba(shebaNumber!, spacer: '-', convert2Persian: false)}";
    result += " \n $shebaNumber";
  }
  if (cardNumber != null) {
    // result += " | ${NumberFormatter.formatCardNumber(cardNumber!, spacer: '-', convert2Persian: false)}";
    result += " \n $cardNumber";
  }
  if (accountNumber != null) {
    result += " \n $accountNumber";
  }
  return result;
}

  /// ✅ اعتبارسنجی کامل حساب بانکی
  Map<bool, String> get isValid {
    // 1️⃣ نام دارنده حساب
    if (accountHolderName.trim().length < 3) {
      return {false: "نام صاحب حساب باید حداقل ۳ کاراکتر باشد."};
    }

    // 2️⃣ بررسی وجود حداقل یکی از شماره‌ها
    final hasAnyNumber = (shebaNumber?.trim().isNotEmpty ?? false) ||
        (cardNumber?.trim().isNotEmpty ?? false) ||
        (accountNumber?.trim().isNotEmpty ?? false);

    if (!hasAnyNumber) {
      return {false: "حداقل یکی از شماره کارت، حساب یا شبا باید وارد شود."};
    }

    // 3️⃣ بانک باید مشخص باشد
    if (bankName.trim().isEmpty) {
      return {false: "نام بانک مشخص نشده است."};
    }

    // 4️⃣ بررسی تطابق بانک شبا و کارت (در صورت وجود هر دو)
    if (shebaNumber != null && cardNumber != null) {
      final shebaBank = BankUtils.getBankFromSheba(shebaNumber!);
      final cardBank = BankUtils.getBankFromCard(cardNumber!);

      if (shebaBank == null || cardBank == null) {
        return {false: "بانک کارت یا شبا نامشخص است."};
      }

      if (shebaBank.name != cardBank.name) {
        return {false: "شماره کارت و شبا متعلق به یک بانک نیستند."};
      }
    }

    // ✅ همه چیز درست است
    return {true: "اطلاعات حساب معتبر است."};
  }
}
// extension BankAccountBaseCopy on BankAccountBase {
//   BankAccountBase copyWith({
//     String? accountHolderName,
//     String? shebaNumber,
//     String? cardNumber,
//     String? accountNumber,
//     String? bankName,
//   }) {
//     return BankAccountBase(
//       accountHolderName: accountHolderName ?? this.accountHolderName,
//       shebaNumber: shebaNumber ?? this.shebaNumber,
//       cardNumber: cardNumber ?? this.cardNumber,
//       accountNumber: accountNumber ?? this.accountNumber,
//       bankName: bankName ?? this.bankName,
//     );
//   }
// }

class BankAccountModel extends BankAccountBase {
  // final String id;
  final bool isDefault;
  final bool isActive;

  BankAccountModel({
    required super.id,
    required super.accountHolderName,
    super.accountNumber,
    super.cardNumber,
    super.shebaNumber,
    required super.bankName,
    required this.isDefault,
    required this.isActive,
  });

  factory BankAccountModel.fromJson(Map<String, dynamic> json) {
    final base = BankAccountBase.parseBase(json);
    return BankAccountModel(
      id: base.id,
      accountHolderName: base.accountHolderName,
      shebaNumber: base.shebaNumber,
      cardNumber: base.cardNumber,
      accountNumber: base.accountNumber,
      bankName: base.bankName,
      isDefault: json['is_default'] as bool,
      isActive: json['is_active'] as bool,
    );
  }

  String get displayText {
    if (shebaNumber != null) return shebaNumber!;
    if (cardNumber != null) return cardNumber!;
    if (accountNumber != null) return accountNumber!;
    return accountHolderName;
  }

  String get displayType {
    if (shebaNumber != null) return 'شبا';
    if (cardNumber != null) return 'کارت';
    if (accountNumber != null) return 'حساب';
    return '';
  }
}
