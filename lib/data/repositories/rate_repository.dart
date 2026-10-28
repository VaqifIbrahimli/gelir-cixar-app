import 'package:drift/drift.dart';

import '../cbar/cbar_parser.dart';
import '../database.dart';
import '../models.dart';

/// A CBAR value held back because it moved more than
/// [RateRepository.maxAutoChange] against the previous CBAR value.
class RateChange {
  const RateChange({required this.currency, required this.previous, required this.next});

  final String currency;

  /// Last stored CBAR value ([ExchangeRate.autoRate]).
  final double previous;

  /// Value in the new bulletin.
  final double next;

  /// Relative change, e.g. 0.8 for +80 %, -0.6 for -60 %.
  double get change => next / previous - 1;
}

/// Result of applying a CBAR bulletin.
class RateApplyResult {
  const RateApplyResult({
    required this.updated,
    required this.keptManual,
    required this.rateDate,
    this.needsConfirmation = const <RateChange>[],
  });

  /// Currencies whose effective rate now comes from CBAR.
  final List<String> updated;

  /// Currencies left alone because the user set them by hand.
  final List<String> keptManual;
  final DateTime rateDate;

  /// Suspicious jumps that were NOT stored (neither the effective rate nor
  /// [ExchangeRate.autoRate]). The UI asks the user and, on confirmation,
  /// calls [RateRepository.applyCbar] again with these codes in `confirmed`.
  final List<RateChange> needsConfirmation;
}

/// Exchange rates to AZN.
class RateRepository {
  RateRepository(this._db);

  final AppDatabase _db;

  /// Plausible AZN per unit. Anything outside is treated as a broken feed.
  static const double minSane = 0.0001;
  static const double maxSane = 1000;

  static bool isSane(double v) => v.isFinite && v >= minSane && v <= maxSane;

  /// A new CBAR value more than 50 % away from the previous CBAR value is
  /// not applied silently: a hostile or broken feed can send numbers that
  /// pass [isSane] but are wrong. Real AZN moves of that size are rare
  /// enough that asking once is cheap.
  static const double maxAutoChange = 0.5;

  static bool isBigChange(double previous, double next) =>
      previous > 0 && (next / previous - 1).abs() > maxAutoChange;

  /// Currencies the app converts (everything but the base).
  static List<String> get foreignCodes => <String>[
        for (final Currency c in Currency.values)
          if (c != Currency.base) c.code,
      ];

  Stream<Rates> watch() => _db.select(_db.exchangeRates).watch().map(
        (List<ExchangeRate> rows) => Rates(<String, double>{
          for (final ExchangeRate r in rows) r.currency: r.rateToAzn,
        }),
      );

  /// Full rows (source, manual flag, CBAR date) for the settings screen.
  Stream<List<ExchangeRate>> watchRows() => (_db.select(_db.exchangeRates)
        ..orderBy(<OrderClauseGenerator<$ExchangeRatesTable>>[(r) => OrderingTerm.asc(r.currency)]))
      .watch();

  /// Manual rate: becomes an override that automatic refresh won't touch.
  Future<void> setRate(String currency, double rateToAzn) =>
      _db.into(_db.exchangeRates).insert(
            ExchangeRatesCompanion.insert(
              currency: currency,
              rateToAzn: rateToAzn,
              source: const Value<RateSource>(RateSource.manual),
              isManual: const Value<bool>(true),
              updatedAt: Value<DateTime?>(DateTime.now()),
            ),
            onConflict: DoUpdate(
              (_) => ExchangeRatesCompanion(
                rateToAzn: Value<double>(rateToAzn),
                source: const Value<RateSource>(RateSource.manual),
                isManual: const Value<bool>(true),
                updatedAt: Value<DateTime?>(DateTime.now()),
              ),
            ),
          );

  /// Stores CBAR rates for the supported currencies. Non-manual currencies
  /// take the new value; manual ones only remember it as [ExchangeRate.autoRate].
  /// Values outside [minSane]..[maxSane] are rejected. A value that moved
  /// more than [maxAutoChange] against the previous CBAR value is held back
  /// in [RateApplyResult.needsConfirmation] unless its code is in [confirmed].
  Future<RateApplyResult> applyCbar(
    CbarBulletin b, {
    DateTime? now,
    Set<String> confirmed = const <String>{},
  }) =>
      _db.transaction(() async {
        final DateTime at = now ?? DateTime.now();
        final Map<String, ExchangeRate> current = <String, ExchangeRate>{
          for (final ExchangeRate r in await _db.select(_db.exchangeRates).get()) r.currency: r,
        };
        final List<String> updated = <String>[];
        final List<String> kept = <String>[];
        final List<RateChange> held = <RateChange>[];
        for (final String code in foreignCodes) {
          final double? v = b.rates[code];
          if (v == null || !isSane(v)) continue;
          final ExchangeRate? old = current[code];
          final double? previous = old?.autoRate;
          if (previous != null && isBigChange(previous, v) && !confirmed.contains(code)) {
            held.add(RateChange(currency: code, previous: previous, next: v));
            continue;
          }
          final bool manual = old?.isManual ?? false;
          await _db.into(_db.exchangeRates).insert(
                ExchangeRatesCompanion.insert(
                  currency: code,
                  rateToAzn: v,
                  source: const Value<RateSource>(RateSource.cbar),
                  autoRate: Value<double?>(v),
                  rateDate: Value<DateTime?>(b.date),
                  updatedAt: Value<DateTime?>(at),
                ),
                onConflict: DoUpdate(
                  (_) => manual
                      ? ExchangeRatesCompanion(
                          autoRate: Value<double?>(v),
                          rateDate: Value<DateTime?>(b.date),
                        )
                      : ExchangeRatesCompanion(
                          rateToAzn: Value<double>(v),
                          source: const Value<RateSource>(RateSource.cbar),
                          autoRate: Value<double?>(v),
                          rateDate: Value<DateTime?>(b.date),
                          updatedAt: Value<DateTime?>(at),
                        ),
                ),
              );
          (manual ? kept : updated).add(code);
        }
        return RateApplyResult(
          updated: updated,
          keptManual: kept,
          rateDate: b.date,
          needsConfirmation: held,
        );
      });

  /// Drops the manual override of [currency]. If a CBAR value is known it
  /// becomes the effective rate right away; returns false when none is
  /// known yet (the caller should refresh).
  Future<bool> resetToAuto(String currency) => _db.transaction(() async {
        final ExchangeRate? r = await (_db.select(_db.exchangeRates)
              ..where((x) => x.currency.equals(currency)))
            .getSingleOrNull();
        if (r == null) return false;
        final double? auto = r.autoRate;
        await (_db.update(_db.exchangeRates)..where((x) => x.currency.equals(currency))).write(
          auto == null
              ? const ExchangeRatesCompanion(isManual: Value<bool>(false))
              : ExchangeRatesCompanion(
                  isManual: const Value<bool>(false),
                  rateToAzn: Value<double>(auto),
                  source: const Value<RateSource>(RateSource.cbar),
                  updatedAt: Value<DateTime?>(DateTime.now()),
                ),
        );
        return auto != null;
      });
}
