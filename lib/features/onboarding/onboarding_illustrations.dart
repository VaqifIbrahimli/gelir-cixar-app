// Onboarding illustrations (DESIGN.md §15.3): code only, no image assets.
// Every colour comes from the theme, so they follow the seed / wallpaper.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// Shared 240dp frame: a 200dp primaryContainer disc, floating shapes, and
/// the page's main drawing. Enters with scale 0.9 → 1, the floats settle
/// 12dp → 0 with a 40ms stagger. Static under reduced motion.
class IllustrationFrame extends StatelessWidget {
  const IllustrationFrame({
    super.key,
    required this.main,
    this.floats = const <Widget>[],
  });

  final Widget main;

  /// Positioned children (small floating shapes).
  final List<Widget> floats;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final bool reduced = AppMotion.reduced(context);
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: AppSizes.onboardingIllustration,
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: reduced ? 1 : 0, end: 1),
          duration: AppMotion.of(context, AppMotion.onboardingPage),
          curve: AppMotion.enter,
          builder: (BuildContext context, double t, _) => Stack(
            alignment: Alignment.center,
            children: <Widget>[
              Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  shape: BoxShape.circle,
                ),
              ),
              Transform.scale(scale: 0.9 + 0.1 * t, child: main),
              for (int i = 0; i < floats.length; i++)
                _Float(
                  // 40ms stagger expressed as a later start within the tween.
                  t: ((t * 1.3) - i * 0.1).clamp(0.0, 1.0),
                  child: floats[i],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Float extends StatelessWidget {
  const _Float({required this.t, required this.child});

  final double t;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final Positioned p = child as Positioned;
    return Positioned(
      left: p.left,
      top: p.top == null ? null : p.top! + 12 * (1 - t),
      right: p.right,
      bottom: p.bottom,
      child: Opacity(opacity: t, child: p.child),
    );
  }
}

Widget _chip(Color bg, Color fg, IconData icon) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
  decoration: BoxDecoration(color: bg, borderRadius: AppRadius.brFull),
  child: Icon(icon, size: 18, color: fg),
);

/// 1: a phone with three ledger rows, a "+" FAB and in / out chips.
class LedgerIllustration extends StatelessWidget {
  const LedgerIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final AppColors c = AppColors.of(context);
    Widget row(int color) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: <Widget>[
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: c.category(color),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 8,
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: AppRadius.brXs,
              ),
            ),
          ),
        ],
      ),
    );
    return IllustrationFrame(
      main: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Container(
            width: 120,
            height: 168,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cs.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(20),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: cs.shadow.withValues(alpha: 0.15),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(children: <Widget>[row(1), row(0), row(2)]),
          ),
          Positioned(
            right: -14,
            bottom: -14,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: cs.primary,
                borderRadius: AppRadius.brMd,
              ),
              child: Icon(Icons.add, color: cs.onPrimary),
            ),
          ),
        ],
      ),
      floats: <Widget>[
        Positioned(
          left: 8,
          top: 28,
          child: _chip(
            c.incomeContainer,
            c.onIncomeContainer,
            Icons.south_west,
          ),
        ),
        Positioned(
          right: 8,
          top: 44,
          child: _chip(
            c.expenseContainer,
            c.onExpenseContainer,
            Icons.north_east,
          ),
        ),
      ],
    );
  }
}

/// 2: three budget bars (45 % / 82 % ⚠ / 100 % ⛔) under a savings badge.
class BudgetIllustration extends StatelessWidget {
  const BudgetIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final AppColors c = AppColors.of(context);
    Widget bar(double v, Color fill, IconData? icon) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 160,
            height: 10,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(5),
            ),
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: v,
              child: Container(
                decoration: BoxDecoration(
                  color: fill,
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          SizedBox(
            width: 18,
            child: icon == null ? null : Icon(icon, size: 18, color: fill),
          ),
        ],
      ),
    );
    return IllustrationFrame(
      main: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: cs.surfaceContainerLowest,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.savings, size: 40, color: cs.primary),
          ),
          const SizedBox(height: 12),
          bar(0.45, cs.primary, null),
          bar(0.82, c.warningFill, Icons.warning_amber),
          bar(1, c.danger, Icons.block),
        ],
      ),
      floats: <Widget>[
        Positioned(
          left: 16,
          top: 20,
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: cs.tertiaryContainer,
              shape: BoxShape.circle,
            ),
          ),
        ),
        Positioned(
          right: 20,
          top: 36,
          child: Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: cs.secondaryContainer,
              borderRadius: AppRadius.brXs,
            ),
          ),
        ),
      ],
    );
  }
}

/// 3: three fanned place-type tiles with a Σ badge.
class NetWorthIllustration extends StatelessWidget {
  const NetWorthIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    Widget tile(HoldingPlaceStyle st, IconData icon, double deg) =>
        Transform.rotate(
          angle: deg * math.pi / 180,
          child: Container(
            width: 64,
            height: 64,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: st.color(c),
              borderRadius: AppRadius.brLg,
            ),
            child: Icon(icon, color: Colors.white, size: 32),
          ),
        );
    return IllustrationFrame(
      main: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: <Widget>[
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              tile(HoldingPlaceStyle.homeCash, Icons.cottage, -8),
              tile(HoldingPlaceStyle.bankDeposit, Icons.account_balance, 0),
              tile(HoldingPlaceStyle.gold, Icons.diamond, 8),
            ],
          ),
          Positioned(
            top: -40,
            child: Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: c.holding,
                shape: BoxShape.circle,
              ),
              child: Text(
                'Σ',
                style: TextStyle(
                  color: c.onHolding,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
