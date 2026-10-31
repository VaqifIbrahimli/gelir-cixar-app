import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router.dart';
import '../../../core/theme.dart';
import '../../../data/providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../accounts/widgets/account_card.dart';
import '../../settings/settings_controller.dart';
import '../../transactions/tx_filter_controller.dart';
import 'totals_card.dart';

/// Home card carousel (DESIGN.md §18.1): the totals card, one card per
/// active account, then an "add account" card; dots and "Hamısı ›" below.
class HomeCardCarousel extends ConsumerStatefulWidget {
  const HomeCardCarousel({super.key});

  @override
  ConsumerState<HomeCardCarousel> createState() => _HomeCardCarouselState();
}

class _HomeCardCarouselState extends ConsumerState<HomeCardCarousel> {
  late final PageController _pc = PageController(viewportFraction: AppCarousel.viewportFraction);
  int _page = 0;

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  Future<void> _addAccount(List<AccountWithBalance> before) async {
    final int? id = await context.push<int>(Routes.newAccount);
    if (id == null || !mounted) return;
    // Its card appears once the stream emits; then animate to it.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    if (!mounted || !_pc.hasClients) return;
    final List<AccountWithBalance> list =
        ref.read(accountBalancesProvider).value ?? const <AccountWithBalance>[];
    final int i = list.indexWhere((AccountWithBalance a) => a.account.id == id);
    if (i >= 0) _goTo(i + 1);
  }

  void _goTo(int page) {
    if (AppMotion.reduced(context)) {
      _pc.jumpToPage(page);
    } else {
      _pc.animateToPage(page, duration: AppMotion.carouselPage, curve: AppMotion.emphasized);
    }
  }

  void _openAccount(Account a) {
    ref.read(txFilterProvider.notifier).apply(TxFilter(accountId: a.id));
    context.go(Routes.transactions);
  }

  Future<void> _actions(Account a) async {
    final AppLocalizations l = AppLocalizations.of(context);
    AppHaptics.longPress();
    final String? v = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.add),
              title: Text(l.addTransaction),
              onTap: () => Navigator.of(ctx).pop('add'),
            ),
            ListTile(
              leading: const Icon(Icons.swap_horiz),
              title: Text(l.makeTransfer),
              onTap: () => Navigator.of(ctx).pop('transfer'),
            ),
            ListTile(
              leading: const Icon(Icons.style_outlined),
              title: Text(l.cardChangeDesign),
              onTap: () => Navigator.of(ctx).pop('edit'),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text(l.edit),
              onTap: () => Navigator.of(ctx).pop('edit'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || v == null) return;
    switch (v) {
      case 'add':
        context.push(Routes.newTransaction(TxType.expense, a.id));
      case 'transfer':
        context.push(Routes.newTransaction(TxType.transfer, a.id));
      default:
        context.push(Routes.editAccount(a.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final List<AccountWithBalance> accounts =
        ref.watch(accountBalancesProvider).value ?? const <AccountWithBalance>[];
    final bool hidden = ref.watch(settingsProvider).hideBalance;
    final int pages = accounts.length + 2;
    if (_page >= pages) _page = pages - 1;
    final bool reduced = AppMotion.reduced(context);

    return LayoutBuilder(builder: (BuildContext context, BoxConstraints c) {
      final double w = c.maxWidth;
      final double h = AppCarousel.height(w, MediaQuery.textScalerOf(context));

      Widget page(int i) {
        final Widget card;
        if (i == 0) {
          card = const TotalsCard();
        } else if (i == pages - 1) {
          card = _AddAccountCard(label: l.addAccount, onTap: () => _addAccount(accounts));
        } else {
          final AccountWithBalance a = accounts[i - 1];
          card = AccountCardView(
            account: a.account,
            balance: a.balance,
            masked: hidden,
            countUpId: 'home.card.${a.account.id}',
            positionLabel: l.cardPosition(i + 1, pages),
            onTap: () => _openAccount(a.account),
            onLongPress: () => _actions(a.account),
          );
        }
        return AnimatedBuilder(
          animation: _pc,
          builder: (BuildContext context, Widget? child) {
            double scale = 1;
            if (!reduced && _pc.hasClients && _pc.position.haveDimensions) {
              final double d = ((_pc.page ?? _page.toDouble()) - i).abs();
              scale = math.max(AppCarousel.inactiveScale, 1 - 0.06 * d);
            }
            return Transform.scale(scale: scale, child: child);
          },
          child: Padding(
            padding: const EdgeInsets.only(left: AppCarousel.pageInset),
            child: card,
          ),
        );
      }

      return Column(
        children: <Widget>[
          SizedBox(
            height: h,
            child: PageView.builder(
              key: const PageStorageKey<String>('home.cards'),
              controller: _pc,
              padEnds: false,
              itemCount: pages,
              onPageChanged: (int p) {
                AppHaptics.key();
                setState(() => _page = p);
              },
              itemBuilder: (BuildContext context, int i) => page(i),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppCarousel.dotsTop - 8, AppSpacing.sm, 0),
            child: Row(
              children: <Widget>[
                ExcludeSemantics(child: _Dots(count: pages, current: _page, onTap: _goTo)),
                const Spacer(),
                TextButton(
                  onPressed: () => context.push(Routes.accounts),
                  child: Text('${l.seeAll} ›'),
                ),
              ],
            ),
          ),
        ],
      );
    });
  }
}

class _AddAccountCard extends StatelessWidget {
  const _AddAccountCard({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    return Material(
      color: cs.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.brCard,
        side: BorderSide(color: cs.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.add_circle_outline, size: 32, color: cs.primary),
              const SizedBox(height: AppSpacing.sm),
              Text(label, style: theme.textTheme.titleMedium?.copyWith(color: cs.primary)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Page dots (DESIGN.md §18.1.2): at most 7, the active one a pill; when
/// the strip scrolls the outer dots shrink so the user sees there is more.
class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.current, required this.onTap});

  final int count;
  final int current;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    const int max = AppCarousel.maxVisibleDots;
    final int first = count <= max ? 0 : (current - max ~/ 2).clamp(0, count - max);
    final int last = math.min(count, first + max);
    final Duration d = AppMotion.of(context, AppMotion.state);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (int i = first; i < last; i++)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onTap(i),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppCarousel.dotGap / 2, vertical: 12),
              child: Transform.scale(
                scale: () {
                  if (count <= max) return 1.0;
                  final bool moreLeft = first > 0;
                  final bool moreRight = last < count;
                  if ((i == first && moreLeft) || (i == last - 1 && moreRight)) return AppCarousel.dotEdgeScale2;
                  if ((i == first + 1 && moreLeft) || (i == last - 2 && moreRight)) {
                    return AppCarousel.dotEdgeScale1;
                  }
                  return 1.0;
                }(),
                child: AnimatedContainer(
                  duration: d,
                  curve: AppMotion.standard,
                  width: i == current ? AppCarousel.dotActive : AppCarousel.dot,
                  height: AppCarousel.dot,
                  decoration: BoxDecoration(
                    color: i == current ? cs.primary : cs.onSurfaceVariant.withValues(alpha: 0.38),
                    borderRadius: AppRadius.brFull,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
