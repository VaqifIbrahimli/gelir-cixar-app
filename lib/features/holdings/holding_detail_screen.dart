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
import 'holding_sheets.dart';

enum _Range { m3, m6, y1, all }

/// One holding (DESIGN.md §14.4).
class HoldingDetailScreen extends ConsumerStatefulWidget {
  const HoldingDetailScreen({super.key, required this.holdingId});

  final int holdingId;

  @override
  ConsumerState<HoldingDetailScreen> createState() =>
      _HoldingDetailScreenState();
}

/// History rows: month headers and entries.
sealed class _Row {}

class _MonthRow extends _Row {
  _MonthRow(this.month);
  final DateTime month;
}

class _EntryRow extends _Row {
  _EntryRow(this.entry, this.before);
  final HoldingEntry entry;

  /// Amount before this entry (for setValue: "əvvəl …").
  final int before;
}

class _HoldingDetailScreenState extends ConsumerState<HoldingDetailScreen> {
  _Range _range = _Range.y1;

  List<_Row> _rows(HoldingDetail d) {
    // Chronological replay gives each entry's "before" amount.
    final List<HoldingEntry> asc = d.entries.reversed.toList();
    final Map<int, int> before = <int, int>{};
    for (int i = 0; i < asc.length; i++) {
      before[asc[i].id] = i == 0
          ? 0
          : (i - 1 < d.series.length ? d.series[i - 1].amount : 0);
    }
    final List<_Row> rows = <_Row>[];
    DateTime? month;
    for (final HoldingEntry e in d.entries) {
      final DateTime m = DateTime(e.date.year, e.date.month);
      if (month != m) {
        rows.add(_MonthRow(m));
        month = m;
      }
      rows.add(_EntryRow(e, before[e.id] ?? 0));
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final String lang = ref.watch(languageProvider);
    final AsyncValue<HoldingDetail?> data = ref.watch(
      holdingDetailProvider(widget.holdingId),
    );
    final Rates rates = ref.watch(ratesProvider).value ?? Rates.defaults;
    final ThemeData theme = Theme.of(context);
    final AppColors c = AppColors.of(context);

    return data.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (Object e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(l.genericError)),
      ),
      data: (HoldingDetail? d) {
        if (d == null) {
          return Scaffold(
            appBar: AppBar(),
            body: EmptyState(icon: Icons.search_off, title: l.holdingNotFound),
          );
        }
        final Holding h = d.holding;
        final int? days = h.placeType == HoldingPlace.bankDeposit
            ? daysToMaturity(h.maturityDate)
            : null;

        return Scaffold(
          body: CustomScrollView(
            slivers: <Widget>[
              SliverAppBar.medium(
                title: Text(h.name),
                actions: <Widget>[
                  IconButton(
                    tooltip: l.edit,
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => context.push(Routes.editHolding(h.id)),
                  ),
                  PopupMenuButton<String>(
                    tooltip: l.more,
                    onSelected: (String v) async {
                      if (v == 'archive') {
                        await ref
                            .read(holdingRepositoryProvider)
                            .setArchived(h.id, !h.isArchived);
                      } else if (await deleteHoldingFlow(context, ref, h) &&
                          context.mounted) {
                        context.pop();
                      }
                    },
                    itemBuilder: (BuildContext ctx) => <PopupMenuEntry<String>>[
                      PopupMenuItem<String>(
                        value: 'archive',
                        child: Text(h.isArchived ? l.unarchive : l.archive),
                      ),
                      PopupMenuItem<String>(
                        value: 'delete',
                        child: Text(l.delete),
                      ),
                    ],
                  ),
                ],
              ),
              SliverPadding(
                padding: AppSpacing.screen,
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Chip(
                        avatar: Icon(
                          holdingPlaceIcon(h.placeType),
                          size: 18,
                          color: c.onHoldingContainer,
                        ),
                        label: Text(holdingPlaceLabel(l, h.placeType)),
                        backgroundColor: c.holdingContainer,
                        labelStyle: theme.textTheme.labelMedium?.copyWith(
                          color: c.onHoldingContainer,
                        ),
                        side: BorderSide.none,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: CountUpAmount(
                          id: 'holding.${h.id}',
                          value: d.amount,
                          format: (int v) => Fmt.money(v, h.currency, lang),
                          style: AppTextStyles.amountDetail.copyWith(
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                      if (h.currency != Currency.base.code)
                        Text(
                          '≈ ${Fmt.base(rates.toBase(d.amount, h.currency), lang)}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      if (days != null && days <= 30) ...<Widget>[
                        const SizedBox(height: AppSpacing.sm),
                        days < 0
                            ? StatusPill(
                                text: l.depositMatured,
                                icon: Icons.alarm,
                                background: c.dangerContainer,
                                foreground: c.onDangerContainer,
                              )
                            : StatusPill(
                                text: l.daysLeft(days),
                                icon: Icons.alarm,
                                background: c.warningContainer,
                                foreground: c.onWarningContainer,
                              ),
                        if (days < 0)
                          TextButton(
                            onPressed: () => showAdjustSheet(
                              context,
                              h,
                              d.amount,
                              kind: HoldingEntryKind.setValue,
                            ),
                            child: Text(l.holdingUpdateValue),
                          ),
                      ],
                      if (h.placeType == HoldingPlace.bankDeposit &&
                          (h.interestRate != null || h.maturityDate != null))
                        _DepositCard(holding: h, amount: d.amount, lang: lang),
                      if (h.note.trim().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.sm),
                          child: Text(
                            h.note,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      const SizedBox(height: AppSpacing.lg),
                      SegmentedButton<_Range>(
                        showSelectedIcon: false,
                        segments: <ButtonSegment<_Range>>[
                          ButtonSegment<_Range>(
                            value: _Range.m3,
                            label: Text(l.range3m),
                          ),
                          ButtonSegment<_Range>(
                            value: _Range.m6,
                            label: Text(l.range6m),
                          ),
                          ButtonSegment<_Range>(
                            value: _Range.y1,
                            label: Text(l.range1y),
                          ),
                          ButtonSegment<_Range>(
                            value: _Range.all,
                            label: Text(l.all),
                          ),
                        ],
                        selected: <_Range>{_range},
                        onSelectionChanged: (Set<_Range> s) {
                          AppHaptics.key();
                          setState(() => _range = s.first);
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _ValueChart(
                        series: d.series,
                        range: _range,
                        place: h.placeType,
                        currency: h.currency,
                        lang: lang,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Row(
                        children: <Widget>[
                          for (final (
                                HoldingEntryKind k,
                                IconData icon,
                                String label,
                              )
                              in <(HoldingEntryKind, IconData, String)>[
                                (
                                  HoldingEntryKind.add,
                                  Icons.add,
                                  l.holdingEntryAdd,
                                ),
                                (
                                  HoldingEntryKind.withdraw,
                                  Icons.remove,
                                  l.holdingEntryWithdraw,
                                ),
                                (
                                  HoldingEntryKind.setValue,
                                  Icons.drag_handle,
                                  l.holdingValueShort,
                                ),
                              ]) ...<Widget>[
                            if (k != HoldingEntryKind.add)
                              const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: FilledButton.tonalIcon(
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.sm,
                                  ),
                                ),
                                onPressed: () => showAdjustSheet(
                                  context,
                                  h,
                                  d.amount,
                                  kind: k,
                                ),
                                icon: Icon(icon, size: 18),
                                label: Text(
                                  label,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(child: SectionHeader(l.holdingHistory)),
              if (d.entries.isEmpty)
                SliverPadding(
                  padding: AppSpacing.screen,
                  sliver: SliverToBoxAdapter(
                    child: Text(
                      l.holdingNoEntries,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                )
              else
                AnimatedDiffSliverList<_Row>(
                  items: _rows(d),
                  keyOf: (_Row r) => switch (r) {
                    _MonthRow(:final DateTime month) =>
                      'm${month.millisecondsSinceEpoch}',
                    _EntryRow(:final HoldingEntry entry) => 'e${entry.id}',
                  },
                  itemBuilder: (BuildContext context, _Row r, int i) =>
                      switch (r) {
                        _MonthRow(:final DateTime month) => _MonthHeader(
                          month: month,
                          lang: lang,
                        ),
                        _EntryRow() => _HistoryTile(
                          row: r,
                          currency: h.currency,
                          account: d.linkedAccounts[r.entry.id],
                          lang: lang,
                        ),
                      },
                ),
              const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxl)),
            ],
          ),
        );
      },
    );
  }
}

class _DepositCard extends StatelessWidget {
  const _DepositCard({
    required this.holding,
    required this.amount,
    required this.lang,
  });

  final Holding holding;
  final int amount;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);
    final int? days = daysToMaturity(holding.maturityDate);
    // Simple interest to maturity, explicitly "approximate".
    final int? interest =
        holding.interestRate != null && days != null && days > 0
        ? (amount * holding.interestRate! / 100 * days / 365).round()
        : null;

    Widget row(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: Text(value, style: theme.textTheme.titleMedium)),
        ],
      ),
    );

    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.md),
      padding: AppSpacing.card,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: AppRadius.brLg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(l.holdingPlaceBankDeposit, style: theme.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.xs),
          if (holding.interestRate != null)
            row(l.holdingInterestRate, '${holding.interestRate} %'),
          if (holding.maturityDate != null)
            row(
              l.holdingMaturityDate,
              days == null || days < 0
                  ? '${Fmt.date(holding.maturityDate!, lang)} · ${l.depositMatured}'
                  : '${Fmt.date(holding.maturityDate!, lang)} · ${l.daysLeft(days)}',
            ),
          if (interest != null)
            row(
              l.estimatedInterest,
              '≈ ${Fmt.money(interest, holding.currency, lang)}',
            ),
        ],
      ),
    );
  }
}

class _ValueChart extends StatefulWidget {
  const _ValueChart({
    required this.series,
    required this.range,
    required this.place,
    required this.currency,
    required this.lang,
  });

  final List<HoldingPoint> series;
  final _Range range;
  final HoldingPlace place;
  final String currency;
  final String lang;

  @override
  State<_ValueChart> createState() => _ValueChartState();
}

class _ValueChartState extends State<_ValueChart> {
  bool _shown = false;

  @override
  void initState() {
    super.initState();
    // First frame draws a flat line; the real one animates in (§11.4).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _shown = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final Color color = HoldingPlaceStyle.forPlace(widget.place)
        .color(AppColors.of(context));
    final DateTime now = DateTime.now();
    final DateTime? from = switch (widget.range) {
      _Range.m3 => DateTime(now.year, now.month - 3, now.day),
      _Range.m6 => DateTime(now.year, now.month - 6, now.day),
      _Range.y1 => DateTime(now.year - 1, now.month, now.day),
      _Range.all => null,
    };

    // Value at the window start, every point inside it, and today.
    final List<HoldingPoint> pts = <HoldingPoint>[];
    int startValue = 0;
    for (final HoldingPoint p in widget.series) {
      if (from != null && p.date.isBefore(from)) {
        startValue = p.amount;
      } else {
        pts.add(p);
      }
    }
    if (from != null &&
        widget.series.isNotEmpty &&
        widget.series.first.date.isBefore(from)) {
      pts.insert(0, (date: from, amount: startValue));
    }
    if (pts.isNotEmpty && pts.last.date.isBefore(now)) {
      pts.add((date: now, amount: pts.last.amount));
    }

    if (pts.length < 2 || widget.series.length < 2) {
      return SizedBox(
        height: 48,
        child: Center(
          child: Text(
            l.chartNeedsTwoPoints,
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    final double x0 = pts.first.date.millisecondsSinceEpoch.toDouble();
    double x(DateTime d) =>
        (d.millisecondsSinceEpoch - x0) / Duration.millisecondsPerDay;
    final double minY = pts
        .map((HoldingPoint p) => p.amount / 100)
        .reduce(math.min);
    final double maxY = pts
        .map((HoldingPoint p) => p.amount / 100)
        .reduce(math.max);
    final double pad = math.max((maxY - minY) * 0.1, 1);
    final DateFormat dayFmt = DateFormat.MMMd(widget.lang);
    final NumberFormat compact = NumberFormat.compact(locale: widget.lang);
    final TextStyle? axis = theme.textTheme.bodySmall?.copyWith(
      color: cs.onSurfaceVariant,
    );

    return SizedBox(
      height: AppSizes.holdingChartHeight,
      child: LineChart(
        LineChartData(
          minY: math.max(0, minY - pad),
          maxY: maxY + pad,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            bottomTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (double v, TitleMeta meta) =>
                    v == meta.min || v == meta.max
                    ? SideTitleWidget(
                        meta: meta,
                        child: Text(compact.format(v), style: axis),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => cs.inverseSurface,
              getTooltipItems: (List<LineBarSpot> spots) => <LineTooltipItem>[
                for (final LineBarSpot s in spots)
                  LineTooltipItem(
                    '${dayFmt.format(DateTime.fromMillisecondsSinceEpoch((x0 + s.x * Duration.millisecondsPerDay).round()))} · '
                    '${Fmt.money((s.y * 100).round(), widget.currency, widget.lang)}',
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
                for (final HoldingPoint p in pts)
                  FlSpot(
                    x(p.date),
                    _shown ? p.amount / 100 : math.max(0, minY - pad),
                  ),
              ],
              isStepLineChart: true,
              color: color,
              barWidth: 2.5,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    color.withValues(alpha: _shown ? 0.24 : 0),
                    color.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ],
        ),
        duration: AppMotion.of(context, AppMotion.chartEntry),
        curve: AppMotion.chartCurve,
      ),
    );
  }
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({required this.month, required this.lang});

  final DateTime month;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.surfaceContainerLow,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Semantics(
        header: true,
        child: Text(
          Fmt.month(month, lang),
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// 56dp history row: kind avatar, signed onSurface amount (never green /
/// red: moving your own money is neither income nor expense).
class _HistoryTile extends StatelessWidget {
  const _HistoryTile({
    required this.row,
    required this.currency,
    required this.account,
    required this.lang,
  });

  final _EntryRow row;
  final String currency;
  final String? account;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);
    final AppColors c = AppColors.of(context);
    final HoldingEntry e = row.entry;
    final String money = Fmt.money(e.amount, currency, lang);
    final (IconData icon, String title, String amount) = switch (e.kind) {
      HoldingEntryKind.add => (
        Icons.add,
        l.holdingAdded,
        '+${Fmt.thinSpace}$money',
      ),
      HoldingEntryKind.withdraw => (
        Icons.remove,
        l.holdingWithdrawn,
        '${Fmt.minus}${Fmt.thinSpace}$money',
      ),
      HoldingEntryKind.setValue => (
        Icons.drag_handle,
        l.holdingValueSet,
        money,
      ),
    };
    final String sub = <String>[
      Fmt.date(e.date, lang),
      if (account != null)
        e.kind == HoldingEntryKind.add
            ? l.fromAccountName(account!)
            : l.toAccountName(account!),
      if (e.kind == HoldingEntryKind.setValue)
        l.holdingBefore(Fmt.money(row.before, currency, lang)),
      if (e.note.trim().isNotEmpty) '«${e.note.trim()}»',
    ].join(' · ');

    return Semantics(
      button: true,
      label: '$title, $amount, $sub',
      excludeSemantics: true,
      child: InkWell(
        onTap: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          builder: (_) => HoldingEntrySheet(entry: e),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: <Widget>[
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: c.holdingContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 18, color: c.onHoldingContainer),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(title, style: theme.textTheme.titleSmall),
                      Text(
                        sub,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  amount,
                  style: AppTextStyles.amountTile.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
