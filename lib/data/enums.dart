/// Domain enums persisted by name (drift `textEnum`). Never rename a value
/// without a migration: the database stores `enum.name`.
library;

/// [bonus] (v1.2): money that only partly arrives when moved out (see
/// `Account.bonusRatePercent`). Appended last; values are stored by name.
enum AccountType { cash, card, bank, savings, bonus }

enum CategoryType { income, expense }

/// Extra behaviour of a category (v1.2). [transport] shows the transport
/// picker in the editor; [bonusLoss] marks the seeded system category that
/// records what a bonus-account transfer loses (cannot be deleted, archived
/// or budgeted).
enum CategorySpecialKind { none, transport, bonusLoss }

/// Sub-mode of a transport expense (v1.2, DESIGN.md §18.5).
enum TransportMode { bus, metro, taxi, train, fuel, parking, bakuCard }

/// [toHolding] / [fromHolding] move money between an account and a
/// "Kənar yer" (holding). Like transfers they are never income or expense.
enum TxType { income, expense, transfer, toHolding, fromHolding }

/// Where money held outside the spendable accounts sits.
enum HoldingPlace { homeCash, person, bankDeposit, gold, other }

/// A change to a holding's amount. [setValue] resets it (e.g. a revaluation).
enum HoldingEntryKind { add, withdraw, setValue }

/// Origin of the effective exchange rate.
enum RateSource { seed, manual, cbar }

/// Supported currencies. All of them use 2 minor-unit digits.
enum Currency {
  azn('AZN', '₼'),
  usd('USD', r'$'),
  eur('EUR', '€'),
  rub('RUB', '₽'),
  tryLira('TRY', '₺');

  const Currency(this.code, this.symbol);

  final String code;
  final String symbol;

  /// Base currency of the app. Fixed to AZN in phase 1.
  static const Currency base = Currency.azn;

  static Currency fromCode(String code) => Currency.values.firstWhere(
        (Currency c) => c.code == code,
        orElse: () => Currency.azn,
      );
}

extension TxTypeX on TxType {
  CategoryType? get categoryType => switch (this) {
        TxType.income => CategoryType.income,
        TxType.expense => CategoryType.expense,
        TxType.transfer || TxType.toHolding || TxType.fromHolding => null,
      };

  /// Account-to-account or account-to-holding move (no income/expense).
  bool get isMove => this == TxType.transfer || isHoldingMove;

  bool get isHoldingMove => this == TxType.toHolding || this == TxType.fromHolding;
}
