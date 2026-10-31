// Gəlir-Çıxar: Material 3 theme.
//
// Design source of truth: docs/DESIGN.md (v1.0 §1–8, v1.1 §9–17, v1.2 §18).
//
// v1.2 additions (all new symbols; nothing existing changed):
//   AppRadius.card / brCard, AppCardDesign, AppCardDesigns (presets, byId,
//   photo, photoScrim), AppCarousel, AppNav (floating pill nav),
//   AccountTypeStyle, TransportModeStyle, MetroLineStyle, AppMotion v1.2.
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

  /// v1.2: bank-card-style account cards on Home (DESIGN.md §18.2).
  static const double card = 20;
  static const BorderRadius brCard = BorderRadius.all(Radius.circular(card));
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

  // ---- v1.2 (DESIGN.md §18.11) ----
  /// Carousel `animateToPage` (dot tap, "back to totals").
  static const Duration carouselPage = medium2;

  /// Floating nav: selected label fade-in and icon lift.
  static const Duration navLabel = medium1;

  /// Window for the second back press that exits the app (§18.9).
  static const Duration backExitWindow = Duration(seconds: 2);

  /// Detail rows that appear in a form (transport picker, bonus-loss row).
  static const Duration reveal = medium1;

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
// v1.2: account card designs (DESIGN.md §18.2)
// ---------------------------------------------------------------------------

/// One bank-card look. Every on-card colour is checked against BOTH gradient
/// stops (DESIGN.md §18.2.2): [onCard] and [onCardVariant] are >= 4.5:1 on
/// each stop, so any pixel of the linear gradient passes too.
@immutable
class AppCardDesign {
  const AppCardDesign._({
    required this.id,
    required this.labelAz,
    required this.labelEn,
    required this.colors,
    required this.onCard,
    required this.onCardVariant,
    this.isPhoto = false,
  });

  /// Persisted value (`accounts.cardDesignId`). Never rename.
  final String id;
  final String labelAz;
  final String labelEn;

  /// Gradient stops, top-left -> bottom-right. For [AppCardDesigns.photo]
  /// this is the placeholder shown while the image loads or if it is gone.
  final List<Color> colors;

  /// Name, balance, icon.
  final Color onCard;

  /// Currency code, "•••• 1234", secondary labels.
  final Color onCardVariant;

  /// True for the user-photo design: draw the image, then
  /// [AppCardDesigns.photoScrimFor] on top, then the text.
  final bool isPhoto;

  String label(String lang) => lang == 'en' ? labelEn : labelAz;

  /// Light card with dark text (gold, platinum).
  bool get isLight => onCard.computeLuminance() < 0.2;

  LinearGradient get gradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: colors,
      );

  /// "Bonus 50%" badge fill. A fixed pair, independent of the card behind it
  /// (10.84:1 on dark cards, 12.74:1 on light cards).
  Color get badge =>
      isLight ? const Color(0xFF2B1D00) : const Color(0xFFFFE08A);
  Color get onBadge =>
      isLight ? const Color(0xFFFFE08A) : const Color(0xFF3D2800);

  /// Inner chips on the card (type icon circle): darkens on dark cards,
  /// so contrast only goes up; lightens on light cards for the same reason.
  Color get overlay =>
      isLight ? const Color(0x33FFFFFF) : const Color(0x29000000);

  /// Lowest text contrast of [onCard] / [onCardVariant] over the stops
  /// (photo: over the worst case, a white pixel under the scrim's text band).
  double get worstTextContrast {
    if (isPhoto) {
      return AppContrast.ratio(onCard, AppCardDesigns.photoWorstBackground);
    }
    double worst = 21;
    for (final Color c in colors) {
      for (final Color fg in <Color>[onCard, onCardVariant]) {
        final double r = AppContrast.ratio(fg, c);
        if (r < worst) worst = r;
      }
    }
    return worst;
  }
}

/// Preset card designs + photo design + card geometry/elevation tokens.
abstract final class AppCardDesigns {
  // ---- presets (ratios: DESIGN.md §18.2.2) ----
  static const AppCardDesign teal = AppCardDesign._(
    id: 'teal',
    labelAz: 'Firuzəyi',
    labelEn: 'Teal',
    colors: <Color>[Color(0xFF004E52), Color(0xFF00777D)],
    onCard: Color(0xFFFFFFFF),
    onCardVariant: Color(0xFFE0F7F8),
  );
  static const AppCardDesign ocean = AppCardDesign._(
    id: 'ocean',
    labelAz: 'Okean',
    labelEn: 'Ocean',
    colors: <Color>[Color(0xFF0B3A82), Color(0xFF1D63BF)],
    onCard: Color(0xFFFFFFFF),
    onCardVariant: Color(0xFFDCEAFF),
  );
  static const AppCardDesign midnight = AppCardDesign._(
    id: 'midnight',
    labelAz: 'Gecə',
    labelEn: 'Midnight',
    colors: <Color>[Color(0xFF14183D), Color(0xFF33398F)],
    onCard: Color(0xFFFFFFFF),
    onCardVariant: Color(0xFFD9DBFF),
  );
  static const AppCardDesign plum = AppCardDesign._(
    id: 'plum',
    labelAz: 'Gavalı',
    labelEn: 'Plum',
    colors: <Color>[Color(0xFF3E1046), Color(0xFF83358F)],
    onCard: Color(0xFFFFFFFF),
    onCardVariant: Color(0xFFF5D9FA),
  );
  static const AppCardDesign sunset = AppCardDesign._(
    id: 'sunset',
    labelAz: 'Qürub',
    labelEn: 'Sunset',
    colors: <Color>[Color(0xFF7A1838), Color(0xFFB8431F)],
    onCard: Color(0xFFFFFFFF),
    onCardVariant: Color(0xFFFFEDE6),
  );
  static const AppCardDesign forest = AppCardDesign._(
    id: 'forest',
    labelAz: 'Meşə',
    labelEn: 'Forest',
    colors: <Color>[Color(0xFF0E3A2B), Color(0xFF23714F)],
    onCard: Color(0xFFFFFFFF),
    onCardVariant: Color(0xFFD9F0E4),
  );
  static const AppCardDesign graphite = AppCardDesign._(
    id: 'graphite',
    labelAz: 'Qrafit',
    labelEn: 'Graphite',
    colors: <Color>[Color(0xFF1E2227), Color(0xFF4A525C)],
    onCard: Color(0xFFFFFFFF),
    onCardVariant: Color(0xFFDCE1E7),
  );
  static const AppCardDesign onyx = AppCardDesign._(
    id: 'onyx',
    labelAz: 'Qara',
    labelEn: 'Onyx',
    colors: <Color>[Color(0xFF0A0A0C), Color(0xFF2C2C33)],
    onCard: Color(0xFFFFFFFF),
    onCardVariant: Color(0xFFD4D4DA),
  );
  static const AppCardDesign gold = AppCardDesign._(
    id: 'gold',
    labelAz: 'Qızılı',
    labelEn: 'Gold',
    colors: <Color>[Color(0xFFF3D98E), Color(0xFFC9A24A)],
    onCard: Color(0xFF2A1C00),
    onCardVariant: Color(0xFF3D2C00),
  );
  static const AppCardDesign platinum = AppCardDesign._(
    id: 'platinum',
    labelAz: 'Gümüşü',
    labelEn: 'Platinum',
    colors: <Color>[Color(0xFFEEF1F4), Color(0xFFB7C0CA)],
    onCard: Color(0xFF14181C),
    onCardVariant: Color(0xFF353D45),
  );

  /// User photo background. Text is always white (no variant tone: the
  /// scrim budget is spent on white only, see [photoScrimFor]).
  static const AppCardDesign photo = AppCardDesign._(
    id: 'photo',
    labelAz: 'Şəkil',
    labelEn: 'Photo',
    colors: <Color>[Color(0xFF1E2227), Color(0xFF4A525C)],
    onCard: Color(0xFFFFFFFF),
    onCardVariant: Color(0xFFFFFFFF),
    isPhoto: true,
  );

  /// Picker order. [photo] is offered separately as the last tile.
  static const List<AppCardDesign> presets = <AppCardDesign>[
    teal,
    ocean,
    midnight,
    plum,
    sunset,
    forest,
    graphite,
    onyx,
    gold,
    platinum,
  ];

  static const String defaultId = 'teal';
  static const String photoId = 'photo';

  /// Unknown / null ids fall back to [teal]; 'photo' returns [photo].
  static AppCardDesign byId(String? id) {
    if (id == photoId) return photo;
    for (final AppCardDesign d in presets) {
      if (d.id == id) return d;
    }
    return teal;
  }

  /// Default design for the n-th account created (cycles the presets, so a
  /// fresh install's cards are not all the same colour).
  static AppCardDesign forIndex(int index) =>
      presets[index.abs() % presets.length];

  // ---- geometry ----
  /// ISO/IEC 7810 ID-1 (85.60 × 53.98 mm).
  static const double aspectRatio = 1.586;
  static const double radius = AppRadius.card;
  static const BorderRadius borderRadius = AppRadius.brCard;
  static const EdgeInsets padding = EdgeInsets.all(20);

  /// Type-icon circle on the card.
  static const double typeIcon = 32;

  /// Nominal M3 elevation level (for Material widgets); the actual look is
  /// [shadows].
  static const double elevation = 6;

  /// Card shadow. Light theme: a soft shadow tinted with the gradient's end
  /// colour plus a tight key shadow. Dark theme: a plain black shadow (a
  /// coloured one is invisible on dark surfaces) + [border].
  static List<BoxShadow> shadows(AppCardDesign d, Brightness b) =>
      b == Brightness.light
          ? <BoxShadow>[
              BoxShadow(
                color: d.colors.last.withValues(alpha: d.isLight ? 0.22 : 0.30),
                blurRadius: 24,
                spreadRadius: -6,
                offset: const Offset(0, 10),
              ),
              const BoxShadow(
                color: Color(0x1A000000),
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ]
          : const <BoxShadow>[
              BoxShadow(
                color: Color(0x66000000),
                blurRadius: 16,
                offset: Offset(0, 6),
              ),
            ];

  /// Hairline that separates the card from the surface where the gradient
  /// alone would not (dark cards on dark surfaces, light cards on light).
  static Border? border(AppCardDesign d, Brightness b) {
    if (b == Brightness.dark && !d.isLight) {
      return Border.all(color: const Color(0x1AFFFFFF));
    }
    if (b == Brightness.light && d.isLight) {
      return Border.all(color: const Color(0x1F000000));
    }
    return null;
  }

  /// Background decoration of a preset card (photo cards: use
  /// [photoDecoration]).
  static BoxDecoration decoration(AppCardDesign d, Brightness b) =>
      BoxDecoration(
        gradient: d.gradient,
        borderRadius: borderRadius,
        boxShadow: shadows(d, b),
        border: border(d, b),
      );

  /// Background decoration of a photo card. Layer order is image (this) ->
  /// [photoScrimFor] (a DecoratedBox with [borderRadius]) -> text. Do not use
  /// `foregroundDecoration` for the scrim: it would paint over the text.
  /// Decode with `ResizeImage` at the card's physical size.
  static BoxDecoration photoDecoration(ImageProvider image, Brightness b) =>
      BoxDecoration(
        color: photo.colors.first,
        image: DecorationImage(image: image, fit: BoxFit.cover),
        borderRadius: borderRadius,
        boxShadow: shadows(photo, b),
        border: border(photo, b),
      );

  // ---- photo scrim (DESIGN.md §18.2.3) ----
  /// Black alpha in the text bands. 0.58 over a pure-white pixel gives
  /// #6B6B6B: white text 5.33:1 (AA needs alpha >= 0.535).
  static const double scrimTextAlpha = 0.58;

  /// Top edge / bottom edge alphas (a little extra for the card corners).
  static const double scrimTopAlpha = 0.62;
  static const double scrimBottomAlpha = 0.70;

  /// Middle of the card: no text there, so the photo shows through.
  static const double scrimMidAlpha = 0.36;

  /// Flat scrim for text scale > 1.3 (text may move out of the bands).
  /// 0.62 -> white 6.19:1 on a white pixel.
  static const double scrimFlatAlpha = 0.62;

  /// Height of the top text band (padding 20 + 36dp name row + 8 slack).
  static const double scrimTopBand = 64;

  /// Height of the bottom text band (padding 20 + 20dp last4 row + 4 gap
  /// + 36dp balance + 8 slack).
  static const double scrimBottomBand = 88;

  /// Reference card height (310dp wide card) for [photoScrim].
  static const double referenceHeight = 195;

  /// The worst-case background under white text: a white pixel under
  /// [scrimTextAlpha] black (sRGB blend, as Flutter composites).
  static const Color photoWorstBackground = Color(0xFF6B6B6B);

  static Color _black(double a) =>
      Color.fromARGB((a * 255).round(), 0, 0, 0);

  /// Scrim gradient (top -> bottom) for a card of [height] dp. The text
  /// bands are fixed in dp, so the guarantee holds for any card size. If
  /// the bands would meet, or [textScale] > 1.3, a flat scrim is returned.
  static LinearGradient photoScrimFor(double height, {double textScale = 1}) {
    final double t1 = scrimTopBand / height;
    final double t2 = 1 - scrimBottomBand / height;
    if (textScale > 1.3 || t2 - t1 < 0.12) {
      final Color f = _black(scrimFlatAlpha);
      return LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[f, f],
      );
    }
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: <Color>[
        _black(scrimTopAlpha),
        _black(scrimTextAlpha),
        _black(scrimMidAlpha),
        _black(scrimTextAlpha),
        _black(scrimBottomAlpha),
      ],
      stops: <double>[0, t1, (t1 + t2) / 2, t2, 1],
    );
  }

  /// [photoScrimFor] at [referenceHeight] (stops 0 / .33 / .44 / .55 / 1).
  static LinearGradient get photoScrim => photoScrimFor(referenceHeight);

  /// Readability shadow under photo-card text. Decorative only: the AA
  /// guarantee comes from the scrim, not from this.
  static const List<Shadow> photoTextShadow = <Shadow>[
    Shadow(color: Color(0x66000000), blurRadius: 4, offset: Offset(0, 1)),
  ];

  // ---- text styles on cards ----
  /// Account balance on a card (count-up). 28sp counts as large text.
  static const TextStyle balanceStyle = TextStyle(
    fontSize: 28,
    height: 36 / 28,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.25,
    fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
  );

  /// "•••• 1234".
  static const TextStyle last4Style = TextStyle(
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 2,
    fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
  );
}

// ---------------------------------------------------------------------------
// v1.2: Home card carousel (DESIGN.md §18.1)
// ---------------------------------------------------------------------------

abstract final class AppCarousel {
  /// `PageView(viewportFraction: ..., padEnds: false)`.
  static const double viewportFraction = 0.86;

  /// Leading inset of every page (= gutter); the gap between cards.
  static const double pageInset = AppSpacing.lg;

  /// Non-current cards scale down by distance: 1 - 0.06 * |offset|.
  static const double inactiveScale = 0.94;

  /// Space between the cards and the dots.
  static const double dotsTop = AppSpacing.md;

  /// Dots: at most this many are drawn; beyond that they scroll.
  static const int maxVisibleDots = 7;
  static const double dot = 6;
  static const double dotActive = 18;
  static const double dotGap = 6;

  /// Scale of the 2nd-from-edge and edge dots when the strip scrolls.
  static const double dotEdgeScale1 = 0.66;
  static const double dotEdgeScale2 = 0.33;

  /// Card width for a viewport of [viewportWidth].
  static double cardWidth(double viewportWidth) =>
      viewportWidth * viewportFraction - pageInset;

  /// PageView height: the 1.586 card, grown with large text so content never
  /// clips (all pages share this height).
  static double height(double viewportWidth, TextScaler scaler) {
    final double base = cardWidth(viewportWidth) / AppCardDesigns.aspectRatio;
    final double s = scaler.scale(14) / 14;
    return s <= 1.0 ? base : base * s.clamp(1.0, 1.6);
  }
}

// ---------------------------------------------------------------------------
// v1.2: floating pill navigation (DESIGN.md §18.3)
// ---------------------------------------------------------------------------

abstract final class AppNav {
  /// Pill height (excluding the raised FAB).
  static const double height = 64;

  /// Side margin; on compact screens (< [compactBreakpoint]) it shrinks so
  /// every tab keeps a 48dp target.
  static const double margin = AppSpacing.lg;
  static const double marginCompact = AppSpacing.sm;
  static const double compactBreakpoint = 392;

  /// Gap between the pill and the bottom safe-area inset.
  static const double bottomGap = AppSpacing.md;

  static const BorderRadius borderRadius = AppRadius.brFull;

  /// surfaceContainer at this opacity + backdrop blur.
  static const double opacity = 0.88;
  static const double blurSigma = 20;

  /// Centre "+" FAB: a circle that rises [fabLift] above the pill's top
  /// edge, ringed by [fabRing] of the scaffold surface.
  static const double fab = 56;
  static const double fabLift = 12;
  static const double fabRing = 4;

  /// Width reserved for the FAB inside the pill.
  static const double fabSlot = 72;
  static const double fabSlotCompact = 56;

  /// Selected-tab indicator (behind the icon).
  static const double indicatorWidth = 48;
  static const double indicatorHeight = 30;
  static const double iconSize = 24;

  /// How far the selected icon moves up to make room for its label.
  static const double iconLift = 8;

  /// Labels are hidden (icons + tooltip only) above this text scale.
  static const double labelMaxTextScale = 1.3;

  /// Minimum tab target width.
  static const double minTab = AppSizes.minTouch;

  static bool isCompact(double screenWidth) => screenWidth < compactBreakpoint;

  static double marginFor(double screenWidth) =>
      isCompact(screenWidth) ? marginCompact : margin;

  static double fabSlotFor(double screenWidth) =>
      isCompact(screenWidth) ? fabSlotCompact : fabSlot;

  /// Distance from the screen bottom to the pill's bottom edge.
  static double bottomOffset(BuildContext context) =>
      MediaQuery.viewPaddingOf(context).bottom + bottomGap;

  /// Bottom padding scrollables need under `extendBody: true` so the last
  /// item clears the pill (+ 16dp breathing room).
  static double contentInset(BuildContext context) =>
      bottomOffset(context) + height + AppSpacing.lg;

  /// Translucent pill fill. Worst case (black content behind, light theme)
  /// keeps onSurfaceVariant at 6.07:1 and onSurface at 11.28:1.
  static Color background(ColorScheme cs) =>
      cs.surfaceContainer.withValues(alpha: opacity);

  static List<BoxShadow> shadows(Brightness b) => b == Brightness.light
      ? const <BoxShadow>[
          BoxShadow(
            color: Color(0x24000000),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ]
      : const <BoxShadow>[
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ];

  /// Hairline around the pill in dark theme (surfaceContainer is close to
  /// the content behind it).
  static Border? border(ColorScheme cs) => cs.brightness == Brightness.dark
      ? Border.all(color: cs.outlineVariant.withValues(alpha: 0.6))
      : null;
}

// ---------------------------------------------------------------------------
// v1.2: account types, transport modes, metro lines
// ---------------------------------------------------------------------------

/// Visual style of an account type, keyed by `AccountType.name`
/// (cash, card, bank, savings, bonus).
@immutable
class AccountTypeStyle {
  const AccountTypeStyle._(this.name, this.icon, this.defaultDesignId);

  final String name;
  final IconData icon;

  /// Suggested card design for a new account of this type.
  final String defaultDesignId;

  bool get isBonus => name == 'bonus';

  static const AccountTypeStyle cash =
      AccountTypeStyle._('cash', Icons.payments_outlined, 'forest');
  static const AccountTypeStyle card =
      AccountTypeStyle._('card', Icons.credit_card, 'ocean');
  static const AccountTypeStyle bank =
      AccountTypeStyle._('bank', Icons.account_balance_outlined, 'midnight');
  static const AccountTypeStyle savings =
      AccountTypeStyle._('savings', Icons.savings_outlined, 'teal');
  static const AccountTypeStyle bonus =
      AccountTypeStyle._('bonus', Icons.redeem, 'gold');

  static const List<AccountTypeStyle> values = <AccountTypeStyle>[
    cash,
    card,
    bank,
    savings,
    bonus,
  ];

  /// Unknown names fall back to [card].
  static AccountTypeStyle of(String? name) => values.firstWhere(
        (AccountTypeStyle s) => s.name == name,
        orElse: () => card,
      );

  static AccountTypeStyle forType(Enum type) => of(type.name);
}

/// Transport sub-modes for the "Nəqliyyat" category (DESIGN.md §18.5),
/// keyed by name: bus, metro, taxi, train, fuel, parking, bakuCard.
@immutable
class TransportModeStyle {
  const TransportModeStyle._(
    this.name,
    this.icon,
    this.paletteIndex,
    this.order, {
    this.hasRoutes = false,
    this.hasStations = false,
    this.hasTrips = false,
  });

  final String name;
  final IconData icon;

  /// Index into [AppColors.categorical] (bars in the Reports card).
  final int paletteIndex;
  final int order;

  /// Bus: searchable route list.
  final bool hasRoutes;

  /// Metro: optional station picker.
  final bool hasStations;

  /// Fixed fare × trip-count stepper (bus, metro, train).
  final bool hasTrips;

  static const TransportModeStyle bus = TransportModeStyle._(
      'bus', Icons.directions_bus_outlined, 0, 0,
      hasRoutes: true, hasTrips: true);
  static const TransportModeStyle metro = TransportModeStyle._(
      'metro', Icons.subway_outlined, 3, 1,
      hasStations: true, hasTrips: true);
  static const TransportModeStyle taxi =
      TransportModeStyle._('taxi', Icons.local_taxi_outlined, 6, 2);
  static const TransportModeStyle train = TransportModeStyle._(
      'train', Icons.train_outlined, 5, 3,
      hasTrips: true);
  static const TransportModeStyle fuel =
      TransportModeStyle._('fuel', Icons.local_gas_station_outlined, 1, 4);
  static const TransportModeStyle parking =
      TransportModeStyle._('parking', Icons.local_parking_outlined, 8, 5);
  static const TransportModeStyle bakuCard =
      TransportModeStyle._('bakuCard', Icons.add_card, 7, 6);

  static const List<TransportModeStyle> values = <TransportModeStyle>[
    bus,
    metro,
    taxi,
    train,
    fuel,
    parking,
    bakuCard,
  ];

  /// Unknown names fall back to [taxi] (a mode with no extra fields).
  static TransportModeStyle of(String? name) => values.firstWhere(
        (TransportModeStyle s) => s.name == name,
        orElse: () => taxi,
      );

  static TransportModeStyle forMode(Enum mode) => of(mode.name);

  Color color(AppColors c) => c.category(paletteIndex);
}

/// Baku Metro line colours for the station picker (DESIGN.md §18.5.3).
/// Each is >= 3:1 on surface ... surfaceContainerLow in both themes; the
/// line name is always shown next to the dot, and the branch is drawn as a
/// ring, so colour is never the only cue.
@immutable
class MetroLineStyle {
  const MetroLineStyle._(
    this.name,
    this.color,
    this.labelAz,
    this.labelEn, {
    this.ring = false,
  });

  final String name;
  final Color color;
  final String labelAz;
  final String labelEn;

  /// Draw as a 2dp ring instead of a filled dot (branch line).
  final bool ring;

  String label(String lang) => lang == 'en' ? labelEn : labelAz;

  static const MetroLineStyle red = MetroLineStyle._(
      'red', Color(0xFFD63A2F), 'Qırmızı xətt', 'Red line');
  static const MetroLineStyle green = MetroLineStyle._(
      'green', Color(0xFF2B9A66), 'Yaşıl xətt', 'Green line');
  static const MetroLineStyle greenBranch = MetroLineStyle._(
      'greenBranch', Color(0xFF2B9A66), 'Yaşıl xətt (Xətai qolu)',
      'Green line (Khatai branch)',
      ring: true);
  static const MetroLineStyle purple = MetroLineStyle._(
      'purple', Color(0xFF9B4FC8), 'Bənövşəyi xətt', 'Purple line');

  static const List<MetroLineStyle> values = <MetroLineStyle>[
    red,
    green,
    greenBranch,
    purple,
  ];

  static MetroLineStyle of(String? name) => values.firstWhere(
        (MetroLineStyle s) => s.name == name,
        orElse: () => red,
      );
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
