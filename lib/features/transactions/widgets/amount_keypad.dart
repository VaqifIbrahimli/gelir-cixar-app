import 'package:flutter/material.dart';

import '../../../core/format.dart';
import '../../../core/motion.dart';
import '../../../core/theme.dart';
import '../../../l10n/app_localizations.dart';

/// 4×4 calculator keypad (DESIGN.md §6.5). Long-press "+" for ×, "−" for ÷,
/// "⌫" to clear.
class AmountKeypad extends StatelessWidget {
  const AmountKeypad({
    super.key,
    required this.decimalLabel,
    required this.checkIsEquals,
    required this.onDigit,
    required this.onDoubleZero,
    required this.onDecimal,
    required this.onOperator,
    required this.onBackspace,
    required this.onClear,
    required this.onCheck,
    this.showOperators = true,
    this.checkEnabled = true,
  });

  /// False for plain amounts (holding adjust sheet): the + / − keys go.
  final bool showOperators;

  /// ✓ drawn disabled (still tappable, so the caller can shake on it).
  final bool checkEnabled;

  final String decimalLabel;
  final bool checkIsEquals;
  final ValueChanged<String> onDigit;
  final VoidCallback onDoubleZero;
  final VoidCallback onDecimal;
  final ValueChanged<String> onOperator;
  final VoidCallback onBackspace;
  final VoidCallback onClear;
  final VoidCallback onCheck;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final ColorScheme cs = Theme.of(context).colorScheme;

    Widget digit(String d) =>
        _Key(label: d, semantics: d, onTap: () => onDigit(d));

    Widget row(List<Widget> keys) => Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: <Widget>[
          for (int i = 0; i < keys.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(width: AppSpacing.sm),
            Expanded(child: keys[i]),
          ],
        ],
      ),
    );

    return Container(
      color: cs.surfaceContainerLow,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.xs,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          row(<Widget>[
            digit('1'),
            digit('2'),
            digit('3'),
            _Key(
              icon: Icons.backspace_outlined,
              semantics: l.backspace,
              tooltip: l.backspaceHint,
              onTap: onBackspace,
              onLongPress: () {
                AppHaptics.longPress();
                onClear();
              },
            ),
          ]),
          row(<Widget>[
            digit('4'),
            digit('5'),
            digit('6'),
            if (!showOperators)
              const SizedBox.shrink()
            else
              _Key(
                label: '+',
                semantics: l.plus,
                tooltip: l.plusHint,
                onTap: () => onOperator('+'),
                onLongPress: () => onOperator('*'),
              ),
          ]),
          row(<Widget>[
            digit('7'),
            digit('8'),
            digit('9'),
            if (!showOperators)
              const SizedBox.shrink()
            else
              _Key(
                label: Fmt.minus,
                semantics: l.minus,
                tooltip: l.minusHint,
                onTap: () => onOperator('-'),
                onLongPress: () => onOperator('/'),
              ),
          ]),
          row(<Widget>[
            _Key(
              label: decimalLabel,
              semantics: l.decimalPoint,
              onTap: onDecimal,
            ),
            digit('0'),
            _Key(label: '00', semantics: '00', onTap: onDoubleZero),
            _Key(
              icon: checkIsEquals ? null : Icons.check,
              label: checkIsEquals ? '=' : null,
              semantics: checkIsEquals ? l.equals : l.save,
              onTap: onCheck,
              primary: true,
              dimmed: !checkEnabled,
            ),
          ]),
        ],
      ),
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({
    required this.semantics,
    required this.onTap,
    this.label,
    this.icon,
    this.onLongPress,
    this.tooltip,
    this.primary = false,
    this.dimmed = false,
  });

  final bool dimmed;

  final String? label;
  final IconData? icon;
  final String semantics;
  final String? tooltip;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final Color bg = primary
        ? (dimmed ? cs.surfaceContainerHighest : cs.primary)
        : cs.surfaceContainerHigh;
    final Color fg = primary
        ? (dimmed ? cs.onSurfaceVariant : cs.onPrimary)
        : cs.onSurface;
    final Widget key = Semantics(
      button: true,
      label: semantics,
      excludeSemantics: true,
      child: Material(
        color: bg,
        borderRadius: AppRadius.brLg,
        child: InkWell(
          borderRadius: AppRadius.brLg,
          onTap: onTap,
          onLongPress: onLongPress,
          child: SizedBox(
            height: AppSizes.keypadKeyHeight,
            child: Center(
              child: icon != null
                  ? Icon(icon, color: fg)
                  : Text(
                      label ?? '',
                      style: theme.textTheme.headlineSmall?.copyWith(color: fg),
                    ),
            ),
          ),
        ),
      ),
    );
    final Widget pressable = PressScale(
      scale: AppMotion.pressScaleKey,
      child: key,
    );
    return tooltip == null
        ? pressable
        : Tooltip(message: tooltip, child: pressable);
  }
}
