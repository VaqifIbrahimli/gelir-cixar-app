// "Kənar yerlər": amount derivation, repository rules, account moves (not
// income/expense), net worth, and backup round-trip with holdings.

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelir_cixar/data/providers.dart';

import 'helpers/test_db.dart';

HoldingEntry _e(int id, HoldingEntryKind kind, int amount, DateTime date) =>
    HoldingEntry(id: id, holdingId: 1, kind: kind, amount: amount, date: date, note: '');

void main() {
  group('HoldingMath', () {
    final DateTime d1 = DateTime(2026, 1, 1);
    final DateTime d2 = DateTime(2026, 2, 1);
    final DateTime d3 = DateTime(2026, 3, 1);

    test('replays in date order: setValue resets, add adds, withdraw subtracts', () {
      final List<HoldingEntry> entries = <HoldingEntry>[
        _e(3, HoldingEntryKind.withdraw, 300, d3),
        _e(1, HoldingEntryKind.add, 1000, d1),
        _e(2, HoldingEntryKind.setValue, 5000, d2),
      ];
      expect(HoldingMath.replay(entries).map((HoldingPoint p) => p.amount), <int>[1000, 5000, 4700]);
      expect(HoldingMath.current(entries), 4700);
      expect(HoldingMath.current(<HoldingEntry>[]), 0);
    });

    test('same date: applied in id order', () {
      expect(
        HoldingMath.current(<HoldingEntry>[
          _e(2, HoldingEntryKind.add, 50, d1),
          _e(1, HoldingEntryKind.setValue, 100, d1),
        ]),
        150,
      );
    });

    test('never below zero at any point in history', () {
      expect(
        () => HoldingMath.replay(<HoldingEntry>[
          _e(1, HoldingEntryKind.add, 100, d1),
          _e(2, HoldingEntryKind.withdraw, 200, d2),
          _e(3, HoldingEntryKind.add, 500, d3),
        ]),
        throwsA(isA<HoldingAmountException>()
            .having((HoldingAmountException e) => e.reason, 'reason', HoldingAmountFailure.negative)),
      );
      expect(
        HoldingMath.tryCurrent(<HoldingEntry>[_e(1, HoldingEntryKind.withdraw, 1, d1)]),
        isNull,
      );
    });

    test('amount rules per kind', () {
      expect(() => HoldingMath.checkAmount(HoldingEntryKind.add, 0), throwsA(isA<HoldingAmountException>()));
      expect(() => HoldingMath.checkAmount(HoldingEntryKind.withdraw, -5), throwsA(isA<HoldingAmountException>()));
      HoldingMath.checkAmount(HoldingEntryKind.setValue, 0);
      expect(
        () => HoldingMath.checkAmount(HoldingEntryKind.add, HoldingMath.maxAmount + 1),
        throwsA(isA<HoldingAmountException>()),
      );
    });
  });

  group('HoldingRepository', () {
    late AppDatabase db;
    late HoldingRepository repo;
    const Rates rates = Rates(<String, double>{'USD': 1.7});

    setUp(() {
      db = openTestDb();
      repo = HoldingRepository(db);
    });
    tearDown(() => db.close());

    Future<int> safe() => repo.create(
          name: 'Ev seyfi',
          placeType: HoldingPlace.homeCash,
          currency: 'AZN',
          initialAmount: 50000,
          date: DateTime(2026, 10, 1),
        );

    test('create with an initial amount, then add / withdraw / set value', () async {
      final int h = await safe();
      await repo.addEntry(holdingId: h, kind: HoldingEntryKind.add, amount: 10000, date: DateTime(2026, 10, 2));
      await repo.addEntry(holdingId: h, kind: HoldingEntryKind.withdraw, amount: 5000, date: DateTime(2026, 10, 3));
      expect((await repo.getHoldings(rates)).single.amount, 55000);
      await repo.addEntry(holdingId: h, kind: HoldingEntryKind.setValue, amount: 70000, date: DateTime(2026, 10, 4));
      final HoldingDetail d = (await repo.watchDetail(h).first)!;
      expect(d.amount, 70000);
      expect(d.series.map((HoldingPoint p) => p.amount), <int>[50000, 60000, 55000, 70000]);
      expect(d.entries.first.kind, HoldingEntryKind.setValue, reason: 'history is newest first');
    });

    test('rejects a withdrawal that would go negative, even back-dated', () async {
      final int h = await safe();
      await repo.addEntry(holdingId: h, kind: HoldingEntryKind.withdraw, amount: 40000, date: DateTime(2026, 10, 5));
      await expectLater(
        repo.addEntry(holdingId: h, kind: HoldingEntryKind.withdraw, amount: 20000, date: DateTime(2026, 10, 2)),
        throwsA(isA<HoldingAmountException>()),
      );
      expect((await repo.getHoldings(rates)).single.amount, 10000);
    });

    test('deleting an entry that would break later history is refused', () async {
      final int h = await safe();
      final int add = await repo.addEntry(
        holdingId: h,
        kind: HoldingEntryKind.add,
        amount: 20000,
        date: DateTime(2026, 10, 2),
      );
      await repo.addEntry(holdingId: h, kind: HoldingEntryKind.withdraw, amount: 60000, date: DateTime(2026, 10, 3));
      await expectLater(repo.deleteEntry(add), throwsA(isA<HoldingAmountException>()));
    });

    test('AZN value uses the rates; foreign holding', () async {
      await repo.create(
        name: 'Dollar',
        placeType: HoldingPlace.homeCash,
        currency: 'USD',
        initialAmount: 10000,
      );
      final HoldingWithValue v = (await repo.getHoldings(rates)).single;
      expect(v.amount, 10000);
      expect(v.azn, 17000);
    });

    test('deposit fields only on bank deposits', () async {
      final int h = await repo.create(
        name: 'Ev',
        placeType: HoldingPlace.homeCash,
        currency: 'AZN',
        interestRate: 9.5,
        maturityDate: DateTime(2027, 1, 1),
      );
      final Holding x = (await repo.byId(h))!;
      expect(x.interestRate, isNull);
      expect(x.maturityDate, isNull);
      final int d = await repo.create(
        name: 'Depozit',
        placeType: HoldingPlace.bankDeposit,
        currency: 'AZN',
        interestRate: 9.5,
      );
      expect((await repo.byId(d))!.interestRate, 9.5);
    });

    test('currency is locked once there are entries', () async {
      final int h = await safe();
      final Holding x = (await repo.byId(h))!;
      await expectLater(repo.update(x.copyWith(currency: 'USD')), throwsA(isA<HoldingAmountException>()));
      await repo.update(x.copyWith(name: 'Seyf'));
      expect((await repo.byId(h))!.name, 'Seyf');
    });

    test('move: one tx + one linked entry; account balance follows', () async {
      final int h = await safe();
      final AccountRepository accounts = AccountRepository(db);
      await db.addIncome(100000, DateTime(2026, 10, 1));

      final int tx = await repo.move(
        accountId: Seed.cashAccount,
        holdingId: h,
        toHolding: true,
        amount: 20000,
        date: DateTime(2026, 10, 10),
      );
      expect((await repo.getHoldings(rates)).single.amount, 70000);
      expect((await accounts.watchWithBalances().first).first.balance, 80000);

      await repo.move(
        accountId: Seed.cashAccount,
        holdingId: h,
        toHolding: false,
        amount: 5000,
        date: DateTime(2026, 10, 11),
      );
      expect((await repo.getHoldings(rates)).single.amount, 65000);
      expect((await accounts.watchWithBalances().first).first.balance, 85000);

      // Taking more than the holding has is refused, nothing is written.
      await expectLater(
        repo.move(
          accountId: Seed.cashAccount,
          holdingId: h,
          toHolding: false,
          amount: 999999,
          date: DateTime(2026, 10, 12),
        ),
        throwsA(isA<HoldingAmountException>()),
      );
      expect((await db.select(db.transactions).get()).length, 3);

      // Deleting the transaction removes its entry; undo puts both back.
      final TransactionRepository txs = TransactionRepository(db);
      final MoneyTx row = (await txs.byId(tx))!;
      final List<HoldingEntry> linked = await txs.delete(tx);
      expect(linked, hasLength(1));
      expect((await repo.getHoldings(rates)).single.amount, 45000);
      await txs.restore(row, entries: linked);
      expect((await repo.getHoldings(rates)).single.amount, 65000);

      // Deleting the entry from the holding removes the transaction too.
      await repo.deleteEntry(linked.single.id);
      expect(await txs.byId(tx), isNull);
      expect((await accounts.watchWithBalances().first).first.balance, 100000 + 5000);
    });

    test('cross-currency move stores both amounts', () async {
      final int h = await repo.create(name: 'Dollar', placeType: HoldingPlace.homeCash, currency: 'USD');
      await expectLater(
        repo.move(accountId: Seed.cashAccount, holdingId: h, toHolding: true, amount: 17000, date: DateTime(2026)),
        throwsA(isA<HoldingAmountException>()),
        reason: 'holding amount required when currencies differ',
      );
      final int tx = await repo.move(
        accountId: Seed.cashAccount,
        holdingId: h,
        toHolding: true,
        amount: 17000,
        holdingAmount: 10000,
        date: DateTime(2026),
      );
      final MoneyTx t = (await TransactionRepository(db).byId(tx))!;
      expect(t.amount, 17000);
      expect(t.toAmount, 10000);
      expect((await repo.getHoldings(rates)).single.amount, 10000);
    });

    test('moves are never income, expense or budget spending', () async {
      final int h = await safe();
      final DateTime d = DateTime(2026, 10, 15);
      await db.addExpense(1000, d);
      await BudgetRepository(db).upsert(categoryId: Seed.food, month: '2026-10', limitAmount: 5000);
      await repo.move(accountId: Seed.cashAccount, holdingId: h, toHolding: true, amount: 30000, date: d);
      await repo.move(accountId: Seed.cashAccount, holdingId: h, toHolding: false, amount: 10000, date: d);

      final DateWindow oct = DateWindow.month(d);
      final PeriodTotals t = await TransactionRepository(db).watchTotals(oct, rates).first;
      expect(t.income, 0);
      expect(t.expense, 1000);
      final ReportRepository reports = ReportRepository(db);
      expect(
        (await reports.watchCategoryTotals(oct, TxType.expense, rates).first)
            .fold(0, (int s, CategoryTotal c) => s + c.amount),
        1000,
      );
      expect((await reports.watchMonthly(d, 1, rates).first).months.single.totals.net, -1000);
      expect((await BudgetRepository(db).getMonth('2026-10', rates)).single.spent, 1000);
    });

    test('archive vs delete follows the account rule', () async {
      final int unused = await safe();
      expect(await repo.deleteOrArchive(unused), isTrue);
      expect(await repo.byId(unused), isNull);
      expect(await db.select(db.holdingEntries).get(), isEmpty, reason: 'entries cascade');

      final int used = await safe();
      await repo.move(accountId: Seed.cashAccount, holdingId: used, toHolding: true, amount: 1, date: DateTime(2026));
      expect(await repo.deleteOrArchive(used), isFalse);
      expect((await repo.byId(used))!.isArchived, isTrue);
      expect(await repo.getHoldings(rates), isEmpty);
      expect(await repo.getHoldings(rates, includeArchived: true), hasLength(1));
    });
  });

  group('net worth', () {
    test('accounts total + holdings total in AZN', () async {
      final AppDatabase db = openTestDb();
      final ProviderContainer c = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      addTearDown(() async {
        c.dispose();
        await db.close();
      });
      final ProviderSubscription<AsyncValue<NetWorth>> sub = c.listen(netWorthProvider, (_, _) {});
      addTearDown(sub.close);

      await db.addIncome(100000, DateTime(2026, 10, 1));
      final HoldingRepository repo = HoldingRepository(db);
      final int usd = await repo.create(
        name: 'Dollar',
        placeType: HoldingPlace.homeCash,
        currency: 'USD',
        initialAmount: 10000, // 100 USD = 170 AZN at the seeded 1.70
      );
      await repo.move(
        accountId: Seed.cashAccount,
        holdingId: await repo.create(name: 'Seyf', placeType: HoldingPlace.homeCash, currency: 'AZN'),
        toHolding: true,
        amount: 30000,
        date: DateTime(2026, 10, 2),
      );
      expect(usd, isPositive);

      Future<NetWorth> read() async {
        for (int i = 0; i < 50; i++) {
          await pumpEventQueue();
          final AsyncValue<NetWorth> v = c.read(netWorthProvider);
          if (v.hasValue &&
              v.requireValue.holdings == 17000 + 30000 &&
              v.requireValue.accounts == 70000) {
            return v.requireValue;
          }
        }
        return c.read(netWorthProvider).requireValue;
      }

      final NetWorth w = await read();
      expect(w.accounts, 70000);
      expect(w.holdings, 47000);
      expect(w.total, 117000);
    });
  });

  group('backup with holdings', () {
    late AppDatabase db;
    late BackupService backup;
    setUp(() async {
      db = openTestDb();
      backup = BackupService(db);
      final HoldingRepository repo = HoldingRepository(db);
      final int h = await repo.create(
        name: 'Depozit — Kapital',
        placeType: HoldingPlace.bankDeposit,
        currency: 'AZN',
        interestRate: 10,
        maturityDate: DateTime(2027, 6, 1),
        initialAmount: 100000,
        date: DateTime(2026, 9, 1),
      );
      await db.addIncome(50000, DateTime(2026, 10, 1));
      await repo.move(accountId: Seed.cashAccount, holdingId: h, toHolding: true, amount: 20000, date: DateTime(2026, 10, 2));
      await RateRepository(db).setRate('EUR', 1.9);
    });
    tearDown(() => db.close());

    test('round-trips holdings, entries, moves and rate flags', () async {
      final String json = await backup.exportJson(appVersion: 'test');
      final Map<String, dynamic> parsed = jsonDecode(json) as Map<String, dynamic>;
      expect(parsed['schemaVersion'], 3);

      await HoldingRepository(db).addEntry(
        holdingId: 1,
        kind: HoldingEntryKind.setValue,
        amount: 1,
        date: DateTime(2026, 10, 20),
      );
      await backup.restoreJson(json);

      final HoldingWithValue h = (await HoldingRepository(db).getHoldings(Rates.defaults)).single;
      expect(h.holding.name, 'Depozit — Kapital');
      expect(h.holding.interestRate, 10);
      expect(h.amount, 120000);
      expect((await db.select(db.holdingEntries).get()).where((HoldingEntry e) => e.transactionId != null), hasLength(1));
      expect((await AccountRepository(db).watchWithBalances().first).first.balance, 30000);
      final ExchangeRate eur =
          (await db.select(db.exchangeRates).get()).firstWhere((ExchangeRate r) => r.currency == 'EUR');
      expect(eur.isManual, isTrue);
    });

    Future<void> expectRejected(void Function(Map<String, dynamic> tables) corrupt) async {
      final Map<String, dynamic> root =
          jsonDecode(await backup.exportJson(appVersion: 'test')) as Map<String, dynamic>;
      corrupt(root['tables'] as Map<String, dynamic>);
      final int before = (await db.select(db.holdingEntries).get()).length;
      await expectLater(backup.restoreJson(jsonEncode(root)), throwsA(isA<BackupException>()));
      expect((await db.select(db.holdingEntries).get()).length, before, reason: 'nothing changed');
    }

    List<Map<String, dynamic>> list(Map<String, dynamic> t, String k) =>
        (t[k] as List<dynamic>).cast<Map<String, dynamic>>();

    test('rejects a history that goes below zero', () => expectRejected((Map<String, dynamic> t) {
          list(t, 'holdingEntries').add(<String, dynamic>{
            'id': 99,
            'holdingId': 1,
            'kind': 'withdraw',
            'amount': 999999999,
            'date': DateTime(2026, 12, 1).millisecondsSinceEpoch,
            'note': '',
            'transactionId': null,
          });
        }));

    test('rejects a move without its holding entry', () => expectRejected((Map<String, dynamic> t) {
          list(t, 'holdingEntries').removeWhere((Map<String, dynamic> e) => e['transactionId'] != null);
        }));

    test('rejects a move pointing at a missing holding', () => expectRejected((Map<String, dynamic> t) {
          for (final Map<String, dynamic> tx in list(t, 'transactions')) {
            if (tx['type'] == 'toHolding') tx['holdingId'] = 42;
          }
        }));

    test('rejects deposit fields on a non-deposit and bad place types', () async {
      await expectRejected((Map<String, dynamic> t) => list(t, 'holdings').first['placeType'] = 'gold');
      await expectRejected((Map<String, dynamic> t) => list(t, 'holdings').first['placeType'] = 'mattress');
    });

    test('rejects a holding id on an ordinary expense', () => expectRejected((Map<String, dynamic> t) {
          list(t, 'transactions').first['holdingId'] = 1;
        }));

    test('a v2 backup (no holdings, old rate rows) still restores', () async {
      final String v2 = jsonEncode(<String, dynamic>{
        'format': BackupService.format,
        'schemaVersion': 2,
        'appVersion': '1.0.0',
        'createdAt': '2026-10-01T00:00:00Z',
        'tables': <String, dynamic>{
          'accounts': <dynamic>[
            <String, dynamic>{
              'id': 1,
              'name': 'Nağd',
              'type': 'cash',
              'currency': 'AZN',
              'initialBalance': 0,
              'colorIndex': 2,
              'isArchived': false,
              'createdAt': DateTime(2026).millisecondsSinceEpoch,
            },
          ],
          'categories': <dynamic>[],
          'transactions': <dynamic>[
            <String, dynamic>{
              'id': 1,
              'type': 'income',
              'accountId': 1,
              'toAccountId': null,
              'categoryId': null,
              'amount': 1500,
              'toAmount': null,
              'date': DateTime(2026, 9, 1).millisecondsSinceEpoch,
              'note': '',
              'createdAt': DateTime(2026, 9, 1).millisecondsSinceEpoch,
            },
          ],
          'budgets': <dynamic>[],
          'exchangeRates': <dynamic>[
            <String, dynamic>{'currency': 'USD', 'rateToAzn': 1.7},
            <String, dynamic>{'currency': 'EUR', 'rateToAzn': 2.1},
          ],
          'budgetAlerts': <dynamic>[],
        },
      });
      final BackupSummary s = await backup.restoreJson(v2);
      expect(s.transactions, 1);
      expect(await db.select(db.holdings).get(), isEmpty);
      final Map<String, ExchangeRate> r = <String, ExchangeRate>{
        for (final ExchangeRate x in await db.select(db.exchangeRates).get()) x.currency: x,
      };
      expect(r['USD']!.isManual, isFalse);
      expect(r['USD']!.source, RateSource.seed);
      expect(r['EUR']!.isManual, isTrue);
      expect(r['EUR']!.source, RateSource.manual);
    });
  });
}
