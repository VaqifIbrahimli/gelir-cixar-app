import 'dart:convert';

import 'package:flutter/foundation.dart' show immutable, visibleForTesting;
import 'package:flutter/services.dart' show rootBundle;

import '../database.dart';

/// Converts a fare stored like 0.6 in the bundled JSON to minor units (60).
int fareToMinor(num fare) => (fare * 100).round();

/// A bus route with its fare (AZN minor units).
@immutable
class BusRoute {
  const BusRoute({
    required this.code,
    required this.from,
    required this.to,
    required this.fare,
    this.uncertain = false,
    this.isCustom = false,
    this.isEdited = false,
    this.bundledFare,
  });

  final String code;
  final String from;
  final String to;

  /// Effective fare, AZN minor units.
  final int fare;

  /// The bundled data marks this fare as possibly outdated.
  final bool uncertain;

  /// Added by the user (not in the bundled data).
  final bool isCustom;

  /// A bundled route whose fare the user changed.
  final bool isEdited;

  /// The bundled fare of an edited route (for "reset").
  final int? bundledFare;

  /// "Xırdalan – 28 May", or the empty string when the stops are unknown.
  String get label => from.isEmpty && to.isEmpty ? '' : '$from – $to';
}

@immutable
class MetroLine {
  const MetroLine({required this.id, required this.nameAz, required this.nameEn, required this.stations});

  /// 'red', 'green', 'purple' (matches MetroLineStyle names).
  final String id;
  final String nameAz;
  final String nameEn;
  final List<String> stations;

  String name(String lang) => lang == 'en' && nameEn.isNotEmpty ? nameEn : nameAz;
}

@immutable
class TransportSource {
  const TransportSource({required this.title, required this.url, this.accessed});

  final String title;
  final String url;
  final String? accessed;
}

/// The bundled Baku transport data (assets/transport/baku.json). Fares are
/// in minor units. Never edited at runtime: user changes live in the
/// transport_fares table and are layered on top by [ResolvedFares].
@immutable
class TransportCatalog {
  const TransportCatalog({
    required this.verifiedAt,
    required this.defaultBusFare,
    required this.bus,
    required this.metroFare,
    required this.metroLines,
    this.trainFare,
    this.sources = const <TransportSource>[],
  });

  static const String assetPath = 'assets/transport/baku.json';

  static const TransportCatalog empty = TransportCatalog(
    verifiedAt: null,
    defaultBusFare: 60,
    bus: <BusRoute>[],
    metroFare: 60,
    metroLines: <MetroLine>[],
  );

  final DateTime? verifiedAt;
  final int defaultBusFare;
  final List<BusRoute> bus;
  final int metroFare;
  final List<MetroLine> metroLines;

  /// Null: no bundled commuter-train fare (the user can set one).
  final int? trainFare;
  final List<TransportSource> sources;

  static TransportCatalog? _cache;

  /// Loads the bundled file once per process; later calls return the cache.
  static Future<TransportCatalog> load() async =>
      _cache ??= parse(await rootBundle.loadString(assetPath));

  /// Widget tests run in fake async, where asset I/O never completes:
  /// they parse the file themselves and hand it over here.
  @visibleForTesting
  static set debugCache(TransportCatalog? c) => _cache = c;

  /// Parses the JSON (schema: version, city, verifiedAt, currency,
  /// defaultBusFare, bus[], metro{fare, lines[]}, train[], sources[]).
  /// Malformed entries are skipped rather than failing the whole file.
  static TransportCatalog parse(String json) {
    final Object? root = jsonDecode(json);
    if (root is! Map<String, Object?>) return empty;
    int? fare(Object? v) => v is num && v > 0 && v < 100 ? fareToMinor(v) : null;
    String str(Object? v) => v is String ? v.trim() : '';

    final int defaultBus = fare(root['defaultBusFare']) ?? 60;
    final List<BusRoute> bus = <BusRoute>[];
    final Set<String> seen = <String>{};
    for (final Object? r in (root['bus'] as List<Object?>?) ?? const <Object?>[]) {
      if (r is! Map<String, Object?>) continue;
      final String code = str(r['code']);
      if (code.isEmpty || code.length > 6 || !seen.add(code)) continue;
      bus.add(BusRoute(
        code: code,
        from: str(r['from']),
        to: str(r['to']),
        fare: fare(r['fare']) ?? defaultBus,
        uncertain: r['uncertain'] == true,
      ));
    }
    bus.sort((BusRoute a, BusRoute b) => compareRouteCodes(a.code, b.code));

    final Object? metro = root['metro'];
    int metroFare = 60;
    final List<MetroLine> lines = <MetroLine>[];
    if (metro is Map<String, Object?>) {
      metroFare = fare(metro['fare']) ?? 60;
      for (final Object? l in (metro['lines'] as List<Object?>?) ?? const <Object?>[]) {
        if (l is! Map<String, Object?>) continue;
        lines.add(MetroLine(
          id: str(l['id']),
          nameAz: str(l['nameAz']),
          nameEn: str(l['nameEn']),
          stations: <String>[
            for (final Object? s in (l['stations'] as List<Object?>?) ?? const <Object?>[])
              if (s is String && s.trim().isNotEmpty) s.trim(),
          ],
        ));
      }
    }

    int? trainFare;
    for (final Object? t in (root['train'] as List<Object?>?) ?? const <Object?>[]) {
      if (t is Map<String, Object?>) trainFare ??= fare(t['fare']);
    }

    return TransportCatalog(
      verifiedAt: DateTime.tryParse(str(root['verifiedAt'])),
      defaultBusFare: defaultBus,
      bus: List<BusRoute>.unmodifiable(bus),
      metroFare: metroFare,
      metroLines: List<MetroLine>.unmodifiable(lines),
      trainFare: trainFare,
      sources: <TransportSource>[
        for (final Object? s in (root['sources'] as List<Object?>?) ?? const <Object?>[])
          if (s is Map<String, Object?> && str(s['url']).isNotEmpty)
            TransportSource(
              title: str(s['title']),
              url: str(s['url']),
              accessed: s['accessed'] is String ? s['accessed']! as String : null,
            ),
      ],
    );
  }
}

/// Natural order of route codes: 1, 2, 3 … 10, 11, 65, 65A, M1.
int compareRouteCodes(String a, String b) {
  final RegExp re = RegExp(r'^(\d*)(.*)$');
  final RegExpMatch ma = re.firstMatch(a)!;
  final RegExpMatch mb = re.firstMatch(b)!;
  final String na = ma.group(1)!;
  final String nb = mb.group(1)!;
  if (na.isNotEmpty && nb.isEmpty) return -1;
  if (na.isEmpty && nb.isNotEmpty) return 1;
  if (na.isNotEmpty && nb.isNotEmpty) {
    final int c = int.parse(na).compareTo(int.parse(nb));
    if (c != 0) return c;
  }
  return ma.group(2)!.compareTo(mb.group(2)!);
}

/// Folds Azerbaijani letters for accent-free search ("xirdalan" finds
/// "Xırdalan").
String foldForSearch(String s) {
  const Map<String, String> m = <String, String>{
    'ə': 'e', 'ı': 'i', 'i̇': 'i', 'ö': 'o', 'ü': 'u', 'ğ': 'g', 'ş': 's', 'ç': 'c',
  };
  String r = s.toLowerCase();
  m.forEach((String k, String v) => r = r.replaceAll(k, v));
  return r;
}

/// Bundled fares with the user's overrides and own routes on top.
@immutable
class ResolvedFares {
  const ResolvedFares({
    required this.catalog,
    required this.bus,
    required this.metroFare,
    required this.metroEdited,
    required this.trainFare,
    required this.trainEdited,
  });

  /// Merges [rows] (transport_fares) over [catalog]:
  /// * bus rows with isCustom false replace the fare of the bundled route
  ///   with the same code (rows for unknown codes are ignored);
  /// * bus rows with isCustom true add a route (a code that clashes with a
  ///   bundled one is ignored, the bundled route wins);
  /// * metro / train rows (code '') replace the single fare.
  factory ResolvedFares.merge(TransportCatalog catalog, List<TransportFare> rows) {
    final Map<String, TransportFare> edits = <String, TransportFare>{};
    final List<TransportFare> custom = <TransportFare>[];
    TransportFare? metro;
    TransportFare? train;
    for (final TransportFare r in rows) {
      switch (r.mode) {
        case TransportMode.bus:
          if (r.isCustom) {
            custom.add(r);
          } else {
            edits[r.code] = r;
          }
        case TransportMode.metro:
          metro = r;
        case TransportMode.train:
          train = r;
        case TransportMode.taxi ||
              TransportMode.fuel ||
              TransportMode.parking ||
              TransportMode.bakuCard:
          break;
      }
    }
    final Set<String> bundled = <String>{for (final BusRoute b in catalog.bus) b.code};
    final List<BusRoute> bus = <BusRoute>[
      for (final BusRoute b in catalog.bus)
        if (edits[b.code] case final TransportFare e when e.fare != b.fare)
          BusRoute(
            code: b.code,
            from: b.from,
            to: b.to,
            fare: e.fare,
            uncertain: false,
            isEdited: true,
            bundledFare: b.fare,
          )
        else
          b,
      for (final TransportFare c in custom)
        if (!bundled.contains(c.code))
          BusRoute(code: c.code, from: c.fromName, to: c.toName, fare: c.fare, isCustom: true),
    ]..sort((BusRoute a, BusRoute b) => compareRouteCodes(a.code, b.code));
    return ResolvedFares(
      catalog: catalog,
      bus: List<BusRoute>.unmodifiable(bus),
      metroFare: metro?.fare ?? catalog.metroFare,
      metroEdited: metro != null && metro.fare != catalog.metroFare,
      trainFare: train?.fare ?? catalog.trainFare,
      trainEdited: train != null && train.fare != catalog.trainFare,
    );
  }

  final TransportCatalog catalog;
  final List<BusRoute> bus;
  final int metroFare;
  final bool metroEdited;
  final int? trainFare;
  final bool trainEdited;

  BusRoute? busRoute(String? code) =>
      code == null ? null : bus.where((BusRoute b) => b.code == code).firstOrNull;

  /// Fare of one trip of [mode] (and bus [routeCode]), or null if unknown.
  int? fareOf(TransportMode mode, {String? routeCode}) => switch (mode) {
        TransportMode.bus => busRoute(routeCode)?.fare,
        TransportMode.metro => metroFare,
        TransportMode.train => trainFare,
        _ => null,
      };

  /// Search: code prefix first, then any stop name (accent-insensitive).
  List<BusRoute> search(String query) {
    final String q = foldForSearch(query.trim());
    if (q.isEmpty) return bus;
    final List<BusRoute> byCode = <BusRoute>[];
    final List<BusRoute> byStop = <BusRoute>[];
    for (final BusRoute b in bus) {
      if (foldForSearch(b.code).startsWith(q)) {
        byCode.add(b);
      } else if (foldForSearch(b.from).contains(q) || foldForSearch(b.to).contains(q)) {
        byStop.add(b);
      }
    }
    return <BusRoute>[...byCode, ...byStop];
  }
}

/// Amount auto-fill of the transport picker (DESIGN.md §18.5.2): fare ×
/// trips until the user types an amount by hand; "Tarifə qaytar" brings
/// the auto value back.
@immutable
class FareAutoFill {
  const FareAutoFill({this.fare, this.trips = 1, this.manual = false});

  static const int maxTrips = 20;

  /// One trip, AZN minor units; null when the mode / route has no fare.
  final int? fare;
  final int trips;

  /// The keypad amount was typed by hand.
  final bool manual;

  /// The amount to write into the keypad, or null to leave it alone.
  int? get amount => fare == null || manual ? null : fare! * trips;

  FareAutoFill withFare(int? fare) => FareAutoFill(fare: fare, trips: trips, manual: false);

  FareAutoFill withTrips(int n) =>
      FareAutoFill(fare: fare, trips: n.clamp(1, maxTrips), manual: manual);

  FareAutoFill typed() => FareAutoFill(fare: fare, trips: trips, manual: true);

  FareAutoFill resetToFare() => FareAutoFill(fare: fare, trips: trips, manual: false);
}
