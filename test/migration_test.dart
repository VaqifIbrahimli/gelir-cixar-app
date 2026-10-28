// v2 → v3 migration: exchange_rates gains source / is_manual / auto_rate /
// rate_date / updated_at, transactions gains holding_id, and the holdings +
// holding_entries tables appear. The v2 DDL below is what drift generated
// for schema 2.

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelir_cixar/data/database.dart';
import 'package:gelir_cixar/data/models.dart';
import 'package:gelir_cixar/data/repositories/account_repository.dart';
import 'package:gelir_cixar/data/repositories/holding_repository.dart';
import 'package:sqlite3/sqlite3.dart' as raw;

const List<String> _v2Schema = <String>[
  '''CREATE TABLE "accounts" ("id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, "name" TEXT NOT NULL, "type" TEXT NOT NULL, "currency" TEXT NOT NULL, "initial_balance" INTEGER NOT NULL DEFAULT 0, "color_index" INTEGER NOT NULL DEFAULT 0, "is_archived" INTEGER NOT NULL DEFAULT 0 CHECK ("is_archived" IN (0, 1)), "created_at" INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER)))''',
  '''CREATE TABLE "categories" ("id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, "name_az" TEXT NOT NULL, "name_en" TEXT NOT NULL, "icon_code_point" INTEGER NOT NULL, "color_index" INTEGER NOT NULL DEFAULT 7, "type" TEXT NOT NULL, "is_archived" INTEGER NOT NULL DEFAULT 0 CHECK ("is_archived" IN (0, 1)), "sort_order" INTEGER NOT NULL DEFAULT 0)''',
  '''CREATE TABLE "transactions" ("id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, "type" TEXT NOT NULL, "account_id" INTEGER NOT NULL REFERENCES accounts (id), "to_account_id" INTEGER NULL REFERENCES accounts (id), "category_id" INTEGER NULL REFERENCES categories (id), "amount" INTEGER NOT NULL CHECK("amount" > 0), "to_amount" INTEGER NULL, "date" INTEGER NOT NULL, "note" TEXT NOT NULL DEFAULT '', "created_at" INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER)))''',
  '''CREATE TABLE "budgets" ("id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, "category_id" INTEGER NOT NULL REFERENCES categories (id), "month" TEXT NOT NULL, "limit_amount" INTEGER NOT NULL, UNIQUE ("category_id", "month"))''',
  '''CREATE TABLE "exchange_rates" ("currency" TEXT NOT NULL, "rate_to_azn" REAL NOT NULL, PRIMARY KEY ("currency"))''',
  '''CREATE TABLE "budget_alerts" ("budget_id" INTEGER NOT NULL REFERENCES budgets (id) ON DELETE CASCADE, "month" TEXT NOT NULL, "threshold" INTEGER NOT NULL, "fired_at" INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER)), PRIMARY KEY ("budget_id", "month", "threshold"))''',
  'CREATE INDEX idx_tx_date ON transactions (date)',
  'CREATE INDEX idx_tx_account ON transactions (account_id)',
  'CREATE INDEX idx_tx_to_account ON transactions (to_account_id)',
  'CREATE INDEX idx_tx_category ON transactions (category_id)',
];

/// A v2 database with some user data: USD left at the default, EUR edited
/// by hand, one expense, one budget.
void _seedV2(raw.Database db) {
  for (final String s in _v2Schema) {
    db.execute(s);
  }
  db.execute("INSERT INTO accounts (id, name, type, currency) VALUES (1, 'Nağd', 'cash', 'AZN')");
  db.execute(
    "INSERT INTO categories (id, name_az, name_en, icon_code_point, type) VALUES (1, 'Yemək', 'Food', 1, 'expense')",
  );
  db.execute(
    "INSERT INTO transactions (type, account_id, category_id, amount, date, note) "
    "VALUES ('expense', 1, 1, 1250, 1793000000, 'çörək')",
  );
  db.execute("INSERT INTO budgets (category_id, month, limit_amount) VALUES (1, '2026-10', 50000)");
  db.execute("INSERT INTO exchange_rates VALUES ('USD', 1.7), ('EUR', 2.0), ('RUB', 0.019), ('TRY', 0.05)");
  db.execute('PRAGMA user_version = 2');
}

void main() {
  late AppDatabase db;

  setUp(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    db = AppDatabase(NativeDatabase.memory(setup: _seedV2));
  });
  tearDown(() => db.close());

  test('upgrades to v3 and keeps the data', () async {
    expect(db.schemaVersion, 3);
    final QueryRow v = await db.customSelect('PRAGMA user_version').getSingle();
    expect(v.data.values.single, 3);

    final MoneyTx tx = (await db.select(db.transactions).get()).single;
    expect(tx.amount, 1250);
    expect(tx.note, 'çörək');
    expect(tx.holdingId, isNull);
    expect((await db.select(db.budgets).get()).single.limitAmount, 50000);
    expect((await db.select(db.accounts).get()).single.name, 'Nağd');
  });

  test('a v2 rate edited by hand becomes a manual override', () async {
    final Map<String, ExchangeRate> rates = <String, ExchangeRate>{
      for (final ExchangeRate r in await db.select(db.exchangeRates).get()) r.currency: r,
    };
    expect(rates['EUR']!.isManual, isTrue);
    expect(rates['EUR']!.source, RateSource.manual);
    expect(rates['EUR']!.rateToAzn, 2.0);
    for (final String c in <String>['USD', 'RUB', 'TRY']) {
      expect(rates[c]!.isManual, isFalse, reason: c);
      expect(rates[c]!.source, RateSource.seed, reason: c);
      expect(rates[c]!.autoRate, isNull, reason: c);
    }
  });

  test('holdings work on a migrated database', () async {
    final HoldingRepository repo = HoldingRepository(db);
    final int h = await repo.create(
      name: 'Ev seyfi',
      placeType: HoldingPlace.homeCash,
      currency: 'AZN',
    );
    await repo.move(
      accountId: 1,
      holdingId: h,
      toHolding: true,
      amount: 20000,
      date: DateTime(2026, 10, 20),
    );
    final List<HoldingWithValue> list = await repo.getHoldings(Rates.defaults);
    expect(list.single.amount, 20000);
    final List<AccountWithBalance> acc = await AccountRepository(db).watchWithBalances().first;
    expect(acc.single.balance, -1250 - 20000);

    final List<QueryRow> idx = await db
        .customSelect("SELECT name FROM sqlite_master WHERE type = 'index' AND name LIKE 'idx_%'")
        .get();
    expect(
      idx.map((QueryRow r) => r.read<String>('name')),
      containsAll(<String>['idx_tx_holding', 'idx_holding_entry']),
    );
  });
}
