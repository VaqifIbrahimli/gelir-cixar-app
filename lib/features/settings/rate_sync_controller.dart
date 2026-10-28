import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/prefs.dart';
import '../../data/providers.dart';
import 'rate_confirm_dialog.dart';

@immutable
class RateSyncState {
  const RateSyncState({
    this.enabled = false,
    this.busy = false,
    this.fetchedAt,
    this.bulletinDate,
    this.error,
    this.keptManual = const <String>[],
  });

  /// "Avtomatik məzənnə (AMB)" toggle.
  final bool enabled;
  final bool busy;

  /// Last successful refresh.
  final DateTime? fetchedAt;

  /// CBAR bulletin date of the applied rates.
  final DateTime? bulletinDate;

  /// Failure of the last attempt (null after a success).
  final CbarFailure? error;

  /// Currencies the last refresh left alone because they are manual.
  final List<String> keptManual;

  RateSyncState copyWith({
    bool? enabled,
    bool? busy,
    DateTime? fetchedAt,
    DateTime? bulletinDate,
    CbarFailure? Function()? error,
    List<String>? keptManual,
  }) =>
      RateSyncState(
        enabled: enabled ?? this.enabled,
        busy: busy ?? this.busy,
        fetchedAt: fetchedAt ?? this.fetchedAt,
        bulletinDate: bulletinDate ?? this.bulletinDate,
        error: error != null ? error() : this.error,
        keptManual: keptManual ?? this.keptManual,
      );
}

/// Automatic exchange rates from CBAR. Network is used only when the user
/// presses "Yenilə", switches the toggle on, pulls Home to refresh, or (toggle
/// on) at start-up / resume when the stored rates are older than [staleAfter].
class RateSyncController extends Notifier<RateSyncState> {
  /// CBAR publishes once a working day; refresh at most every 6 h on start
  /// and resume (DESIGN.md §16.2).
  static const Duration staleAfter = Duration(hours: 6);

  /// Rates older than this are shown as stale ("köhnəlib").
  static const Duration staleWarning = Duration(days: 3);

  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  @override
  RateSyncState build() {
    final SharedPreferences p = ref.watch(sharedPreferencesProvider);
    DateTime? ms(String key) {
      final int? v = p.getInt(key);
      return v == null ? null : DateTime.fromMillisecondsSinceEpoch(v);
    }

    return RateSyncState(
      enabled: p.getBool(PrefKeys.autoRates) ?? false,
      fetchedAt: ms(PrefKeys.ratesFetchedAt),
      bulletinDate: ms(PrefKeys.ratesBulletinDate),
    );
  }

  Future<void> setEnabled(bool on) async {
    await _prefs.setBool(PrefKeys.autoRates, on);
    state = state.copyWith(enabled: on, error: () => null);
    if (on) await refresh();
  }

  bool isStale(DateTime now) {
    final DateTime? at = state.fetchedAt;
    return at == null || now.difference(at) >= staleAfter || now.isBefore(at);
  }

  /// Start-up hook: refreshes only if enabled and stale.
  Future<void> refreshIfStale({DateTime? now}) async {
    if (!state.enabled || state.busy || !isStale(now ?? DateTime.now())) return;
    await refresh(now: now);
  }

  /// Fetches the latest bulletin and applies it. Returns the failure, or
  /// null on success.
  Future<CbarFailure?> refresh({DateTime? now}) async {
    if (state.busy) return state.error;
    state = state.copyWith(busy: true);
    final DateTime at = now ?? DateTime.now();
    try {
      final CbarBulletin b = await ref.read(cbarClientProvider).fetchLatest(at);
      final RateRepository repo = ref.read(rateRepositoryProvider);
      RateApplyResult r = await repo.applyCbar(b, now: at);
      // Values that jumped > 50 % since the last CBAR value are held back
      // until the user confirms them; on "no" nothing more is applied.
      final List<RateChange> held = r.needsConfirmation;
      if (held.isNotEmpty && await ref.read(rateJumpConfirmerProvider)(held)) {
        r = await repo.applyCbar(
          b,
          now: at,
          confirmed: <String>{for (final RateChange c in held) c.currency},
        );
      }
      if (held.isEmpty && r.updated.isEmpty && r.keptManual.isEmpty) {
        // A bulletin without any sane USD/EUR/RUB/TRY value.
        throw const CbarException(CbarFailure.parse);
      }
      await _prefs.setInt(PrefKeys.ratesFetchedAt, at.millisecondsSinceEpoch);
      await _prefs.setInt(PrefKeys.ratesBulletinDate, b.date.millisecondsSinceEpoch);
      state = state.copyWith(
        busy: false,
        fetchedAt: at,
        bulletinDate: b.date,
        error: () => null,
        keptManual: r.keptManual,
      );
      return null;
    } on CbarException catch (e) {
      state = state.copyWith(busy: false, error: () => e.failure);
      return e.failure;
    } on Exception {
      // Anything unexpected (e.g. a malformed but parseable value): never
      // leave the spinner on, report it as unusable data.
      state = state.copyWith(busy: false, error: () => CbarFailure.parse);
      return CbarFailure.parse;
    }
  }
}

final NotifierProvider<RateSyncController, RateSyncState> rateSyncProvider =
    NotifierProvider<RateSyncController, RateSyncState>(RateSyncController.new);
