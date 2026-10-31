// v1.2 data layer: v3 → v4 migration, bonus transfers, transport fares,
// time-of-day filter, and the backup with card photos / transport fields.

import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelir_cixar/core/format.dart';
import 'package:gelir_cixar/data/providers.dart';
import 'package:image/image.dart' as img;
import 'package:sqlite3/sqlite3.dart' as raw;

import 'helpers/test_db.dart';

/// Schema 3 as v1.1 created it (v2 tables + the v3 columns and tables).
const List<String> _v3Schema = <String>[
  '''CREATE TABLE "accounts" ("id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, "name" TEXT NOT NULL, "type" TEXT NOT NULL, "currency" TEXT NOT NULL, "initial_balance" INTEGER NOT NULL DEFAULT 0, "color_index" INTEGER NOT NULL DEFAULT 0, "is_archived" INTEGER NOT NULL DEFAULT 0 CHECK ("is_archived" IN (0, 1)), "created_at" INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER)))''',
  '''CREATE TABLE "categories" ("id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, "name_az" TEXT NOT NULL, "name_en" TEXT NOT NULL, "icon_code_point" INTEGER NOT NULL, "color_index" INTEGER NOT NULL DEFAULT 7, "type" TEXT NOT NULL, "is_archived" INTEGER NOT NULL DEFAULT 0 CHECK ("is_archived" IN (0, 1)), "sort_order" INTEGER NOT NULL DEFAULT 0)''',
  '''CREATE TABLE "holdings" ("id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, "name" TEXT NOT NULL, "place_type" TEXT NOT NULL, "currency" TEXT NOT NULL, "note" TEXT NOT NULL DEFAULT '', "interest_rate" REAL NULL, "maturity_date" INTEGER NULL, "color_index" INTEGER NOT NULL DEFAULT 0, "is_archived" INTEGER NOT NULL DEFAULT 0 CHECK ("is_archived" IN (0, 1)), "created_at" INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER)), "sort_order" INTEGER NOT NULL DEFAULT 0)''',
  '''CREATE TABLE "transactions" ("id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, "type" TEXT NOT NULL, "account_id" INTEGER NOT NULL REFERENCES accounts (id), "to_account_id" INTEGER NULL REFERENCES accounts (id), "category_id" INTEGER NULL REFERENCES categories (id), "amount" INTEGER NOT NULL CHECK("amount" > 0), "to_amount" INTEGER NULL, "date" INTEGER NOT NULL, "note" TEXT NOT NULL DEFAULT '', "created_at" INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER)), "holding_id" INTEGER NULL REFERENCES holdings (id))''',
  '''CREATE TABLE "budgets" ("id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, "category_id" INTEGER NOT NULL REFERENCES categories (id), "month" TEXT NOT NULL, "limit_amount" INTEGER NOT NULL, UNIQUE ("category_id", "month"))''',
  '''CREATE TABLE "exchange_rates" ("currency" TEXT NOT NULL, "rate_to_azn" REAL NOT NULL, "source" TEXT NOT NULL DEFAULT 'seed', "is_manual" INTEGER NOT NULL DEFAULT 0 CHECK ("is_manual" IN (0, 1)), "auto_rate" REAL NULL, "rate_date" INTEGER NULL, "updated_at" INTEGER NULL, PRIMARY KEY ("currency"))''',
  '''CREATE TABLE "budget_alerts" ("budget_id" INTEGER NOT NULL REFERENCES budgets (id) ON DELETE CASCADE, "month" TEXT NOT NULL, "threshold" INTEGER NOT NULL, "fired_at" INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER)), PRIMARY KEY ("budget_id", "month", "threshold"))''',
  '''CREATE TABLE "holding_entries" ("id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, "holding_id" INTEGER NOT NULL REFERENCES holdings (id) ON DELETE CASCADE, "kind" TEXT NOT NULL, "amount" INTEGER NOT NULL, "date" INTEGER NOT NULL, "note" TEXT NOT NULL DEFAULT '', "transaction_id" INTEGER NULL REFERENCES transactions (id) ON DELETE CASCADE)''',
  'CREATE INDEX idx_tx_date ON transactions (date)',
  "INSERT INTO accounts (id, name, type, currency) VALUES (1, 'Nağd', 'cash', 'AZN'), (2, 'Kart', 'card', 'AZN')",
  "INSERT INTO categories (id, name_az, name_en, icon_code_point, type) VALUES "
      "(1, 'Yemək', 'Food', 1, 'expense'), (2, 'Nəqliyyat', 'Transport', 2, 'expense'), "
      "(3, 'Maaş', 'Salary', 3, 'income')",
  "INSERT INTO transactions (type, account_id, category_id, amount, date) VALUES ('expense', 2, 2, 60, 1793000000)",
  "INSERT INTO exchange_rates (currency, rate_to_azn) VALUES ('USD', 1.7)",
];

void _seedV3(dynamic raw, {List<String> extra = const <String>[]}) {
  for (final String s in <String>[..._v3Schema, ...extra]) {
    raw.execute(s);
  }
  raw.execute('PRAGMA user_version = 3');
}

Future<Set<String>> _cols(AppDatabase db, String table) async => <String>{
      for (final QueryRow r in await db.customSelect('PRAGMA table_info($table)').get()) r.read<String>('name'),
    };

/// A small real JPEG.
Uint8List _jpeg() => img.encodeJpg(img.Image(width: 8, height: 5), quality: 80);

void main() {
  group('v3 → v4 migration', () {
    test('adds the v1.2 columns and table, seeds Bonus itkisi, marks Nəqliyyat, keeps data', () async {
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      final AppDatabase db = AppDatabase(NativeDatabase.memory(setup: (raw) => _seedV3(raw)));
      addTearDown(db.close);

      expect((await db.customSelect('PRAGMA user_version').getSingle()).data.values.single, 4);
      expect(await _cols(db, 'accounts'),
          containsAll(<String>['card_design_id', 'card_image_path', 'card_last4', 'bonus_rate_percent']));
      expect(await _cols(db, 'categories'), contains('special_kind'));
      expect(await _cols(db, 'transactions'),
          containsAll(<String>['updated_at', 'transport_mode', 'route_code', 'trips', 'link_group_id']));
      expect(await db.select(db.transportFares).get(), isEmpty, reason: 'table exists');

      final List<Account> accounts = await db.select(db.accounts).get();
      expect(accounts.map((Account a) => a.cardDesignId), <String>['forest', 'ocean'],
          reason: 'per-type default design');
      expect(accounts.every((Account a) => a.bonusRatePercent == 50 && a.cardLast4 == null), isTrue);

      final List<TxCategory> cats = await db.select(db.categories).get();
      expect(cats.firstWhere((TxCategory c) => c.id == 2).specialKind, CategorySpecialKind.transport);
      expect(cats.firstWhere((TxCategory c) => c.id == 1).specialKind, CategorySpecialKind.none);
      final TxCategory loss = cats.singleWhere((TxCategory c) => c.isSystem);
      expect(loss.nameAz, 'Bonus itkisi');
      expect(loss.type, CategoryType.expense);

      final MoneyTx tx = (await db.select(db.transactions).get()).single;
      expect(tx.amount, 60);
      expect(tx.trips, 1);
      expect(tx.transportMode, isNull);
      expect(tx.linkGroupId, isNull);
    });

    test('re-running over a half-applied v4 step is harmless (idempotent)', () async {
      // Columns already present and the system category already seeded, but
      // user_version still 3: as if the version bump was lost after commit.
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      final AppDatabase db = AppDatabase(NativeDatabase.memory(
        setup: (raw) => _seedV3(raw, extra: <String>[
          "ALTER TABLE accounts ADD COLUMN card_design_id TEXT NOT NULL DEFAULT 'teal'",
          "UPDATE accounts SET card_design_id = 'plum' WHERE id = 2",
          "ALTER TABLE categories ADD COLUMN special_kind TEXT NOT NULL DEFAULT 'none'",
          "INSERT INTO categories (name_az, name_en, icon_code_point, type, special_kind) "
              "VALUES ('Bonus itkisi', 'Bonus loss', 4, 'expense', 'bonusLoss')",
          "UPDATE categories SET special_kind = 'transport' WHERE id = 1",
        ]),
      ));
      addTearDown(db.close);

      final List<Account> accounts = await db.select(db.accounts).get();
      expect(accounts.firstWhere((Account a) => a.id == 2).cardDesignId, 'plum',
          reason: 'an existing design value is never overwritten');
      final List<TxCategory> cats = await db.select(db.categories).get();
      expect(cats.where((TxCategory c) => c.isSystem), hasLength(1), reason: 'no second system category');
      expect(cats.where((TxCategory c) => c.isTransport).map((TxCategory c) => c.id), <int>[1],
          reason: 'an existing transport choice is kept');
      expect((await db.customSelect('PRAGMA user_version').getSingle()).data.values.single, 4);
    });

    test('a failure inside the v4 step rolls everything back, and a retry succeeds', () async {
      final Directory dir = Directory.systemTemp.createTempSync('gc_v4');
      addTearDown(() {
        try {
          dir.deleteSync(recursive: true);
        } on FileSystemException {
          // Windows may still hold the file briefly.
        }
      });
      final String path = '${dir.path}${Platform.pathSeparator}db.sqlite';
      final raw.Database seed = raw.sqlite3.open(path);
      // Seeding "Bonus itkisi" is the last v4 step; this trigger makes it
      // fail after the columns and the fares table were already created.
      _seedV3(seed, extra: <String>[
        "CREATE TRIGGER no_new_categories BEFORE INSERT ON categories BEGIN SELECT RAISE(ABORT, 'boom'); END",
      ]);
      seed.close();

      Set<String> rawColumns(String table) {
        final raw.Database r = raw.sqlite3.open(path);
        try {
          return <String>{for (final raw.Row row in r.select('PRAGMA table_info($table)')) row['name'] as String};
        } finally {
          r.close();
        }
      }

      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      final AppDatabase broken = AppDatabase(NativeDatabase(File(path)));
      await expectLater(broken.select(broken.accounts).get(), throwsA(anything));
      await broken.close();

      final raw.Database check = raw.sqlite3.open(path);
      expect(check.select('PRAGMA user_version').single.values.single, 3);
      expect(check.select("SELECT name FROM sqlite_master WHERE name = 'transport_fares'"), isEmpty);
      check
        ..execute('DROP TRIGGER no_new_categories')
        ..close();
      expect(rawColumns('accounts'), isNot(contains('card_design_id')), reason: 'rolled back to a clean v3');
      expect(rawColumns('transactions'), isNot(contains('link_group_id')));

      final AppDatabase db = AppDatabase(NativeDatabase(File(path)));
      expect((await db.select(db.transactions).get()).single.amount, 60);
      expect((await db.select(db.categories).get()).where((TxCategory c) => c.isSystem), hasLength(1));
      await db.close();
    });
  });

  group('bonus transfers', () {
    late AppDatabase db;
    late TransactionRepository repo;
    late int bonus;
    late int card;
    setUp(() async {
      db = openTestDb();
      repo = TransactionRepository(db);
      bonus = await db.into(db.accounts).insert(AccountsCompanion.insert(
            name: 'Bonus',
            type: AccountType.bonus,
            currency: 'AZN',
            initialBalance: const Value<int>(1000),
            bonusRatePercent: const Value<int>(50),
          ));
      card = await db.addAccount(name: 'Kart');
    });
    tearDown(() => db.close());

    Future<Map<int, int>> balances() async => <int, int>{
          for (final AccountWithBalance a in await AccountRepository(db).watchWithBalances().first)
            a.account.id: a.balance,
        };

    test('5 sent at 50 %: 2.50 arrives, 2.50 is a linked bonus-loss expense', () async {
      expect(bonusReceived(500, 50), 250);
      final int id = await repo.saveBonusTransfer(
        fromId: bonus,
        toId: card,
        sent: 500,
        received: bonusReceived(500, 50),
        date: DateTime(2026, 10, 31, 14, 32),
      );
      final List<MoneyTx> rows = await db.select(db.transactions).get();
      expect(rows, hasLength(2));
      final MoneyTx transfer = rows.singleWhere((MoneyTx t) => t.id == id);
      final MoneyTx loss = rows.singleWhere((MoneyTx t) => t.id != id);
      expect(transfer.type, TxType.transfer);
      expect(transfer.amount, 250);
      expect(transfer.toAmount, isNull);
      expect(loss.type, TxType.expense);
      expect(loss.amount, 250);
      expect(loss.accountId, bonus);
      final TxCategory cat = (await db.select(db.categories).get()).singleWhere((TxCategory c) => c.id == loss.categoryId);
      expect(cat.isSystem, isTrue);
      expect(transfer.linkGroupId, isNotNull);
      expect(loss.linkGroupId, transfer.linkGroupId);

      final Map<int, int> b = await balances();
      expect(b[bonus], 1000 - 500, reason: 'bonus −sent');
      expect(b[card], 250, reason: 'target +received');
    });

    test('rounding is half up and received + loss always equals sent', () async {
      expect(bonusReceived(333, 50), 167);
      expect(bonusReceived(1, 50), 1);
      expect(bonusReceived(999, 33), 330);
      await repo.saveBonusTransfer(fromId: bonus, toId: card, sent: 333, received: 167, date: DateTime(2026, 10, 1));
      final int total = (await db.select(db.transactions).get()).fold<int>(0, (int s, MoneyTx t) => s + t.amount);
      expect(total, 333);
    });

    test('deleting either row deletes both; undo restores both and the balances', () async {
      final int id = await repo.saveBonusTransfer(
          fromId: bonus, toId: card, sent: 500, received: 250, date: DateTime(2026, 10, 31));
      final int lossId = (await db.select(db.transactions).get()).singleWhere((MoneyTx t) => t.id != id).id;

      final DeletedTransactions d = await repo.deleteWithLinked(lossId);
      expect(d.isPair, isTrue);
      expect(await db.select(db.transactions).get(), isEmpty);
      expect((await balances())[bonus], 1000);
      expect((await balances())[card], 0);

      await repo.restoreDeleted(d);
      expect((await db.select(db.transactions).get()).map((MoneyTx t) => t.id).toSet(), <int>{id, lossId});
      expect((await balances())[bonus], 500);
      expect((await balances())[card], 250);

      await repo.deleteWithLinked(id);
      expect(await db.select(db.transactions).get(), isEmpty);
    });

    test('editing the pair rewrites both rows in place; no loss means no link', () async {
      final int id = await repo.saveBonusTransfer(
          fromId: bonus, toId: card, sent: 500, received: 250, date: DateTime(2026, 10, 31));
      await repo.saveBonusTransfer(
          transferId: id, fromId: bonus, toId: card, sent: 800, received: 400, date: DateTime(2026, 10, 30));
      List<MoneyTx> rows = await db.select(db.transactions).get();
      expect(rows, hasLength(2));
      expect(rows.map((MoneyTx t) => t.amount).toSet(), <int>{400});
      expect(rows.every((MoneyTx t) => t.date == DateTime(2026, 10, 30)), isTrue);
      expect((await balances())[bonus], 1000 - 800);

      // Received = sent: the loss row goes and the transfer leaves its group.
      await repo.saveBonusTransfer(
          transferId: id, fromId: bonus, toId: card, sent: 300, received: 300, date: DateTime(2026, 10, 30));
      rows = await db.select(db.transactions).get();
      expect(rows.single.id, id);
      expect(rows.single.linkGroupId, isNull);
      expect((await balances())[card], 300);
    });

    test('a plain update of one row dissolves the pair', () async {
      final int id = await repo.saveBonusTransfer(
          fromId: bonus, toId: card, sent: 500, received: 250, date: DateTime(2026, 10, 31));
      final MoneyTx transfer = (await repo.byId(id))!;
      await repo.update(transfer.copyWith(amount: 100));
      final MoneyTx only = (await db.select(db.transactions).get()).single;
      expect(only.linkGroupId, isNull);
      expect(only.updatedAt, isNotNull);
    });

    test('guards: received above sent, cross currency, non-bonus source', () async {
      final int usd = await db.addAccount(name: 'USD', currency: 'USD');
      await expectLater(
          repo.saveBonusTransfer(fromId: bonus, toId: card, sent: 100, received: 101, date: DateTime(2026)),
          throwsArgumentError);
      await expectLater(
          repo.saveBonusTransfer(fromId: bonus, toId: usd, sent: 100, received: 50, date: DateTime(2026)),
          throwsArgumentError);
      await expectLater(
          repo.saveBonusTransfer(fromId: card, toId: bonus, sent: 100, received: 50, date: DateTime(2026)),
          throwsArgumentError);
      expect(await db.select(db.transactions).get(), isEmpty);
    });

    test('the system category cannot be deleted, archived or budgeted', () async {
      final int sys = await db.ensureBonusLossCategory();
      final CategoryRepository cats = CategoryRepository(db);
      await expectLater(cats.deleteOrArchive(sys), throwsStateError);
      await expectLater(cats.setArchived(sys, true), throwsStateError);
      await expectLater(
        BudgetRepository(db).upsert(categoryId: sys, month: '2026-10', limitAmount: 1000),
        throwsArgumentError,
      );
      expect(await db.ensureBonusLossCategory(), sys, reason: 'never seeded twice');
    });

    test('grouping folds the loss into its transfer for lists', () async {
      await repo.saveBonusTransfer(fromId: bonus, toId: card, sent: 500, received: 250, date: DateTime(2026, 10, 31));
      final List<TxDetails> all = await repo.watch(const TxFilter()).first;
      expect(all, hasLength(2));
      final List<TxDetails> grouped = groupBonusPairs(all);
      expect(grouped.single.tx.type, TxType.transfer);
      expect(grouped.single.linkedLoss?.tx.amount, 250);
      expect(grouped.single.sentAmount, 500);
    });
  });

  group('transport fares', () {
    late TransportCatalog catalog;
    setUpAll(() => catalog = TransportCatalog.parse(File('assets/transport/baku.json').readAsStringSync()));

    test('the bundled data parses: bus routes, metro lines and a 0,60 ₼ metro fare', () {
      expect(catalog.bus, isNotEmpty);
      expect(catalog.metroFare, 60);
      expect(catalog.metroLines.map((MetroLine l) => l.id), containsAll(<String>['red', 'green', 'purple']));
      expect(catalog.verifiedAt, isNotNull);
      expect(Fmt.money(catalog.metroFare, 'AZN', 'az'), '0,60${Fmt.nbsp}₼', reason: 'always 2 decimals');
      final BusRoute one = catalog.bus.firstWhere((BusRoute b) => b.code == '1');
      expect(one.fare, 60);
      expect(catalog.bus.any((BusRoute b) => b.uncertain), isTrue);
      // Natural order: 1, 2, … 10 …, then lettered codes.
      expect(catalog.bus.first.code, '1');
      expect(compareRouteCodes('2', '10'), lessThan(0));
      expect(compareRouteCodes('65', '65A'), lessThan(0));
    });

    test('bus route auto-fill: fare × trips, manual typing wins until "Tarifə qaytar"', () {
      final ResolvedFares fares = ResolvedFares.merge(catalog, const <TransportFare>[]);
      final int fare = fares.fareOf(TransportMode.bus, routeCode: '1')!;
      FareAutoFill f = const FareAutoFill().withFare(fare);
      expect(f.amount, 60);
      f = f.withTrips(2);
      expect(f.amount, 120);
      f = f.typed();
      expect(f.amount, isNull, reason: 'a typed amount is not overwritten');
      f = f.withTrips(3);
      expect(f.amount, isNull);
      f = f.resetToFare();
      expect(f.amount, 180);
      expect(f.withTrips(99).trips, FareAutoFill.maxTrips);
      expect(f.withTrips(0).trips, 1);
      expect(fares.fareOf(TransportMode.metro), 60);
      expect(fares.fareOf(TransportMode.taxi), isNull);
    });

    test('a custom fare overrides the bundled one; reset and own routes', () async {
      final AppDatabase db = openTestDb();
      addTearDown(db.close);
      final TransportFareRepository repo = TransportFareRepository(db);

      await repo.setFare(TransportMode.bus, '1', 80);
      ResolvedFares fares = ResolvedFares.merge(catalog, await repo.getAll());
      expect(fares.busRoute('1')!.fare, 80);
      expect(fares.busRoute('1')!.isEdited, isTrue);
      expect(fares.busRoute('1')!.bundledFare, 60);
      expect(const FareAutoFill().withFare(fares.fareOf(TransportMode.bus, routeCode: '1')).withTrips(2).amount, 160);

      await repo.setFare(TransportMode.metro, '', 70);
      fares = ResolvedFares.merge(catalog, await repo.getAll());
      expect(fares.metroFare, 70);
      expect(fares.metroEdited, isTrue);

      await repo.resetFare(TransportMode.bus, '1');
      fares = ResolvedFares.merge(catalog, await repo.getAll());
      expect(fares.busRoute('1')!.fare, 60);

      final Set<String> taken = <String>{for (final BusRoute b in fares.bus) b.code};
      await repo.saveCustomRoute(code: '7K', fromName: 'Ev', toName: 'İş', fare: 60, takenCodes: taken);
      fares = ResolvedFares.merge(catalog, await repo.getAll());
      expect(fares.busRoute('7K')!.isCustom, isTrue);
      expect(fares.search('7k').first.code, '7K', reason: 'code prefix first');
      await expectLater(
        repo.saveCustomRoute(code: '1', fromName: 'A', toName: 'B', fare: 60, takenCodes: taken),
        throwsStateError,
        reason: 'a bundled code is taken',
      );
      await expectLater(repo.setFare(TransportMode.bus, '1', 0), throwsArgumentError);
      await repo.deleteCustomRoute('7K');
      expect(ResolvedFares.merge(catalog, await repo.getAll()).busRoute('7K'), isNull);
    });

    test('accent-free stop search: "xirdalan" finds "Xırdalan"', () {
      expect(foldForSearch('Xırdalan'), foldForSearch('xirdalan'));
      final ResolvedFares fares = ResolvedFares.merge(catalog, const <TransportFare>[]);
      final BusRoute withStop = catalog.bus.firstWhere((BusRoute b) => b.from.isNotEmpty);
      final String word = withStop.from.split(' ').first;
      expect(fares.search(word), contains(withStop));
    });

    test('reports: spend by mode and top routes by trips', () async {
      final AppDatabase db = openTestDb();
      addTearDown(db.close);
      Future<void> ride(TransportMode m, String? route, int trips, int amount) =>
          db.into(db.transactions).insert(TransactionsCompanion.insert(
                type: TxType.expense,
                accountId: Seed.cashAccount,
                categoryId: const Value<int?>(Seed.transport),
                amount: amount,
                date: DateTime(2026, 10, 5),
                transportMode: Value<TransportMode?>(m),
                routeCode: Value<String?>(route),
                trips: Value<int>(trips),
              ));
      await ride(TransportMode.bus, '65', 2, 120);
      await ride(TransportMode.bus, '65', 1, 60);
      await ride(TransportMode.bus, '3', 1, 60);
      await ride(TransportMode.taxi, null, 1, 500);
      final TransportReport r =
          await ReportRepository(db).watchTransport(DateWindow.month(DateTime(2026, 10)), Rates.defaults).first;
      expect(r.byMode, <TransportMode, int>{TransportMode.bus: 240, TransportMode.taxi: 500});
      expect(r.total, 740);
      expect(r.routes.first.code, '65');
      expect(r.routes.first.trips, 3);
      expect(r.routes.first.amount, 180);
    });
  });

  group('time-of-day filter', () {
    test('a window that wraps midnight', () {
      const TimeOfDayRange night = TimeOfDayRange(22 * 60, 6 * 60);
      expect(night.wraps, isTrue);
      expect(night.contains(DateTime(2026, 10, 1, 22)), isTrue);
      expect(night.contains(DateTime(2026, 10, 1, 23, 15)), isTrue);
      expect(night.contains(DateTime(2026, 10, 1, 0, 0)), isTrue);
      expect(night.contains(DateTime(2026, 10, 1, 5, 59)), isTrue);
      expect(night.contains(DateTime(2026, 10, 1, 6, 0)), isTrue, reason: 'both ends inclusive');
      expect(night.contains(DateTime(2026, 10, 1, 6, 1)), isFalse);
      expect(night.contains(DateTime(2026, 10, 1, 12)), isFalse);
      expect(night.contains(DateTime(2026, 10, 1, 21, 59)), isFalse);
      const TimeOfDayRange day = TimeOfDayRange(9 * 60, 17 * 60);
      expect(day.contains(DateTime(2026, 10, 1, 12)), isTrue);
      expect(day.contains(DateTime(2026, 10, 1, 23)), isFalse);
    });

    test('the repository applies it (with a limit) in local time', () async {
      final AppDatabase db = openTestDb();
      addTearDown(db.close);
      await db.addExpense(100, DateTime(2026, 10, 1, 23, 30), note: 'late');
      await db.addExpense(200, DateTime(2026, 10, 2, 3, 0), note: 'night');
      await db.addExpense(300, DateTime(2026, 10, 2, 12, 0), note: 'noon');
      final TransactionRepository repo = TransactionRepository(db);
      const TimeOfDayRange night = TimeOfDayRange(22 * 60, 6 * 60);
      final List<TxDetails> list = await repo.watch(const TxFilter(timeOfDay: night)).first;
      expect(list.map((TxDetails t) => t.tx.note), <String>['night', 'late']);
      final List<TxDetails> one = await repo.watch(const TxFilter(timeOfDay: night, limit: 1)).first;
      expect(one.single.tx.note, 'night');
    });

    test('mode and route filters', () async {
      final AppDatabase db = openTestDb();
      addTearDown(db.close);
      await db.into(db.transactions).insert(TransactionsCompanion.insert(
            type: TxType.expense,
            accountId: Seed.cashAccount,
            categoryId: const Value<int?>(Seed.transport),
            amount: 60,
            date: DateTime(2026, 10, 1),
            transportMode: const Value<TransportMode?>(TransportMode.bus),
            routeCode: const Value<String?>('65'),
          ));
      await db.addExpense(100, DateTime(2026, 10, 1));
      final TransactionRepository repo = TransactionRepository(db);
      expect(await repo.watch(const TxFilter(transportMode: TransportMode.bus)).first, hasLength(1));
      expect(await repo.watch(const TxFilter(routeCode: '65')).first, hasLength(1));
      expect(await repo.watch(const TxFilter(routeCode: '3')).first, isEmpty);
    });
  });

  group('backup v4', () {
    late Directory dirA;
    late Directory dirB;
    late AppDatabase db;
    late CardImageStore store;
    late BackupService backup;
    late String photo;
    late Uint8List jpeg;

    setUp(() async {
      dirA = Directory.systemTemp.createTempSync('gc_img_a');
      dirB = Directory.systemTemp.createTempSync('gc_img_b');
      db = openTestDb();
      store = CardImageStore(() async => dirA);
      backup = BackupService(db, images: store);
      jpeg = _jpeg();
      photo = await store.saveJpeg(jpeg);
      final int bonus = await AccountRepository(db).create(
        name: 'Bonus',
        type: AccountType.bonus,
        currency: 'AZN',
        initialBalance: 1000,
        colorIndex: 0,
        cardDesignId: 'photo',
        cardImagePath: photo,
        cardLast4: '1234',
        bonusRatePercent: 40,
      );
      await TransactionRepository(db)
          .saveBonusTransfer(fromId: bonus, toId: Seed.cashAccount, sent: 500, received: 200, date: DateTime(2026, 10, 3));
      await db.into(db.transactions).insert(TransactionsCompanion.insert(
            type: TxType.expense,
            accountId: Seed.cashAccount,
            categoryId: const Value<int?>(Seed.transport),
            amount: 120,
            date: DateTime(2026, 10, 4, 8, 14),
            transportMode: const Value<TransportMode?>(TransportMode.bus),
            routeCode: const Value<String?>('65'),
            trips: const Value<int>(2),
          ));
      await TransportFareRepository(db).setFare(TransportMode.bus, '65', 80);
      await TransportFareRepository(db).saveCustomRoute(code: '7K', fromName: 'Ev', toName: 'İş', fare: 60);
    });
    tearDown(() async {
      await db.close();
      for (final Directory d in <Directory>[dirA, dirB]) {
        try {
          d.deleteSync(recursive: true);
        } on FileSystemException {
          // Windows may still hold a file briefly.
        }
      }
    });

    test('round-trips card photo, card fields, transport fields, fares and the bonus pair', () async {
      final BackupExport export = await backup.export(appVersion: 'test');
      expect(export.skippedImages, 0);
      final Map<String, dynamic> root = jsonDecode(export.json) as Map<String, dynamic>;
      expect(root['schemaVersion'], 4);
      expect((root['cardImages'] as List<dynamic>).single['name'], photo);

      // Restore into a fresh database with an empty photo folder.
      final AppDatabase other = openTestDb();
      addTearDown(other.close);
      final CardImageStore otherStore = CardImageStore(() async => dirB);
      await BackupService(other, images: otherStore).restoreJson(export.json);

      final Account a = (await other.select(other.accounts).get()).singleWhere((Account x) => x.name == 'Bonus');
      expect(a.type, AccountType.bonus);
      expect(a.cardDesignId, 'photo');
      expect(a.cardImagePath, photo);
      expect(a.cardLast4, '1234');
      expect(a.bonusRatePercent, 40);
      expect(await otherStore.read(photo), jpeg, reason: 'the photo file is written');

      final List<MoneyTx> rows = await other.select(other.transactions).get();
      final MoneyTx bus = rows.singleWhere((MoneyTx t) => t.transportMode == TransportMode.bus);
      expect(bus.routeCode, '65');
      expect(bus.trips, 2);
      expect(bus.date, DateTime(2026, 10, 4, 8, 14));
      expect(rows.where((MoneyTx t) => t.linkGroupId != null), hasLength(2));
      final List<TransportFare> fares = await other.select(other.transportFares).get();
      expect(fares.map((TransportFare f) => f.code).toSet(), <String>{'65', '7K'});
      expect((await other.select(other.categories).get()).where((TxCategory c) => c.isSystem), hasLength(1));
    });

    Future<void> expectRejected(void Function(Map<String, dynamic> root) corrupt) async {
      final Map<String, dynamic> root = jsonDecode(await backup.exportJson(appVersion: 'test')) as Map<String, dynamic>;
      corrupt(root);
      await expectLater(
        backup.restoreJson(jsonEncode(root)),
        throwsA(isA<BackupException>().having((BackupException e) => e.reason, 'reason', BackupFailure.invalidData)),
      );
      expect((await db.select(db.transactions).get()), hasLength(3), reason: 'nothing changed');
      expect(await store.read(photo), jpeg, reason: 'the current photo survives');
    }

    Map<String, dynamic> image(Map<String, dynamic> root) =>
        (root['cardImages'] as List<dynamic>).cast<Map<String, dynamic>>().single;

    List<Map<String, dynamic>> table(Map<String, dynamic> root, String k) =>
        ((root['tables'] as Map<String, dynamic>)[k] as List<dynamic>).cast<Map<String, dynamic>>();

    test('rejects a payload that is not a JPEG / PNG', () => expectRejected(
          (Map<String, dynamic> r) => image(r)['data'] = base64Encode(utf8.encode('<svg>not an image</svg>')),
        ));

    test('rejects an oversized image', () => expectRejected((Map<String, dynamic> r) {
          final Uint8List big = Uint8List(CardImageStore.maxBytes + 1)
            ..setAll(0, <int>[0xFF, 0xD8, 0xFF, 0xE0]);
          image(r)['data'] = base64Encode(big);
        }));

    test('rejects path tricks, orphan images and broken pairs', () async {
      await expectRejected((Map<String, dynamic> r) {
        image(r)['name'] = '../evil.jpg';
        table(r, 'accounts').firstWhere((Map<String, dynamic> a) => a['cardImagePath'] != null)['cardImagePath'] =
            '../evil.jpg';
      });
      await expectRejected((Map<String, dynamic> r) =>
          table(r, 'accounts').firstWhere((Map<String, dynamic> a) => a['cardImagePath'] != null)['cardImagePath'] =
              null);
      await expectRejected((Map<String, dynamic> r) => table(r, 'accounts').first['cardLast4'] = '12345678');
      await expectRejected((Map<String, dynamic> r) => table(r, 'accounts').first['bonusRatePercent'] = 0);
      // A loss row without its transfer.
      await expectRejected((Map<String, dynamic> r) => table(r, 'transactions')
          .removeWhere((Map<String, dynamic> t) => t['type'] == 'transfer'));
      await expectRejected((Map<String, dynamic> r) =>
          table(r, 'transactions').firstWhere((Map<String, dynamic> t) => t['transportMode'] != null)['trips'] = 500);
      await expectRejected((Map<String, dynamic> r) =>
          table(r, 'transportFares').first['fare'] = 0);
    });

    test('an image over 1 MB is left out of the export with a count', () async {
      final Uint8List big = Uint8List(CardImageStore.maxBytes + 10)..setAll(0, <int>[0xFF, 0xD8, 0xFF, 0xE0]);
      await store.write(photo, big);
      final BackupExport export = await backup.export(appVersion: 'test');
      expect(export.skippedImages, 1);
      final Map<String, dynamic> root = jsonDecode(export.json) as Map<String, dynamic>;
      expect(root['cardImages'], isEmpty);
      expect(table(root, 'accounts').every((Map<String, dynamic> a) => a['cardImagePath'] == null), isTrue);
      // ... and that file still restores.
      await backup.restoreJson(export.json);
    });

    test('a v3 backup restores: defaults filled, Nəqliyyat marked, Bonus itkisi added', () async {
      final Map<String, dynamic> root = jsonDecode(await backup.exportJson(appVersion: 'test')) as Map<String, dynamic>;
      root['schemaVersion'] = 3;
      root.remove('cardImages');
      final Map<String, dynamic> tables = root['tables'] as Map<String, dynamic>;
      tables.remove('transportFares');
      for (final Map<String, dynamic> a in table(root, 'accounts')) {
        a
          ..remove('cardDesignId')
          ..remove('cardImagePath')
          ..remove('cardLast4')
          ..remove('bonusRatePercent')
          ..['type'] = a['type'] == 'bonus' ? 'card' : a['type'];
      }
      tables['categories'] = table(root, 'categories')
          .where((Map<String, dynamic> c) => c['specialKind'] != 'bonusLoss')
          .map((Map<String, dynamic> c) => c..remove('specialKind'))
          .toList();
      tables['transactions'] = <Map<String, dynamic>>[
        for (final Map<String, dynamic> t in table(root, 'transactions'))
          if (t['linkGroupId'] == null)
            t
              ..remove('transportMode')
              ..remove('routeCode')
              ..remove('trips')
              ..remove('linkGroupId')
              ..remove('updatedAt'),
      ];
      await backup.restoreJson(jsonEncode(root));
      final List<Account> accounts = await db.select(db.accounts).get();
      expect(accounts.firstWhere((Account a) => a.name == 'Nağd').cardDesignId, 'forest');
      expect(accounts.every((Account a) => a.bonusRatePercent == 50), isTrue);
      final List<TxCategory> cats = await db.select(db.categories).get();
      expect(cats.singleWhere((TxCategory c) => c.isTransport).id, Seed.transport);
      expect(cats.where((TxCategory c) => c.isSystem), hasLength(1));
      expect((await db.select(db.transactions).get()).single.trips, 1);
      expect(await store.read(photo), isNull, reason: 'photos no account references are cleaned up');
    });
  });
}
