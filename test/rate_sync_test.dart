// Automatic CBAR rates: the network is touched only when the toggle is on
// and the stored rates are stale (or on an explicit refresh).

import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelir_cixar/core/prefs.dart';
import 'package:gelir_cixar/data/providers.dart';
import 'package:gelir_cixar/features/settings/rate_sync_controller.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/test_db.dart';

void main() {
  final List<int> fixture = utf8.encode(File('test/fixtures/cbar_27.10.2026.xml').readAsStringSync());
  final DateTime now = DateTime(2026, 10, 28, 9);

  Future<(ProviderContainer, List<Uri>)> make(
    Map<String, Object> prefs, {
    http.Response Function()? respond,
  }) async {
    SharedPreferences.setMockInitialValues(prefs);
    final SharedPreferences p = await SharedPreferences.getInstance();
    final AppDatabase db = openTestDb();
    final List<Uri> calls = <Uri>[];
    final ProviderContainer c = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(p),
        databaseProvider.overrideWithValue(db),
        cbarClientProvider.overrideWithValue(CbarClient(
          client: MockClient((http.Request r) async {
            calls.add(r.url);
            return respond?.call() ?? http.Response.bytes(fixture, 200);
          }),
        )),
      ],
    );
    addTearDown(() async {
      c.dispose();
      await db.close();
    });
    return (c, calls);
  }

  test('off by default: start-up never touches the network', () async {
    final (ProviderContainer c, List<Uri> calls) = await make(<String, Object>{});
    expect(c.read(rateSyncProvider).enabled, isFalse);
    await c.read(rateSyncProvider.notifier).refreshIfStale(now: now);
    expect(calls, isEmpty);
  });

  test('enabled + fresh (< 12 h): no request', () async {
    final (ProviderContainer c, List<Uri> calls) = await make(<String, Object>{
      PrefKeys.autoRates: true,
      PrefKeys.ratesFetchedAt: now.subtract(const Duration(hours: 3)).millisecondsSinceEpoch,
    });
    await c.read(rateSyncProvider.notifier).refreshIfStale(now: now);
    expect(calls, isEmpty);
  });

  test('enabled + stale: refreshes and applies CBAR rates', () async {
    final (ProviderContainer c, List<Uri> calls) = await make(<String, Object>{
      PrefKeys.autoRates: true,
      PrefKeys.ratesFetchedAt: now.subtract(const Duration(hours: 13)).millisecondsSinceEpoch,
    });
    await c.read(rateSyncProvider.notifier).refreshIfStale(now: now);
    expect(calls, hasLength(1));
    final RateSyncState s = c.read(rateSyncProvider);
    expect(s.error, isNull);
    expect(s.fetchedAt, now);
    expect(s.bulletinDate, DateTime(2026, 10, 27));
    final Rates r = await c.read(rateRepositoryProvider).watch().first;
    expect(r.rateOf('USD'), 1.7);
    expect(c.read(sharedPreferencesProvider).getInt(PrefKeys.ratesFetchedAt), now.millisecondsSinceEpoch);
  });

  test('a failed refresh reports the kind and keeps the old rates', () async {
    final (ProviderContainer c, _) = await make(
      <String, Object>{PrefKeys.autoRates: true},
      respond: () => http.Response('', 500),
    );
    expect(await c.read(rateSyncProvider.notifier).refresh(now: now), CbarFailure.server);
    expect(c.read(rateSyncProvider).error, CbarFailure.server);
    expect(c.read(rateSyncProvider).busy, isFalse);
    expect((await c.read(rateRepositoryProvider).watch().first).rateOf('USD'), 1.70);
  });
}
