import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router.dart';
import '../../core/theme.dart';
import '../../l10n/app_localizations.dart';

/// Bottom navigation scaffold for the five tabs (DESIGN.md §6.8).
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final int index = navigationShell.currentIndex;
    final bool showFab = index == 0 || index == 1;

    return Scaffold(
      body: _FadeThroughOnTab(index: index, child: navigationShell),
      floatingActionButton: showFab
          ? FloatingActionButton(
              tooltip: l.addTransaction,
              onPressed: () => context.push(Routes.newTransaction()),
              child: const Icon(Icons.add),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (int i) {
          AppHaptics.key();
          navigationShell.goBranch(i, initialLocation: i == index);
        },
        destinations: <NavigationDestination>[
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: l.navHome,
          ),
          NavigationDestination(
            icon: const Icon(Icons.receipt_long_outlined),
            selectedIcon: const Icon(Icons.receipt_long),
            label: l.navTransactions,
          ),
          NavigationDestination(
            icon: const Icon(Icons.pie_chart_outline),
            selectedIcon: const Icon(Icons.pie_chart),
            label: l.navReports,
          ),
          NavigationDestination(
            icon: const Icon(Icons.savings_outlined),
            selectedIcon: const Icon(Icons.savings),
            label: l.navBudgets,
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings),
            label: l.navSettings,
          ),
        ],
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
