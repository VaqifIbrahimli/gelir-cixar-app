// Security regression tests for the v1.1 additions: CBAR feed hardening
// (XML, size cap, dates, big-change gate), the v2→v3 migration under
// partial failure, backup consistency of account↔holding moves, and the
// data-layer guards around holding moves.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelir_cixar/data/providers.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqlite3/sqlite3.dart' as raw;

import 'helpers/test_db.dart';

final String fixture = File('test/fixtures/cbar_27.10.2026.xml').readAsStringSync();

String _bulletin(String valutes, {String date = '27.10.2026', String prolog = ''}) =>
    '$prolog<ValCurs Date="$date"><ValType Type="Xarici valyutalar">$valutes</ValType></ValCurs>';

String _valute(String code, String nominal, String value) =>
    '<Valute Code="$code"><Nominal>$nominal</Nominal><Value>$value</Value></Valute>';

Matcher _failure(CbarFailure f) =>
    throwsA(isA<CbarException>().having((CbarException e) => e.failure, 'failure', f));

void main() {
  group('CbarParser hardening', () {
    test('rejects any DOCTYPE: internal entities (billion laughs)', () {
      const String laughs = '<?xml version="1.0"?>'
          '<!DOCTYPE ValCurs [<!ENTITY a "aaaaaaaaaa"><!ENTITY b "&a;&a;&a;&a;&a;&a;&a;&a;&a;&a;">'
          '<!ENTITY c "&b;&b;&b;&b;&b;&b;&b;&b;&b;&b;">]>';
      expect(
        () => CbarParser.parse(_bulletin(_valute('USD', '1', '1.7'), prolog: laughs)),
        throwsA(isA<CbarParseException>()),
      );
    });

    test('rejects any DOCTYPE: external entities (XXE)', () {
      const String xxe = '<!DOCTYPE ValCurs [<!ENTITY x SYSTEM "file:///data/data/az.vaqif.gelir_cixar/">]>';
      expect(
        () => CbarParser.parse(_bulletin(
            '${_valute('USD', '1', '1.7')}<Valute Code="EUR"><Nominal>1</Nominal><Value>&x;</Value></Valute>',
            prolog: xxe)),
        throwsA(isA<CbarParseException>()),
      );
    });

    test('an undeclared entity is never resolved into a value', () {
      // Without a DOCTYPE there is nothing to resolve; the value text is not
      // a number, so the row is skipped.
      final CbarBulletin b = CbarParser.parse(_bulletin(
        '${_valute('USD', '1', '1.7')}<Valute Code="EUR"><Nominal>1</Nominal><Value>&x;</Value></Valute>',
      ));
      expect(b.rates, <String, double>{'USD': 1.7});
    });

    test('rejects deep nesting and oversized input', () {
      // Valid rates plus a deep junk branch: only the depth limit rejects it.
      final String deep = _bulletin('${_valute('USD', '1', '1.7')}${'<a>' * 50}${'</a>' * 50}');
      expect(() => CbarParser.parse(deep), throwsA(isA<CbarParseException>()));
      final String big = _bulletin('${_valute('USD', '1', '1.7')}<!--${'x' * CbarParser.maxLength}-->');
      expect(() => CbarParser.parse(big), throwsA(isA<CbarParseException>()));
      // The real bulletin is well inside both limits.
      expect(CbarParser.parse(fixture).rates, isNotEmpty);
    });

    test('numbers: no locale comma, sign, exponent, NaN/Infinity or non-ASCII digits', () {
      final CbarBulletin b = CbarParser.parse(_bulletin(<String>[
        _valute('USD', '1', '1.7'),
        _valute('EUR', '1', '1,8987'),
        _valute('RUB', '100', '-2.1'),
        _valute('TRY', '1', 'NaN'),
        _valute('GBP', '1', 'Infinity'),
        _valute('CHF', '1', '2e0'),
        _valute('JPY', '1', '+1.0'),
        _valute('CNY', '1', '٢.٣'),
        _valute('KZT', '0', '1.0'),
        _valute('GEL', '1', '0'),
        _valute('UAH', '1', '9' * 400),
      ].join()));
      expect(b.rates, <String, double>{'USD': 1.7});
    });

    test('a repeated currency code cannot override the first value', () {
      final CbarBulletin b = CbarParser.parse(_bulletin(_valute('USD', '1', '1.7') + _valute('USD', '1', '170')));
      expect(b.rates['USD'], 1.7);
    });

    test('impossible bulletin dates are rejected, not normalised', () {
      for (final String d in <String>['31.02.2026', '00.10.2026', '27.13.2026']) {
        expect(
          () => CbarParser.parse(_bulletin(_valute('USD', '1', '1.7'), date: d)),
          throwsA(isA<CbarParseException>()),
          reason: d,
        );
      }
    });
  });

  group('CbarClient hardening', () {
    test('sends a bare GET: no body, cookies, auth or user data', () async {
      late http.BaseRequest seen;
      final CbarClient c = CbarClient(
        client: MockClient((http.Request r) async {
          seen = r;
          return http.Response.bytes(utf8.encode(fixture), 200);
        }),
      );
      await c.fetchLatest(DateTime(2026, 10, 28));
      expect(seen.method, 'GET');
      expect(seen.url.hasQuery, isFalse);
      expect(seen.url.hasFragment, isFalse);
      expect(seen.url.userInfo, isEmpty);
      expect(seen.headers.keys.map((String k) => k.toLowerCase()), <String>['accept']);
      expect((seen as http.Request).bodyBytes, isEmpty);
    });

    test('a body larger than the cap is cut off, not buffered', () async {
      int sent = 0;
      bool cancelled = false;
      final CbarClient c = CbarClient(
        client: MockClient.streaming((http.BaseRequest r, http.ByteStream _) async {
          late StreamController<List<int>> ctl;
          ctl = StreamController<List<int>>(
            onListen: () async {
              final List<int> chunk = List<int>.filled(64 * 1024, 0x20);
              while (!cancelled && sent < 64 * 1024 * 1024) {
                sent += chunk.length;
                ctl.add(chunk);
                await Future<void>.delayed(Duration.zero);
              }
              await ctl.close();
            },
            onCancel: () => cancelled = true,
          );
          // No Content-Length: only the streamed cap can stop it.
          return http.StreamedResponse(ctl.stream, 200);
        }),
      );
      await expectLater(c.fetchLatest(DateTime(2026, 10, 28)), _failure(CbarFailure.server));
      expect(cancelled, isTrue);
      // Each of the 8 attempts stops right after crossing the cap.
      expect(sent, lessThan((CbarClient.fallbackDays + 1) * (CbarClient.maxBytes + 128 * 1024)));
    });

    test('a declared Content-Length over the cap is not downloaded', () async {
      final CbarClient c = CbarClient(
        client: MockClient.streaming((http.BaseRequest r, http.ByteStream _) async => http.StreamedResponse(
              Stream<List<int>>.value(utf8.encode(fixture)),
              200,
              contentLength: CbarClient.maxBytes + 1,
            )),
      );
      await expectLater(c.fetchLatest(DateTime(2026, 10, 28)), _failure(CbarFailure.server));
    });

    test('TLS / certificate errors are offline, not retried', () async {
      int calls = 0;
      final CbarClient c = CbarClient(
        client: MockClient((_) async {
          calls++;
          throw const HandshakeException('CERTIFICATE_VERIFY_FAILED');
        }),
      );
      await expectLater(c.fetchLatest(DateTime(2026, 10, 28)), _failure(CbarFailure.offline));
      expect(calls, 1);
    });

    test('a bulletin dated far from the requested day is rejected', () async {
      for (final String d in <String>['27.10.2099', '27.10.2000']) {
        final CbarClient c = CbarClient(
          client: MockClient((_) async =>
              http.Response.bytes(utf8.encode(_bulletin(_valute('USD', '1', '1.7'), date: d)), 200)),
        );
        await expectLater(c.fetchLatest(DateTime(2026, 10, 28)), _failure(CbarFailure.parse), reason: d);
      }
      expect(CbarClient.plausibleDate(DateTime(2026, 10, 24), DateTime(2026, 10, 27, 23)), isTrue);
      expect(CbarClient.plausibleDate(DateTime(2026, 10, 28), DateTime(2026, 10, 27)), isTrue);
      expect(CbarClient.plausibleDate(DateTime(2026, 10, 30), DateTime(2026, 10, 27)), isFalse);
    });
  });

  group('RateRepository big-change gate', () {
    late AppDatabase db;
    late RateRepository repo;
    setUp(() async {
      db = openTestDb();
      repo = RateRepository(db);
      await repo.applyCbar(CbarParser.parse(fixture), now: DateTime(2026, 10, 28));
    });
    tearDown(() => db.close());

    Future<ExchangeRate> row(String c) async =>
        (await db.select(db.exchangeRates).get()).firstWhere((ExchangeRate r) => r.currency == c);

    CbarBulletin next(Map<String, double> rates) => CbarBulletin(date: DateTime(2026, 10, 29), rates: rates);

    test('first sync (no previous CBAR value) applies normally', () async {
      expect((await row('USD')).autoRate, 1.7);
      expect((await row('USD')).rateToAzn, 1.7);
    });

    test('a >50% jump is held back, stored nowhere, and reported', () async {
      final RateApplyResult r = await repo.applyCbar(next(<String, double>{'USD': 2.6, 'EUR': 1.95}));
      expect(r.updated, <String>['EUR']);
      expect(r.needsConfirmation.single.currency, 'USD');
      expect(r.needsConfirmation.single.previous, 1.7);
      expect(r.needsConfirmation.single.next, 2.6);
      final ExchangeRate usd = await row('USD');
      expect(usd.rateToAzn, 1.7);
      expect(usd.autoRate, 1.7);
      expect(usd.rateDate, DateTime(2026, 10, 27));

      // A drop of more than half too.
      final RateApplyResult down = await repo.applyCbar(next(<String, double>{'USD': 0.8}));
      expect(down.needsConfirmation.single.currency, 'USD');
      expect(down.updated, isEmpty);
    });

    test('a confirmed jump is applied', () async {
      final RateApplyResult r =
          await repo.applyCbar(next(<String, double>{'USD': 2.6}), confirmed: <String>{'USD'});
      expect(r.updated, <String>['USD']);
      expect(r.needsConfirmation, isEmpty);
      expect((await row('USD')).rateToAzn, 2.6);
    });

    test('a manual override does not hide a suspicious auto value', () async {
      await repo.setRate('USD', 1.75);
      final RateApplyResult r = await repo.applyCbar(next(<String, double>{'USD': 9.0}));
      expect(r.keptManual, isEmpty);
      expect(r.needsConfirmation.single.currency, 'USD');
      expect((await row('USD')).autoRate, 1.7, reason: '"back to automatic" must not pick up 9.0');
    });

    test('exactly 50% is still applied', () async {
      expect(RateRepository.isBigChange(1.0, 1.5), isFalse);
      expect(RateRepository.isBigChange(1.0, 1.5001), isTrue);
      expect(RateRepository.isBigChange(1.0, 0.5), isFalse);
      expect(RateRepository.isBigChange(1.0, 0.4999), isTrue);
    });
  });

  group('v2 → v3 migration robustness', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('gc_mig'));
    tearDown(() {
      try {
        dir.deleteSync(recursive: true);
      } on FileSystemException {
        // Windows may still hold the file briefly.
      }
    });

    const List<String> v2 = <String>[
      '''CREATE TABLE "accounts" ("id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, "name" TEXT NOT NULL, "type" TEXT NOT NULL, "currency" TEXT NOT NULL, "initial_balance" INTEGER NOT NULL DEFAULT 0, "color_index" INTEGER NOT NULL DEFAULT 0, "is_archived" INTEGER NOT NULL DEFAULT 0 CHECK ("is_archived" IN (0, 1)), "created_at" INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER)))''',
      '''CREATE TABLE "categories" ("id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, "name_az" TEXT NOT NULL, "name_en" TEXT NOT NULL, "icon_code_point" INTEGER NOT NULL, "color_index" INTEGER NOT NULL DEFAULT 7, "type" TEXT NOT NULL, "is_archived" INTEGER NOT NULL DEFAULT 0 CHECK ("is_archived" IN (0, 1)), "sort_order" INTEGER NOT NULL DEFAULT 0)''',
      '''CREATE TABLE "transactions" ("id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, "type" TEXT NOT NULL, "account_id" INTEGER NOT NULL REFERENCES accounts (id), "to_account_id" INTEGER NULL REFERENCES accounts (id), "category_id" INTEGER NULL REFERENCES categories (id), "amount" INTEGER NOT NULL CHECK("amount" > 0), "to_amount" INTEGER NULL, "date" INTEGER NOT NULL, "note" TEXT NOT NULL DEFAULT '', "created_at" INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER)))''',
      '''CREATE TABLE "budgets" ("id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, "category_id" INTEGER NOT NULL REFERENCES categories (id), "month" TEXT NOT NULL, "limit_amount" INTEGER NOT NULL, UNIQUE ("category_id", "month"))''',
      '''CREATE TABLE "exchange_rates" ("currency" TEXT NOT NULL, "rate_to_azn" REAL NOT NULL, PRIMARY KEY ("currency"))''',
      '''CREATE TABLE "budget_alerts" ("budget_id" INTEGER NOT NULL REFERENCES budgets (id) ON DELETE CASCADE, "month" TEXT NOT NULL, "threshold" INTEGER NOT NULL, "fired_at" INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER)), PRIMARY KEY ("budget_id", "month", "threshold"))''',
      "INSERT INTO accounts (id, name, type, currency) VALUES (1, 'Nağd', 'cash', 'AZN')",
      "INSERT INTO transactions (type, account_id, amount, date) VALUES ('income', 1, 5000, 1793000000)",
      "INSERT INTO exchange_rates VALUES ('USD', 1.7), ('EUR', 2.0)",
      'PRAGMA user_version = 2',
    ];

    String seed({List<String> extra = const <String>[]}) {
      final String path = '${dir.path}${Platform.pathSeparator}db.sqlite';
      final raw.Database r = raw.sqlite3.open(path);
      for (final String s in <String>[...v2, ...extra]) {
        r.execute(s);
      }
      r.close();
      return path;
    }

    Set<String> rawColumns(String path, String table) {
      final raw.Database r = raw.sqlite3.open(path);
      try {
        return <String>{for (final raw.Row row in r.select('PRAGMA table_info($table)')) row['name'] as String};
      } finally {
        r.close();
      }
    }

    int rawVersion(String path) {
      final raw.Database r = raw.sqlite3.open(path);
      try {
        return r.select('PRAGMA user_version').single.values.single! as int;
      } finally {
        r.close();
      }
    }

    test('a failure half-way rolls back to a clean v2, and a retry succeeds', () async {
      // A view squatting on holding_entries makes CREATE TABLE IF NOT EXISTS
      // a no-op and the index on it fail, after the columns were added.
      final String path = seed(extra: <String>['CREATE VIEW holding_entries AS SELECT 1 AS holding_id, 1 AS date']);
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      final AppDatabase broken = AppDatabase(NativeDatabase(File(path)));
      await expectLater(broken.select(broken.accounts).get(), throwsA(anything));
      await broken.close();

      expect(rawVersion(path), 2);
      expect(rawColumns(path, 'exchange_rates'), <String>{'currency', 'rate_to_azn'});
      expect(rawColumns(path, 'transactions'), isNot(contains('holding_id')));

      final raw.Database r = raw.sqlite3.open(path)..execute('DROP VIEW holding_entries');
      r.close();
      final AppDatabase db = AppDatabase(NativeDatabase(File(path)));
      expect((await db.select(db.transactions).get()).single.amount, 5000);
      final ExchangeRate eur =
          (await db.select(db.exchangeRates).get()).firstWhere((ExchangeRate x) => x.currency == 'EUR');
      expect(eur.isManual, isTrue);
      expect(eur.rateToAzn, 2.0);
      await db.close();
      expect(rawVersion(path), 3);
    });

    test('re-running over an already-applied step is harmless (idempotent)', () async {
      // Columns present but user_version still 2, as if the version bump
      // was lost after a commit.
      final String path = seed(extra: <String>[
        "ALTER TABLE exchange_rates ADD COLUMN source TEXT NOT NULL DEFAULT 'seed'",
        "UPDATE exchange_rates SET source = 'cbar' WHERE currency = 'EUR'",
      ]);
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      final AppDatabase db = AppDatabase(NativeDatabase(File(path)));
      final Map<String, ExchangeRate> m = <String, ExchangeRate>{
        for (final ExchangeRate x in await db.select(db.exchangeRates).get()) x.currency: x,
      };
      expect(m['USD']!.isManual, isFalse);
      expect(m['EUR']!.source, RateSource.cbar, reason: 'a CBAR row is not re-flagged as manual');
      expect(m['EUR']!.rateToAzn, 2.0, reason: 'values are never touched');
      await db.close();
      expect(rawVersion(path), 3);
    });
  });

  group('backup: account ↔ holding consistency', () {
    late AppDatabase db;
    late BackupService backup;
    setUp(() async {
      db = openTestDb();
      backup = BackupService(db);
      final HoldingRepository repo = HoldingRepository(db);
      final int azn = await repo.create(name: 'Seyf', placeType: HoldingPlace.homeCash, currency: 'AZN');
      final int usd = await repo.create(name: 'Dollar', placeType: HoldingPlace.homeCash, currency: 'USD');
      await db.addIncome(100000, DateTime(2026, 10, 1));
      await repo.move(accountId: Seed.cashAccount, holdingId: azn, toHolding: true, amount: 20000, date: DateTime(2026, 10, 2));
      await repo.move(
        accountId: Seed.cashAccount,
        holdingId: usd,
        toHolding: true,
        amount: 17000,
        holdingAmount: 10000,
        date: DateTime(2026, 10, 3),
      );
    });
    tearDown(() => db.close());

    List<Map<String, dynamic>> list(Map<String, dynamic> t, String k) =>
        (t[k] as List<dynamic>).cast<Map<String, dynamic>>();

    Map<String, dynamic> moveTx(Map<String, dynamic> t, int holdingId) =>
        list(t, 'transactions').firstWhere((Map<String, dynamic> x) => x['holdingId'] == holdingId);

    Map<String, dynamic> moveEntry(Map<String, dynamic> t, int holdingId) => list(t, 'holdingEntries')
        .firstWhere((Map<String, dynamic> x) => x['holdingId'] == holdingId && x['transactionId'] != null);

    Future<void> expectRejected(void Function(Map<String, dynamic> tables) corrupt) async {
      final Map<String, dynamic> root =
          jsonDecode(await backup.exportJson(appVersion: 'test')) as Map<String, dynamic>;
      corrupt(root['tables'] as Map<String, dynamic>);
      await expectLater(
        backup.restoreJson(jsonEncode(root)),
        throwsA(isA<BackupException>().having((BackupException e) => e.reason, 'reason', BackupFailure.invalidData)),
      );
      expect((await db.select(db.holdingEntries).get()).length, 2, reason: 'nothing changed');
    }

    test('the honest file round-trips', () async {
      await backup.restoreJson(await backup.exportJson(appVersion: 'test'));
      expect((await HoldingRepository(db).getHoldings(Rates.defaults)).map((HoldingWithValue h) => h.amount),
          <int>[20000, 10000]);
    });

    test('rejects a holding credit that differs from the account debit', () => expectRejected(
          (Map<String, dynamic> t) => moveEntry(t, 1)['amount'] = 999999999,
        ));

    test('rejects a cross-currency credit that differs from toAmount', () => expectRejected(
          (Map<String, dynamic> t) => moveEntry(t, 2)['amount'] = 50000,
        ));

    test('rejects a cross-currency move without toAmount', () => expectRejected(
          (Map<String, dynamic> t) => moveTx(t, 2)['toAmount'] = null,
        ));

    test('rejects a same-currency move with a toAmount', () => expectRejected(
          (Map<String, dynamic> t) {
            moveTx(t, 1)['toAmount'] = 999999;
            moveEntry(t, 1)['amount'] = 999999;
          },
        ));

    test('rejects an entry dated apart from its move', () => expectRejected(
          (Map<String, dynamic> t) => moveEntry(t, 1)['date'] = DateTime(2026, 1, 1).millisecondsSinceEpoch,
        ));

    test('rejects an entry linked to an income, or a move linked twice', () async {
      await expectRejected((Map<String, dynamic> t) {
        final int income = list(t, 'transactions').firstWhere((Map<String, dynamic> x) => x['type'] == 'income')['id']
            as int;
        moveEntry(t, 1)['transactionId'] = income;
      });
      await expectRejected((Map<String, dynamic> t) {
        list(t, 'holdingEntries').add(<String, dynamic>{
          ...moveEntry(t, 1),
          'id': 99,
        });
      });
    });

    test('rejects a move whose entry kind contradicts its direction', () => expectRejected(
          (Map<String, dynamic> t) => moveEntry(t, 1)['kind'] = 'withdraw',
        ));

    test('rejects unknown entry kinds and negative amounts', () async {
      await expectRejected((Map<String, dynamic> t) => moveEntry(t, 1)['kind'] = 'steal');
      await expectRejected((Map<String, dynamic> t) => list(t, 'holdingEntries').add(<String, dynamic>{
            'id': 77,
            'holdingId': 1,
            'kind': 'setValue',
            'amount': -1,
            'date': DateTime(2026, 10, 5).millisecondsSinceEpoch,
            'note': '',
            'transactionId': null,
          }));
    });

    test('a v1 backup (no budgetAlerts, holdings or rate flags) still restores', () async {
      final String v1 = jsonEncode(<String, dynamic>{
        'format': BackupService.format,
        'schemaVersion': 1,
        'appVersion': '1.0.0',
        'createdAt': '2026-01-01T00:00:00Z',
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
          'transactions': <dynamic>[],
          'budgets': <dynamic>[],
          'exchangeRates': <dynamic>[
            <String, dynamic>{'currency': 'USD', 'rateToAzn': 1.7},
          ],
        },
      });
      final BackupSummary s = await backup.restoreJson(v1);
      expect(s.accounts, 1);
      expect(await db.select(db.holdings).get(), isEmpty);
      expect(await db.select(db.holdingEntries).get(), isEmpty);
    });
  });

  group('holding move guards', () {
    late AppDatabase db;
    late HoldingRepository holdings;
    late TransactionRepository txs;
    setUp(() {
      db = openTestDb();
      holdings = HoldingRepository(db);
      txs = TransactionRepository(db);
    });
    tearDown(() => db.close());

    test('deleting a move whose money was withdrawn later is refused, nothing changes', () async {
      final int h = await holdings.create(name: 'Seyf', placeType: HoldingPlace.homeCash, currency: 'AZN');
      final int inTx =
          await holdings.move(accountId: Seed.cashAccount, holdingId: h, toHolding: true, amount: 10000, date: DateTime(2026, 10, 1));
      await holdings.addEntry(holdingId: h, kind: HoldingEntryKind.withdraw, amount: 10000, date: DateTime(2026, 10, 5));

      await expectLater(txs.delete(inTx), throwsA(isA<HoldingAmountException>()));
      expect(await txs.byId(inTx), isNotNull);
      expect(await db.select(db.holdingEntries).get(), hasLength(2));

      // An unrelated move can still be deleted and undone.
      final int out =
          await holdings.move(accountId: Seed.cashAccount, holdingId: h, toHolding: true, amount: 500, date: DateTime(2026, 10, 6));
      final MoneyTx row = (await txs.byId(out))!;
      final List<HoldingEntry> linked = await txs.delete(out);
      expect(linked, hasLength(1));
      await txs.restore(row, entries: linked);
      expect((await holdings.getHoldings(Rates.defaults)).single.amount, 500);
    });

    test('undo is refused if the holding changed so that it no longer fits', () async {
      final int h = await holdings.create(name: 'Seyf', placeType: HoldingPlace.homeCash, currency: 'AZN', initialAmount: 1000, date: DateTime(2026, 10, 1));
      final int out =
          await holdings.move(accountId: Seed.cashAccount, holdingId: h, toHolding: false, amount: 1000, date: DateTime(2026, 10, 2));
      final MoneyTx row = (await txs.byId(out))!;
      final List<HoldingEntry> linked = await txs.delete(out);
      // Meanwhile the money is withdrawn by hand.
      await holdings.addEntry(holdingId: h, kind: HoldingEntryKind.withdraw, amount: 1000, date: DateTime(2026, 10, 3));
      await expectLater(txs.restore(row, entries: linked), throwsA(isA<HoldingAmountException>()));
      expect(await txs.byId(out), isNull);
      expect((await holdings.getHoldings(Rates.defaults)).single.amount, 0);
    });

    test('the generic editor path cannot create or rewrite holding moves', () async {
      final int h = await holdings.create(name: 'Seyf', placeType: HoldingPlace.homeCash, currency: 'AZN');
      expect(
        () => txs.insert(TransactionsCompanion.insert(
          type: TxType.toHolding,
          accountId: Seed.cashAccount,
          holdingId: Value<int?>(h),
          amount: 100,
          date: DateTime(2026, 10, 1),
        )),
        throwsArgumentError,
      );
      expect(
        () => txs.insert(TransactionsCompanion.insert(
          type: TxType.expense,
          accountId: Seed.cashAccount,
          holdingId: Value<int?>(h),
          amount: 100,
          date: DateTime(2026, 10, 1),
        )),
        throwsArgumentError,
      );
      final int move =
          await holdings.move(accountId: Seed.cashAccount, holdingId: h, toHolding: true, amount: 100, date: DateTime(2026, 10, 1));
      final MoneyTx m = (await txs.byId(move))!;
      await expectLater(txs.update(m.copyWith(amount: 999999)), throwsArgumentError);
      await expectLater(
        txs.update(m.copyWith(type: TxType.income, holdingId: const Value<int?>(null))),
        throwsArgumentError,
      );
      expect((await txs.byId(move))!.amount, 100);

      // Ordinary edits still work.
      final int e = await db.addExpense(300, DateTime(2026, 10, 2));
      await txs.update((await txs.byId(e))!.copyWith(amount: 400));
      expect((await txs.byId(e))!.amount, 400);
    });

    test('an account with moves cannot change currency', () async {
      final AccountRepository accounts = AccountRepository(db);
      final int h = await holdings.create(name: 'Seyf', placeType: HoldingPlace.homeCash, currency: 'AZN');
      await holdings.move(accountId: Seed.cashAccount, holdingId: h, toHolding: true, amount: 100, date: DateTime(2026, 10, 1));
      final Account a = (await accounts.byId(Seed.cashAccount))!;
      await expectLater(accounts.update(a.copyWith(currency: 'USD')), throwsStateError);
      await accounts.update(a.copyWith(name: 'Pul kisəsi'));
      expect((await accounts.byId(Seed.cashAccount))!.name, 'Pul kisəsi');

      final int fresh = await db.addAccount(currency: 'AZN');
      await accounts.update((await accounts.byId(fresh))!.copyWith(currency: 'EUR'));
      expect((await accounts.byId(fresh))!.currency, 'EUR');
    });
  });
}
