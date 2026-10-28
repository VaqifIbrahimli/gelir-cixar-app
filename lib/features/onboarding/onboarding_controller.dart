import 'dart:async';

import 'package:drift/drift.dart' show QueryRow;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/prefs.dart';
import '../../data/providers.dart';
import '../lock/lock_controller.dart';

enum OnboardingStatus { loading, needed, done }

/// First-launch onboarding (DESIGN.md §15). Shown once; never shown to
/// people upgrading from v1.0.
class OnboardingController extends Notifier<OnboardingStatus> {
  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  @override
  OnboardingStatus build() {
    if (ref.read(sharedPreferencesProvider).getBool(PrefKeys.onboardingDone) ??
        false) {
      return OnboardingStatus.done;
    }
    Future<void>.microtask(_init);
    return OnboardingStatus.loading;
  }

  Future<void> _init() async {
    final bool upgrade = await isExistingInstall();
    if (upgrade) await _prefs.setBool(PrefKeys.onboardingDone, true);
    state = upgrade ? OnboardingStatus.done : OnboardingStatus.needed;
  }

  /// A v1.0 install: the first-run PIN step was already completed or
  /// skipped, a PIN exists, or the user has data beyond the seed (one
  /// account "Nağd", no transactions).
  Future<bool> isExistingInstall() async {
    if (_prefs.getBool(PrefKeys.lockOnboarded) ?? false) return true;
    if (await ref.read(pinServiceProvider).hasPin()) return true;
    final QueryRow r = await ref
        .read(databaseProvider)
        .customSelect(
          'SELECT (SELECT COUNT(*) FROM transactions) AS t, '
          '(SELECT COUNT(*) FROM accounts) AS a, '
          '(SELECT COUNT(*) FROM holdings) AS h',
        )
        .getSingle();
    if (r.read<int>('t') > 0 || r.read<int>('a') > 1 || r.read<int>('h') > 0) {
      return true;
    }
    return false;
  }

  /// Marks onboarding done and releases the first-run PIN requirement
  /// (a PIN set during onboarding is kept).
  Future<void> finish() async {
    await _prefs.setBool(PrefKeys.onboardingDone, true);
    await ref.read(lockControllerProvider.notifier).completeOnboarding();
    state = OnboardingStatus.done;
  }
}

final NotifierProvider<OnboardingController, OnboardingStatus>
onboardingProvider = NotifierProvider<OnboardingController, OnboardingStatus>(
  OnboardingController.new,
);
