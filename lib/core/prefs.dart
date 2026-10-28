import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Overridden in `main()` with the instance loaded before `runApp`.
final Provider<SharedPreferences> sharedPreferencesProvider =
    Provider<SharedPreferences>(
  (Ref ref) => throw UnimplementedError('sharedPreferencesProvider'),
);

/// Shared-preferences keys used across features.
abstract final class PrefKeys {
  static const String language = 'settings.language';
  static const String themeMode = 'settings.themeMode';
  static const String hideBalance = 'settings.hideBalance';
  static const String notificationsEnabled = 'settings.notifications';
  static const String notificationPermissionAsked = 'settings.notificationsAsked';
  static const String blockScreenshots = 'settings.blockScreenshots';
  static const String seedId = 'settings.seedId';
  static const String useDynamicColor = 'settings.dynamicColor';

  /// v1.1 first-run onboarding finished (or skipped for v1.0 upgraders).
  static const String onboardingDone = 'onboarding.done';

  /// Automatic CBAR exchange rates (default off).
  static const String autoRates = 'rates.auto';

  /// Epoch ms of the last successful CBAR refresh.
  static const String ratesFetchedAt = 'rates.fetchedAt';

  /// Epoch ms of the CBAR bulletin date last applied.
  static const String ratesBulletinDate = 'rates.bulletinDate';

  static const String lockEnabled = 'lock.enabled';
  static const String biometricEnabled = 'lock.biometric';
  static const String lockOnboarded = 'lock.onboarded';
}
