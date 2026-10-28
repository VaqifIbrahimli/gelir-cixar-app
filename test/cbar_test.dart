// CBAR rates: parser on a real bulletin (fixture, no network), the client's
// day fallback and error mapping against a fake HTTP client, and applying
// rates with manual overrides.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gelir_cixar/data/cbar/cbar_client.dart';
import 'package:gelir_cixar/data/cbar/cbar_parser.dart';
import 'package:gelir_cixar/data/database.dart';
import 'package:gelir_cixar/data/models.dart';
import 'package:gelir_cixar/data/repositories/rate_repository.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'helpers/test_db.dart';

/// Real https://www.cbar.az/currencies/28.10.2026.xml (bulletin dated 27.10).
final String fixture = File('test/fixtures/cbar_27.10.2026.xml').readAsStringSync();

void main() {
  group('CbarParser', () {
    test('reads foreign currencies as AZN per unit, nominal applied', () {
      final CbarBulletin b = CbarParser.parse(fixture);
      expect(b.date, DateTime(2026, 10, 27));
      expect(b.rates['USD'], 1.7);
      expect(b.rates['EUR'], 1.8987);
      // RUB is quoted per 100 units.
      expect(b.rates['RUB'], closeTo(2.1036 / 100, 1e-12));
      expect(b.rates['TRY'], 0.0341);
      // JPY is per 100 too.
      expect(b.rates['JPY'], closeTo(1.0788 / 100, 1e-12));
    });

    test('ignores the bank metals section', () {
      final CbarBulletin b = CbarParser.parse(fixture);
      for (final String metal in <String>['XAU', 'XAG', 'XPT', 'XPD']) {
        expect(b.rates.containsKey(metal), isFalse, reason: metal);
      }
    });

    test('rejects empty, non-XML and wrong documents', () {
      expect(() => CbarParser.parse(''), throwsA(isA<CbarParseException>()));
      expect(() => CbarParser.parse('<html>maintenance</html>'), throwsA(isA<CbarParseException>()));
      expect(() => CbarParser.parse('not xml <'), throwsA(isA<CbarParseException>()));
      expect(
        () => CbarParser.parse('<ValCurs Date="27.10.2026"><ValType Type="Bank metalları"/></ValCurs>'),
        throwsA(isA<CbarParseException>()),
      );
      expect(
        () => CbarParser.parse('<ValCurs Date="2026-10-27"><ValType Type="Xarici valyutalar"/></ValCurs>'),
        throwsA(isA<CbarParseException>()),
      );
    });

    test('skips malformed entries but keeps the good ones', () {
      const String xml = '''
<ValCurs Date="01.11.2026"><ValType Type="Xarici valyutalar">
  <Valute Code="USD"><Nominal>1</Nominal><Value>1.7</Value></Valute>
  <Valute Code="EUR"><Nominal>0</Nominal><Value>1.9</Value></Valute>
  <Valute Code="RUB"><Nominal>100</Nominal><Value>-2</Value></Valute>
  <Valute Code="bad"><Nominal>1</Nominal><Value>3</Value></Valute>
</ValType></ValCurs>''';
      final CbarBulletin b = CbarParser.parse(xml);
      expect(b.rates, <String, double>{'USD': 1.7});
    });
  });

  group('CbarClient', () {
    test('builds the official HTTPS URL', () {
      final Uri u = CbarClient.urlFor(DateTime(2026, 3, 7));
      expect(u.toString(), 'https://www.cbar.az/currencies/07.03.2026.xml');
    });

    test('falls back to earlier days on 404 / empty, without redirects', () async {
      final List<Uri> asked = <Uri>[];
      final CbarClient c = CbarClient(
        client: MockClient((http.Request r) async {
          asked.add(r.url);
          expect(r.followRedirects, isFalse);
          expect(r.url.host, CbarClient.host);
          expect(r.url.scheme, 'https');
          if (r.url.path.endsWith('28.10.2026.xml')) return http.Response('', 404);
          if (r.url.path.endsWith('27.10.2026.xml')) return http.Response('', 200);
          return http.Response.bytes(utf8.encode(fixture), 200);
        }),
      );
      final CbarBulletin b = await c.fetchLatest(DateTime(2026, 10, 28, 9));
      expect(b.rates['USD'], 1.7);
      expect(asked.map((Uri u) => u.pathSegments.last), <String>[
        '28.10.2026.xml',
        '27.10.2026.xml',
        '26.10.2026.xml',
      ]);
    });

    test('gives up after 8 days with a server error', () async {
      int calls = 0;
      final CbarClient c = CbarClient(
        client: MockClient((_) async {
          calls++;
          return http.Response('gone', 404);
        }),
      );
      await expectLater(
        c.fetchLatest(DateTime(2026, 10, 28)),
        throwsA(isA<CbarException>().having((CbarException e) => e.failure, 'failure', CbarFailure.server)),
      );
      expect(calls, CbarClient.fallbackDays + 1);
    });

    test('redirects are a server failure, not followed', () async {
      final CbarClient c = CbarClient(
        client: MockClient((_) async => http.Response('', 302, headers: <String, String>{
              'location': 'https://example.com/x.xml',
            })),
      );
      await expectLater(
        c.fetchLatest(DateTime(2026, 10, 28)),
        throwsA(isA<CbarException>().having((CbarException e) => e.failure, 'failure', CbarFailure.server)),
      );
    });

    test('maps connection problems to offline and stops at once', () async {
      int calls = 0;
      final CbarClient c = CbarClient(
        client: MockClient((_) async {
          calls++;
          throw http.ClientException('Failed host lookup');
        }),
      );
      await expectLater(
        c.fetchLatest(DateTime(2026, 10, 28)),
        throwsA(isA<CbarException>().having((CbarException e) => e.failure, 'failure', CbarFailure.offline)),
      );
      expect(calls, 1);
    });

    test('broken XML on every day is a parse failure', () async {
      final CbarClient c = CbarClient(client: MockClient((_) async => http.Response('<oops', 200)));
      await expectLater(
        c.fetchLatest(DateTime(2026, 10, 28)),
        throwsA(isA<CbarException>().having((CbarException e) => e.failure, 'failure', CbarFailure.parse)),
      );
    });
  });

  group('RateRepository CBAR', () {
    late AppDatabase db;
    late RateRepository repo;
    setUp(() {
      db = openTestDb();
      repo = RateRepository(db);
    });
    tearDown(() => db.close());

    Future<Map<String, ExchangeRate>> rows() async => <String, ExchangeRate>{
          for (final ExchangeRate r in await db.select(db.exchangeRates).get()) r.currency: r,
        };

    test('applies sane rates and leaves manual ones alone', () async {
      await repo.setRate('EUR', 2.5);
      final RateApplyResult r = await repo.applyCbar(CbarParser.parse(fixture), now: DateTime(2026, 10, 28));
      expect(r.updated, unorderedEquals(<String>['USD', 'RUB', 'TRY']));
      expect(r.keptManual, <String>['EUR']);

      final Map<String, ExchangeRate> m = await rows();
      expect(m['USD']!.rateToAzn, 1.7);
      expect(m['USD']!.source, RateSource.cbar);
      expect(m['USD']!.rateDate, DateTime(2026, 10, 27));
      expect(m['RUB']!.rateToAzn, closeTo(0.021036, 1e-12));
      expect(m['EUR']!.rateToAzn, 2.5);
      expect(m['EUR']!.isManual, isTrue);
      expect(m['EUR']!.autoRate, 1.8987);

      // "Avtomatik dəyərə qaytar" uses the stored CBAR value, offline.
      expect(await repo.resetToAuto('EUR'), isTrue);
      final ExchangeRate eur = (await rows())['EUR']!;
      expect(eur.isManual, isFalse);
      expect(eur.rateToAzn, 1.8987);
      expect(eur.source, RateSource.cbar);
    });

    test('rejects values outside 0.0001..1000 AZN', () async {
      final RateApplyResult r = await repo.applyCbar(
        CbarBulletin(
          date: DateTime(2026, 10, 27),
          rates: <String, double>{'USD': 1700, 'EUR': 0.00001, 'RUB': 0.02, 'TRY': double.nan},
        ),
      );
      expect(r.updated, <String>['RUB']);
      final Map<String, ExchangeRate> m = await rows();
      expect(m['USD']!.rateToAzn, 1.70);
      expect(m['EUR']!.rateToAzn, 1.85);
      expect(m['RUB']!.rateToAzn, 0.02);
    });

    test('a manual edit sets the override flag', () async {
      await repo.setRate('USD', 1.71);
      final ExchangeRate usd = (await rows())['USD']!;
      expect(usd.isManual, isTrue);
      expect(usd.source, RateSource.manual);
      expect(await repo.resetToAuto('USD'), isFalse, reason: 'no CBAR value yet');
      expect((await rows())['USD']!.isManual, isFalse);
    });

    test('Rates conversion uses the effective rate', () async {
      await repo.applyCbar(CbarParser.parse(fixture));
      final Rates r = await repo.watch().first;
      expect(r.toBase(10000, 'RUB'), 210); // 100 RUB = 2.1036 AZN
    });
  });
}
