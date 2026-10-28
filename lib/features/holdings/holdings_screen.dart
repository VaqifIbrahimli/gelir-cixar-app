import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/motion.dart';
import '../../core/router.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';
import '../settings/settings_controller.dart';
import 'holding_sheets.dart';

/// "Kənar yerlər" list (DESIGN.md §14.3): total, stacked bar by place type,
/// groups in place order, archived and long-idle zero holdings folded away.
class HoldingsScreen extends ConsumerWidget {
  const HoldingsScreen({super.key});

  /// Zero-value holdings untouched this long fold into "Sıfır qalıqlılar".
  static const Duration idleZero = Duration(days: 90);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l = AppLocalizations.of(context);
    final String lang = ref.watch(languageProvider);
    final AsyncValue<List<HoldingWithValue>> data = ref.watch(
      allHoldingsProvider,
    );
    final NetWorth? worth = ref.watch(netWorthProvider).value;
    final ThemeData theme = Theme.of(context);
    final AppColors c = AppColors.of(context);

    return Scaffold(
      body: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, _) => Center(child: Text(l.genericError)),
        data: (List<HoldingWithValue> all) {
          final DateTime now = DateTime.now();
          bool idle(HoldingWithValue h) =>
              h.amount == 0 &&
              h.lastChange != null &&
              now.difference(h.lastChange!) > idleZero;
          final List<HoldingWithValue> active =
              all
                  .where(
                    (HoldingWithValue h) => !h.holding.isArchived && !idle(h),
                  )
                  .toList()
                ..sort(
                  (HoldingWithValue a, HoldingWithValue b) =>
                      b.azn.compareTo(a.azn),
                );
          final List<HoldingWithValue> zero = all
              .where((HoldingWithValue h) => !h.holding.isArchived && idle(h))
              .toList();
          final List<HoldingWithValue> archived = all
              .where((HoldingWithValue h) => h.holding.isArchived)
              .toList();
          final int total = active.fold(
            0,
            (int s, HoldingWithValue h) => s + h.azn,
          );
          final List<HoldingPlace> places = HoldingPlace.values.toList()
            ..sort(
              (HoldingPlace a, HoldingPlace b) =>
                  HoldingPlaceStyle.forPlace(a).order
                      .compareTo(HoldingPlaceStyle.forPlace(b).order),
            );

          return CustomScrollView(
            slivers: <Widget>[
              SliverAppBar.medium(
                title: Text(l.holdings),
                actions: <Widget>[
                  IconButton(
                    tooltip: l.addHolding,
                    icon: const Icon(Icons.add),
                    onPressed: () => context.push(Routes.newHolding),
                  ),
                ],
              ),
              if (all.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyHoldings(
                    onAdd: () => context.push(Routes.newHolding),
                  ),
                )
              else ...<Widget>[
                SliverPadding(
                  padding: AppSpacing.screen,
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          l.total,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        CountUpAmount(
                          id: 'holdings.total',
                          value: total,
                          format: (int v) => Fmt.base(v, lang),
                          semanticsPrefix: l.holdingsElsewhere,
                          style:
                              (theme.textTheme.headlineSmall ??
                                      const TextStyle())
                                  .merge(AppTextStyles.tabular)
                                  .copyWith(color: c.holding),
                        ),
                        Text(
                          <String>[
                            if (worth != null && worth.total > 0)
                              l.holdingsShareOfNetWorth(
                                (total * 100 / worth.total).round(),
                              ),
                            l.holdingsPlaceCount(active.length),
                          ].join(' · '),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        if (total > 0)
                          _StackedBar(holdings: active, total: total),
                      ],
                    ),
                  ),
                ),
                for (final HoldingPlace place in places)
                  if (active.any(
                    (HoldingWithValue h) => h.holding.placeType == place,
                  ))
                    _Group(
                      title: holdingPlaceLabel(l, place),
                      total: active
                          .where(
                            (HoldingWithValue h) =>
                                h.holding.placeType == place,
                          )
                          .fold(0, (int s, HoldingWithValue h) => s + h.azn),
                      items: active
                          .where(
                            (HoldingWithValue h) =>
                                h.holding.placeType == place,
                          )
                          .toList(),
                      lang: lang,
                    ),
                if (zero.isNotEmpty)
                  SliverToBoxAdapter(
                    child: ExpansionTile(
                      title: Text(l.holdingsZeroGroup(zero.length)),
                      children: <Widget>[
                        for (final HoldingWithValue h in zero)
                          HoldingTile(item: h),
                      ],
                    ),
                  ),
                if (archived.isNotEmpty)
                  SliverToBoxAdapter(
                    child: ExpansionTile(
                      title: Text(l.archivedCount(archived.length)),
                      children: <Widget>[
                        for (final HoldingWithValue h in archived)
                          HoldingTile(item: h),
                      ],
                    ),
                  ),
                const SliverToBoxAdapter(
                  child: SizedBox(height: AppSpacing.xxl),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _EmptyHoldings extends StatelessWidget {
  const _EmptyHoldings({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final AppColors c = AppColors.of(context);
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Container(
            width: AppSizes.emptyStateIconCircle,
            height: AppSizes.emptyStateIconCircle,
            decoration: BoxDecoration(
              color: c.holdingContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              HoldingPlaceStyle.featureIcon,
              size: 48,
              color: c.onHoldingContainer,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            l.emptyHoldingsTitle,
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280),
            child: Text(
              l.emptyHoldingsBody,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          FilledButton.tonal(onPressed: onAdd, child: Text(l.addHolding)),
        ],
      ),
    );
  }
}

/// 8dp bar split by place type, 2dp gaps (DESIGN.md §14.3).
class _StackedBar extends StatelessWidget {
  const _StackedBar({required this.holdings, required this.total});

  final List<HoldingWithValue> holdings;
  final int total;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final AppColors c = AppColors.of(context);
    final Map<HoldingPlace, int> byPlace = <HoldingPlace, int>{};
    for (final HoldingWithValue h in holdings) {
      byPlace[h.holding.placeType] =
          (byPlace[h.holding.placeType] ?? 0) + h.azn;
    }
    final List<MapEntry<HoldingPlace, int>> parts =
        byPlace.entries
            .where((MapEntry<HoldingPlace, int> e) => e.value > 0)
            .toList()
          ..sort(
            (MapEntry<HoldingPlace, int> a, MapEntry<HoldingPlace, int> b) =>
                HoldingPlaceStyle.forPlace(a.key).order
                    .compareTo(HoldingPlaceStyle.forPlace(b.key).order),
          );
    return Semantics(
      label: <String>[
        for (final MapEntry<HoldingPlace, int> e in parts)
          '${holdingPlaceLabel(l, e.key)} ${(e.value * 100 / total).round()}%',
      ].join(', '),
      excludeSemantics: true,
      child: ClipRRect(
        borderRadius: AppRadius.brXs,
        child: SizedBox(
          height: AppSizes.progressHeight,
          child: Row(
            children: <Widget>[
              for (int i = 0; i < parts.length; i++) ...<Widget>[
                if (i > 0) const SizedBox(width: 2),
                Expanded(
                  flex: (parts[i].value * 1000 ~/ total).clamp(1, 1000),
                  child: ColoredBox(
                    color: HoldingPlaceStyle.forPlace(parts[i].key).color(c),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({
    required this.title,
    required this.total,
    required this.items,
    required this.lang,
  });

  final String title;
  final int total;
  final List<HoldingWithValue> items;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextStyle? head = theme.textTheme.titleSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.lg,
        0,
      ),
      sliver: SliverToBoxAdapter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(title.toUpperCase(), style: head),
                    ),
                  ),
                  Text(
                    Fmt.base(total, lang),
                    style: head?.merge(AppTextStyles.tabular),
                  ),
                ],
              ),
            ),
            Material(
              color: theme.colorScheme.surfaceContainerLow,
              borderRadius: AppRadius.brMd,
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: <Widget>[
                  for (int i = 0; i < items.length; i++)
                    StaggerIn(
                      index: i,
                      child: HoldingTile(item: items[i]),
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

/// 64dp holding row: place avatar, name, subtitle (deposit info, note or
/// "updated N days ago"), amount and "≈ AZN" for foreign currencies.
class HoldingTile extends ConsumerWidget {
  const HoldingTile({super.key, required this.item});

  final HoldingWithValue item;

  Future<void> _menu(BuildContext context, WidgetRef ref) async {
    final AppLocalizations l = AppLocalizations.of(context);
    AppHaptics.longPress();
    final String? v = await showModalBottomSheet<String>(
      context: context,
      builder: (BuildContext ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text(l.edit),
              onTap: () => Navigator.of(ctx).pop('edit'),
            ),
            ListTile(
              leading: const Icon(Icons.tune),
              title: Text(l.holdingAdjust),
              onTap: () => Navigator.of(ctx).pop('adjust'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: Text(l.delete),
              onTap: () => Navigator.of(ctx).pop('delete'),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted || v == null) return;
    switch (v) {
      case 'edit':
        context.push(Routes.editHolding(item.holding.id));
      case 'adjust':
        showAdjustSheet(context, item.holding, item.amount);
      case 'delete':
        await deleteHoldingFlow(context, ref, item.holding);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l = AppLocalizations.of(context);
    final String lang = ref.watch(languageProvider);
    final ThemeData theme = Theme.of(context);
    final AppColors c = AppColors.of(context);
    final Holding h = item.holding;
    final bool foreign = h.currency != Currency.base.code;
    final int? days = h.placeType == HoldingPlace.bankDeposit
        ? daysToMaturity(h.maturityDate)
        : null;

    final String subtitle;
    if (h.placeType == HoldingPlace.bankDeposit &&
        (h.interestRate != null || days != null)) {
      subtitle = <String>[
        if (h.interestRate != null) '${_rate(h.interestRate!, lang)} %',
        if (days != null) days < 0 ? l.depositMatured : l.daysLeft(days),
      ].join(' · ');
    } else if (h.isArchived) {
      subtitle = l.archived;
    } else if (h.note.trim().isNotEmpty) {
      subtitle = h.note.trim();
    } else {
      subtitle = item.lastChange == null ? '' : _ago(l, item.lastChange!);
    }

    return PressScale(
      child: InkWell(
        onTap: () => context.push(Routes.holding(h.id)),
        onLongPress: () => _menu(context, ref),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSizes.tileMinHeight),
          child: Padding(
            padding: AppSpacing.tile,
            child: Row(
              children: <Widget>[
                PlaceAvatar(place: h.placeType),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        h.name,
                        style: theme.textTheme.titleMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (subtitle.isNotEmpty)
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Text(
                      Fmt.money(item.amount, h.currency, lang),
                      style: AppTextStyles.amountTile.copyWith(
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    if (foreign)
                      Text(
                        '≈ ${Fmt.base(item.azn, lang)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    if (days != null && days <= 30)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Icon(
                          Icons.alarm,
                          size: 16,
                          color: days < 0 ? c.danger : c.warning,
                          semanticLabel: days < 0
                              ? l.depositMatured
                              : l.daysLeft(days),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _rate(double r, String lang) {
    final String s = r == r.roundToDouble()
        ? r.toStringAsFixed(0)
        : r.toString();
    return lang == 'en' ? s : s.replaceAll('.', ',');
  }

  static String _ago(AppLocalizations l, DateTime t) {
    final int d = DateTime.now().difference(t).inDays;
    return d <= 0 ? l.updatedToday : l.updatedDaysAgo(d);
  }
}
