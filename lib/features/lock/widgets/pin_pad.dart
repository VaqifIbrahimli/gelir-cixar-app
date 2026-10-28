import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/motion.dart';
import '../../../core/theme.dart';
import '../../../l10n/app_localizations.dart';

/// PIN dots + circular keypad (DESIGN.md §6.7).
///
/// With a fixed [length] it calls [onCompleted] as soon as that many digits
/// are entered. With `length == null` (PIN creation) it accepts
/// [minLength]..[maxLength] digits and shows a confirm key.
class PinPad extends StatefulWidget {
  const PinPad({
    super.key,
    required this.onCompleted,
    this.length,
    this.minLength = 4,
    this.maxLength = 6,
    this.enabled = true,
    this.onBiometric,
  });

  final int? length;
  final int minLength;
  final int maxLength;
  final bool enabled;
  final ValueChanged<String> onCompleted;

  /// Shows the fingerprint key when non-null.
  final VoidCallback? onBiometric;

  @override
  State<PinPad> createState() => PinPadState();
}

class PinPadState extends State<PinPad> with SingleTickerProviderStateMixin {
  String _pin = '';
  bool _error = false;
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  );

  int get _max => widget.length ?? widget.maxLength;

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  /// Clears the input.
  void clear() => setState(() {
    _pin = '';
    _error = false;
  });

  /// Wrong-PIN feedback: red dots, shake, heavy haptic, then reset.
  Future<void> showError() async {
    AppHaptics.error();
    setState(() => _error = true);
    if (!MediaQuery.disableAnimationsOf(context)) {
      await _shake.forward(from: 0);
    } else {
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }
    if (mounted) clear();
  }

  void _digit(String d) {
    if (!widget.enabled || _pin.length >= _max) return;
    AppHaptics.pinDigit();
    setState(() {
      _error = false;
      _pin += d;
    });
    if (widget.length != null && _pin.length == widget.length) {
      widget.onCompleted(_pin);
    }
  }

  void _backspace() {
    if (!widget.enabled || _pin.isEmpty) return;
    AppHaptics.key();
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  void _confirm() {
    if (!widget.enabled || _pin.length < widget.minLength) return;
    widget.onCompleted(_pin);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final ColorScheme cs = Theme.of(context).colorScheme;
    final AppColors colors = AppColors.of(context);
    final int dots =
        widget.length ??
        math.max(widget.minLength, math.min(_pin.length + 1, widget.maxLength));

    Widget dot(int i) {
      final bool filled = i < _pin.length;
      final Color c = _error ? colors.danger : cs.primary;
      // The ring stays; the fill scales 0 → 1 in 150ms (DESIGN.md §11.5).
      return AnimatedContainer(
        duration: AppMotion.of(context, AppMotion.state),
        width: AppSizes.pinDot,
        height: AppSizes.pinDot,
        margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: _error ? c : (filled ? c : cs.outline),
            width: 2,
          ),
        ),
        child: AnimatedScale(
          scale: filled || _error ? 1 : 0,
          duration: AppMotion.of(context, AppMotion.state),
          curve: AppMotion.standard,
          child: DecoratedBox(
            decoration: BoxDecoration(shape: BoxShape.circle, color: c),
          ),
        ),
      );
    }

    final bool showConfirm = widget.length == null;
    final Widget leftKey = showConfirm
        ? _PinKey(
            semanticLabel: l.confirm,
            onTap: _pin.length >= widget.minLength ? _confirm : null,
            filled: true,
            child: const Icon(Icons.check),
          )
        : widget.onBiometric != null
        ? _PinKey(
            semanticLabel: l.useFingerprint,
            onTap: widget.enabled ? widget.onBiometric : null,
            child: const Icon(Icons.fingerprint, size: 32),
          )
        : const SizedBox(width: AppSizes.pinKey, height: AppSizes.pinKey);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        AnimatedBuilder(
          animation: _shake,
          builder: (BuildContext context, Widget? child) => Transform.translate(
            offset: Offset(math.sin(_shake.value * math.pi * 6) * 8, 0),
            child: child,
          ),
          child: Semantics(
            liveRegion: true,
            label: l.pinDigitsEntered(_pin.length, dots),
            child: ExcludeSemantics(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List<Widget>.generate(dots, dot),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        for (final List<String> row in const <List<String>>[
          <String>['1', '2', '3'],
          <String>['4', '5', '6'],
          <String>['7', '8', '9'],
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.lg),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                for (int i = 0; i < row.length; i++) ...<Widget>[
                  if (i > 0) const SizedBox(width: AppSpacing.xl),
                  _PinKey(
                    semanticLabel: row[i],
                    onTap: widget.enabled ? () => _digit(row[i]) : null,
                    child: Text(row[i]),
                  ),
                ],
              ],
            ),
          ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            leftKey,
            const SizedBox(width: AppSpacing.xl),
            _PinKey(
              semanticLabel: '0',
              onTap: widget.enabled ? () => _digit('0') : null,
              child: const Text('0'),
            ),
            const SizedBox(width: AppSpacing.xl),
            _PinKey(
              semanticLabel: l.backspace,
              onTap: widget.enabled ? _backspace : null,
              plain: true,
              child: const Icon(Icons.backspace_outlined),
            ),
          ],
        ),
      ],
    );
  }
}

class _PinKey extends StatelessWidget {
  const _PinKey({
    required this.child,
    required this.semanticLabel,
    required this.onTap,
    this.filled = false,
    this.plain = false,
  });

  final Widget child;
  final String semanticLabel;
  final VoidCallback? onTap;
  final bool filled;
  final bool plain;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final bool enabled = onTap != null;
    final Color bg = plain
        ? Colors.transparent
        : filled
        ? (enabled ? cs.primary : cs.surfaceContainerHighest)
        : cs.surfaceContainerHigh;
    final Color fg = filled
        ? (enabled ? cs.onPrimary : cs.onSurfaceVariant)
        : (enabled ? cs.onSurface : cs.onSurface.withValues(alpha: 0.38));
    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticLabel,
      excludeSemantics: true,
      child: PressScale(
        scale: AppMotion.pressScaleKey,
        enabled: enabled,
        child: Material(
          color: bg,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: AppSizes.pinKey,
              height: AppSizes.pinKey,
              child: Center(
                child: IconTheme.merge(
                  data: IconThemeData(color: fg),
                  child: DefaultTextStyle.merge(
                    style: Theme.of(context).textTheme.headlineMedium
                        ?.copyWith(color: fg),
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
