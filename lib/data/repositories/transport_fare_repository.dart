import 'package:drift/drift.dart';

import '../database.dart';

/// User fare overrides and own routes (table transport_fares).
class TransportFareRepository {
  TransportFareRepository(this._db);

  final AppDatabase _db;

  /// Lowest / highest fare accepted (0,01 – 99,99 ₼).
  static const int minFare = 1;
  static const int maxFare = 9999;

  /// Route numbers: 1–6 letters, digits or '-'.
  static final RegExp codePattern = RegExp(r'^[0-9A-Za-zƏəÖöÜüĞğİıŞşÇç-]{1,6}$');

  static bool fareOk(int f) => f >= minFare && f <= maxFare;

  Stream<List<TransportFare>> watchAll() => _db.select(_db.transportFares).watch();

  Future<List<TransportFare>> getAll() => _db.select(_db.transportFares).get();

  /// Overrides the fare of a bundled bus route ([code]) or of the metro /
  /// train ([code] '').
  Future<void> setFare(TransportMode mode, String code, int fare) async {
    if (!fareOk(fare)) throw ArgumentError('fare out of range');
    final TransportFare? old = await _row(mode, code);
    await _db.into(_db.transportFares).insertOnConflictUpdate(TransportFaresCompanion.insert(
          mode: mode,
          code: code,
          fromName: Value<String>(old?.fromName ?? ''),
          toName: Value<String>(old?.toName ?? ''),
          fare: fare,
          isCustom: Value<bool>(old?.isCustom ?? false),
          updatedAt: Value<DateTime>(DateTime.now()),
        ));
  }

  /// Back to the bundled fare (removes the override). Own routes are not
  /// touched; use [deleteCustomRoute].
  Future<void> resetFare(TransportMode mode, String code) =>
      (_db.delete(_db.transportFares)
            ..where((f) => f.mode.equalsValue(mode) & f.code.equals(code) & f.isCustom.equals(false)))
          .go();

  /// Adds or edits one of the user's own bus routes. [previousCode] is the
  /// code being edited (it may change). Throws [StateError] for a code that
  /// already exists in [takenCodes] or among the own routes.
  Future<void> saveCustomRoute({
    String? previousCode,
    required String code,
    required String fromName,
    required String toName,
    required int fare,
    Set<String> takenCodes = const <String>{},
  }) =>
      _db.transaction(() async {
        final String c = code.trim();
        if (!codePattern.hasMatch(c)) throw ArgumentError('route code');
        if (!fareOk(fare)) throw ArgumentError('fare out of range');
        if (fromName.trim().isEmpty || toName.trim().isEmpty) throw ArgumentError('stops');
        if (c != previousCode && (takenCodes.contains(c) || await _row(TransportMode.bus, c) != null)) {
          throw StateError('route code exists');
        }
        if (previousCode != null && previousCode != c) await deleteCustomRoute(previousCode);
        await _db.into(_db.transportFares).insertOnConflictUpdate(TransportFaresCompanion.insert(
              mode: TransportMode.bus,
              code: c,
              fromName: Value<String>(fromName.trim()),
              toName: Value<String>(toName.trim()),
              fare: fare,
              isCustom: const Value<bool>(true),
              updatedAt: Value<DateTime>(DateTime.now()),
            ));
      });

  Future<void> deleteCustomRoute(String code) => (_db.delete(_db.transportFares)
        ..where((f) =>
            f.mode.equalsValue(TransportMode.bus) & f.code.equals(code) & f.isCustom.equals(true)))
      .go();

  Future<TransportFare?> _row(TransportMode mode, String code) => (_db.select(_db.transportFares)
        ..where((f) => f.mode.equalsValue(mode) & f.code.equals(code)))
      .getSingleOrNull();
}
