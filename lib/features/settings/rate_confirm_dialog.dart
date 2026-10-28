import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/router.dart';
import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';
import 'exchange_rates_screen.dart';
import 'settings_controller.dart';

/// Asks whether CBAR values that moved more than 50 % may be applied.
typedef RateJumpConfirmer = Future<bool> Function(List<RateChange> changes);

/// Default: a dialog on the root navigator. No UI (start-up before the app
/// is built, tests) means "not confirmed": the old rates stay.
final Provider<RateJumpConfirmer> rateJumpConfirmerProvider = Provider<RateJumpConfirmer>(
  (Ref ref) => (List<RateChange> changes) async {
    final BuildContext? context = rootNavigatorKey.currentContext;
    if (context == null || !context.mounted) return false;
    return confirmRateJumps(context, changes, ref.read(languageProvider));
  },
);

/// "USD 1,70 → 2,90 (+71 %)" per held currency.
String rateChangeLine(RateChange c, String lang) {
  final int pct = (c.change * 100).round();
  final String sign = pct > 0 ? '+' : (pct < 0 ? '−' : '');
  return '${c.currency} ${ExchangeRatesScreen.formatRate(c.previous, lang)} → '
      '${ExchangeRatesScreen.formatRate(c.next, lang)} ($sign${pct.abs()} %)';
}

Future<bool> confirmRateJumps(BuildContext context, List<RateChange> changes, String lang) async {
  final AppLocalizations l = AppLocalizations.of(context);
  final bool? ok = await showDialog<bool>(
    context: context,
    builder: (BuildContext ctx) => AlertDialog(
      icon: const Icon(Icons.warning_amber),
      title: Text(l.rateJumpTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(l.rateJumpBody),
          const SizedBox(height: 12),
          for (final RateChange c in changes)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(rateChangeLine(c, lang), style: Theme.of(ctx).textTheme.titleSmall),
            ),
        ],
      ),
      actions: <Widget>[
        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(l.rateJumpKeep)),
        FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(l.rateJumpApply)),
      ],
    ),
  );
  return ok ?? false;
}
