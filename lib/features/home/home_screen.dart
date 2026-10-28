import 'dart:async';

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
import '../settings/exchange_rates_screen.dart';
import '../settings/rate_sync_controller.dart';
import '../settings/settings_controller.dart';
import '../transactions/widgets/tx_tile.dart';
import 'widgets/account_strip.dart';
import 'widgets/balance_card.dart';
import 'widgets/home_cards.dart';

const TxFilter _recentFilter = TxFilter(limit: 5);

/// "Sabahınız xeyir" … by local time (DESIGN.md §13.6).
String greetingFor(AppLocalizations l, DateTime now) {
  final int h = now.hour;
  if (h >= 5 && h < 12) return l.greetingMorning;
  if (h >= 12 && h < 18) return l.greetingAfternoon;
  if (h >= 18 && h < 23) return l.greetingEvening;
  return l.greetingNight;
}

/// Home (DESIGN.md §13): greeting, balance card, week, budgets, holdings,
/// accounts, recent transactions.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  // Recompute the greeting when the app comes back to the foreground.
  late final AppLifecycleListener _life = AppLifecycleListener(
    onResume: () => mounted ? setState(() {}) : null,
  );

  @override
  void dispose() {
    _life.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final AppLocalizations l = AppLocalizations.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final String lang = ref.read(languageProvider);
    AppHaptics.confirm();
    ref
      ..invalidate(dailyExpensesProvider)
      ..invalidate(accountBalancesProvider)
      ..invalidate(holdingsProvider);
    if (!ref.read(rateSyncProvider).enabled) {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      return;
    }
    CbarFailure? f;
    try {
      f = await ref
          .read(rateSyncProvider.notifier)
          .refresh()
          .timeout(const Duration(seconds: 8));
    } on TimeoutException {
      f = CbarFailure.offline;
    }
    final RateSyncState s = ref.read(rateSyncProvider);
    if (f == null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            l.ratesUpdatedAt(Fmt.time(s.fetchedAt ?? DateTime.now(), lang)),
          ),
        ),
      );
    } else if (f == CbarFailure.offline) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            s.bulletinDate == null
                ? l.ratesErrorOffline
                : l.ratesOfflineUsingLast(Fmt.date(s.bulletinDate!, lang)),
          ),
        ),
      );
    } else {
      messenger.showSnackBar(SnackBar(content: Text(rateSyncErrorText(l, f))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final String lang = ref.watch(languageProvider);
    final ThemeData theme = Theme.of(context);
    final AsyncValue<List<TxDetails>> recent = ref.watch(
      transactionsProvider(_recentFilter),
    );
    final DateTime now = DateTime.now();
    final String date = DateFormat('EEEE, d MMMM', lang).format(now);

    Widget section(Widget child, int index) => SliverPadding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.section,
      ),
      sliver: SliverToBoxAdapter(
        child: StaggerIn(index: index, child: child),
      ),
    );

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: <Widget>[
            SliverAppBar.large(title: Text(greetingFor(l, now))),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              sliver: SliverToBoxAdapter(
                child: Text(
                  '${date[0].toUpperCase()}${date.substring(1)}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            section(const BalanceCard(), 0),
            section(const WeekCard(), 1),
            section(const BudgetSummaryCard(), 2),
            SliverToBoxAdapter(
              child: StaggerIn(
                index: 3,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  child: Column(
                    children: <Widget>[
                      const HoldingsCard(),
                      // Keep the 24dp rhythm only when the card is shown.
                      if ((ref.watch(holdingsProvider).value ??
                              const <HoldingWithValue>[])
                          .isNotEmpty)
                        const SizedBox(height: AppSpacing.section),
                    ],
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: AccountStrip()),
            SliverToBoxAdapter(
              child: SectionHeader(
                l.recentTransactions,
                trailing: TextButton(
                  onPressed: () => context.go(Routes.transactions),
                  child: Text(l.seeAll),
                ),
              ),
            ),
            ...recent.when(
              data: (List<TxDetails> items) => items.isEmpty
                  ? <Widget>[
                      SliverToBoxAdapter(
                        child: EmptyState(
                          icon: Icons.receipt_long,
                          title: l.emptyTransactionsTitle,
                          body: l.emptyTransactionsBody,
                          actionLabel: l.addTransaction,
                          onAction: () => context.push(Routes.newTransaction()),
                        ),
                      ),
                    ]
                  : <Widget>[
                      AnimatedDiffSliverList<TxDetails>(
                        items: items,
                        keyOf: (TxDetails t) => t.tx.id,
                        itemBuilder:
                            (BuildContext context, TxDetails t, int i) =>
                                TxTile(
                                  item: t,
                                  onTap: () => context.push(
                                    Routes.editTransaction(t.tx.id),
                                  ),
                                ),
                      ),
                    ],
              loading: () => const <Widget>[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.xxl),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
              ],
              error: (Object e, _) => <Widget>[
                SliverToBoxAdapter(child: Center(child: Text(l.genericError))),
              ],
            ),
            // Room for the FAB.
            const SliverToBoxAdapter(child: SizedBox(height: 96)),
          ],
        ),
      ),
    );
  }
}
