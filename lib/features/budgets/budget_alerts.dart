import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/notifications.dart';
import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';
import '../settings/settings_controller.dart';

/// Requests POST_NOTIFICATIONS once (Android 13+), if alerts are enabled.
Future<void> ensureNotificationPermission(WidgetRef ref) async {
  final SettingsController settings = ref.read(settingsProvider.notifier);
  if (!ref.read(settingsProvider).notificationsEnabled) return;
  if (settings.notificationPermissionAsked) return;
  await settings.markNotificationPermissionAsked();
  await ref.read(notificationServiceProvider).requestPermission();
}

/// After a transaction is saved: if its category's budget for that month
/// crossed 80 % or 100 % for the first time, show a SnackBar and (when
/// enabled) a system notification.
///
/// [messenger] and [l] are captured by the caller before any route pop.
Future<void> checkBudgetAlerts({
  required WidgetRef ref,
  required ScaffoldMessengerState messenger,
  required AppLocalizations l,
  required int? categoryId,
  required TxType type,
  required DateTime date,
}) async {
  if (categoryId == null || type != TxType.expense) return;
  final Rates rates = ref.read(ratesProvider).value ?? Rates.defaults;
  final BudgetAlertEvent? ev = await ref.read(budgetRepositoryProvider).checkThresholds(
        categoryId: categoryId,
        date: date,
        rates: rates,
      );
  if (ev == null) return;

  final String lang = ref.read(languageProvider);
  final List<TxCategory> cats = await ref
      .read(categoryRepositoryProvider)
      .watch(includeArchived: true)
      .first;
  final String name = cats
          .where((TxCategory c) => c.id == categoryId)
          .firstOrNull
          ?.localizedName(lang) ??
      l.category;
  final bool over = ev.threshold >= BudgetThresholds.danger;
  final String amounts =
      '${Fmt.base(ev.spent, lang)} / ${Fmt.base(ev.budget.limitAmount, lang)}';
  final String title = over ? l.budgetAlertOverTitle(name) : l.budgetAlertWarningTitle(name);
  final String body = over
      ? l.budgetAlertOverBody(amounts)
      : l.budgetAlertWarningBody(ev.threshold, amounts);

  messenger.showSnackBar(SnackBar(
    content: Text('$title. $body'),
    duration: const Duration(seconds: 6),
  ));

  if (ref.read(settingsProvider).notificationsEnabled) {
    await ref.read(notificationServiceProvider).showBudgetAlert(
          // Stable per budget + threshold, so a newer alert replaces an older one.
          id: ev.budget.id * 1000 + ev.threshold,
          title: title,
          body: body,
          channelName: l.notificationChannelName,
          channelDescription: l.notificationChannelDescription,
        );
  }
}
