import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/platform_window.dart';
import 'core/prefs.dart';
import 'core/share_files.dart';
import 'features/lock/lock_back_interceptor.dart';
import 'features/lock/lock_controller.dart';
import 'features/onboarding/onboarding_controller.dart';
import 'features/settings/rate_sync_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('az');
  await initializeDateFormatting('en');
  final SharedPreferences prefs = await SharedPreferences.getInstance();

  final ProviderContainer container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
    ],
  );

  // Before runApp: see LockBackInterceptor for why the order matters.
  WidgetsBinding.instance.addObserver(
    LockBackInterceptor(
      () =>
          container.read(lockControllerProvider).isBlocking ||
          container.read(onboardingProvider) != OnboardingStatus.done,
    ),
  );

  // MainActivity starts with FLAG_SECURE on; apply the saved preference.
  await PlatformWindow.setSecure(container.read(secureWindowProvider));

  // Exports / backups left in the cache by a crash or a killed share.
  unawaited(ShareFiles.purge());

  // Only when the user switched on automatic CBAR rates and the stored ones
  // are older than 6 h. Failures are silent here; Settings shows them.
  unawaited(container.read(rateSyncProvider.notifier).refreshIfStale());
  // …and again when the app returns to the foreground (same 6 h rule).
  AppLifecycleListener(
    onResume: () => unawaited(container.read(rateSyncProvider.notifier).refreshIfStale()),
  );

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const GelirCixarApp(),
    ),
  );
}
