import 'package:drift/drift.dart';

import 'enums.dart';

/// Money accounts (wallets, cards, bank accounts). Amounts are int minor units.
@DataClassName('Account')
class Accounts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 60)();
  TextColumn get type => textEnum<AccountType>()();

  /// ISO code, see [Currency].
  TextColumn get currency => text().withLength(min: 3, max: 3)();
  IntColumn get initialBalance => integer().withDefault(const Constant(0))();
  IntColumn get colorIndex => integer().withDefault(const Constant(0))();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Income / expense categories. Named `TxCategory` in Dart to avoid clashing
/// with Flutter's `Category` annotation.
@DataClassName('TxCategory')
class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get nameAz => text().withLength(min: 1, max: 60)();
  TextColumn get nameEn => text().withLength(min: 0, max: 60)();

  /// Material icon code point; resolved through the const icon catalogue.
  IntColumn get iconCodePoint => integer()();

  /// Index into the 12-colour categorical palette (AppColors.categorical).
  IntColumn get colorIndex => integer().withDefault(const Constant(7))();
  TextColumn get type => textEnum<CategoryType>()();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}

/// Income, expense and transfer records.
@DataClassName('MoneyTx')
class Transactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get type => textEnum<TxType>()();
  @ReferenceName('outgoingTransactions')
  IntColumn get accountId => integer().references(Accounts, #id)();

  /// Destination account; transfers only.
  @ReferenceName('incomingTransactions')
  IntColumn get toAccountId =>
      integer().nullable().references(Accounts, #id)();

  /// Null for transfers.
  IntColumn get categoryId =>
      integer().nullable().references(Categories, #id)();

  /// Amount in the source account's currency, minor units, always > 0.
  // ignore: recursive_getters (drift's documented CHECK-constraint pattern)
  IntColumn get amount => integer().check(amount.isBiggerThanValue(0))();

  /// Amount credited to [toAccountId] when its currency differs. For holding
  /// moves: the amount in the holding's currency when it differs.
  IntColumn get toAmount => integer().nullable()();

  /// The holding of a [TxType.toHolding] / [TxType.fromHolding] move.
  IntColumn get holdingId => integer().nullable().references(Holdings, #id)();
  DateTimeColumn get date => dateTime()();
  TextColumn get note => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Monthly per-category limits (UI arrives in phase 2).
@DataClassName('Budget')
class Budgets extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get categoryId => integer().references(Categories, #id)();

  /// `yyyy-MM`.
  TextColumn get month => text().withLength(min: 7, max: 7)();

  /// Limit in the base currency (AZN), minor units.
  IntColumn get limitAmount => integer()();

  @override
  List<Set<Column>> get uniqueKeys => <Set<Column>>[
        <Column>{categoryId, month},
      ];
}

/// How many AZN one unit of [currency] is worth. AZN itself is implicit (1.0).
@DataClassName('ExchangeRate')
class ExchangeRates extends Table {
  TextColumn get currency => text().withLength(min: 3, max: 3)();

  /// Effective rate used for every conversion.
  RealColumn get rateToAzn => real()();

  /// Where [rateToAzn] came from.
  TextColumn get source =>
      textEnum<RateSource>().withDefault(Constant(RateSource.seed.name))();

  /// User override: automatic refresh leaves [rateToAzn] alone while true.
  BoolColumn get isManual => boolean().withDefault(const Constant(false))();

  /// Last value received from CBAR (kept even while overridden, so
  /// "back to automatic" works offline).
  RealColumn get autoRate => real().nullable()();

  /// CBAR bulletin date of [autoRate].
  DateTimeColumn get rateDate => dateTime().nullable()();

  /// When [rateToAzn] last changed.
  DateTimeColumn get updatedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => <Column>{currency};
}

/// Budget thresholds (80 / 100 %) that already raised an alert, so each one
/// fires at most once per budget and month.
@DataClassName('BudgetAlert')
class BudgetAlerts extends Table {
  IntColumn get budgetId =>
      integer().references(Budgets, #id, onDelete: KeyAction.cascade)();

  /// `yyyy-MM`.
  TextColumn get month => text().withLength(min: 7, max: 7)();

  /// 80 or 100.
  IntColumn get threshold => integer()();
  DateTimeColumn get firedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => <Column>{budgetId, month, threshold};
}

/// Money kept outside the spendable accounts ("Kənar yerlər"): cash at home,
/// money lent to a person, deposits, gold. Counted in net worth only.
@DataClassName('Holding')
class Holdings extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 60)();
  TextColumn get placeType => textEnum<HoldingPlace>()();
  TextColumn get currency => text().withLength(min: 3, max: 3)();
  TextColumn get note => text().withDefault(const Constant(''))();

  /// Annual interest in percent; bank deposits only.
  RealColumn get interestRate => real().nullable()();
  DateTimeColumn get maturityDate => dateTime().nullable()();
  IntColumn get colorIndex => integer().withDefault(const Constant(0))();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}

/// Changes to a holding. The current amount is replayed from these in date
/// order (setValue resets, add adds, withdraw subtracts) and never < 0.
@DataClassName('HoldingEntry')
class HoldingEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get holdingId =>
      integer().references(Holdings, #id, onDelete: KeyAction.cascade)();
  TextColumn get kind => textEnum<HoldingEntryKind>()();

  /// Minor units in the holding's currency. > 0, or >= 0 for setValue.
  IntColumn get amount => integer()();
  DateTimeColumn get date => dateTime()();
  TextColumn get note => text().withDefault(const Constant(''))();

  /// The account move that created this entry; deleting that transaction
  /// deletes the entry with it.
  IntColumn get transactionId => integer()
      .nullable()
      .references(Transactions, #id, onDelete: KeyAction.cascade)();
}
