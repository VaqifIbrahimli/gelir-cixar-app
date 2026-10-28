import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/format.dart';
import '../../../core/motion.dart';
import '../../../core/router.dart';
import '../../../core/theme.dart';
import '../../../core/widgets.dart';
import '../../../data/providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../budgets/widgets/budget_progress_row.dart';
import '../../reports/reports_screen.dart';
import '../../settings/settings_controller.dart';

/// Shared Home card frame: surfaceContainerLow, radius 16, padding 16,
/// optional header with a "Hamısı ›" action, press scale when tappable.
class HomeCard extends StatelessWidget {
  const HomeCard({
    super.key,
    required this.child,
    this.title,
    this.icon,
    this.trailing,
    this.onTap,
  });

  final String? title;
  final IconData? icon;
  final Widget? trailing;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Widget body = Padding(
      padding: AppSpacing.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (title != null)
            Row(
              children: <Widget>[
                if (icon != null) ...<Widget>[
                  Icon(
                    icon,
                    size: 20,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                ],
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(title!, style: theme.textTheme.titleMedium),
                  ),
                ),
                ?trailing,
              ],
            ),
          child,
        ],
      ),
    );
    final Widget card = Material(
      color: theme.colorScheme.surfaceContainerLow,
      borderRadius: AppRadius.brLg,
      clipBehavior: Clip.antiAlias,
      child: onTap == null ? body : InkWell(onTap: onTap, child: body),
    );
    return onTap == null ? card : PressScale(child: card);
  }
}

/// "Bu həftə" (§13.3): expense per day for the last 7 days, today on the
/// right, compared with the 7 days before.
class WeekCard extends ConsumerStatefulWidget {
  const WeekCard({super.key});

  @override
  ConsumerState<WeekCard> createState() => _WeekCardState();
}

class _WeekCardState extends ConsumerState<WeekCard> {
  /// First frame draws empty bars; the real values animate in (§11.4).
  bool _shown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _shown = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final String lang = ref.watch(languageProvider);
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final AppColors colors = AppColors.of(context);
    final List<int> days =
        ref.watch(dailyExpensesProvider).value ?? List<int>.filled(14, 0);
    final List<int> week = days.sublist(days.length - 7);
    final int total = week.fold(0, (int s, int v) => s + v);
    final int previous = days
        .sublist(0, days.length - 7)
        .fold(0, (int s, int v) => s + v);
    final DateTime today = DateTime.now();
    final List<DateTime> dates = <DateTime>[
      for (int i = 6; i >= 0; i--)
        DateTime(today.year, today.month, today.day - i),
    ];
    final DateFormat shortDay = DateFormat.E(lang);
    final DateFormat longDay = DateFormat.EEEE(lang);
    final double maxV = math.max(1, week.fold<int>(0, math.max)) / 100;

    String? compare;
    Color? compareColor;
    if (previous > 0) {
      final int pct = ((total - previous).abs() * 100 / previous).round();
      if (total <= previous) {
        compare = l.vsLastWeekLess(pct);
        compareColor = colors.income;
      } else {
        compare = l.vsLastWeekMore(pct);
        compareColor = colors.expense;
      }
    }

    void openReports() {
      ref
          .read(reportsRequestProvider.notifier)
          .open(
            ReportsRequest(window: DateWindow.days(dates.first, dates.last)),
          );
      context.go(Routes.reports);
    }

    return HomeCard(
      title: l.thisWeek,
      onTap: openReports,
      trailing: Text(
        Fmt.base(total, lang),
        style: AppTextStyles.amountTile.copyWith(color: cs.onSurface),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (compare != null)
            Text(
              compare,
              style: theme.textTheme.bodySmall?.copyWith(color: compareColor),
            ),
          const SizedBox(height: AppSpacing.md),
          Semantics(
            label: <String>[
              for (int i = 0; i < 7; i++)
                '${longDay.format(dates[i])} ${Fmt.base(week[i], lang)}',
            ].join(', '),
            excludeSemantics: true,
            child: SizedBox(
              height: AppSizes.weekChartHeight + 24,
              child: BarChart(
                BarChartData(
                  maxY: maxV,
                  minY: 0,
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  alignment: BarChartAlignment.spaceAround,
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(),
                    rightTitles: const AxisTitles(),
                    topTitles: const AxisTitles(),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 24,
                        getTitlesWidget: (double v, TitleMeta meta) {
                          final int i = v.round();
                          if (i < 0 || i > 6) return const SizedBox.shrink();
                          final bool isToday = i == 6;
                          return SideTitleWidget(
                            meta: meta,
                            space: 4,
                            child: Text(
                              shortDay.format(dates[i]),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: isToday
                                    ? cs.onSurface
                                    : cs.onSurfaceVariant,
                                fontWeight: isToday ? FontWeight.w700 : null,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => cs.inverseSurface,
                      getTooltipItem:
                          (
                            BarChartGroupData g,
                            int gi,
                            BarChartRodData r,
                            int ri,
                          ) => BarTooltipItem(
                            '${longDay.format(dates[g.x])} · ${Fmt.base(week[g.x], lang)}',
                            theme.textTheme.bodySmall!.copyWith(
                              color: cs.onInverseSurface,
                            ),
                          ),
                    ),
                  ),
                  barGroups: <BarChartGroupData>[
                    for (int i = 0; i < 7; i++)
                      BarChartGroupData(
                        x: i,
                        barRods: <BarChartRodData>[
                          BarChartRodData(
                            // A day without spending shows a 2dp stub.
                            toY: !_shown
                                ? 0
                                : (week[i] == 0 ? maxV * 0.03 : week[i] / 100),
                            color: week[i] == 0
                                ? cs.outlineVariant
                                : colors.expense,
                            width: AppSizes.weekBarWidth,
                            borderRadius: AppRadius.brBarTop,
                          ),
                        ],
                      ),
                  ],
                ),
                duration: AppMotion.of(context, AppMotion.chartEntry),
                curve: AppMotion.chartCurve,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Budget summary (§13.4): top 3 budgets by usage, or a compact empty state.
class BudgetSummaryCard extends ConsumerWidget {
  const BudgetSummaryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l = AppLocalizations.of(context);
    final String lang = ref.watch(languageProvider);
    final List<BudgetProgress> list =
        ref.watch(budgetProgressProvider(monthKey(DateTime.now()))).value ??
        const <BudgetProgress>[];
    final List<TxCategory> cats =
        ref
            .watch(categoriesProvider((type: null, includeArchived: true)))
            .value ??
        const <TxCategory>[];
    final List<BudgetProgress> top = <BudgetProgress>[
      ...list,
    ]..sort((BudgetProgress a, BudgetProgress b) => b.ratio.compareTo(a.ratio));

    return HomeCard(
      title: l.budgetSummary,
      trailing: TextButton(
        onPressed: () => context.go(Routes.budgets),
        child: Text(l.seeAll),
      ),
      child: list.isEmpty
          ? Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    l.emptyBudgetsTitle,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                TextButton(
                  onPressed: () => context.go(Routes.budgets),
                  child: Text(l.createBudget),
                ),
              ],
            )
          : Column(
              children: <Widget>[
                for (final BudgetProgress p in top.take(3))
                  BudgetProgressRow(
                    progress: p,
                    category: cats
                        .where((TxCategory c) => c.id == p.budget.categoryId)
                        .firstOrNull,
                    lang: lang,
                    onTap: () => context.go(Routes.budgets),
                  ),
              ],
            ),
    );
  }
}

/// Holdings card (§13.5): total, top 3 by AZN value, deposit maturity pill.
/// Hidden when there are no holdings.
class HoldingsCard extends ConsumerWidget {
  const HoldingsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l = AppLocalizations.of(context);
    final String lang = ref.watch(languageProvider);
    final bool hidden = ref.watch(settingsProvider).hideBalance;
    final List<HoldingWithValue> holdings =
        ref.watch(holdingsProvider).value ?? const <HoldingWithValue>[];
    if (holdings.isEmpty) return const SizedBox.shrink();
    final ThemeData theme = Theme.of(context);
    final AppColors c = AppColors.of(context);
    final int total = holdings.fold(
      0,
      (int s, HoldingWithValue h) => s + h.azn,
    );
    final List<HoldingWithValue> top = <HoldingWithValue>[
      ...holdings,
    ]..sort((HoldingWithValue a, HoldingWithValue b) => b.azn.compareTo(a.azn));
    final String masked = Fmt.masked(Currency.base.code, lang);

    // The deposit maturing soonest (≤ 30 days) or already matured.
    int? soonest;
    for (final HoldingWithValue h in holdings) {
      if (h.holding.placeType != HoldingPlace.bankDeposit) continue;
      final int? d = daysToMaturity(h.holding.maturityDate);
      if (d != null && d <= 30 && (soonest == null || d < soonest)) soonest = d;
    }

    return HomeCard(
      title: l.holdings,
      icon: HoldingPlaceStyle.featureIcon,
      onTap: () => context.push(Routes.holdings),
      trailing: TextButton(
        onPressed: () => context.push(Routes.holdings),
        child: Text(l.seeAll),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          CountUpAmount(
            id: 'home.holdingsCard',
            value: total,
            format: (int v) => Fmt.base(v, lang),
            masked: hidden ? masked : null,
            semanticsPrefix: l.holdingsElsewhere,
            style: AppTextStyles.amountSecondary.copyWith(color: c.holding),
          ),
          const SizedBox(height: AppSpacing.xs),
          for (final HoldingWithValue h in top.take(3))
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: AppSizes.minTouch),
              child: Row(
                children: <Widget>[
                  PlaceAvatar(place: h.holding.placeType, size: 32),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      h.holding.name,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge,
                    ),
                  ),
                  Text(
                    hidden
                        ? Fmt.masked(h.holding.currency, lang)
                        : Fmt.money(h.amount, h.holding.currency, lang),
                    style: AppTextStyles.amountTile.copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          if (soonest != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: soonest < 0
                  ? StatusPill(
                      text: l.depositMatured,
                      icon: Icons.alarm,
                      background: c.dangerContainer,
                      foreground: c.onDangerContainer,
                    )
                  : StatusPill(
                      text: l.depositEndsIn(soonest),
                      icon: Icons.alarm,
                      background: c.warningContainer,
                      foreground: c.onWarningContainer,
                    ),
            ),
        ],
      ),
    );
  }
}
