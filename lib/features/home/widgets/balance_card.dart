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

/// Home hero card v1.1 (DESIGN.md §13.2): spendable balance, the month's
/// income / expense, then "Kənarda" and "Ümumi sərvət".
class BalanceCard extends ConsumerStatefulWidget {
  const BalanceCard({super.key});

  @override
  ConsumerState<BalanceCard> createState() => _BalanceCardState();
}

class _BalanceCardState extends ConsumerState<BalanceCard> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  Future<void> _pickMonth(String lang) async {
    final DateTime now = DateTime.now();
    final List<DateTime> months = <DateTime>[
      for (int i = 0; i < 12; i++) DateTime(now.year, now.month - i),
    ];
    final DateTime? m = await showModalBottomSheet<DateTime>(
      context: context,
      builder: (BuildContext ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: <Widget>[
            for (final DateTime x in months)
              ListTile(
                title: Text(Fmt.month(x, lang)),
                trailing: x == _month ? const Icon(Icons.check) : null,
                onTap: () => Navigator.of(ctx).pop(x),
              ),
          ],
        ),
      ),
    );
    if (m != null && mounted) setState(() => _month = m);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final AppColors c = AppColors.of(context);
    final TextTheme tt = Theme.of(context).textTheme;
    final String lang = ref.watch(languageProvider);
    final bool hidden = ref.watch(settingsProvider).hideBalance;
    final AsyncValue<NetWorth> worth = ref.watch(netWorthProvider);
    final int? spendable = ref.watch(totalBalanceProvider).value;
    final bool hasHoldings =
        (ref.watch(holdingsProvider).value ?? const <HoldingWithValue>[])
            .isNotEmpty;
    final PeriodTotals totals =
        ref.watch(periodTotalsProvider(DateWindow.month(_month))).value ??
        const PeriodTotals();
    final String masked = Fmt.masked(Currency.base.code, lang);
    final Color divider = c.onBalanceCard.withValues(alpha: 0.16);

    Widget shimmer(double h, double w) => Container(
      height: h,
      width: w,
      margin: const EdgeInsets.only(top: AppSpacing.xs),
      decoration: BoxDecoration(
        color: c.onBalanceCard.withValues(alpha: 0.16),
        borderRadius: AppRadius.brSm,
      ),
    );

    return Container(
      decoration: BoxDecoration(
        gradient: c.balanceGradient,
        borderRadius: AppRadius.brXl,
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  l.spendableBalance,
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
          if (spendable == null)
            shimmer(36, 180)
          else
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: CountUpAmount(
                id: 'home.spendable',
                value: spendable,
                format: (int v) => Fmt.base(v, lang),
                masked: hidden ? masked : null,
                semanticsPrefix: l.spendableBalance,
                style: AppTextStyles.amountHero.copyWith(
                  color: c.onBalanceCard,
                ),
              ),
            ),
          if (spendable != null && spendable < 0 && !hidden)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xxs,
                ),
                decoration: BoxDecoration(
                  color: c.dangerContainer,
                  borderRadius: AppRadius.brFull,
                ),
                child: Text(
                  l.negativeBalance,
                  style: tt.labelSmall?.copyWith(color: c.onDangerContainer),
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.lg),
          AnimatedSwitcher(
            duration: AppMotion.of(context, AppMotion.fadeThroughDuration),
            transitionBuilder: AppMotion.fadeThrough,
            child: Row(
              key: ValueKey<DateTime>(_month),
              children: <Widget>[
                Expanded(
                  child: _MonthTile(
                    icon: Icons.south_west,
                    label: l.income,
                    value: hidden
                        ? masked
                        : Fmt.signed(
                            totals.income,
                            Currency.base.code,
                            TxType.income,
                            lang,
                          ),
                    color: c.balanceIncome,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _MonthTile(
                    icon: Icons.north_east,
                    label: l.expense,
                    value: hidden
                        ? masked
                        : Fmt.signed(
                            totals.expense,
                            Currency.base.code,
                            TxType.expense,
                            lang,
                          ),
                    color: c.balanceExpense,
                  ),
                ),
              ],
            ),
          ),
          if (hasHoldings) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Divider(color: divider, height: 1),
            _MetricRow(
              icon: HoldingPlaceStyle.featureIcon,
              label: l.holdingsElsewhere,
              value: worth.value?.holdings,
              id: 'home.holdings',
              color: c.balanceHolding,
              masked: hidden ? masked : null,
              lang: lang,
              onTap: () => context.push(Routes.holdings),
            ),
            _MetricRow(
              icon: Icons.functions,
              label: l.netWorth,
              value: worth.value?.total,
              id: 'home.netWorth',
              color: c.onBalanceCard,
              masked: hidden ? masked : null,
              lang: lang,
            ),
          ],
          const SizedBox(height: AppSpacing.xs),
          InkWell(
            borderRadius: AppRadius.brSm,
            onTap: () => _pickMonth(lang),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: AppSizes.minTouch),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    Fmt.month(_month, lang),
                    style: tt.bodySmall?.copyWith(
                      color: c.onBalanceCardVariant,
                    ),
                  ),
                  Icon(
                    Icons.arrow_drop_down,
                    color: c.onBalanceCardVariant,
                    size: 18,
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

/// A 48dp balance-card row: icon, label, right-aligned amount, chevron.
class _MetricRow extends StatelessWidget {
  const _MetricRow({
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
    final String finalText =
        masked ?? (value == null ? '…' : Fmt.base(value!, lang));
    return Semantics(
      button: onTap != null,
      label: '$label, $finalText',
      excludeSemantics: true,
      child: InkWell(
        borderRadius: AppRadius.brSm,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSizes.minTouch),
          child: Row(
            children: <Widget>[
              Icon(icon, size: 20, color: c.onBalanceCardVariant),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  label,
                  style: tt.bodyMedium?.copyWith(color: c.onBalanceCardVariant),
                ),
              ),
              if (value != null)
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: CountUpAmount(
                      id: id,
                      value: value!,
                      format: (int v) => Fmt.base(v, lang),
                      masked: masked,
                      style: AppTextStyles.amountSecondary.copyWith(
                        color: color,
                      ),
                    ),
                  ),
                ),
              if (onTap != null)
                Icon(Icons.chevron_right, color: c.onBalanceCardVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _MonthTile extends StatelessWidget {
  const _MonthTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final TextTheme tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: c.balanceCardOverlay,
        borderRadius: AppRadius.brLg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: 16, color: c.onBalanceCardVariant),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: tt.labelMedium?.copyWith(
                    color: c.onBalanceCardVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: tt.titleMedium
                  ?.merge(AppTextStyles.tabular)
                  .copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
