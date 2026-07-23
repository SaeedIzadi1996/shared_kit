# shared_kit

Shared Flutter code (utils, models, widgets) used by both the
**gold-trade-platform** and **trust-chain** apps.

Consumed as a git dependency:

```yaml
dependencies:
  shared_kit:
    git:
      url: https://github.com/SaeedIzadi1996/shared_kit.git
      ref: main
```

## Contents

- `models/` — `enums.dart` (incl. gold-trade `AssetType`), `bank_account_model.dart`
- `utils/` — `number_formatter.dart`, `bank_utils.dart`, `transaction_parser.dart`,
  `phone_number_formatter.dart`, `no_persian_chars_formatter.dart`, `app_toast.dart`
- `core/` — `floating_route.dart`

## Notes

- `AppToast` is navigation-agnostic. Set `AppToast.overlayResolver` once in each
  app's `main()`.
- `number_formatter.dart` is the union of both apps' formatters. The String
  helpers live in the `StringDigitExt` extension.
