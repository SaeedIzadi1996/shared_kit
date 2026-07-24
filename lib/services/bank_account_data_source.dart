/// Abstraction over the host app's bank-account backend, injected into
/// [BankAccountForm] (see `BankAccountForm.dataSource`).
///
/// `shared_kit` cannot import either app's concrete service (each lives under
/// its own package), so each app provides a small adapter implementing this
/// interface and assigns it once at startup. When no data source is injected,
/// [BankAccountForm] runs in validate-only mode: it never loads or persists
/// accounts and simply reports the entered data via its `onAccountSelected`
/// callback.
///
/// Both methods return the loosely-typed `Map<String, dynamic>` the existing
/// services already produce:
///  - [getBankAccounts] → `{ 'success': bool, 'items': List<BankAccountModel> }`
///  - [createBankAccount] → `{ 'success': bool, 'account': BankAccountModel, 'message': String? }`
abstract class BankAccountDataSource {
  Future<Map<String, dynamic>> getBankAccounts({bool isSavedByUser = true});

  Future<Map<String, dynamic>> createBankAccount({
    required String accountHolderName,
    String? shebaNumber,
    String? cardNumber,
    required String bankName,
    bool isSavedByUser = false,
  });
}
