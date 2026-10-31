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
    TransportFares,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? driftDatabase(name: 'gelir_cixar'));

  @override
  int get schemaVersion => 4;

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
          await _createV4Indexes();
          await _seed();
          await _seedV4();
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
              if (from < 4) await _migrateV4(m);
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

  /// Card design a pre-v1.2 account gets, by type (mirrors
  /// `AccountTypeStyle.defaultDesignId` in core/theme.dart).
  static const Map<String, String> defaultDesignByType = <String, String>{
    'cash': 'forest',
    'card': 'ocean',
    'bank': 'midnight',
    'savings': 'teal',
    'bonus': 'gold',
  };

  /// Seeded name of the expense category that records bonus-transfer losses.
  static const String bonusLossNameAz = 'Bonus itkisi';
  static const String bonusLossNameEn = 'Bonus loss';

  /// Seeded name of the transport category (id 2 on a fresh install).
  static const String transportNameAz = 'Nəqliyyat';
  static const int transportSeedId = 2;

  /// v3 -> v4 (v1.2): card design / photo / last4 / bonus rate on accounts,
  /// specialKind on categories, transport + link fields on transactions,
  /// the transport_fares table and the "Bonus itkisi" system category.
  /// Runs inside the onUpgrade transaction; every step is idempotent.
  Future<void> _migrateV4(Migrator m) async {
    final Set<String> accCols = await _columns('accounts');
    for (final GeneratedColumn<Object> c in <GeneratedColumn<Object>>[
      accounts.cardDesignId,
      accounts.cardImagePath,
      accounts.cardLast4,
      accounts.bonusRatePercent,
    ]) {
      if (!accCols.contains(c.name)) await m.addColumn(accounts, c);
    }
    if (!accCols.contains(accounts.cardDesignId.name)) {
      // Only when the column is new: an existing value was the user's pick.
      for (final MapEntry<String, String> e in defaultDesignByType.entries) {
        await customStatement(
          'UPDATE accounts SET card_design_id = ? WHERE type = ?',
          <Object>[e.value, e.key],
        );
      }
    }
    final Set<String> catCols = await _columns('categories');
    if (!catCols.contains(categories.specialKind.name)) {
      await m.addColumn(categories, categories.specialKind);
    }
    final Set<String> txCols = await _columns('transactions');
    for (final GeneratedColumn<Object> c in <GeneratedColumn<Object>>[
      transactions.updatedAt,
      transactions.transportMode,
      transactions.routeCode,
      transactions.trips,
      transactions.linkGroupId,
    ]) {
      if (!txCols.contains(c.name)) await m.addColumn(transactions, c);
    }
    await m.createTable(transportFares);
    // The seeded Nəqliyyat becomes the transport category: by seed id when
    // it still has its seeded name, else by name. Only if none is marked yet.
    final QueryRow marked = await customSelect(
      "SELECT COUNT(*) AS n FROM categories WHERE special_kind = 'transport'",
    ).getSingle();
    if (marked.read<int>('n') == 0) {
      await customStatement(
        "UPDATE categories SET special_kind = 'transport' "
        "WHERE id = (SELECT id FROM categories WHERE type = 'expense' AND special_kind = 'none' "
        'AND (id = ? OR name_az = ?) ORDER BY (id = ? AND name_az = ?) DESC, id LIMIT 1)',
        <Object>[transportSeedId, transportNameAz, transportSeedId, transportNameAz],
      );
    }
    await _createV4Indexes();
    await ensureBonusLossCategory();
  }

  Future<void> _createV4Indexes() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_tx_link ON transactions (link_group_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_tx_transport ON transactions (transport_mode, route_code)',
    );
  }

  /// Fresh install: Nəqliyyat (id 2) is the transport category, plus the
  /// bonus-loss system category.
  Future<void> _seedV4() async {
    await (update(categories)..where((c) => c.id.equals(transportSeedId)))
        .write(const CategoriesCompanion(specialKind: Value(CategorySpecialKind.transport)));
    await ensureBonusLossCategory();
  }

  /// Id of the "Bonus itkisi" system category, created when missing (also
  /// after restoring a pre-v1.2 backup). Raw SQL, so it also works inside
  /// the migration before drift's generated table matches the file.
  Future<int> ensureBonusLossCategory() async {
    final QueryRow? row = await customSelect(
      "SELECT id FROM categories WHERE special_kind = 'bonusLoss' ORDER BY id LIMIT 1",
    ).getSingleOrNull();
    if (row != null) {
      // A system category is never archived.
      await customStatement(
        'UPDATE categories SET is_archived = 0 WHERE id = ?',
        <Object>[row.read<int>('id')],
      );
      return row.read<int>('id');
    }
    final QueryRow maxRow =
        await customSelect('SELECT COALESCE(MAX(sort_order), 0) AS m FROM categories').getSingle();
    await customStatement(
      'INSERT INTO categories (name_az, name_en, icon_code_point, color_index, type, '
      "is_archived, sort_order, special_kind) VALUES (?, ?, ?, 6, 'expense', 0, ?, 'bonusLoss')",
      <Object>[
        bonusLossNameAz,
        bonusLossNameEn,
        Icons.trending_down.codePoint,
        maxRow.read<int>('m') + 1,
      ],
    );
    final QueryRow id = await customSelect('SELECT last_insert_rowid() AS id').getSingle();
    return id.read<int>('id');
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
