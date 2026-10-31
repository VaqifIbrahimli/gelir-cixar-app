import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemNavigator;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router.dart';
import '../../core/theme.dart';
import '../../l10n/app_localizations.dart';
import '../settings/settings_controller.dart';
import 'floating_nav.dart';

/// Shell for the tabs (DESIGN.md §18.3): floating pill navigation with the
/// "+" on every tab, and double-back-to-exit on Home (§18.9).
///
/// The [StatefulShellRoute] always has five branches (home, transactions,
/// reports, budgets, settings); with budgets off the Budgets tab is simply
/// not shown, so no other branch is re-created.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  /// Branch index of the Budgets tab.
  static const int budgetsBranch = 3;

  /// Visible branch indices, left to right.
  static List<int> visibleBranches({required bool budgets}) =>
      budgets ? const <int>[0, 1, 2, 3, 4] : const <int>[0, 1, 2, 4];

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  /// Time of the first back press on Home, while the exit window is open.
  DateTime? _firstBack;

  /// Back with nothing to pop (no pushed route, sheet or dialog: those are
  /// routes above this one and pop first). The lock overlay never gets
  /// here: LockBackInterceptor consumes back while locked.
  void _onBack() {
    final StatefulNavigationShell shell = widget.navigationShell;
    if (shell.currentIndex != 0) {
      _firstBack = null;
      shell.goBranch(0);
      return;
    }
    final DateTime now = DateTime.now();
    final DateTime? first = _firstBack;
    if (first != null && now.difference(first) <= AppMotion.backExitWindow) {
      _firstBack = null;
      SystemNavigator.pop();
      return;
    }
    _firstBack = now;
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(
      content: Text(AppLocalizations.of(context).pressBackAgainToExit),
      duration: AppMotion.backExitWindow,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final StatefulNavigationShell shell = widget.navigationShell;
    final bool budgets = ref.watch(settingsProvider.select((AppSettings s) => s.budgetsEnabled));

    // Switching budgets off while on the Budgets tab goes Home.
    ref.listen<bool>(settingsProvider.select((AppSettings s) => s.budgetsEnabled), (bool? was, bool now) {
      if (!now && widget.navigationShell.currentIndex == AppShell.budgetsBranch) {
        widget.navigationShell.goBranch(0);
      }
    });

    final List<int> branches = AppShell.visibleBranches(budgets: budgets);
    final int current = shell.currentIndex;
    final int selected = branches.indexOf(current).clamp(0, branches.length - 1);

    final Map<int, AppNavItem> all = <int, AppNavItem>{
      0: AppNavItem(icon: Icons.home_outlined, selectedIcon: Icons.home, label: l.navHome),
      1: AppNavItem(
        icon: Icons.receipt_long_outlined,
        selectedIcon: Icons.receipt_long,
        label: l.navTransactions,
      ),
      2: AppNavItem(icon: Icons.pie_chart_outline, selectedIcon: Icons.pie_chart, label: l.navReports),
      3: AppNavItem(icon: Icons.savings_outlined, selectedIcon: Icons.savings, label: l.navBudgets),
      4: AppNavItem(icon: Icons.settings_outlined, selectedIcon: Icons.settings, label: l.navSettings),
    };

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) _onBack();
      },
      child: Scaffold(
        extendBody: true,
        body: _FadeThroughOnTab(index: current, child: shell),
        bottomNavigationBar: AppFloatingNav(
          items: <AppNavItem>[for (final int b in branches) all[b]!],
          selectedIndex: selected,
          addTooltip: l.addTransaction,
          onAdd: () => context.push(Routes.newTransaction()),
          onSelected: (int i) {
            final int branch = branches[i];
            _firstBack = null;
            shell.goBranch(branch, initialLocation: branch == current);
          },
        ),
      ),
    );
  }
}

/// Fade through between tabs (DESIGN.md §11.2). The navigation shell keeps
/// one widget (and its branch navigators), so instead of an AnimatedSwitcher
/// the same child replays an opacity + scale 0.92 → 1 entrance whenever the
/// tab index changes. Instant under reduced motion.
class _FadeThroughOnTab extends StatefulWidget {
  const _FadeThroughOnTab({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  State<_FadeThroughOnTab> createState() => _FadeThroughOnTabState();
}

class _FadeThroughOnTabState extends State<_FadeThroughOnTab> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: AppMotion.fadeThroughDuration, value: 1);

  @override
  void didUpdateWidget(_FadeThroughOnTab old) {
    super.didUpdateWidget(old);
    if (old.index != widget.index && !AppMotion.reduced(context)) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppMotion.fadeThrough(widget.child, _c);
}
