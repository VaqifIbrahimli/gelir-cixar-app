import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_info.dart';
import '../../core/notifications.dart';
import '../../data/providers.dart' show ExchangeRate, rateRowsProvider;
import '../../core/router.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/enums.dart';
import '../../l10n/app_localizations.dart';
import '../lock/lock_controller.dart';
import '../lock/pin_flow_screen.dart';
import 'backup_actions.dart';
import 'exchange_rates_screen.dart';
import 'rate_sync_controller.dart';
import 'settings_controller.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<T?> _choose<T>(
    BuildContext context, {
    required String title,
    required List<(T, String)> options,
    required T current,
  }) {
    return showDialog<T>(
      context: context,
      builder: (BuildContext ctx) => SimpleDialog(
        title: Text(title),
        children: <Widget>[
          for (final (T value, String label) in options)
            ListTile(
              title: Text(label),
              trailing: value == current ? const Icon(Icons.check) : null,
              selected: value == current,
              onTap: () => Navigator.of(ctx).pop(value),
            ),
        ],
      ),
    );
  }

  Future<void> _toggleLock(BuildContext context, WidgetRef ref, bool on) async {
    if (on) {
      await context.push<bool>(Routes.pin(PinFlowMode.setup));
      return;
    }
    final bool? ok = await context.push<bool>(Routes.pin(PinFlowMode.verify));
    if (ok ?? false) await ref.read(lockControllerProvider.notifier).disable();
  }

  Future<void> _toggleBiometric(BuildContext context, WidgetRef ref, bool on) async {
    final AppLocalizations l = AppLocalizations.of(context);
    final LockController c = ref.read(lockControllerProvider.notifier);
    if (!on) {
      await c.setBiometricEnabled(false);
      return;
    }
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    if (!await c.canUseBiometrics()) {
      messenger.showSnackBar(SnackBar(content: Text(l.biometricUnavailable)));
      return;
    }
    if (await c.authenticateBiometric(l.biometricEnableReason)) {
      await c.setBiometricEnabled(true);
    }
  }

  Future<void> _toggleNotifications(BuildContext context, WidgetRef ref, bool on) async {
    final SettingsController ctl = ref.read(settingsProvider.notifier);
    final AppLocalizations l = AppLocalizations.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    await ctl.setNotificationsEnabled(on);
    if (!on) return;
    await ctl.markNotificationPermissionAsked();
    final bool granted = await ref.read(notificationServiceProvider).requestPermission();
    if (!granted) {
      messenger.showSnackBar(SnackBar(content: Text(l.notificationsDenied)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l = AppLocalizations.of(context);
    final AppSettings s = ref.watch(settingsProvider);
    final RateSyncState rateSync = ref.watch(rateSyncProvider);
    final SettingsController ctl = ref.read(settingsProvider.notifier);
    final AppLockState lock = ref.watch(lockControllerProvider);
    final String version = ref.watch(appVersionProvider);

    final Map<ThemeMode, String> themeLabels = <ThemeMode, String>{
      ThemeMode.system: l.themeSystem,
      ThemeMode.light: l.themeLight,
      ThemeMode.dark: l.themeDark,
    };
    const Map<String, String> languageLabels = <String, String>{
      'az': 'Azərbaycan dili',
      'en': 'English',
    };

    return Scaffold(
      appBar: AppBar(title: Text(l.navSettings)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
        children: <Widget>[
          SectionHeader(l.settingsGeneral),
          ListTile(
            leading: const Icon(Icons.language),
            title: Text(l.language),
            subtitle: Text(languageLabels[s.languageCode]!),
            onTap: () async {
              final String? v = await _choose<String>(
                context,
                title: l.language,
                options: languageLabels.entries
                    .map((MapEntry<String, String> e) => (e.key, e.value))
                    .toList(),
                current: s.languageCode,
              );
              if (v != null) await ctl.setLanguage(v);
            },
          ),
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: Text(l.appearance),
            subtitle: Text(
              '${themeLabels[s.themeMode]!} · '
              '${s.useDynamicColor ? l.wallpaperColour : AppSeed.fromId(s.seedId).label(s.languageCode)}',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(Routes.appearance),
          ),
          ListTile(
            leading: const Icon(Icons.currency_exchange),
            title: Text(l.baseCurrency),
            subtitle: Text('${Currency.base.code} (${Currency.base.symbol})'),
            enabled: false,
          ),
          SectionHeader(l.ratesSection),
          SwitchListTile(
            secondary: const Icon(Icons.cloud_sync_outlined),
            title: Text(l.autoRatesShort),
            subtitle: Text(l.autoRatesSource),
            value: rateSync.enabled,
            onChanged: rateSync.busy
                ? null
                : (bool v) {
                    AppHaptics.key();
                    ref.read(rateSyncProvider.notifier).setEnabled(v);
                  },
          ),
          AnimatedSize(
            duration: AppMotion.of(context, AppMotion.medium1),
            curve: AppMotion.standard,
            child: rateSync.enabled
                ? const Padding(
                    padding: EdgeInsets.only(left: AppSpacing.lg, right: AppSpacing.sm),
                    child: RateStatusRow(),
                  )
                : const SizedBox(width: double.infinity),
          ),
          ListTile(
            leading: const Icon(Icons.swap_vert_circle_outlined),
            title: Text(l.exchangeRates),
            subtitle: Text(rateSummary(ref.watch(rateRowsProvider).value ?? const <ExchangeRate>[], s.languageCode)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(Routes.rates),
          ),
          SectionHeader(l.settingsNotifications),
          SwitchListTile(
            secondary: const Icon(Icons.notifications_outlined),
            title: Text(l.budgetNotifications),
            subtitle: Text(l.budgetNotificationsSubtitle),
            value: s.notificationsEnabled,
            onChanged: (bool v) => _toggleNotifications(context, ref, v),
          ),
          SectionHeader(l.settingsSecurity),
          SwitchListTile(
            secondary: const Icon(Icons.lock_outline),
            title: Text(l.appLock),
            subtitle: Text(l.appLockSubtitle),
            value: lock.enabled,
            onChanged: (bool v) => _toggleLock(context, ref, v),
          ),
          ListTile(
            leading: const Icon(Icons.pin_outlined),
            title: Text(l.changePin),
            enabled: lock.enabled,
            onTap: () => context.push<bool>(Routes.pin(PinFlowMode.change)),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.fingerprint),
            title: Text(l.fingerprint),
            subtitle: Text(l.fingerprintSubtitle),
            value: lock.biometricEnabled,
            onChanged: lock.enabled ? (bool v) => _toggleBiometric(context, ref, v) : null,
          ),
          SwitchListTile(
            secondary: const Icon(Icons.screenshot_monitor_outlined),
            title: Text(l.blockScreenshots),
            subtitle: Text(l.blockScreenshotsSubtitle),
            value: s.blockScreenshots,
            onChanged: ctl.setBlockScreenshots,
          ),
          SectionHeader(l.settingsData),
          ListTile(
            leading: const Icon(Icons.account_balance_wallet_outlined),
            title: Text(l.accounts),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(Routes.accounts),
          ),
          ListTile(
            leading: const Icon(Icons.category_outlined),
            title: Text(l.categories),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(Routes.categories),
          ),
          ListTile(
            leading: const Icon(Icons.savings_outlined),
            title: Text(l.holdings),
            subtitle: Text(l.holdingsSubtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(Routes.holdings),
          ),
          ListTile(
            leading: const Icon(Icons.file_download_outlined),
            title: Text(l.export),
            subtitle: Text(l.exportSubtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(Routes.export),
          ),
          ListTile(
            leading: const Icon(Icons.backup_outlined),
            title: Text(l.backupCreate),
            subtitle: Text(l.backupCreateSubtitle),
            onTap: () => createBackup(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.settings_backup_restore),
            title: Text(l.backupRestore),
            subtitle: Text(l.backupRestoreSubtitle),
            onTap: () => restoreBackup(context, ref),
          ),
          SectionHeader(l.settingsAbout),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(l.about),
            subtitle: Text(l.versionN(version)),
            onTap: () => showAboutDialog(
              context: context,
              applicationName: l.appTitle,
              applicationVersion: version,
              applicationIcon: Icon(
                Icons.account_balance_wallet,
                size: 40,
                color: Theme.of(context).colorScheme.primary,
              ),
              children: <Widget>[Text(l.aboutBody)],
            ),
          ),
        ],
      ),
    );
  }
}
