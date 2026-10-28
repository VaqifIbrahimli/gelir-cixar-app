import 'dart:convert';

import 'database.dart';
import 'holding_math.dart';
import 'models.dart' show BudgetThresholds;

/// Thrown when a backup file cannot be restored. [reason] is a stable code
/// the UI maps to a localised message.
class BackupException implements Exception {
  const BackupException(this.reason, [this.detail]);

  final BackupFailure reason;
  final Object? detail;

  @override
  String toString() => 'BackupException($reason, $detail)';
}

enum BackupFailure { notJson, wrongFormat, newerSchema, invalidData, tooLarge }

/// Full JSON backup of every table, and an all-or-nothing restore.
///
/// File shape:
/// ```json
/// { "format": "gelir_cixar_backup", "schemaVersion": 3, "appVersion": "1.0.0",
///   "createdAt": "...", "tables": { "accounts": [...], ... } }
/// ```
/// Rows use drift's JSON serialisation (camelCase keys, DateTime as epoch ms,
/// enums by name).
class BackupService {
  BackupService(this._db);

  final AppDatabase _db;

  static const String format = 'gelir_cixar_backup';

  /// Largest backup file accepted (~150k transactions); bigger input is
  /// refused before it is read or parsed.
  static const int maxBytes = 32 * 1024 * 1024;

  /// Per-table row caps, far above real use, so a crafted file cannot make
  /// the restore run for minutes.
  static const Map<String, int> maxRows = <String, int>{
    'accounts': 1000,
    'categories': 1000,
    'transactions': 300000,
    'budgets': 100000,
    'exchangeRates': 100,
    'budgetAlerts': 300000,
    'holdings': 10000,
    'holdingEntries': 300000,
  };

  /// Matches the amount keypad (10 integer digits, 2 decimals).
  static const int maxAmountMinor = 999999999999;

  /// Same limit as the note field in the transaction editor, with headroom.
  static const int maxNoteLength = 1000;

  /// Entries of the categorical palette (AppColors.categorical).
  static const int paletteSize = 12;

  Future<String> exportJson({required String appVersion}) async {
    final Map<String, Object?> data = <String, Object?>{
      'format': format,
      'schemaVersion': _db.schemaVersion,
      'appVersion': appVersion,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'tables': <String, Object?>{
        'accounts': (await _db.select(_db.accounts).get()).map((Account r) => r.toJson()).toList(),
        'categories':
            (await _db.select(_db.categories).get()).map((TxCategory r) => r.toJson()).toList(),
        'transactions':
            (await _db.select(_db.transactions).get()).map((MoneyTx r) => r.toJson()).toList(),
        'budgets': (await _db.select(_db.budgets).get()).map((Budget r) => r.toJson()).toList(),
        'exchangeRates': (await _db.select(_db.exchangeRates).get())
            .map((ExchangeRate r) => r.toJson())
            .toList(),
        'budgetAlerts': (await _db.select(_db.budgetAlerts).get())
            .map((BudgetAlert r) => r.toJson())
            .toList(),
        'holdings':
            (await _db.select(_db.holdings).get()).map((Holding r) => r.toJson()).toList(),
        'holdingEntries': (await _db.select(_db.holdingEntries).get())
            .map((HoldingEntry r) => r.toJson())
            .toList(),
      },
    };
    return const JsonEncoder.withIndent(' ').convert(data);
  }

  /// Parses and validates [json] completely, then replaces all data inside a
  /// single transaction. Any failure leaves the current data untouched.
  Future<BackupSummary> restoreJson(String json) async {
    // UTF-16 length <= UTF-8 byte length, so this never rejects a file that
    // passed the byte check in the UI.
    if (json.length > maxBytes) throw const BackupException(BackupFailure.tooLarge);
    final _Parsed p = _parse(json);
    _validate(p);
    try {
      await _db.transaction(() async {
        await _db.delete(_db.budgetAlerts).go();
        await _db.delete(_db.budgets).go();
        await _db.delete(_db.holdingEntries).go();
        await _db.delete(_db.transactions).go();
        await _db.delete(_db.holdings).go();
        await _db.delete(_db.categories).go();
        await _db.delete(_db.accounts).go();
        await _db.delete(_db.exchangeRates).go();
        await _db.batch((b) {
          b.insertAll(_db.accounts, p.accounts);
          b.insertAll(_db.categories, p.categories);
          b.insertAll(_db.holdings, p.holdings);
          b.insertAll(_db.transactions, p.transactions);
          b.insertAll(_db.holdingEntries, p.holdingEntries);
          b.insertAll(_db.budgets, p.budgets);
          b.insertAll(_db.exchangeRates, p.rates);
          b.insertAll(_db.budgetAlerts, p.alerts);
        });
      });
    } on BackupException {
      rethrow;
    } catch (e) {
      // Constraint violations (e.g. a transaction pointing at a missing
      // account) roll the transaction back.
      throw BackupException(BackupFailure.invalidData, e);
    }
    return BackupSummary(
      accounts: p.accounts.length,
      categories: p.categories.length,
      transactions: p.transactions.length,
    );
  }

  _Parsed _parse(String json) {
    final Object? root;
    try {
      root = jsonDecode(json);
    } on FormatException catch (e) {
      throw BackupException(BackupFailure.notJson, e);
    }
    if (root is! Map<String, Object?> || root['format'] != format) {
      throw const BackupException(BackupFailure.wrongFormat);
    }
    final Object? version = root['schemaVersion'];
    if (version is! int || version < 1) {
      throw const BackupException(BackupFailure.wrongFormat);
    }
    if (version > _db.schemaVersion) {
      throw BackupException(BackupFailure.newerSchema, version);
    }
    final Object? tables = root['tables'];
    if (tables is! Map<String, Object?>) {
      throw const BackupException(BackupFailure.wrongFormat);
    }

    List<T> rows<T>(
      String key,
      T Function(Map<String, dynamic>) fromJson, {
      bool optional = false,
      Map<String, dynamic> Function(Map<String, dynamic>)? upgrade,
    }) {
      final Object? list = tables[key];
      if (list == null && optional) return <T>[];
      if (list is! List<Object?>) {
        throw BackupException(BackupFailure.wrongFormat, key);
      }
      if (list.length > maxRows[key]!) {
        throw BackupException(BackupFailure.invalidData, '$key: too many rows');
      }
      try {
        return <T>[
          for (final Object? r in list)
            fromJson(upgrade == null
                ? r! as Map<String, dynamic>
                : upgrade(Map<String, dynamic>.of(r! as Map<String, dynamic>))),
        ];
      } catch (e) {
        throw BackupException(BackupFailure.invalidData, '$key: $e');
      }
    }

    return _Parsed(
      accounts: rows('accounts', Account.fromJson),
      categories: rows('categories', TxCategory.fromJson),
      transactions: rows('transactions', MoneyTx.fromJson),
      budgets: rows('budgets', Budget.fromJson),
      rates: rows(
        'exchangeRates',
        ExchangeRate.fromJson,
        upgrade: version < 3 ? _upgradeRateRow : null,
      ),
      // Absent in schema-1 backups.
      alerts: rows('budgetAlerts', BudgetAlert.fromJson, optional: true),
      // Absent before schema 3.
      holdings: rows('holdings', Holding.fromJson, optional: true),
      holdingEntries: rows('holdingEntries', HoldingEntry.fromJson, optional: true),
    );
  }

  /// Pre-v3 rate rows have only currency + rateToAzn. A value that differs
  /// from the seeded default was typed by the user, so it becomes a manual
  /// override (same rule as the v2 to v3 database migration).
  static Map<String, dynamic> _upgradeRateRow(Map<String, dynamic> r) {
    final Object? code = r['currency'];
    final Object? value = r['rateToAzn'];
    final bool manual = value is num && AppDatabase.defaultRates[code] != value.toDouble();
    return r
      ..putIfAbsent('isManual', () => manual)
      ..putIfAbsent('source', () => manual ? RateSource.manual.name : RateSource.seed.name);
  }

  /// Semantic checks drift's column constraints do not cover, so a restored
  /// file can only contain data the app itself could have written. Column
  /// lengths and NOT NULL are checked by drift on insert, and foreign keys by
  /// SQLite; both roll the whole restore back.
  static void _validate(_Parsed p) {
    Never bad(String what) => throw BackupException(BackupFailure.invalidData, what);
    bool amountOk(int v) => v > 0 && v <= maxAmountMinor;
    bool colorOk(int v) => v >= 0 && v < paletteSize;
    final RegExp month = RegExp(r'^\d{4}-(0[1-9]|1[0-2])$');
    final Set<String> currencies = <String>{for (final Currency c in Currency.values) c.code};
    final DateTime minDate = DateTime(1900);
    final DateTime maxDate = DateTime(2200);
    bool dateOk(DateTime d) => !d.isBefore(minDate) && d.isBefore(maxDate);

    final Map<int, String> accountCurrency = <int, String>{};
    for (final Account a in p.accounts) {
      if (accountCurrency.containsKey(a.id)) bad('account id ${a.id} repeated');
      accountCurrency[a.id] = a.currency;
      if (!currencies.contains(a.currency)) bad('account currency');
      if (a.initialBalance.abs() > maxAmountMinor) bad('account balance');
      if (!colorOk(a.colorIndex)) bad('account color');
    }

    final Map<int, CategoryType> categoryTypes = <int, CategoryType>{};
    for (final TxCategory c in p.categories) {
      if (categoryTypes.containsKey(c.id)) bad('category id ${c.id} repeated');
      categoryTypes[c.id] = c.type;
      if (!colorOk(c.colorIndex)) bad('category color');
      if (c.iconCodePoint < 0 || c.iconCodePoint > 0x10FFFF) bad('category icon');
    }

    final Set<int> accountIds = accountCurrency.keys.toSet();

    final Map<int, Holding> holdings = <int, Holding>{};
    for (final Holding h in p.holdings) {
      if (holdings.containsKey(h.id)) bad('holding id ${h.id} repeated');
      holdings[h.id] = h;
      if (!currencies.contains(h.currency)) bad('holding currency');
      if (!colorOk(h.colorIndex)) bad('holding color');
      if (h.note.length > maxNoteLength) bad('holding note');
      final double? rate = h.interestRate;
      if (rate != null && (!rate.isFinite || rate < 0 || rate > 100)) bad('holding interest');
      if (h.maturityDate != null && !dateOk(h.maturityDate!)) bad('holding maturity');
      if (h.placeType != HoldingPlace.bankDeposit && (rate != null || h.maturityDate != null)) {
        bad('deposit fields on ${h.placeType.name}');
      }
    }

    final Map<int, MoneyTx> moves = <int, MoneyTx>{};
    for (final MoneyTx t in p.transactions) {
      if (!amountOk(t.amount)) bad('transaction amount');
      if (!dateOk(t.date)) bad('transaction date');
      if (t.note.length > maxNoteLength) bad('transaction note');
      if (!accountIds.contains(t.accountId)) bad('transaction account');
      if (t.type.isHoldingMove) {
        final int? h = t.holdingId;
        if (h == null || !holdings.containsKey(h)) bad('move holding');
        if (t.toAccountId != null || t.categoryId != null) bad('move with account/category');
        // Same shape HoldingRepository.move writes: toAmount only (and
        // always) when the account and holding currencies differ.
        final bool sameCurrency = accountCurrency[t.accountId] == holdings[h]!.currency;
        if (sameCurrency ? t.toAmount != null : t.toAmount == null) bad('move currency');
        if (t.toAmount != null && !amountOk(t.toAmount!)) bad('move amount');
        if (moves.containsKey(t.id)) bad('transaction id ${t.id} repeated');
        moves[t.id] = t;
        continue;
      }
      if (t.holdingId != null) bad('holding on ${t.type.name}');
      if (t.type == TxType.transfer) {
        final int? to = t.toAccountId;
        if (to == null || to == t.accountId || !accountIds.contains(to)) {
          bad('transfer target');
        }
        if (t.categoryId != null) bad('transfer with category');
        if (t.toAmount != null && !amountOk(t.toAmount!)) bad('transfer amount');
      } else {
        if (t.toAccountId != null || t.toAmount != null) bad('transfer fields on ${t.type.name}');
        final int? cat = t.categoryId;
        if (cat != null && categoryTypes[cat] != t.type.categoryType) {
          bad('transaction category');
        }
      }
    }

    final Set<int> budgetIds = <int>{};
    for (final Budget b in p.budgets) {
      if (!budgetIds.add(b.id)) bad('budget id ${b.id} repeated');
      if (!categoryTypes.containsKey(b.categoryId)) bad('budget category');
      if (!month.hasMatch(b.month)) bad('budget month');
      if (!amountOk(b.limitAmount)) bad('budget limit');
    }

    final Set<int> entryIds = <int>{};
    final Map<int, List<HoldingEntry>> byHolding = <int, List<HoldingEntry>>{};
    final Set<int> linkedMoves = <int>{};
    for (final HoldingEntry e in p.holdingEntries) {
      if (!entryIds.add(e.id)) bad('holding entry id ${e.id} repeated');
      if (!holdings.containsKey(e.holdingId)) bad('entry holding');
      if (!dateOk(e.date)) bad('entry date');
      if (e.note.length > maxNoteLength) bad('entry note');
      final int? txId = e.transactionId;
      if (txId != null) {
        final MoneyTx? m = moves[txId];
        if (m == null || m.holdingId != e.holdingId || !linkedMoves.add(txId)) bad('entry move');
        final HoldingEntryKind expected =
            m.type == TxType.toHolding ? HoldingEntryKind.add : HoldingEntryKind.withdraw;
        if (e.kind != expected) bad('entry move kind');
        // The entry must move exactly what the account side moved, on the
        // same day; otherwise a file could debit 1 ₼ and credit a fortune.
        if (e.amount != (m.toAmount ?? m.amount)) bad('entry move amount');
        if (e.date != m.date) bad('entry move date');
      }
      byHolding.putIfAbsent(e.holdingId, () => <HoldingEntry>[]).add(e);
    }
    if (linkedMoves.length != moves.length) bad('move without holding entry');
    for (final List<HoldingEntry> list in byHolding.values) {
      try {
        HoldingMath.replay(list);
      } on HoldingAmountException {
        bad('holding amount out of range');
      }
    }

    for (final ExchangeRate r in p.rates) {
      final double? auto = r.autoRate;
      if (auto != null && (!auto.isFinite || auto <= 0 || auto > 1e6)) bad('auto rate value');
      if (r.rateDate != null && !dateOk(r.rateDate!)) bad('rate date');
      if (!currencies.contains(r.currency) || r.currency == Currency.base.code) {
        bad('rate currency');
      }
      if (!r.rateToAzn.isFinite || r.rateToAzn <= 0 || r.rateToAzn > 1e6) bad('rate value');
    }

    for (final BudgetAlert a in p.alerts) {
      if (!budgetIds.contains(a.budgetId)) bad('alert budget');
      if (!month.hasMatch(a.month)) bad('alert month');
      if (a.threshold != BudgetThresholds.warning && a.threshold != BudgetThresholds.danger) {
        bad('alert threshold');
      }
    }
  }
}

class BackupSummary {
  const BackupSummary({
    required this.accounts,
    required this.categories,
    required this.transactions,
  });

  final int accounts;
  final int categories;
  final int transactions;
}

class _Parsed {
  const _Parsed({
    required this.accounts,
    required this.categories,
    required this.transactions,
    required this.budgets,
    required this.rates,
    required this.alerts,
    required this.holdings,
    required this.holdingEntries,
  });

  final List<Account> accounts;
  final List<TxCategory> categories;
  final List<MoneyTx> transactions;
  final List<Budget> budgets;
  final List<ExchangeRate> rates;
  final List<BudgetAlert> alerts;
  final List<Holding> holdings;
  final List<HoldingEntry> holdingEntries;
}
