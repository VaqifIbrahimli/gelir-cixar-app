import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/material.dart' show Icons;

import 'enums.dart';
import 'tables.dart';

export 'enums.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: <Type>[
    Accounts,
    Categories,
    Transactions,
    Budgets,
    ExchangeRates,
    BudgetAlerts,
    Holdings,
    HoldingEntries,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? driftDatabase(name: 'gelir_cixar'));

  @override
  int get schemaVersion => 3;

  /// Seeded defaults; a v2 rate that differs from these was typed by the user.
  static const Map<String, double> defaultRates = <String, double>{
    'USD': 1.70,
    'EUR': 1.85,
    'RUB': 0.019,
    'TRY': 0.05,
  };

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_tx_date ON transactions (date)',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_tx_account ON transactions (account_id)',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_tx_to_account ON transactions (to_account_id)',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_tx_category ON transactions (category_id)',
          );
          await _createV3Indexes();
          await _seed();
        },
        // drift does not wrap onUpgrade in a transaction and only bumps
        // user_version after it returns. So the whole upgrade runs in one
        // transaction (SQLite DDL is transactional: a crash half-way rolls
        // back to a clean v2), and every step is idempotent in case the
        // commit succeeded but the version bump did not.
        onUpgrade: (Migrator m, int from, int to) => transaction(() async {
              if (from < 2) await m.createTable(budgetAlerts);
              if (from < 3) {
                final Set<String> rateCols = await _columns('exchange_rates');
                for (final GeneratedColumn<Object> c in <GeneratedColumn<Object>>[
                  exchangeRates.source,
                  exchangeRates.isManual,
                  exchangeRates.autoRate,
                  exchangeRates.rateDate,
                  exchangeRates.updatedAt,
                ]) {
                  if (!rateCols.contains(c.name)) await m.addColumn(exchangeRates, c);
                }
                // Rates edited by hand in v2 become manual overrides, so
                // turning on automatic CBAR rates never silently replaces
                // them. Only flags change; no rate value is touched, and
                // rows already marked (or set by CBAR) are left alone.
                for (final MapEntry<String, double> e in defaultRates.entries) {
                  await customStatement(
                    "UPDATE exchange_rates SET is_manual = 1, source = 'manual' "
                    "WHERE currency = ? AND rate_to_azn <> ? AND source = 'seed'",
                    <Object>[e.key, e.value],
                  );
                }
                await m.createTable(holdings);
                await m.createTable(holdingEntries);
                if (!(await _columns('transactions')).contains(transactions.holdingId.name)) {
                  await m.addColumn(transactions, transactions.holdingId);
                }
                await _createV3Indexes();
              }
            }),
        beforeOpen: (OpeningDetails details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  /// Column names of [table] (for idempotent migrations).
  Future<Set<String>> _columns(String table) async => <String>{
        for (final QueryRow r in await customSelect('PRAGMA table_info($table)').get())
          r.read<String>('name'),
      };

  Future<void> _createV3Indexes() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_tx_holding ON transactions (holding_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_holding_entry ON holding_entries (holding_id, date)',
    );
  }

  Future<void> _seed() async {
    await batch((Batch b) {
      b.insertAll(exchangeRates, <ExchangeRatesCompanion>[
        _rate(Currency.usd, 1.70),
        _rate(Currency.eur, 1.85),
        _rate(Currency.rub, 0.019),
        _rate(Currency.tryLira, 0.05),
      ]);

      b.insert(
        accounts,
        AccountsCompanion.insert(
          name: 'Nağd',
          type: AccountType.cash,
          currency: Currency.azn.code,
          colorIndex: const Value(2),
        ),
      );

      int order = 0;
      CategoriesCompanion cat(
        String az,
        String en,
        int icon,
        int color,
        CategoryType type,
      ) =>
          CategoriesCompanion.insert(
            nameAz: az,
            nameEn: en,
            iconCodePoint: icon,
            colorIndex: Value(color),
            type: type,
            sortOrder: Value(order++),
          );

      const CategoryType e = CategoryType.expense;
      const CategoryType i = CategoryType.income;
      b.insertAll(categories, <CategoriesCompanion>[
        cat('Yemək', 'Food', Icons.restaurant.codePoint, 1, e),
        cat('Nəqliyyat', 'Transport', Icons.directions_bus.codePoint, 0, e),
        cat('Kommunal', 'Utilities', Icons.bolt.codePoint, 5, e),
        cat('Alış-veriş', 'Shopping', Icons.shopping_bag.codePoint, 6, e),
        cat('Sağlamlıq', 'Health', Icons.local_hospital.codePoint, 3, e),
        cat('Əyləncə', 'Entertainment', Icons.movie.codePoint, 4, e),
        cat('Təhsil', 'Education', Icons.school.codePoint, 8, e),
        cat('Kirayə', 'Rent', Icons.home.codePoint, 9, e),
        cat('Rabitə', 'Telecom', Icons.phone_android.codePoint, 11, e),
        cat('Digər', 'Other', Icons.more_horiz.codePoint, 7, e),
        cat('Maaş', 'Salary', Icons.payments.codePoint, 2, i),
        cat('Bonus', 'Bonus', Icons.star.codePoint, 6, i),
        cat('Hədiyyə', 'Gift', Icons.redeem.codePoint, 10, i),
        cat('Digər gəlir', 'Other income', Icons.attach_money.codePoint, 7, i),
      ]);
    });
  }

  static ExchangeRatesCompanion _rate(Currency c, double r) =>
      ExchangeRatesCompanion.insert(currency: c.code, rateToAzn: r);
}
