// Motion building blocks (DESIGN.md §11). Every animation here respects
// MediaQuery.disableAnimations through AppMotion.of / AppMotion.reduced.

import 'dart:async';

import 'package:flutter/material.dart';

import 'theme.dart';

/// Scales its child while a pointer is down (cards 0.97, keys 0.92). The
/// child keeps its own InkWell / ripple. No scale under reduced motion.
class PressScale extends StatefulWidget {
  const PressScale({
    super.key,
    required this.child,
    this.scale = AppMotion.pressScaleCard,
    this.enabled = true,
  });

  final Widget child;
  final double scale;
  final bool enabled;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v && mounted) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || AppMotion.reduced(context)) return widget.child;
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: _down ? AppMotion.pressDown : AppMotion.pressUp,
        curve: AppMotion.standard,
        child: widget.child,
      ),
    );
  }
}

/// An amount that counts to its value (§11.3): from 0 on the first build of
/// [id] after a cold start, then from the previous value. Semantics carry
/// the final text only; masked and reduced-motion states don't animate.
class CountUpAmount extends StatelessWidget {
  const CountUpAmount({
    super.key,
    required this.id,
    required this.value,
    required this.format,
    this.style,
    this.masked,
    this.semanticsPrefix,
  });

  /// Stable id so the previous value survives rebuilds and re-entries.
  final String id;
  final int value;
  final String Function(int minor) format;
  final TextStyle? style;

  /// Shown instead of the number (hidden balance).
  final String? masked;
  final String? semanticsPrefix;

  static final Map<String, int> _last = <String, int>{};

  @override
  Widget build(BuildContext context) {
    final String finalText = masked ?? format(value);
    final String label = semanticsPrefix == null
        ? finalText
        : '$semanticsPrefix, $finalText';
    final int from = _last[id] ?? 0;
    _last[id] = value;
    final Widget text;
    if (masked != null || AppMotion.reduced(context)) {
      text = Text(finalText, style: style, maxLines: 1);
    } else {
      text = TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: from.toDouble(), end: value.toDouble()),
        duration: AppMotion.countUp,
        curve: AppMotion.countUpCurve,
        builder: (BuildContext context, double v, _) =>
            Text(format(v.round()), style: style, maxLines: 1),
      );
    }
    return Semantics(label: label, excludeSemantics: true, child: text);
  }
}

/// First-load entrance: fade in and rise 8dp, 30ms apart, first 6 items
/// only (§11.6). Later items and reduced motion appear at once.
class StaggerIn extends StatefulWidget {
  const StaggerIn({super.key, required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  State<StaggerIn> createState() => _StaggerInState();
}

class _StaggerInState extends State<StaggerIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: AppMotion.listInsert,
  );
  Timer? _timer;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (widget.index >= 6 || AppMotion.reduced(context)) {
      _c.value = 1;
    } else {
      _timer = Timer(AppMotion.staggerFor(context, widget.index), () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Animation<double> a = CurvedAnimation(
      parent: _c,
      curve: AppMotion.enter,
    );
    return AnimatedBuilder(
      animation: a,
      builder: (BuildContext context, Widget? child) => Opacity(
        opacity: a.value,
        child: Transform.translate(
          offset: Offset(0, 8 * (1 - a.value)),
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}

typedef DiffItemBuilder<T> = Widget Function(
  BuildContext context,
  T item,
  int index,
);

/// A [SliverAnimatedList] fed with plain data: on every new [items] list it
/// diffs by [keyOf] and animates removals and insertions (§11.6, size +
/// fade). Items that stay keep their state. The first batch staggers in.
class AnimatedDiffSliverList<T> extends StatefulWidget {
  const AnimatedDiffSliverList({
    super.key,
    required this.items,
    required this.keyOf,
    required this.itemBuilder,
    this.removedBuilder,
  });

  final List<T> items;
  final Object Function(T item) keyOf;
  final DiffItemBuilder<T> itemBuilder;

  /// How a removed item looks while it animates out (defaults to
  /// [itemBuilder]). Return an empty box for items already swiped away.
  final Widget Function(BuildContext context, T item)? removedBuilder;

  @override
  State<AnimatedDiffSliverList<T>> createState() =>
      _AnimatedDiffSliverListState<T>();
}

class _AnimatedDiffSliverListState<T> extends State<AnimatedDiffSliverList<T>> {
  final GlobalKey<SliverAnimatedListState> _list =
      GlobalKey<SliverAnimatedListState>();
  late List<T> _items = List<T>.of(widget.items);
  bool _initial = true;

  @override
  void didUpdateWidget(AnimatedDiffSliverList<T> old) {
    super.didUpdateWidget(old);
    final List<T> next = widget.items;
    final Set<Object> nextKeys = <Object>{
      for (final T i in next) widget.keyOf(i),
    };
    final SliverAnimatedListState? list = _list.currentState;
    final Duration removeD = AppMotion.of(context, AppMotion.listRemove);
    final Duration insertD = AppMotion.of(context, AppMotion.listInsert);
    _initial = false;

    for (int i = _items.length - 1; i >= 0; i--) {
      final T gone = _items[i];
      if (nextKeys.contains(widget.keyOf(gone))) continue;
      _items.removeAt(i);
      list?.removeItem(
        i,
        (BuildContext context, Animation<double> a) => AppMotion.listItem(
          widget.removedBuilder?.call(context, gone) ??
              widget.itemBuilder(context, gone, i),
          a,
        ),
        duration: removeD,
      );
    }
    final Set<Object> kept = <Object>{
      for (final T i in _items) widget.keyOf(i),
    };
    for (int i = 0; i < next.length; i++) {
      if (kept.contains(widget.keyOf(next[i]))) continue;
      list?.insertItem(i, duration: insertD);
    }
    _items = List<T>.of(next);
  }

  @override
  Widget build(BuildContext context) {
    return SliverAnimatedList(
      key: _list,
      initialItemCount: _items.length,
      itemBuilder: (BuildContext context, int index, Animation<double> a) {
        if (index >= _items.length) return const SizedBox.shrink();
        final T item = _items[index];
        // Always the same wrapper (keyed by the item), so later rebuilds keep
        // each item's element and state; only the first batch staggers.
        return AppMotion.listItem(
          StaggerIn(
            key: ValueKey<Object>(widget.keyOf(item)),
            index: _initial ? index : 99,
            child: widget.itemBuilder(context, item, index),
          ),
          a,
        );
      },
    );
  }
}

/// Charts animate in (DESIGN.md §11.4): [builder] gets `shown == false` on
/// the first frame (draw zeros / equal slices), then `true`, so fl_chart
/// animates from empty to the real data with `chartEntry` / `chartCurve`.
class ChartEntry extends StatefulWidget {
  const ChartEntry({super.key, required this.builder});

  final Widget Function(BuildContext context, bool shown) builder;

  @override
  State<ChartEntry> createState() => _ChartEntryState();
}

class _ChartEntryState extends State<ChartEntry> {
  bool _shown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _shown = true);
    });
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _shown);
}
