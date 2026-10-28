// Gəlir-Çıxar: Material 3 theme.
//
// Design source of truth: docs/DESIGN.md (v1.0 §1–8, v1.1 §9–17).
// Flutter SDK only. This file does NOT import dynamic_color: callers pass the
// wallpaper scheme in as a plain `ColorScheme?`.
//
// Usage (v1.0, still valid):
//   MaterialApp(theme: AppTheme.light, darkTheme: AppTheme.dark, ...);
//
// Usage (v1.1, Material You):
//   DynamicColorBuilder(builder: (ColorScheme? light, ColorScheme? dark) {
//     final AppSeed seed = AppSeed.fromId(settings.seedId);
//     final bool useDyn = settings.useDynamicColor;
//     return MaterialApp(
//       theme: AppTheme.build(Brightness.light,
//           seed: seed, dynamicScheme: useDyn ? light : null),
//       darkTheme: AppTheme.build(Brightness.dark,
//           seed: seed, dynamicScheme: useDyn ? dark : null),
//     );
//   });
//
//   final c = AppColors.of(context);   // income / expense / holdings / ...

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ---------------------------------------------------------------------------
// Tokens
// ---------------------------------------------------------------------------

/// 4dp-grid spacing tokens.
abstract final class AppSpacing {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;

  /// Horizontal screen gutter.
  static const double gutter = lg;

  static const EdgeInsets screen = EdgeInsets.symmetric(horizontal: gutter);
  static const EdgeInsets card = EdgeInsets.all(lg);
  static const EdgeInsets tile =
      EdgeInsets.symmetric(horizontal: lg, vertical: md);

  /// v1.1: gap between Home cards.
  static const double section = xl;
}

/// Corner radius tokens.
abstract final class AppRadius {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double sheet = 28;
  static const double full = 999;

  static const BorderRadius brXs = BorderRadius.all(Radius.circular(xs));
  static const BorderRadius brSm = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius brMd = BorderRadius.all(Radius.circular(md));
  static const BorderRadius brLg = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius brXl = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius brFull = BorderRadius.all(Radius.circular(full));
  static const BorderRadius brSheetTop =
      BorderRadius.vertical(top: Radius.circular(sheet));

  /// v1.1: rounded top of a chart bar.
  static const BorderRadius brBarTop =
      BorderRadius.vertical(top: Radius.circular(xs));
}

/// Component size tokens.
abstract final class AppSizes {
  static const double minTouch = 48;
  static const double tileMinHeight = 64;
  static const double categoryAvatar = 40;
  static const double categoryPickerAvatar = 48;
  static const double keypadKeyHeight = 64;
  static const double pinKey = 72;
  static const double pinDot = 14;
  static const double progressHeight = 8;
  static const double fab = 56;
  static const double navBarHeight = 80;
  static const double emptyStateIconCircle = 96;

  // ---- v1.1 ----
  /// Home weekly spending mini chart: plot height (labels excluded).
  static const double weekChartHeight = 72;

  /// Bar width in the weekly mini chart.
  static const double weekBarWidth = 14;

  /// Holdings detail line chart height.
  static const double holdingChartHeight = 160;

  /// Square box of an onboarding illustration.
  static const double onboardingIllustration = 240;

  /// Onboarding page indicator dot (inactive); the active one is a pill.
  static const double onboardingDot = 8;
  static const double onboardingDotActive = 24;

  /// Seed colour swatch in the theme picker.
  static const double seedSwatch = 48;

  /// Place-type avatar in holdings lists (same as category avatar).
  static const double holdingAvatar = 40;
}

/// Motion durations (v1.0). Use [AppDurations.of] to respect reduced motion.
/// v1.1 adds the richer [AppMotion] token set; these stay as aliases.
abstract final class AppDurations {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 600);

  static Duration of(BuildContext context, Duration d) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : d;
}

/// v1.1 motion tokens (DESIGN.md §11). Durations follow the M3 scale; the
/// semantic tokens below are what screens should use.
abstract final class AppMotion {
  // ---- M3 duration scale ----
  static const Duration short2 = Duration(milliseconds: 100);
  static const Duration short3 = Duration(milliseconds: 150);
  static const Duration short4 = Duration(milliseconds: 200);
  static const Duration medium1 = Duration(milliseconds: 250);
  static const Duration medium2 = Duration(milliseconds: 300);
  static const Duration medium4 = Duration(milliseconds: 400);
  static const Duration long2 = Duration(milliseconds: 500);
  static const Duration long4 = Duration(milliseconds: 700);
  static const Duration extraLong1 = Duration(milliseconds: 800);

  // ---- semantic durations ----
  /// Push / pop between screens (shared axis X).
  static const Duration page = medium2;

  /// Bottom-nav tab switch and content swaps (fade through).
  static const Duration fadeThroughDuration = medium2;

  /// Count-up of balance numbers.
  static const Duration countUp = extraLong1;

  /// Chart entry (bars grow, line draws, donut sweeps).
  static const Duration chartEntry = long4;

  /// Chart value change after a filter / period change.
  static const Duration chartUpdate = medium4;

  /// Progress bar fill (budget rows).
  static const Duration progress = AppDurations.slow;

  /// Animated list insert / remove.
  static const Duration listInsert = medium2;
  static const Duration listRemove = short4;

  /// Delay between staggered items (first 6 items only).
  static const Duration stagger = Duration(milliseconds: 30);

  /// Press-down scale and the release back to rest.
  static const Duration pressDown = short2;
  static const Duration pressUp = short4;

  /// Colour / state changes (chips, toggles, PIN dots).
  static const Duration state = short3;

  /// Wrong-PIN and invalid-amount shake.
  static const Duration shake = medium2;

  /// Onboarding page change and illustration settle.
  static const Duration onboardingPage = long2;

  // ---- curves ----
  static const Curve standard = Easing.standard;
  static const Curve enter = Easing.emphasizedDecelerate;
  static const Curve exit = Easing.emphasizedAccelerate;
  static const Curve emphasized = Curves.easeInOutCubicEmphasized;
  static const Curve countUpCurve = Curves.easeOutCubic;
  static const Curve chartCurve = Curves.easeOutCubic;

  // ---- press feedback ----
  /// Scale while pressed: cards / tiles.
  static const double pressScaleCard = 0.97;

  /// Scale while pressed: keypad and PIN keys.
  static const double pressScaleKey = 0.92;

  /// Horizontal travel of the shared-axis transition.
  static const double sharedAxisDistance = 30;

  // ---- helpers ----
  /// True when the user asked the OS to remove animations.
  static bool reduced(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context);

  /// [d], or zero when reduced motion is on.
  static Duration of(BuildContext context, Duration d) =>
      reduced(context) ? Duration.zero : d;

  /// Stagger delay for list item [index] (capped at 6 items).
  static Duration staggerFor(BuildContext context, int index) =>
      reduced(context) ? Duration.zero : stagger * (index.clamp(0, 6));

  /// Shared axis X (M3): the new page slides in 30dp from the end while fading
  /// in; the old page slides 30dp toward the start while fading out. Usable
  /// directly in a go_router `CustomTransitionPage.transitionsBuilder`.
  static Widget sharedAxisX(
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) =>
      _SharedAxisX(
        animation: animation,
        secondaryAnimation: secondaryAnimation,
        child: child,
      );

  /// Fade through (M3), route version: outgoing content fades out in the first
  /// 35 %, incoming fades in and scales 0.92 → 1.0 in the remaining 65 %.
  static Widget fadeThroughRoute(
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return FadeTransition(
      opacity: ReverseAnimation(CurvedAnimation(
        parent: secondaryAnimation,
        curve: const Interval(0, 0.35, curve: Easing.emphasizedAccelerate),
      )),
      child: fadeThrough(child, animation),
    );
  }

  /// Fade through for `AnimatedSwitcher.transitionBuilder` (tab bodies, the
  /// Home month switch, onboarding illustrations).
  static Widget fadeThrough(Widget child, Animation<double> animation) {
    final Animation<double> inPart = CurvedAnimation(
      parent: animation,
      curve: const Interval(0.35, 1, curve: Easing.emphasizedDecelerate),
    );
    return FadeTransition(
      opacity: inPart,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.92, end: 1).animate(inPart),
        child: child,
      ),
    );
  }

  /// Animated list insert/remove: size + fade. Pass the item animation of an
  /// `AnimatedList` / `SliverAnimatedList`.
  static Widget listItem(Widget child, Animation<double> animation) {
    final Animation<double> a = CurvedAnimation(
      parent: animation,
      curve: enter,
      reverseCurve: exit,
    );
    return SizeTransition(
      sizeFactor: a,
      alignment: Alignment.topCenter,
      child: FadeTransition(opacity: a, child: child),
    );
  }
}

class _SharedAxisX extends StatelessWidget {
  const _SharedAxisX({
    required this.animation,
    required this.secondaryAnimation,
    required this.child,
  });

  final Animation<double> animation;
  final Animation<double> secondaryAnimation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final double dir =
        Directionality.of(context) == TextDirection.rtl ? -1 : 1;
    const double d = AppMotion.sharedAxisDistance;
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[animation, secondaryAnimation]),
      child: child,
      builder: (BuildContext context, Widget? child) {
        final double enterT = AppMotion.emphasized.transform(animation.value);
        final double exitT =
            AppMotion.emphasized.transform(secondaryAnimation.value);
        final double enterOpacity = const Interval(0.3, 1, curve: Easing.emphasizedDecelerate)
            .transform(animation.value);
        final double exitOpacity = 1 -
            const Interval(0, 0.3, curve: Easing.emphasizedAccelerate)
                .transform(secondaryAnimation.value);
        return Opacity(
          opacity: (enterOpacity * exitOpacity).clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(dir * d * ((1 - enterT) - exitT), 0),
            child: child,
          ),
        );
      },
    );
  }
}

/// Page transition for every MaterialPageRoute (push/pop): shared axis X.
/// Falls back to no animation when reduced motion is on.
class AppSharedAxisPageTransitionsBuilder extends PageTransitionsBuilder {
  const AppSharedAxisPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (AppMotion.reduced(context)) return child;
    return AppMotion.sharedAxisX(animation, secondaryAnimation, child);
  }
}

/// Fade-through page transition (top-level destinations, onboarding → app).
class AppFadeThroughPageTransitionsBuilder extends PageTransitionsBuilder {
  const AppFadeThroughPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (AppMotion.reduced(context)) return child;
    return AppMotion.fadeThroughRoute(animation, secondaryAnimation, child);
  }
}

/// Haptic vocabulary (DESIGN.md §11.6). Haptics are not motion, so they are
/// NOT disabled by reduced motion; the OS "touch feedback" switch governs them.
abstract final class AppHaptics {
  /// Amount keypad key, chip / segment change, picker selection.
  static Future<void> key() => HapticFeedback.selectionClick();

  /// PIN pad digit.
  static Future<void> pinDigit() => HapticFeedback.lightImpact();

  /// Save succeeded, PIN accepted, pull-to-refresh threshold crossed.
  static Future<void> confirm() => HapticFeedback.mediumImpact();

  /// Wrong PIN, invalid amount (paired with the shake).
  static Future<void> error() => HapticFeedback.heavyImpact();

  /// Long-press actions (clear amount, reorder start).
  static Future<void> longPress() => HapticFeedback.vibrate();
}

// ---------------------------------------------------------------------------
// Seeds (Material You presets)
// ---------------------------------------------------------------------------

/// Preset seed colours for the theme picker (DESIGN.md §12). Persist [id].
/// No green, red or amber seeds: those hues belong to income / expense /
/// budget warning.
enum AppSeed {
  teal('teal', Color(0xFF00696E), 'Firuzəyi', 'Teal'),
  ocean('ocean', Color(0xFF1F5FA8), 'Dəniz', 'Ocean'),
  indigo('indigo', Color(0xFF4A4FB0), 'İndiqo', 'Indigo'),
  plum('plum', Color(0xFF7B3F8A), 'Gavalı', 'Plum'),
  graphite('graphite', Color(0xFF4F5B66), 'Qrafit', 'Graphite');

  const AppSeed(this.id, this.color, this.labelAz, this.labelEn);

  final String id;
  final Color color;
  final String labelAz;
  final String labelEn;

  /// The v1.0 brand colour. Its scheme is hand-tuned (DESIGN.md §2).
  static const AppSeed defaultSeed = AppSeed.teal;

  String label(String lang) => lang == 'en' ? labelEn : labelAz;

  /// Unknown / null ids fall back to [defaultSeed].
  static AppSeed fromId(String? id) => AppSeed.values.firstWhere(
        (AppSeed s) => s.id == id,
        orElse: () => defaultSeed,
      );
}

// ---------------------------------------------------------------------------
// Raw palette (see DESIGN.md §2 for contrast ratios)
// ---------------------------------------------------------------------------

abstract final class _Palette {
  static const Color seed = Color(0xFF00696E);

  /// 12-colour categorical palette. Every entry keeps at least 3:1 against
  /// surface ... surfaceContainer in both themes (light tone >= 94,
  /// dark tone <= 12), so it is shared by every seed and dynamic scheme.
  static const List<Color> categorical = <Color>[
    Color(0xFF2F7ED8), // 0 blue
    Color(0xFFE8590C), // 1 orange
    Color(0xFF2B9A66), // 2 green
    Color(0xFFD6336C), // 3 raspberry
    Color(0xFF7950F2), // 4 violet
    Color(0xFF0C8599), // 5 teal
    Color(0xFFB07D00), // 6 mustard
    Color(0xFF6B7C93), // 7 slate ("Other")
    Color(0xFF5C7CFA), // 8 periwinkle
    Color(0xFF74872A), // 9 olive
    Color(0xFFAE3EC9), // 10 purple
    Color(0xFFB5603A), // 11 sienna
  ];
}

// ---------------------------------------------------------------------------
// Contrast utilities (WCAG 2.x)
// ---------------------------------------------------------------------------

abstract final class AppContrast {
  /// AA for normal text.
  static const double text = 4.5;

  /// AA for large text and graphical objects.
  static const double graphic = 3.0;

  /// WCAG contrast ratio of two opaque colours (1 ... 21).
  static double ratio(Color a, Color b) {
    final double la = a.computeLuminance();
    final double lb = b.computeLuminance();
    final double hi = la > lb ? la : lb;
    final double lo = la > lb ? lb : la;
    return (hi + 0.05) / (lo + 0.05);
  }

  /// Returns [fg] unchanged if it reaches [min] against every colour in
  /// [backgrounds]; otherwise moves its HSL lightness (hue and saturation
  /// kept) the smallest amount that does. Darkens on light backgrounds,
  /// lightens on dark ones.
  static Color ensure(
    Color fg,
    List<Color> backgrounds, {
    double min = text,
  }) {
    bool ok(Color c) =>
        backgrounds.every((Color b) => ratio(c, b) >= min);
    if (backgrounds.isEmpty || ok(fg)) return fg;

    double bgLum = 0;
    for (final Color b in backgrounds) {
      bgLum += b.computeLuminance();
    }
    bgLum /= backgrounds.length;
    final bool darken = fg.computeLuminance() <= bgLum;

    final HSLColor h = HSLColor.fromColor(fg);
    double lo = darken ? 0 : h.lightness;
    double hi = darken ? h.lightness : 1;
    for (int i = 0; i < 24; i++) {
      final double mid = (lo + hi) / 2;
      final bool good = ok(h.withLightness(mid).toColor());
      if (darken) {
        good ? lo = mid : hi = mid;
      } else {
        good ? hi = mid : lo = mid;
      }
    }
    return h.withLightness(darken ? lo : hi).toColor();
  }

  /// A colour with [color]'s hue and (clamped) saturation whose relative
  /// luminance is [luminance] (0 ... 1). Used to derive the balance-card
  /// gradient from any primary so its text contrast is fixed.
  static Color withLuminance(
    Color color,
    double luminance, {
    double minSaturation = 0,
    double maxSaturation = 1,
  }) {
    final HSLColor h0 = HSLColor.fromColor(color);
    final HSLColor h =
        h0.withSaturation(h0.saturation.clamp(minSaturation, maxSaturation));
    double lo = 0;
    double hi = 1;
    for (int i = 0; i < 24; i++) {
      final double mid = (lo + hi) / 2;
      if (h.withLightness(mid).toColor().computeLuminance() < luminance) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    return h.withLightness((lo + hi) / 2).toColor();
  }
}

// ---------------------------------------------------------------------------
// Holdings place types ("Kənar yerlər")
// ---------------------------------------------------------------------------

/// Visual style of a holding's place type (DESIGN.md §14). Keyed by name so
/// theme.dart does not depend on lib/data: the data enum's `.name` should be
/// one of [homeCash], [person], [bankDeposit], [gold], [other]
/// (matches `HoldingPlace` in lib/data/enums.dart).
@immutable
class HoldingPlaceStyle {
  const HoldingPlaceStyle._(this.name, this.icon, this.paletteIndex, this.order);

  final String name;
  final IconData icon;

  /// Index into [AppColors.categorical].
  final int paletteIndex;

  /// Group order on the holdings list.
  final int order;

  static const HoldingPlaceStyle homeCash =
      HoldingPlaceStyle._('homeCash', Icons.cottage_outlined, 9, 0);
  static const HoldingPlaceStyle person =
      HoldingPlaceStyle._('person', Icons.person_outline, 4, 1);
  static const HoldingPlaceStyle bankDeposit =
      HoldingPlaceStyle._('bankDeposit', Icons.account_balance_outlined, 0, 2);
  static const HoldingPlaceStyle gold =
      HoldingPlaceStyle._('gold', Icons.diamond_outlined, 6, 3);
  static const HoldingPlaceStyle other =
      HoldingPlaceStyle._('other', Icons.inventory_2_outlined, 7, 4);

  static const List<HoldingPlaceStyle> values = <HoldingPlaceStyle>[
    homeCash,
    person,
    bankDeposit,
    gold,
    other,
  ];

  /// Unknown names fall back to [other].
  static HoldingPlaceStyle of(String? name) => values.firstWhere(
        (HoldingPlaceStyle s) => s.name == name,
        orElse: () => other,
      );

  /// `HoldingPlaceStyle.forPlace(holding.place)` with the data enum.
  static HoldingPlaceStyle forPlace(Enum place) => of(place.name);

  Color color(AppColors c) => c.category(paletteIndex);

  /// Icon used for the holdings feature itself (Home card, Settings tile).
  static const IconData featureIcon = Icons.inventory_2_outlined;
}

// ---------------------------------------------------------------------------
// ThemeExtension: semantic money / budget colours + categorical palette
// ---------------------------------------------------------------------------

/// Budget usage state derived from spent / limit.
enum BudgetState { normal, warning, danger }

@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.income,
    required this.onIncome,
    required this.incomeContainer,
    required this.onIncomeContainer,
    required this.expense,
    required this.onExpense,
    required this.expenseContainer,
    required this.onExpenseContainer,
    required this.transfer,
    required this.onTransfer,
    required this.transferContainer,
    required this.onTransferContainer,
    required this.warning,
    required this.warningFill,
    required this.warningContainer,
    required this.onWarningContainer,
    required this.danger,
    required this.dangerContainer,
    required this.onDangerContainer,
    required this.balanceCard,
    required this.balanceCardEnd,
    required this.onBalanceCard,
    required this.onBalanceCardVariant,
    required this.balanceIncome,
    required this.balanceExpense,
    required this.categorical,
    // v1.1 (optional so v1.0 call sites keep compiling; defaults = light).
    this.holding = const Color(0xFF5B45B0),
    this.onHolding = const Color(0xFFFFFFFF),
    this.holdingContainer = const Color(0xFFE7DEFF),
    this.onHoldingContainer = const Color(0xFF2A1A6B),
    this.balanceHolding = const Color(0xFFE2D9FF),
    this.balanceCardOverlay = const Color(0x29000000),
    this.success = const Color(0xFF146C35),
  });

  // Income
  final Color income;
  final Color onIncome;
  final Color incomeContainer;
  final Color onIncomeContainer;

  // Expense
  final Color expense;
  final Color onExpense;
  final Color expenseContainer;
  final Color onExpenseContainer;

  // Transfer
  final Color transfer;
  final Color onTransfer;
  final Color transferContainer;
  final Color onTransferContainer;

  // Budget >= 80 %
  /// Text / icon colour (AA on surfaces).
  final Color warning;

  /// Progress-bar fill (>= 3:1 on card).
  final Color warningFill;
  final Color warningContainer;
  final Color onWarningContainer;

  // Budget >= 100 %
  final Color danger;
  final Color dangerContainer;
  final Color onDangerContainer;

  // Hero balance card
  final Color balanceCard;
  final Color balanceCardEnd;
  final Color onBalanceCard;
  final Color onBalanceCardVariant;
  final Color balanceIncome;
  final Color balanceExpense;

  /// 12 category / chart colours. Persist the index, not the colour.
  final List<Color> categorical;

  // ---- v1.1 ----
  /// Holdings ("Kənar yerlər") accent: text / icon (AA on surfaces).
  final Color holding;
  final Color onHolding;
  final Color holdingContainer;
  final Color onHoldingContainer;

  /// "Kənarda" amount on the balance card.
  final Color balanceHolding;

  /// Inner tiles / chips on the balance card: black 16 % (darkens, so on-card
  /// text contrast only goes up; a white overlay would drop it below AA).
  final Color balanceCardOverlay;

  /// Positive status text (rates updated, PIN set). Same tone as income.
  final Color success;

  // ---- helpers -----------------------------------------------------------

  static AppColors of(BuildContext context) =>
      Theme.of(context).extension<AppColors>()!;

  /// Category colour by stored palette index (wraps safely).
  Color category(int index) =>
      categorical[index.abs() % categorical.length];

  /// Gradient for the Home balance card.
  LinearGradient get balanceGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[balanceCard, balanceCardEnd],
      );

  static BudgetState budgetState(double spent, double limit) {
    if (limit <= 0) return BudgetState.normal;
    final double r = spent / limit;
    if (r >= 1.0) return BudgetState.danger;
    if (r >= 0.8) return BudgetState.warning;
    return BudgetState.normal;
  }

  /// Progress-bar fill for a budget. [normal] is usually the category colour.
  Color budgetFill(BudgetState s, Color normal) => switch (s) {
        BudgetState.normal => normal,
        BudgetState.warning => warningFill,
        BudgetState.danger => danger,
      };

  /// Text colour for the percentage label of a budget.
  Color budgetText(BudgetState s, Color normal) => switch (s) {
        BudgetState.normal => normal,
        BudgetState.warning => warning,
        BudgetState.danger => danger,
      };

  // ---- presets -----------------------------------------------------------

  /// Light preset. v1.1 darkened income (#17763A -> #146C35) and expense
  /// (#C0262D -> #B42229) to tone <= 40 so they pass 4.5:1 on every light
  /// surface role down to tone 87, for any seed or wallpaper.
  static const AppColors light = AppColors(
    income: Color(0xFF146C35),
    onIncome: Color(0xFFFFFFFF),
    incomeContainer: Color(0xFFD3F4DC),
    onIncomeContainer: Color(0xFF0E5128),
    expense: Color(0xFFB42229),
    onExpense: Color(0xFFFFFFFF),
    expenseContainer: Color(0xFFFFDAD7),
    onExpenseContainer: Color(0xFF7A1015),
    transfer: Color(0xFF2F5D8A),
    onTransfer: Color(0xFFFFFFFF),
    transferContainer: Color(0xFFD4E5F7),
    onTransferContainer: Color(0xFF1A3F63),
    warning: Color(0xFF8A5300),
    warningFill: Color(0xFFC07600),
    warningContainer: Color(0xFFFFE3BF),
    onWarningContainer: Color(0xFF5C3600),
    danger: Color(0xFFB3261E),
    dangerContainer: Color(0xFFFFDAD6),
    onDangerContainer: Color(0xFF410002),
    balanceCard: Color(0xFF00585C),
    balanceCardEnd: Color(0xFF006A6F),
    onBalanceCard: Color(0xFFFFFFFF),
    onBalanceCardVariant: Color(0xFFCDEFF0),
    balanceIncome: Color(0xFFB6F2C8),
    balanceExpense: Color(0xFFFFD6D2),
    categorical: _Palette.categorical,
    holding: Color(0xFF5B45B0),
    onHolding: Color(0xFFFFFFFF),
    holdingContainer: Color(0xFFE7DEFF),
    onHoldingContainer: Color(0xFF2A1A6B),
    balanceHolding: Color(0xFFE2D9FF),
    balanceCardOverlay: Color(0x29000000),
    success: Color(0xFF146C35),
  );

  static const AppColors dark = AppColors(
    income: Color(0xFF6FD892),
    onIncome: Color(0xFF00391A),
    incomeContainer: Color(0xFF14432A),
    onIncomeContainer: Color(0xFFC6F2D3),
    expense: Color(0xFFFF8A84),
    onExpense: Color(0xFF5C1518),
    expenseContainer: Color(0xFF5C1518),
    onExpenseContainer: Color(0xFFFFDAD7),
    transfer: Color(0xFF9DC4EE),
    onTransfer: Color(0xFF0E2F4D),
    transferContainer: Color(0xFF1E3A57),
    onTransferContainer: Color(0xFFD4E5F7),
    warning: Color(0xFFFFB547),
    warningFill: Color(0xFFFFB547),
    warningContainer: Color(0xFF4A3000),
    onWarningContainer: Color(0xFFFFE3BF),
    danger: Color(0xFFFFB4AB),
    dangerContainer: Color(0xFF93000A),
    onDangerContainer: Color(0xFFFFDAD6),
    balanceCard: Color(0xFF163B3E),
    balanceCardEnd: Color(0xFF1C4649),
    onBalanceCard: Color(0xFFE1E4E4),
    onBalanceCardVariant: Color(0xFFA9CFD1),
    balanceIncome: Color(0xFF6FD892),
    balanceExpense: Color(0xFFFFA19B),
    categorical: _Palette.categorical,
    holding: Color(0xFFC9BCFF),
    onHolding: Color(0xFF25105F),
    holdingContainer: Color(0xFF3B2F7A),
    onHoldingContainer: Color(0xFFE7DEFF),
    balanceHolding: Color(0xFFC9BCFF),
    balanceCardOverlay: Color(0x29000000),
    success: Color(0xFF6FD892),
  );

  /// Semantic colours for an arbitrary [scheme] (preset seed or wallpaper).
  ///
  /// * Money / budget / holding hues stay FIXED (the presets above); only if a
  ///   scheme's surfaces are unusual is a text colour's lightness nudged
  ///   until it is >= 4.5:1 on every surface role, see [AppContrast.ensure].
  /// * The balance-card gradient follows the scheme's primary hue at fixed
  ///   luminance (light 0.060 -> 0.100, dark 0.022 -> 0.045), so the fixed
  ///   on-card colours keep >= 4.5:1 for every hue.
  /// * With [tunedCard] the hand-tuned teal card is kept (default seed).
  static AppColors resolve(ColorScheme scheme, {bool tunedCard = false}) {
    final bool isDark = scheme.brightness == Brightness.dark;
    final AppColors base = isDark ? dark : light;

    final List<Color> surfaces = <Color>[
      scheme.surface,
      scheme.surfaceContainerLowest,
      scheme.surfaceContainerLow,
      scheme.surfaceContainer,
      scheme.surfaceContainerHigh,
      scheme.surfaceContainerHighest,
    ];
    Color t(Color c) => AppContrast.ensure(c, surfaces);

    Color cardStart = base.balanceCard;
    Color cardEnd = base.balanceCardEnd;
    Color onCard = base.onBalanceCard;
    Color onCardVariant = base.onBalanceCardVariant;
    if (!tunedCard) {
      final Color p = scheme.primary;
      if (isDark) {
        cardStart = AppContrast.withLuminance(p, 0.022,
            minSaturation: 0.15, maxSaturation: 0.45);
        cardEnd = AppContrast.withLuminance(p, 0.045,
            minSaturation: 0.15, maxSaturation: 0.45);
        onCard = AppContrast.withLuminance(p, 0.78, maxSaturation: 0.15);
        onCardVariant = AppContrast.withLuminance(p, 0.50, maxSaturation: 0.35);
      } else {
        cardStart = AppContrast.withLuminance(p, 0.060,
            minSaturation: 0.30, maxSaturation: 0.90);
        cardEnd = AppContrast.withLuminance(p, 0.100,
            minSaturation: 0.30, maxSaturation: 0.90);
        onCard = const Color(0xFFFFFFFF);
        onCardVariant = AppContrast.withLuminance(p, 0.72, maxSaturation: 0.50);
      }
    }
    final List<Color> card = <Color>[cardStart, cardEnd];
    Color k(Color c) => AppContrast.ensure(c, card);

    return base.copyWith(
      income: t(base.income),
      expense: t(base.expense),
      transfer: t(base.transfer),
      warning: t(base.warning),
      danger: t(base.danger),
      holding: t(base.holding),
      success: t(base.success),
      balanceCard: cardStart,
      balanceCardEnd: cardEnd,
      onBalanceCard: k(onCard),
      onBalanceCardVariant: k(onCardVariant),
      balanceIncome: k(base.balanceIncome),
      balanceExpense: k(base.balanceExpense),
      balanceHolding: k(base.balanceHolding),
    );
  }

  // ---- ThemeExtension ----------------------------------------------------

  @override
  AppColors copyWith({
    Color? income,
    Color? onIncome,
    Color? incomeContainer,
    Color? onIncomeContainer,
    Color? expense,
    Color? onExpense,
    Color? expenseContainer,
    Color? onExpenseContainer,
    Color? transfer,
    Color? onTransfer,
    Color? transferContainer,
    Color? onTransferContainer,
    Color? warning,
    Color? warningFill,
    Color? warningContainer,
    Color? onWarningContainer,
    Color? danger,
    Color? dangerContainer,
    Color? onDangerContainer,
    Color? balanceCard,
    Color? balanceCardEnd,
    Color? onBalanceCard,
    Color? onBalanceCardVariant,
    Color? balanceIncome,
    Color? balanceExpense,
    List<Color>? categorical,
    Color? holding,
    Color? onHolding,
    Color? holdingContainer,
    Color? onHoldingContainer,
    Color? balanceHolding,
    Color? balanceCardOverlay,
    Color? success,
  }) {
    return AppColors(
      income: income ?? this.income,
      onIncome: onIncome ?? this.onIncome,
      incomeContainer: incomeContainer ?? this.incomeContainer,
      onIncomeContainer: onIncomeContainer ?? this.onIncomeContainer,
      expense: expense ?? this.expense,
      onExpense: onExpense ?? this.onExpense,
      expenseContainer: expenseContainer ?? this.expenseContainer,
      onExpenseContainer: onExpenseContainer ?? this.onExpenseContainer,
      transfer: transfer ?? this.transfer,
      onTransfer: onTransfer ?? this.onTransfer,
      transferContainer: transferContainer ?? this.transferContainer,
      onTransferContainer: onTransferContainer ?? this.onTransferContainer,
      warning: warning ?? this.warning,
      warningFill: warningFill ?? this.warningFill,
      warningContainer: warningContainer ?? this.warningContainer,
      onWarningContainer: onWarningContainer ?? this.onWarningContainer,
      danger: danger ?? this.danger,
      dangerContainer: dangerContainer ?? this.dangerContainer,
      onDangerContainer: onDangerContainer ?? this.onDangerContainer,
      balanceCard: balanceCard ?? this.balanceCard,
      balanceCardEnd: balanceCardEnd ?? this.balanceCardEnd,
      onBalanceCard: onBalanceCard ?? this.onBalanceCard,
      onBalanceCardVariant: onBalanceCardVariant ?? this.onBalanceCardVariant,
      balanceIncome: balanceIncome ?? this.balanceIncome,
      balanceExpense: balanceExpense ?? this.balanceExpense,
      categorical: categorical ?? this.categorical,
      holding: holding ?? this.holding,
      onHolding: onHolding ?? this.onHolding,
      holdingContainer: holdingContainer ?? this.holdingContainer,
      onHoldingContainer: onHoldingContainer ?? this.onHoldingContainer,
      balanceHolding: balanceHolding ?? this.balanceHolding,
      balanceCardOverlay: balanceCardOverlay ?? this.balanceCardOverlay,
      success: success ?? this.success,
    );
  }

  @override
  AppColors lerp(covariant ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;

    final List<Color> cats;
    if (categorical.length == other.categorical.length) {
      cats = List<Color>.generate(
        categorical.length,
        (int i) => l(categorical[i], other.categorical[i]),
        growable: false,
      );
    } else {
      cats = t < 0.5 ? categorical : other.categorical;
    }

    return AppColors(
      income: l(income, other.income),
      onIncome: l(onIncome, other.onIncome),
      incomeContainer: l(incomeContainer, other.incomeContainer),
      onIncomeContainer: l(onIncomeContainer, other.onIncomeContainer),
      expense: l(expense, other.expense),
      onExpense: l(onExpense, other.onExpense),
      expenseContainer: l(expenseContainer, other.expenseContainer),
      onExpenseContainer: l(onExpenseContainer, other.onExpenseContainer),
      transfer: l(transfer, other.transfer),
      onTransfer: l(onTransfer, other.onTransfer),
      transferContainer: l(transferContainer, other.transferContainer),
      onTransferContainer: l(onTransferContainer, other.onTransferContainer),
      warning: l(warning, other.warning),
      warningFill: l(warningFill, other.warningFill),
      warningContainer: l(warningContainer, other.warningContainer),
      onWarningContainer: l(onWarningContainer, other.onWarningContainer),
      danger: l(danger, other.danger),
      dangerContainer: l(dangerContainer, other.dangerContainer),
      onDangerContainer: l(onDangerContainer, other.onDangerContainer),
      balanceCard: l(balanceCard, other.balanceCard),
      balanceCardEnd: l(balanceCardEnd, other.balanceCardEnd),
      onBalanceCard: l(onBalanceCard, other.onBalanceCard),
      onBalanceCardVariant:
          l(onBalanceCardVariant, other.onBalanceCardVariant),
      balanceIncome: l(balanceIncome, other.balanceIncome),
      balanceExpense: l(balanceExpense, other.balanceExpense),
      categorical: cats,
      holding: l(holding, other.holding),
      onHolding: l(onHolding, other.onHolding),
      holdingContainer: l(holdingContainer, other.holdingContainer),
      onHoldingContainer: l(onHoldingContainer, other.onHoldingContainer),
      balanceHolding: l(balanceHolding, other.balanceHolding),
      balanceCardOverlay: l(balanceCardOverlay, other.balanceCardOverlay),
      success: l(success, other.success),
    );
  }
}

// ---------------------------------------------------------------------------
// Typography
// ---------------------------------------------------------------------------

abstract final class AppTextStyles {
  static const List<FontFeature> _tabular = <FontFeature>[
    FontFeature.tabularFigures(),
  ];

  /// Size/weight-only text theme; colours are merged in by ThemeData.
  static const TextTheme textTheme = TextTheme(
    displaySmall: TextStyle(
        fontSize: 36, height: 44 / 36, fontWeight: FontWeight.w600,
        letterSpacing: -0.5),
    headlineMedium: TextStyle(
        fontSize: 28, height: 36 / 28, fontWeight: FontWeight.w600,
        letterSpacing: -0.25),
    headlineSmall: TextStyle(
        fontSize: 24, height: 32 / 24, fontWeight: FontWeight.w600,
        letterSpacing: 0),
    titleLarge: TextStyle(
        fontSize: 20, height: 28 / 20, fontWeight: FontWeight.w600,
        letterSpacing: 0),
    titleMedium: TextStyle(
        fontSize: 16, height: 24 / 16, fontWeight: FontWeight.w600,
        letterSpacing: 0.1),
    titleSmall: TextStyle(
        fontSize: 14, height: 20 / 14, fontWeight: FontWeight.w600,
        letterSpacing: 0.1),
    bodyLarge: TextStyle(
        fontSize: 16, height: 24 / 16, fontWeight: FontWeight.w400,
        letterSpacing: 0.15),
    bodyMedium: TextStyle(
        fontSize: 14, height: 20 / 14, fontWeight: FontWeight.w400,
        letterSpacing: 0.25),
    bodySmall: TextStyle(
        fontSize: 12, height: 16 / 12, fontWeight: FontWeight.w400,
        letterSpacing: 0.4),
    labelLarge: TextStyle(
        fontSize: 14, height: 20 / 14, fontWeight: FontWeight.w600,
        letterSpacing: 0.1),
    labelMedium: TextStyle(
        fontSize: 12, height: 16 / 12, fontWeight: FontWeight.w600,
        letterSpacing: 0.5),
    labelSmall: TextStyle(
        fontSize: 11, height: 16 / 11, fontWeight: FontWeight.w500,
        letterSpacing: 0.5),
  );

  /// Hero balance amount (colour applied at call site).
  static const TextStyle amountHero = TextStyle(
    fontSize: 36,
    height: 44 / 36,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.5,
    fontFeatures: _tabular,
  );

  /// Amount in list tiles.
  static const TextStyle amountTile = TextStyle(
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
    fontFeatures: _tabular,
  );

  /// Amount display above the numeric keypad.
  static const TextStyle amountInput = TextStyle(
    fontSize: 40,
    height: 48 / 40,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.5,
    fontFeatures: _tabular,
  );

  /// v1.1: secondary amounts on the balance card ("Kənarda", "Ümumi sərvət")
  /// and the holdings list total.
  static const TextStyle amountSecondary = TextStyle(
    fontSize: 20,
    height: 28 / 20,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    fontFeatures: _tabular,
  );

  /// v1.1: holding detail headline amount.
  static const TextStyle amountDetail = TextStyle(
    fontSize: 32,
    height: 40 / 32,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.25,
    fontFeatures: _tabular,
  );

  /// v1.1: onboarding page title.
  static const TextStyle onboardingTitle = TextStyle(
    fontSize: 28,
    height: 36 / 28,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.25,
  );

  /// Generic tabular-figures modifier: `style.merge(AppTextStyles.tabular)`.
  static const TextStyle tabular = TextStyle(fontFeatures: _tabular);
}

// ---------------------------------------------------------------------------
// Theme
// ---------------------------------------------------------------------------

abstract final class AppTheme {
  /// v1.0 default (teal, hand-tuned). Unchanged API.
  static ThemeData get light => build(Brightness.light);
  static ThemeData get dark => build(Brightness.dark);

  /// Builds the app theme.
  ///
  /// * [dynamicScheme]: the wallpaper scheme from dynamic_color
  ///   (`DynamicColorBuilder`), or null when unsupported / switched off.
  ///   When non-null it wins over [seed].
  /// * [seed]: a preset; [AppSeed.teal] (default) uses the hand-tuned
  ///   v1.0 scheme and card.
  /// * [rederiveDynamic]: re-generate the wallpaper scheme from its primary
  ///   with `ColorScheme.fromSeed` (default true). dynamic_color builds from
  ///   a CorePalette and may leave surfaceContainer* roles unset; re-deriving
  ///   keeps every M3 role consistent while keeping the wallpaper hue.
  static ThemeData build(
    Brightness brightness, {
    AppSeed seed = AppSeed.defaultSeed,
    ColorScheme? dynamicScheme,
    bool rederiveDynamic = true,
  }) {
    final ColorScheme cs = scheme(
      brightness,
      seed: seed,
      dynamicScheme: dynamicScheme,
      rederiveDynamic: rederiveDynamic,
    );
    final bool tuned = dynamicScheme == null && seed == AppSeed.defaultSeed;
    final AppColors app = tuned
        ? (brightness == Brightness.dark ? AppColors.dark : AppColors.light)
        : AppColors.resolve(cs);
    return _build(cs, app);
  }

  /// Convenience wrappers.
  static ThemeData lightWith({AppSeed seed = AppSeed.defaultSeed, ColorScheme? dynamicScheme}) =>
      build(Brightness.light, seed: seed, dynamicScheme: dynamicScheme);
  static ThemeData darkWith({AppSeed seed = AppSeed.defaultSeed, ColorScheme? dynamicScheme}) =>
      build(Brightness.dark, seed: seed, dynamicScheme: dynamicScheme);

  /// The ColorScheme alone (theme picker previews, swatches).
  static ColorScheme scheme(
    Brightness brightness, {
    AppSeed seed = AppSeed.defaultSeed,
    ColorScheme? dynamicScheme,
    bool rederiveDynamic = true,
  }) {
    if (dynamicScheme != null) {
      final ColorScheme d = rederiveDynamic
          ? ColorScheme.fromSeed(
              seedColor: dynamicScheme.primary,
              brightness: brightness,
            )
          : dynamicScheme;
      return _withFixedError(d, brightness);
    }
    if (seed == AppSeed.defaultSeed) {
      return brightness == Brightness.dark ? _darkScheme : _lightScheme;
    }
    return _withFixedError(
      ColorScheme.fromSeed(seedColor: seed.color, brightness: brightness),
      brightness,
    );
  }

  /// Error roles stay equal to the fixed `danger` tokens for every scheme, so
  /// form errors and over-budget states never drift with the wallpaper.
  static ColorScheme _withFixedError(ColorScheme cs, Brightness b) =>
      b == Brightness.dark
          ? cs.copyWith(
              error: const Color(0xFFFFB4AB),
              onError: const Color(0xFF690005),
              errorContainer: const Color(0xFF93000A),
              onErrorContainer: const Color(0xFFFFDAD6),
            )
          : cs.copyWith(
              error: const Color(0xFFB3261E),
              onError: const Color(0xFFFFFFFF),
              errorContainer: const Color(0xFFFFDAD6),
              onErrorContainer: const Color(0xFF410002),
            );

  // Seed-generated schemes with fixed overrides for contrast-checked roles.
  static final ColorScheme _lightScheme = ColorScheme.fromSeed(
    seedColor: _Palette.seed,
    brightness: Brightness.light,
  ).copyWith(
    primary: const Color(0xFF00696E),
    onPrimary: const Color(0xFFFFFFFF),
    primaryContainer: const Color(0xFF9CF0F6),
    onPrimaryContainer: const Color(0xFF002022),
    secondary: const Color(0xFF4A6365),
    onSecondary: const Color(0xFFFFFFFF),
    tertiary: const Color(0xFF4C5F7C),
    onTertiary: const Color(0xFFFFFFFF),
    error: const Color(0xFFB3261E),
    onError: const Color(0xFFFFFFFF),
    errorContainer: const Color(0xFFFFDAD6),
    onErrorContainer: const Color(0xFF410002),
    surface: const Color(0xFFF8FAF9),
    onSurface: const Color(0xFF171D1E),
    onSurfaceVariant: const Color(0xFF43494B),
    surfaceContainerLowest: const Color(0xFFFFFFFF),
    surfaceContainerLow: const Color(0xFFF2F5F4),
    surfaceContainer: const Color(0xFFECF0EF),
    surfaceContainerHigh: const Color(0xFFE9EFEE),
    surfaceContainerHighest: const Color(0xFFE0E6E5),
    outline: const Color(0xFF6F797A),
    outlineVariant: const Color(0xFFBFC8C9),
  );

  static final ColorScheme _darkScheme = ColorScheme.fromSeed(
    seedColor: _Palette.seed,
    brightness: Brightness.dark,
  ).copyWith(
    primary: const Color(0xFF6FD5DC),
    onPrimary: const Color(0xFF00373A),
    primaryContainer: const Color(0xFF004F53),
    onPrimaryContainer: const Color(0xFF9CF0F6),
    secondary: const Color(0xFFB1CBCD),
    onSecondary: const Color(0xFF1C3436),
    tertiary: const Color(0xFFB4C8E9),
    onTertiary: const Color(0xFF1D314C),
    error: const Color(0xFFFFB4AB),
    onError: const Color(0xFF690005),
    errorContainer: const Color(0xFF93000A),
    onErrorContainer: const Color(0xFFFFDAD6),
    surface: const Color(0xFF0F1416),
    onSurface: const Color(0xFFE1E4E4),
    onSurfaceVariant: const Color(0xFFBEC8C9),
    surfaceContainerLowest: const Color(0xFF0A0F10),
    surfaceContainerLow: const Color(0xFF171D1E),
    surfaceContainer: const Color(0xFF1A2124),
    surfaceContainerHigh: const Color(0xFF232B2E),
    surfaceContainerHighest: const Color(0xFF2D3639),
    outline: const Color(0xFF89938F),
    outlineVariant: const Color(0xFF3F484A),
  );

  /// Push/pop transition for every platform the app runs on.
  static const PageTransitionsTheme pageTransitions = PageTransitionsTheme(
    builders: <TargetPlatform, PageTransitionsBuilder>{
      TargetPlatform.android: AppSharedAxisPageTransitionsBuilder(),
      TargetPlatform.iOS: AppSharedAxisPageTransitionsBuilder(),
      TargetPlatform.windows: AppSharedAxisPageTransitionsBuilder(),
      TargetPlatform.linux: AppSharedAxisPageTransitionsBuilder(),
      TargetPlatform.macOS: AppSharedAxisPageTransitionsBuilder(),
      TargetPlatform.fuchsia: AppSharedAxisPageTransitionsBuilder(),
    },
  );

  static ThemeData _build(ColorScheme cs, AppColors app) {
    final ThemeData base = ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      brightness: cs.brightness,
      scaffoldBackgroundColor: cs.surface,
      textTheme: AppTextStyles.textTheme,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      splashFactory: InkSparkle.splashFactory,
      pageTransitionsTheme: pageTransitions,
      extensions: <ThemeExtension<dynamic>>[app],

      // NOTE: cardTheme, dialogTheme, tabBarTheme, appBarTheme and
      // inputDecorationTheme are intentionally NOT set here. Their parameter
      // types were migrated (CardTheme -> CardThemeData, AppBarTheme ->
      // AppBarThemeData, InputDecorationTheme -> InputDecorationThemeData)
      // across Flutter 3.27 ... 3.35+, so setting them would break either the
      // 3.24 floor or newer SDKs. M3 defaults already use the colour roles
      // above; use AppTheme.inputDecoration() and AppRadius for the rest.

      navigationBarTheme: NavigationBarThemeData(
        height: AppSizes.navBarHeight,
        backgroundColor: cs.surfaceContainer,
        indicatorColor: cs.primaryContainer,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((Set<WidgetState> s) {
          final bool sel = s.contains(WidgetState.selected);
          return IconThemeData(
            size: 24,
            color: sel ? cs.onPrimaryContainer : cs.onSurfaceVariant,
          );
        }),
        labelTextStyle:
            WidgetStateProperty.resolveWith((Set<WidgetState> s) {
          final bool sel = s.contains(WidgetState.selected);
          return AppTextStyles.textTheme.labelMedium?.copyWith(
            color: sel ? cs.onSurface : cs.onSurfaceVariant,
            overflow: TextOverflow.ellipsis,
          );
        }),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        elevation: 3,
        focusElevation: 3,
        hoverElevation: 4,
        highlightElevation: 2,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.brLg),
        sizeConstraints: const BoxConstraints.tightFor(
          width: AppSizes.fab,
          height: AppSizes.fab,
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, AppSizes.minTouch),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.brMd),
          textStyle: AppTextStyles.textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, AppSizes.minTouch),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.brMd),
          side: BorderSide(color: cs.outline),
          textStyle: AppTextStyles.textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, AppSizes.minTouch),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.brMd),
          textStyle: AppTextStyles.textTheme.labelLarge,
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll<Size>(
            Size(0, AppSizes.minTouch),
          ),
          textStyle: WidgetStatePropertyAll<TextStyle?>(
            AppTextStyles.textTheme.labelLarge,
          ),
          shape: const WidgetStatePropertyAll<OutlinedBorder>(
            RoundedRectangleBorder(borderRadius: AppRadius.brMd),
          ),
        ),
      ),

      chipTheme: ChipThemeData(
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.brSm),
        side: BorderSide(color: cs.outline),
        labelStyle: AppTextStyles.textTheme.labelMedium
            ?.copyWith(color: cs.onSurfaceVariant),
        selectedColor: cs.secondaryContainer,
        checkmarkColor: cs.onSecondaryContainer,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
        labelPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        showCheckmark: true,
      ),

      listTileTheme: ListTileThemeData(
        minVerticalPadding: AppSpacing.md,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        minLeadingWidth: AppSizes.categoryAvatar,
        iconColor: cs.onSurfaceVariant,
        titleTextStyle: AppTextStyles.textTheme.titleMedium
            ?.copyWith(color: cs.onSurface),
        subtitleTextStyle: AppTextStyles.textTheme.bodyMedium
            ?.copyWith(color: cs.onSurfaceVariant),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: cs.primary,
        linearTrackColor: cs.surfaceContainerHighest,
        linearMinHeight: AppSizes.progressHeight,
        refreshBackgroundColor: cs.surfaceContainerHigh,
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: cs.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: cs.onSurfaceVariant,
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadius.brSheetTop,
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: cs.inverseSurface,
        actionTextColor: cs.inversePrimary,
        contentTextStyle: AppTextStyles.textTheme.bodyMedium
            ?.copyWith(color: cs.onInverseSurface),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.brSm),
      ),

      dividerTheme: DividerThemeData(
        color: cs.outlineVariant,
        thickness: 1,
        space: 1,
      ),

      switchTheme: SwitchThemeData(
        thumbIcon: WidgetStateProperty.resolveWith((Set<WidgetState> s) =>
            s.contains(WidgetState.selected)
                ? const Icon(Icons.check, size: 16)
                : null),
      ),
    );

    return base;
  }

  /// Standard filled text-field decoration (DESIGN.md §6). Applied per field
  /// instead of via ThemeData.inputDecorationTheme for SDK compatibility.
  static InputDecoration inputDecoration(
    BuildContext context, {
    String? label,
    String? hint,
    String? errorText,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    OutlineInputBorder b(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: AppRadius.brMd,
          borderSide: BorderSide(color: c, width: w),
        );
    return InputDecoration(
      labelText: label,
      hintText: hint,
      errorText: errorText,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: cs.surfaceContainerHigh,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      hintStyle: TextStyle(color: cs.onSurfaceVariant),
      labelStyle: TextStyle(color: cs.onSurfaceVariant),
      border: b(cs.outlineVariant),
      enabledBorder: b(cs.outlineVariant),
      focusedBorder: b(cs.primary, 2),
      errorBorder: b(cs.error),
      focusedErrorBorder: b(cs.error, 2),
    );
  }
}
