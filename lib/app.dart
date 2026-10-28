import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart' as mui;
import 'package:go_router/go_router.dart';

import 'core/platform_window.dart';
import 'core/router.dart';
import 'core/theme.dart';
import 'features/lock/lock_controller.dart';
import 'features/lock/lock_screen.dart';
import 'features/lock/pin_flow_screen.dart';
import 'features/onboarding/onboarding_controller.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/settings/settings_controller.dart';
import 'l10n/app_localizations.dart';

/// dynamic_color 2.x reports schemes as `material_ui` types, while this app
/// uses the SDK's `flutter/material`. AppTheme re-derives a wallpaper scheme
/// from its primary anyway (DESIGN.md §12.3), so the primary is all we take.
ColorScheme? wallpaperScheme(mui.ColorScheme? s, Brightness b) =>
    s == null ? null : ColorScheme.fromSeed(seedColor: s.primary, brightness: b);

class GelirCixarApp extends ConsumerWidget {
  const GelirCixarApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppSettings settings = ref.watch(settingsProvider);
    final GoRouter router = ref.watch(routerProvider);
    ref.listen<bool>(
      secureWindowProvider,
      (bool? previous, bool next) => PlatformWindow.setSecure(next),
    );

    // DESIGN.md §12.3: wallpaper colours (Android 12+) when switched on,
    // otherwise the chosen preset. Null schemes mean "not supported".
    return DynamicColorBuilder(
      builder: (mui.ColorScheme? lightDyn, mui.ColorScheme? darkDyn) {
        final ColorScheme? lightDynamic = wallpaperScheme(lightDyn, Brightness.light);
        final ColorScheme? darkDynamic = wallpaperScheme(darkDyn, Brightness.dark);
        final AppSeed seed = AppSeed.fromId(settings.seedId);
        final bool dyn = settings.useDynamicColor;
        return MaterialApp.router(
          onGenerateTitle: (BuildContext context) => AppLocalizations.of(context).appTitle,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.build(
            Brightness.light,
            seed: seed,
            dynamicScheme: dyn ? lightDynamic : null,
          ),
          darkTheme: AppTheme.build(
            Brightness.dark,
            seed: seed,
            dynamicScheme: dyn ? darkDynamic : null,
          ),
          themeMode: settings.themeMode,
          locale: settings.locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          routerConfig: router,
          builder: (BuildContext context, Widget? child) =>
              _LockGate(child: child ?? const SizedBox.shrink()),
        );
      },
    );
  }
}

/// What covers the app: onboarding (first launch), the lock screen or the
/// first-run PIN screen.
enum _Cover { none, loading, onboarding, locked, setup }

/// Covers the whole app with onboarding / lock / first-run PIN when needed.
/// The router subtree stays mounted underneath, so an unfinished form keeps
/// its state across a re-lock.
class _LockGate extends ConsumerWidget {
  const _LockGate({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final LockStatus status =
        ref.watch(lockControllerProvider.select((AppLockState s) => s.status));
    final OnboardingStatus onboarding = ref.watch(onboardingProvider);

    final _Cover kind = switch ((onboarding, status)) {
      (OnboardingStatus.loading, _) || (_, LockStatus.loading) => _Cover.loading,
      // Onboarding has its own (optional) PIN step and replaces the v1.0
      // forced first-run PIN screen.
      (OnboardingStatus.needed, _) => _Cover.onboarding,
      (_, LockStatus.locked) => _Cover.locked,
      (_, LockStatus.setupRequired) => _Cover.setup,
      (_, LockStatus.unlocked) => _Cover.none,
    };

    final Widget? cover = switch (kind) {
      _Cover.none => null,
      _Cover.loading => const SizedBox.expand(),
      _Cover.onboarding => const OnboardingScreen(),
      _Cover.locked => const LockScreen(),
      _Cover.setup => PinFlowScreen(
          mode: PinFlowMode.setup,
          canCancel: false,
          onFinished: (_) {},
        ),
    };

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        // Hide the app from accessibility services and input while covered.
        ExcludeSemantics(
          excluding: cover != null,
          child: IgnorePointer(ignoring: cover != null, child: child),
        ),
        // Fade through out of the cover (onboarding → Home, unlock).
        Positioned.fill(
          child: IgnorePointer(
            ignoring: cover == null,
            child: AnimatedSwitcher(
              // Appear instantly (a fade-in would briefly show the app on
              // re-lock); only the way out is animated.
              duration: cover == null
                  ? AppMotion.of(context, AppMotion.fadeThroughDuration)
                  : Duration.zero,
              transitionBuilder: AppMotion.fadeThrough,
              child: cover == null
                  ? const SizedBox.shrink(key: ValueKey<String>('no-cover'))
                  : ColoredBox(
                      key: ValueKey<_Cover>(kind),
                      color: Theme.of(context).colorScheme.surface,
                      // Own navigator so dialogs, tooltips and ink work on the cover.
                      child: HeroControllerScope.none(
                        child: Navigator(
                          onGenerateRoute: (_) => PageRouteBuilder<void>(
                            pageBuilder: (_, _, _) => cover,
                            transitionDuration: Duration.zero,
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}
