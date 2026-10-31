import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// One tab of [AppFloatingNav].
@immutable
class AppNavItem {
  const AppNavItem({required this.icon, required this.selectedIcon, required this.label});

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

/// Floating pill navigation with a raised centre "+" (DESIGN.md §18.3).
///
/// The first [leftCount] items sit left of the "+", the rest right of it.
/// Only the selected tab shows its label (clamped inside its half of the
/// bar); unselected tabs are icon-only with a tooltip. Above text scale
/// [AppNav.labelMaxTextScale] no label is drawn.
class AppFloatingNav extends StatelessWidget {
  const AppFloatingNav({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
    required this.onAdd,
    required this.addTooltip,
    this.leftCount = 2,
  });

  final List<AppNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final VoidCallback onAdd;
  final String addTooltip;
  final int leftCount;

  /// Total height the Scaffold reserves (raised FAB + pill + bottom inset).
  static double totalHeight(BuildContext context) =>
      AppNav.fabLift + AppNav.height + AppNav.bottomOffset(context);

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final double screen = MediaQuery.sizeOf(context).width;
    final double margin = AppNav.marginFor(screen);
    final double pill = math.min(screen - 2 * margin, 480);
    final double fabSlot = AppNav.fabSlotFor(screen);
    final double half = (pill - fabSlot) / 2;
    final double bottom = AppNav.bottomOffset(context);
    final bool showLabel =
        MediaQuery.textScalerOf(context).scale(1) <= AppNav.labelMaxTextScale;

    Widget halfOf(int start, int end) => SizedBox(
          width: half,
          child: _NavHalf(
            items: items.sublist(start, end),
            firstIndex: start,
            total: items.length,
            selectedIndex: selectedIndex,
            onSelected: onSelected,
            showLabel: showLabel,
          ),
        );

    final int split = math.min(leftCount, items.length);
    return SizedBox(
      height: totalHeight(context),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: <Widget>[
          Positioned(
            bottom: bottom,
            width: pill,
            height: AppNav.height,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: AppNav.borderRadius,
                boxShadow: AppNav.shadows(cs.brightness),
              ),
              child: ClipRRect(
                borderRadius: AppNav.borderRadius,
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: AppNav.blurSigma, sigmaY: AppNav.blurSigma),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppNav.background(cs),
                      borderRadius: AppNav.borderRadius,
                      border: AppNav.border(cs),
                    ),
                    child: Material(
                      type: MaterialType.transparency,
                      child: Row(
                        children: <Widget>[
                          halfOf(0, split),
                          SizedBox(width: fabSlot),
                          halfOf(split, items.length),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: bottom + AppNav.height + AppNav.fabLift - AppNav.fab - AppNav.fabRing,
            child: _CenterFab(onPressed: onAdd, tooltip: addTooltip),
          ),
        ],
      ),
    );
  }
}

class _CenterFab extends StatelessWidget {
  const _CenterFab({required this.onPressed, required this.tooltip});

  final VoidCallback onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    const double outer = AppNav.fab + 2 * AppNav.fabRing;
    return Container(
      width: outer,
      height: outer,
      decoration: BoxDecoration(
        color: cs.surface,
        shape: BoxShape.circle,
        boxShadow: AppNav.shadows(cs.brightness),
      ),
      alignment: Alignment.center,
      child: Tooltip(
        message: tooltip,
        child: Semantics(
          button: true,
          label: tooltip,
          excludeSemantics: true,
          child: Material(
            color: cs.primary,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () {
                AppHaptics.key();
                onPressed();
              },
              child: SizedBox(
                width: AppNav.fab,
                height: AppNav.fab,
                child: Icon(Icons.add, color: cs.onPrimary, size: 24),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One side of the pill: equal slots, plus the selected label placed under
/// its icon and clamped to the half (DESIGN.md §18.3.3).
class _NavHalf extends StatelessWidget {
  const _NavHalf({
    required this.items,
    required this.firstIndex,
    required this.total,
    required this.selectedIndex,
    required this.onSelected,
    required this.showLabel,
  });

  final List<AppNavItem> items;
  final int firstIndex;
  final int total;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final Duration d = AppMotion.of(context, AppMotion.navLabel);
    final int local = selectedIndex - firstIndex;
    final bool hasSelected = local >= 0 && local < items.length;

    return LayoutBuilder(builder: (BuildContext context, BoxConstraints c) {
      final double slot = c.maxWidth / items.length;
      Widget? label;
      if (hasSelected && showLabel) {
        final TextStyle style = (theme.textTheme.labelMedium ?? const TextStyle())
            .copyWith(color: cs.onSurface, fontWeight: FontWeight.w600);
        final double maxW = math.max(c.maxWidth - 16, 0);
        final TextPainter tp = TextPainter(
          text: TextSpan(text: items[local].label, style: style),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
          maxLines: 1,
        )..layout(maxWidth: maxW);
        final double w = tp.width;
        tp.dispose();
        final double centre = slot * local + slot / 2;
        final double left = (centre - w / 2).clamp(8.0, math.max(8.0, c.maxWidth - 8 - w));
        label = Positioned(
          left: left,
          width: w + 1,
          top: 41,
          child: IgnorePointer(
            child: ExcludeSemantics(
              child: Text(
                items[local].label,
                key: ValueKey<String>('navLabel.${items[local].label}'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: style,
              ),
            ),
          ),
        );
      }
      return Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Row(
            children: <Widget>[
              for (int i = 0; i < items.length; i++)
                SizedBox(
                  width: slot,
                  height: AppNav.height,
                  child: _NavTab(
                    item: items[i],
                    selected: i == local,
                    position: firstIndex + i + 1,
                    total: total,
                    lift: showLabel,
                    duration: d,
                    onTap: () => onSelected(firstIndex + i),
                  ),
                ),
            ],
          ),
          ?label,
        ],
      );
    });
  }
}

class _NavTab extends StatelessWidget {
  const _NavTab({
    required this.item,
    required this.selected,
    required this.position,
    required this.total,
    required this.lift,
    required this.duration,
    required this.onTap,
  });

  final AppNavItem item;
  final bool selected;
  final int position;
  final int total;
  final bool lift;
  final Duration duration;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final double dy = selected && lift ? -AppNav.iconLift : 0;
    return Tooltip(
      message: item.label,
      child: Semantics(
        button: true,
        selected: selected,
        label: '${item.label}, $position / $total',
        excludeSemantics: true,
        child: InkResponse(
          onTap: () {
            AppHaptics.key();
            onTap();
          },
          radius: 32,
          child: Center(
            child: AnimatedSlide(
              duration: duration,
              curve: AppMotion.emphasized,
              offset: Offset(0, dy / AppNav.indicatorHeight),
              child: AnimatedContainer(
                duration: duration,
                curve: AppMotion.emphasized,
                width: AppNav.indicatorWidth,
                height: AppNav.indicatorHeight,
                decoration: BoxDecoration(
                  color: selected ? cs.primaryContainer : cs.primaryContainer.withValues(alpha: 0),
                  borderRadius: AppRadius.brFull,
                ),
                child: Icon(
                  selected ? item.selectedIcon : item.icon,
                  size: AppNav.iconSize,
                  color: selected ? cs.onPrimaryContainer : cs.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
