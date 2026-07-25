enum TransferType {
  buyGoods,
  accountingSystem,
  melted,
  coin,
  debt;

  // نمایش فارسی
  String get displayName {
    switch (this) {
      case TransferType.buyGoods: return 'خرید کالا';
      case TransferType.accountingSystem: return 'تسویه حسابداری';
      case TransferType.melted: return 'ارز';
      case TransferType.coin: return 'سکه';
      case TransferType.debt: return 'قرض';
    }
  }

  // مقدار API
  String get value {
    switch (this) {
      case TransferType.buyGoods: return 'BUYGOODS';
      case TransferType.accountingSystem: return 'ACCOUNTINGSYSTEM';
      case TransferType.melted: return 'MELTED';
      case TransferType.coin: return 'COIN';
      case TransferType.debt: return 'DEBT';
    }
  }

  // از String بساز
  static TransferType? fromValue(String value) {
    return TransferType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => TransferType.buyGoods,
    );
  }
}

enum RequestType {
  receive('RECEIVE'),
  payment('PAYMENT'),
  transfer('TRANSFER');

  final String value;

  const RequestType(this.value);

  static RequestType fromJson(String? value) {
    return RequestType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => RequestType.receive,
    );
  }

  String toJson() => value;
}


enum BankAccountType {
  sheba,
  card,
  account;

  // نمایش فارسی
  String get displayName {
    switch (this) {
      case BankAccountType.sheba: return 'شبا';
      case BankAccountType.card: return 'کارت';
      case BankAccountType.account: return 'حساب';
    }
  }

  // مقدار API
  String get value {
    switch (this) {
      case BankAccountType.sheba: return 'sheba';
      case BankAccountType.card: return 'card';
      case BankAccountType.account: return 'account';
    }
  }

  // از String بساز
  static BankAccountType? fromValue(String value) {
    return BankAccountType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => BankAccountType.sheba,
    );
  }
}

/// Display/input unit for money amounts. All stored/API amounts remain in
/// Toman; `Rial` is a pure presentation-and-input multiplier (× 10).
enum CurrencyUnit {
  toman(1, 'تومان'),
  rial(10, 'ریال');

  final int multiplierFromToman;
  final String label;

  const CurrencyUnit(this.multiplierFromToman, this.label);

  static CurrencyUnit fromValue(String? value) {
    if (value == null) return CurrencyUnit.toman;
    return CurrencyUnit.values.firstWhere(
      (u) => u.name.toUpperCase() == value.toUpperCase(),
      orElse: () => CurrencyUnit.toman,
    );
  }

  String toJson() => name.toUpperCase();
}

/// gold-trade-platform-specific asset taxonomy (طلا / سکه / نقدی).
/// Kept in the shared package so both apps can import `enums.dart` unchanged;
/// only gold-trade currently references it.
enum AssetType {
  gold('gold', 'طلا'),
  fullCoin('full_coin', 'سکه تمام'),
  halfCoin('half_coin', 'نیم‌سکه'),
  quarterCoin('quarter_coin', 'ربع‌سکه'),
  cash('cash', 'نقدی');

  final String value;
  final String displayName;

  const AssetType(this.value, this.displayName);

  static AssetType? fromValue(String value) {
    return AssetType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => AssetType.cash,
    );
  }

  String toJson() => value;
}
