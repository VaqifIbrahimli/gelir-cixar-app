import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format.dart';
import '../../../core/motion.dart';
import '../../../core/router.dart';
import '../../../core/theme.dart';
import '../../../data/providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../settings/settings_controller.dart';

/// Opens the month picker sheet (last 12 months) used by the "Bu ay" strip.
Future<DateTime?> pickMonthSheet(BuildContext context, DateTime current, String lang) {
  final DateTime now = DateTime.now();
  final List<DateTime> months = <DateTime>[
    for (int i = 0; i < 12; i++) DateTime(now.year, now.month - i),
  ];
  return showModalBottomSheet<DateTime>(
    context: context,
    builder: (BuildContext ctx) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: <Widget>[
          for (final DateTime x in months)
            ListTile(
              title: Text(Fmt.month(x, lang)),
              trailing: x == current ? const Icon(Icons.check) : null,
              onTap: () => Navigator.of(ctx).pop(x),
            ),
        ],
      ),
    ),
  );
}

/// Carousel page 0 (DESIGN.md §18.1.3): spendable balance with the eye
/// toggle, then "Kənarda" and "Ümumi sərvət" side by side. With no
/// holdings the bottom row offers "Kənar yer əlavə et" instead.
class TotalsCard extends ConsumerWidget {
  const TotalsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l = AppLocalizations.of(context);
    final AppColors c = AppColors.of(context);
    final TextTheme tt = Theme.of(context).textTheme;
    final String lang = ref.watch(languageProvider);
    final bool hidden = ref.watch(settingsProvider).hideBalance;
    final AsyncValue<NetWorth> worth = ref.watch(netWorthProvider);
    final int? spendable = ref.watch(totalBalanceProvider).value;
    final bool hasHoldings =
        (ref.watch(holdingsProvider).value ?? const <HoldingWithValue>[]).isNotEmpty;
    final String masked = Fmt.masked(Currency.base.code, lang);

    return Container(
      decoration: BoxDecoration(gradient: c.balanceGradient, borderRadius: AppRadius.brCard),
      padding: const EdgeInsets.fromLTRB(20, 8, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  l.spendableBalance,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tt.labelLarge?.copyWith(color: c.onBalanceCardVariant),
                ),
              ),
              IconButton(
                tooltip: hidden ? l.showBalance : l.hideBalance,
                color: c.onBalanceCardVariant,
                icon: Icon(hidden ? Icons.visibility_off : Icons.visibility),
                onPressed: () {
                  AppHaptics.key();
                  ref.read(settingsProvider.notifier).toggleHideBalance();
                },
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: spendable == null
                ? const SizedBox(height: 36)
                : FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: CountUpAmount(
                      id: 'home.spendable',
                      value: spendable,
                      format: (int v) => Fmt.base(v, lang),
                      masked: hidden ? masked : null,
                      semanticsPrefix: l.spendableBalance,
                      style: AppTextStyles.amountHero.copyWith(color: c.onBalanceCard),
                    ),
                  ),
          ),
          if (spendable != null && spendable < 0 && !hidden)
            Container(
              margin: const EdgeInsets.only(top: AppSpacing.xxs),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
              decoration: BoxDecoration(color: c.dangerContainer, borderRadius: AppRadius.brFull),
              child: Text(l.negativeBalance, style: tt.labelSmall?.copyWith(color: c.onDangerContainer)),
            ),
          const Spacer(),
          if (hasHoldings)
            Row(
              children: <Widget>[
                Expanded(
                  child: _Metric(
                    icon: HoldingPlaceStyle.featureIcon,
                    label: l.holdingsElsewhere,
                    value: worth.value?.holdings,
                    id: 'home.holdings',
                    color: c.balanceHolding,
                    masked: hidden ? masked : null,
                    lang: lang,
                    onTap: () => context.push(Routes.holdings),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _Metric(
                    icon: Icons.functions,
                    label: l.netWorth,
                    value: worth.value?.total,
                    id: 'home.netWorth',
                    color: c.onBalanceCard,
                    masked: hidden ? masked : null,
                    lang: lang,
                  ),
                ),
              ],
            )
          else
            InkWell(
              borderRadius: AppRadius.brSm,
              onTap: () => context.push(Routes.newHolding),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: AppSizes.minTouch),
                child: Row(
                  children: <Widget>[
                    Icon(Icons.add, size: 18, color: c.onBalanceCardVariant),
                    const SizedBox(width: AppSpacing.xs),
                    Flexible(
                      child: Text(
                        l.addHolding,
                        overflow: TextOverflow.ellipsis,
                        style: tt.bodyMedium?.copyWith(color: c.onBalanceCardVariant),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A bottom metric of the totals card: label over amount, 48dp tall.
class _Metric extends StatelessWidget {
  const _Metric({
    required this.icon,
    required this.label,
    required this.value,
    required this.id,
    required this.color,
    required this.masked,
    required this.lang,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final int? value;
  final String id;
  final Color color;
  final String? masked;
  final String lang;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final TextTheme tt = Theme.of(context).textTheme;
    final String finalText = masked ?? (value == null ? '…' : Fmt.base(value!, lang));
    return Semantics(
      button: onTap != null,
      label: '$label, $finalText',
      excludeSemantics: true,
      child: InkWell(
        borderRadius: AppRadius.brSm,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSizes.minTouch),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(icon, size: 16, color: c.onBalanceCardVariant),
                  const SizedBox(width: AppSpacing.xs),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.labelMedium?.copyWith(color: c.onBalanceCardVariant),
                    ),
                  ),
                  if (onTap != null) Icon(Icons.chevron_right, size: 16, color: c.onBalanceCardVariant),
                ],
              ),
              if (value != null)
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: CountUpAmount(
                    id: id,
                    value: value!,
                    format: (int v) => Fmt.base(v, lang),
                    masked: masked,
                    style: AppTextStyles.amountSecondary.copyWith(color: color),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Bu ay" strip under the carousel (DESIGN.md §18.1.6): the chosen
/// month's income and expense; the header opens the month picker.
class MonthStrip extends ConsumerStatefulWidget {
  const MonthStrip({super.key});

  @override
  ConsumerState<MonthStrip> createState() => _MonthStripState();
}

class _MonthStripState extends ConsumerState<MonthStrip> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final AppColors c = AppColors.of(context);
    final ThemeData theme = Theme.of(context);
    final String lang = ref.watch(languageProvider);
    final bool hidden = ref.watch(settingsProvider).hideBalance;
    final PeriodTotals totals =
        ref.watch(periodTotalsProvider(DateWindow.month(_month))).value ?? const PeriodTotals();
    final String masked = Fmt.masked(Currency.base.code, lang);
    final DateTime now = DateTime.now();
    final bool current = _month.year == now.year && _month.month == now.month;
    final String monthName = Fmt.month(_month, lang).split(' ').first;
    final String header = current ? '${l.thisMonthShort} · $monthName' : Fmt.month(_month, lang);

    Widget half(IconData icon, String value, Color color, String label) => Expanded(
          child: Semantics(
            label: '$label $value',
            excludeSemantics: true,
            child: Row(
              children: <Widget>[
                Icon(icon, size: 18, color: color),
                const SizedBox(width: AppSpacing.xs),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(value, style: AppTextStyles.amountTile.copyWith(color: color)),
                  ),
                ),
              ],
            ),
          ),
        );

    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      borderRadius: AppRadius.brLg,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.xs, AppSpacing.lg, AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            InkWell(
              borderRadius: AppRadius.brSm,
              onTap: () async {
                final DateTime? m = await pickMonthSheet(context, _month, lang);
                if (m != null && mounted) setState(() => _month = m);
              },
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: AppSizes.minTouch),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(header, style: theme.textTheme.titleSmall),
                    const Icon(Icons.arrow_drop_down, size: 20),
                  ],
                ),
              ),
            ),
            AnimatedSwitcher(
              duration: AppMotion.of(context, AppMotion.fadeThroughDuration),
              transitionBuilder: AppMotion.fadeThrough,
              child: Row(
                key: ValueKey<DateTime>(_month),
                children: <Widget>[
                  half(
                    Icons.south_west,
                    hidden ? masked : Fmt.signed(totals.income, Currency.base.code, TxType.income, lang),
                    c.income,
                    l.income,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  half(
                    Icons.north_east,
                    hidden ? masked : Fmt.signed(totals.expense, Currency.base.code, TxType.expense, lang),
                    c.expense,
                    l.expense,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
