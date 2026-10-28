import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/format.dart';
import '../../core/motion.dart';
import '../../core/router.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';
import '../settings/settings_controller.dart';
import '../transactions/tx_filter_controller.dart';

enum ReportPeriod { thisMonth, lastMonth, thisYear, custom }

/// Reports tab (DESIGN.md §7.7). All values are AZN.
class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

/// A request from elsewhere (Home weekly card) to open Reports on a given
/// period and pie type. Consumed once by [ReportsScreen].
class ReportsRequest {
  const ReportsRequest({required this.window, this.type = TxType.expense});

  final DateWindow window;
  final TxType type;
}

class ReportsRequestController extends Notifier<ReportsRequest?> {
  @override
  ReportsRequest? build() => null;

  void open(ReportsRequest r) => state = r;

  void clear() => state = null;
}

final NotifierProvider<ReportsRequestController, ReportsRequest?>
reportsRequestProvider =
    NotifierProvider<ReportsRequestController, ReportsRequest?>(
      ReportsRequestController.new,
    );

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  ReportPeriod _period = ReportPeriod.thisMonth;
  DateWindow? _custom;
  TxType _pieType = TxType.expense;
  int _months = 6;

  void _consume(ReportsRequest? r) {
    if (r == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _period = ReportPeriod.custom;
        _custom = r.window;
        _pieType = r.type;
      });
      ref.read(reportsRequestProvider.notifier).clear();
    });
  }

  DateWindow get _window {
    final DateTime now = DateTime.now();
    return switch (_period) {
      ReportPeriod.thisMonth => DateWindow.month(now),
      ReportPeriod.lastMonth => DateWindow.month(
        DateTime(now.year, now.month - 1),
      ),
      ReportPeriod.thisYear => DateWindow(
        DateTime(now.year),
        DateTime(now.year + 1),
      ),
      ReportPeriod.custom => _custom ?? DateWindow.month(now),
    };
  }

  Future<void> _pickCustom() async {
    final DateWindow w = _window;
    final DateTimeRange? r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: DateTimeRange(
        start: w.start,
        end: w.end.subtract(const Duration(days: 1)),
      ),
    );
    if (r == null) return;
    setState(() {
      _custom = DateWindow.days(r.start, r.end);
      _period = ReportPeriod.custom;
    });
  }

  void _openCategory(int categoryId) {
    ref
        .read(txFilterProvider.notifier)
        .apply(
          TxFilter(
            types: <TxType>[_pieType],
            categoryId: categoryId,
            window: _window,
          ),
        );
    context.go(Routes.transactions);
  }

  @override
  void initState() {
    super.initState();
    _consume(ref.read(reportsRequestProvider));
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<ReportsRequest?>(
      reportsRequestProvider,
      (_, ReportsRequest? r) => _consume(r),
    );
    final AppLocalizations l = AppLocalizations.of(context);
    final String lang = ref.watch(languageProvider);
    final DateWindow w = _window;
    final DateTime last = w.end.subtract(const Duration(days: 1));

    return Scaffold(
      appBar: AppBar(
        title: Text(l.navReports),
        actions: <Widget>[
          IconButton(
            tooltip: l.export,
            icon: const Icon(Icons.file_download_outlined),
            onPressed: () => context.push(Routes.export),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.xxl,
        ),
        children: <Widget>[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SegmentedButton<ReportPeriod>(
              showSelectedIcon: false,
              segments: <ButtonSegment<ReportPeriod>>[
                ButtonSegment<ReportPeriod>(
                  value: ReportPeriod.thisMonth,
                  label: Text(l.periodThisMonth),
                ),
                ButtonSegment<ReportPeriod>(
                  value: ReportPeriod.lastMonth,
                  label: Text(l.periodLastMonth),
                ),
                ButtonSegment<ReportPeriod>(
                  value: ReportPeriod.thisYear,
                  label: Text(l.periodThisYear),
                ),
                ButtonSegment<ReportPeriod>(
                  value: ReportPeriod.custom,
                  label: Text(l.periodCustom),
                ),
              ],
              selected: <ReportPeriod>{_period},
              onSelectionChanged: (Set<ReportPeriod> s) {
                if (s.first == ReportPeriod.custom) {
                  _pickCustom();
                } else {
                  setState(() => _period = s.first);
                }
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Text(
              '${Fmt.date(w.start, lang)} – ${Fmt.date(last, lang)}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Center(
            child: SegmentedButton<TxType>(
              showSelectedIcon: false,
              segments: <ButtonSegment<TxType>>[
                ButtonSegment<TxType>(
                  value: TxType.expense,
                  label: Text(l.txTypeExpense),
                ),
                ButtonSegment<TxType>(
                  value: TxType.income,
                  label: Text(l.txTypeIncome),
                ),
              ],
              selected: <TxType>{_pieType},
              onSelectionChanged: (Set<TxType> s) =>
                  setState(() => _pieType = s.first),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _CategoryPie(
            window: w,
            type: _pieType,
            lang: lang,
            onCategory: _openCategory,
          ),
          SectionHeader(
            l.reportsByMonth,
            trailing: SegmentedButton<int>(
              showSelectedIcon: false,
              segments: <ButtonSegment<int>>[
                ButtonSegment<int>(value: 6, label: Text(l.monthsN(6))),
                ButtonSegment<int>(value: 12, label: Text(l.monthsN(12))),
              ],
              selected: <int>{_months},
              onSelectionChanged: (Set<int> s) =>
                  setState(() => _months = s.first),
            ),
          ),
          _MonthlyCharts(months: _months, lang: lang),
        ],
      ),
    );
  }
}

/// A pie slice: category (null for the merged "Other") and its amount.
class _Slice {
  const _Slice(this.category, this.amount, this.color, this.label);

  final int? category;
  final int amount;
  final Color color;
  final String label;
}

class _CategoryPie extends ConsumerStatefulWidget {
  const _CategoryPie({
    required this.window,
    required this.type,
    required this.lang,
    required this.onCategory,
  });

  final DateWindow window;
  final TxType type;
  final String lang;
  final ValueChanged<int> onCategory;

  @override
  ConsumerState<_CategoryPie> createState() => _CategoryPieState();
}

class _CategoryPieState extends ConsumerState<_CategoryPie> {
  int _touched = -1;
  bool _shown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _shown = true);
    });
  }

  static const int _maxSlices = 7;
  static const int _otherColor = 7; // slate

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final AppColors colors = AppColors.of(context);
    final AsyncValue<List<CategoryTotal>> data = ref.watch(
      categoryTotalsProvider((window: widget.window, type: widget.type)),
    );
    final List<TxCategory> cats =
        ref
            .watch(categoriesProvider((type: null, includeArchived: true)))
            .value ??
        const <TxCategory>[];

    return data.when(
      loading: () => const SizedBox(
        height: 220,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (Object e, _) => Center(child: Text(l.genericError)),
      data: (List<CategoryTotal> totals) {
        if (totals.isEmpty) {
          return EmptyState(
            icon: Icons.pie_chart_outline,
            title: l.emptyReportsTitle,
          );
        }
        final int sum = totals.fold(
          0,
          (int s, CategoryTotal t) => s + t.amount,
        );

        // Palette order by rank, skipping slate (reserved for "Other").
        final List<int> paletteOrder = <int>[
          for (int i = 0; i < colors.categorical.length; i++)
            if (i != _otherColor) i,
        ];
        final List<_Slice> slices = <_Slice>[];
        final bool merge = totals.length > _maxSlices;
        final int shown = merge ? _maxSlices - 1 : totals.length;
        for (int i = 0; i < shown; i++) {
          final CategoryTotal t = totals[i];
          final TxCategory? c = cats
              .where((TxCategory c) => c.id == t.categoryId)
              .firstOrNull;
          slices.add(
            _Slice(
              t.categoryId,
              t.amount,
              colors.categorical[paletteOrder[i % paletteOrder.length]],
              c?.localizedName(widget.lang) ?? l.uncategorized,
            ),
          );
        }
        if (merge) {
          final int rest = totals
              .skip(shown)
              .fold(0, (int s, CategoryTotal t) => s + t.amount);
          slices.add(
            _Slice(
              null,
              rest,
              colors.categorical[_otherColor],
              l.otherCategories,
            ),
          );
        }

        String pct(int v) =>
            '${(v * 100 / sum).toStringAsFixed(v * 100 / sum < 10 ? 1 : 0)}%';

        return Column(
          children: <Widget>[
            SizedBox(
              height: 240,
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  PieChart(
                    PieChartData(
                      startDegreeOffset: -90,
                      sectionsSpace: 2,
                      centerSpaceRadius: 56,
                      pieTouchData: PieTouchData(
                        touchCallback:
                            (FlTouchEvent event, PieTouchResponse? r) {
                              final int idx =
                                  r?.touchedSection?.touchedSectionIndex ?? -1;
                              if (event is FlTapUpEvent &&
                                  idx >= 0 &&
                                  idx < slices.length) {
                                final int? cid = slices[idx].category;
                                if (cid != null) widget.onCategory(cid);
                                return;
                              }
                              setState(
                                () =>
                                    _touched = event.isInterestedForInteractions
                                    ? idx
                                    : -1,
                              );
                            },
                      ),
                      sections: <PieChartSectionData>[
                        for (int i = 0; i < slices.length; i++)
                          PieChartSectionData(
                            value: _shown ? slices[i].amount.toDouble() : 1,
                            color: slices[i].color,
                            radius: i == _touched ? 52 : 46,
                            showTitle: i == _touched,
                            title: pct(slices[i].amount),
                            titleStyle: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.white,
                            ),
                          ),
                      ],
                    ),
                    duration: AppMotion.of(context, AppMotion.chartEntry),
                    curve: AppMotion.chartCurve,
                  ),
                  Semantics(
                    label:
                        '${widget.type == TxType.expense ? l.expense : l.income} ${Fmt.base(sum, widget.lang)}',
                    excludeSemantics: true,
                    child: SizedBox(
                      width: 104,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          Fmt.base(sum, widget.lang),
                          style: theme.textTheme.titleLarge?.merge(
                            AppTextStyles.tabular,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            for (final _Slice s in slices)
              InkWell(
                borderRadius: AppRadius.brMd,
                onTap: s.category == null
                    ? null
                    : () => widget.onCategory(s.category!),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.sm,
                    horizontal: AppSpacing.xs,
                  ),
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: s.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          s.label,
                          style: theme.textTheme.bodyLarge,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        Fmt.base(s.amount, widget.lang),
                        style: theme.textTheme.bodyMedium?.merge(
                          AppTextStyles.tabular,
                        ),
                      ),
                      SizedBox(
                        width: 56,
                        child: Text(
                          pct(s.amount),
                          textAlign: TextAlign.end,
                          style: theme.textTheme.bodySmall
                              ?.merge(AppTextStyles.tabular)
                              .copyWith(color: cs.onSurfaceVariant),
                        ),
                      ),
                      if (s.category != null)
                        Icon(
                          Icons.chevron_right,
                          size: 18,
                          color: cs.onSurfaceVariant,
                        )
                      else
                        const SizedBox(width: 18),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _MonthlyCharts extends ConsumerWidget {
  const _MonthlyCharts({required this.months, required this.lang});

  final int months;
  final String lang;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final AppColors colors = AppColors.of(context);
    final AsyncValue<MonthlySeries> data = ref.watch(
      monthlySeriesProvider(months),
    );
    final int? balanceNow = ref.watch(totalBalanceProvider).value;

    return data.when(
      loading: () => const SizedBox(
        height: 220,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (Object e, _) => Center(child: Text(l.genericError)),
      data: (MonthlySeries series) {
        final List<MonthTotals> ms = series.months;
        if (ms.every(
          (MonthTotals m) => m.totals.income == 0 && m.totals.expense == 0,
        )) {
          return EmptyState(icon: Icons.bar_chart, title: l.emptyReportsTitle);
        }
        double major(int minor) => minor / 100;
        final double maxY = ms.fold<double>(
          0,
          (double m, MonthTotals t) =>
              math.max(m, major(math.max(t.totals.income, t.totals.expense))),
        );
        final NumberFormat compact = NumberFormat.compact(locale: lang);
        final TextStyle? axis = theme.textTheme.bodySmall?.copyWith(
          color: cs.onSurfaceVariant,
        );
        final DateFormat monthFmt = DateFormat.MMM(lang);

        Widget bottom(double v, TitleMeta meta) {
          final int i = v.round();
          if (i < 0 || i >= ms.length || v != i.toDouble()) {
            return const SizedBox.shrink();
          }
          if (ms.length > 6 && i.isOdd) return const SizedBox.shrink();
          return SideTitleWidget(
            meta: meta,
            child: Text(monthFmt.format(ms[i].month), style: axis),
          );
        }

        Widget left(double v, TitleMeta meta) {
          if (v == meta.max && v != 0) return const SizedBox.shrink();
          return SideTitleWidget(
            meta: meta,
            child: Text(compact.format(v), style: axis),
          );
        }

        FlTitlesData titles() => FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: 1,
              getTitlesWidget: bottom,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              getTitlesWidget: left,
            ),
          ),
        );

        final FlGridData grid = FlGridData(
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(
            color: cs.outlineVariant,
            strokeWidth: 1,
            dashArray: <int>[4, 4],
          ),
        );

        // Balance at each month end, walking back from today's total.
        final List<int> balances = List<int>.filled(ms.length, 0);
        if (balanceNow != null) {
          int b = balanceNow - series.netAfter;
          for (int i = ms.length - 1; i >= 0; i--) {
            balances[i] = b;
            b -= ms[i].totals.net;
          }
        }
        final double minB = balances.map(major).reduce(math.min);
        final double maxB = balances.map(major).reduce(math.max);
        final double pad = math.max((maxB - minB) * 0.1, 1);

        final int avgExpense =
            ms.fold(0, (int s, MonthTotals m) => s + m.totals.expense) ~/
            ms.length;
        final double rodWidth = ms.length > 6 ? 6 : 8;

        return ChartEntry(
          builder: (BuildContext context, bool shown) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Wrap(
                spacing: AppSpacing.lg,
                children: <Widget>[
                  _Legend(color: colors.income, label: l.income),
                  _Legend(color: colors.expense, label: l.expense),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                height: 220,
                child: BarChart(
                  BarChartData(
                    maxY: maxY <= 0 ? 1 : maxY * 1.15,
                    gridData: grid,
                    borderData: FlBorderData(show: false),
                    titlesData: titles(),
                    barTouchData: BarTouchData(
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipColor: (_) => cs.inverseSurface,
                        getTooltipItem:
                            (
                              BarChartGroupData g,
                              int gi,
                              BarChartRodData rod,
                              int ri,
                            ) => BarTooltipItem(
                              '${ri == 0 ? l.income : l.expense}\n${Fmt.base((rod.toY * 100).round(), lang)}',
                              theme.textTheme.bodySmall!.copyWith(
                                color: cs.onInverseSurface,
                              ),
                            ),
                      ),
                    ),
                    barGroups: <BarChartGroupData>[
                      for (int i = 0; i < ms.length; i++)
                        BarChartGroupData(
                          x: i,
                          barsSpace: 4,
                          barRods: <BarChartRodData>[
                            BarChartRodData(
                              toY: shown ? major(ms[i].totals.income) : 0,
                              color: colors.income,
                              width: rodWidth,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(AppRadius.xs),
                              ),
                            ),
                            BarChartRodData(
                              toY: shown ? major(ms[i].totals.expense) : 0,
                              color: colors.expense,
                              width: rodWidth,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(AppRadius.xs),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  duration: AppMotion.of(context, AppMotion.chartEntry),
                  curve: AppMotion.chartCurve,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                l.averageMonthlyExpense(Fmt.base(avgExpense, lang)),
                style: theme.textTheme.bodyMedium,
              ),
              if (balanceNow != null) ...<Widget>[
                SectionHeader(l.balanceTrend),
                SizedBox(
                  height: 200,
                  child: LineChart(
                    LineChartData(
                      minY: minB - pad,
                      maxY: maxB + pad,
                      minX: 0,
                      maxX: (ms.length - 1).toDouble(),
                      gridData: grid,
                      borderData: FlBorderData(show: false),
                      titlesData: titles(),
                      lineTouchData: LineTouchData(
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipColor: (_) => cs.inverseSurface,
                          getTooltipItems: (List<LineBarSpot> spots) =>
                              <LineTooltipItem>[
                                for (final LineBarSpot s in spots)
                                  LineTooltipItem(
                                    Fmt.base((s.y * 100).round(), lang),
                                    theme.textTheme.bodySmall!.copyWith(
                                      color: cs.onInverseSurface,
                                    ),
                                  ),
                              ],
                        ),
                      ),
                      lineBarsData: <LineChartBarData>[
                        LineChartBarData(
                          spots: <FlSpot>[
                            for (int i = 0; i < ms.length; i++)
                              FlSpot(
                                i.toDouble(),
                                shown ? major(balances[i]) : minB - pad,
                              ),
                          ],
                          color: cs.primary,
                          barWidth: 3,
                          isCurved: true,
                          preventCurveOverShooting: true,
                          dotData: const FlDotData(show: true),
                          belowBarData: BarAreaData(
                            show: true,
                            color: cs.primary.withValues(alpha: 0.12),
                          ),
                        ),
                      ],
                    ),
                    duration: AppMotion.of(context, AppMotion.chartEntry),
                    curve: AppMotion.chartCurve,
                  ),
                ),
                Text(
                  l.balanceTrendHint,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, borderRadius: AppRadius.brXs),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
