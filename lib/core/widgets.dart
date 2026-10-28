import 'package:flutter/material.dart';

import '../data/database.dart';
import '../l10n/app_localizations.dart';
import 'category_icons.dart';
import 'theme.dart';

/// Centred empty state (DESIGN.md §6.6).
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.body,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? body;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: AppSizes.emptyStateIconCircle,
              height: AppSizes.emptyStateIconCircle,
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 48, color: cs.onPrimaryContainer),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              title,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (body != null) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 280),
                child: Text(
                  body!,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: cs.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
            if (actionLabel != null && onAction != null) ...<Widget>[
              const SizedBox(height: AppSpacing.xl),
              FilledButton.tonal(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Filled colour circle with a white glyph (DESIGN.md §2.3).
class CategoryAvatar extends StatelessWidget {
  const CategoryAvatar({
    super.key,
    required this.icon,
    required this.colorIndex,
    this.size = AppSizes.categoryAvatar,
  });

  CategoryAvatar.category(TxCategory c, {Key? key, double size = AppSizes.categoryAvatar})
      : this(
          key: key,
          icon: CategoryIcons.byCodePoint(c.iconCodePoint),
          colorIndex: c.colorIndex,
          size: size,
        );

  final IconData icon;
  final int colorIndex;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.of(context).category(colorIndex),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: size * 0.5, color: Colors.white),
      ),
    );
  }
}

/// Section header (titleSmall in primary), used in Settings and forms.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                text,
                style: theme.textTheme.titleSmall
                    ?.copyWith(color: theme.colorScheme.primary),
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Icons for account types.
IconData accountTypeIcon(AccountType t) => switch (t) {
      AccountType.cash => Icons.payments_outlined,
      AccountType.card => Icons.credit_card,
      AccountType.bank => Icons.account_balance_outlined,
      AccountType.savings => Icons.savings_outlined,
    };

String accountTypeLabel(AppLocalizations l, AccountType t) => switch (t) {
      AccountType.cash => l.accountTypeCash,
      AccountType.card => l.accountTypeCard,
      AccountType.bank => l.accountTypeBank,
      AccountType.savings => l.accountTypeSavings,
    };

/// Icons and labels for "Kənar yerlər" place types.
IconData holdingPlaceIcon(HoldingPlace p) => HoldingPlaceStyle.forPlace(p).icon;

String holdingPlaceLabel(AppLocalizations l, HoldingPlace p) => switch (p) {
      HoldingPlace.homeCash => l.holdingPlaceHomeCash,
      HoldingPlace.person => l.holdingPlacePerson,
      HoldingPlace.bankDeposit => l.holdingPlaceBankDeposit,
      HoldingPlace.gold => l.holdingPlaceGold,
      HoldingPlace.other => l.holdingPlaceOther,
    };

String holdingEntryKindLabel(AppLocalizations l, HoldingEntryKind k) => switch (k) {
      HoldingEntryKind.add => l.holdingEntryAdd,
      HoldingEntryKind.withdraw => l.holdingEntryWithdraw,
      HoldingEntryKind.setValue => l.holdingEntrySetValue,
    };

String txTypeLabel(AppLocalizations l, TxType t) => switch (t) {
      TxType.income => l.txTypeIncome,
      TxType.expense => l.txTypeExpense,
      TxType.transfer => l.txTypeTransfer,
      TxType.toHolding => l.txTypeToHolding,
      TxType.fromHolding => l.txTypeFromHolding,
    };

/// Semantic colour for a transaction type.
Color txTypeColor(BuildContext context, TxType t) {
  final AppColors c = AppColors.of(context);
  return switch (t) {
    TxType.income => c.income,
    TxType.expense => c.expense,
    TxType.transfer => c.transfer,
    TxType.toHolding || TxType.fromHolding => c.holding,
  };
}

/// Yes/no confirmation dialog. Returns true on confirm.
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  String? message,
  required String confirmLabel,
  bool destructive = false,
}) async {
  final AppLocalizations l = AppLocalizations.of(context);
  final bool? r = await showDialog<bool>(
    context: context,
    builder: (BuildContext ctx) {
      final ColorScheme cs = Theme.of(ctx).colorScheme;
      return AlertDialog(
        title: Text(title),
        content: message == null ? null : Text(message),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l.cancel),
          ),
          FilledButton(
            style: destructive
                ? FilledButton.styleFrom(
                    backgroundColor: cs.error,
                    foregroundColor: cs.onError,
                  )
                : null,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );
  return r ?? false;
}

/// 12-swatch palette row with a ring on the selected colour (DESIGN.md §7.6).
class ColorPalettePicker extends StatelessWidget {
  const ColorPalettePicker({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final AppColors c = AppColors.of(context);
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: <Widget>[
        for (int i = 0; i < c.categorical.length; i++)
          Semantics(
            button: true,
            selected: i == selected,
            label: l.colorN(i + 1),
            excludeSemantics: true,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => onChanged(i),
              child: Container(
                width: AppSizes.minTouch,
                height: AppSizes.minTouch,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: i == selected ? cs.primary : Colors.transparent,
                    width: 3,
                  ),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: c.categorical[i],
                    shape: BoxShape.circle,
                  ),
                  child: i == selected
                      ? const Icon(Icons.check, color: Colors.white, size: 18)
                      : null,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Place-type avatar (DESIGN.md §14.2): palette colour circle, white icon.
class PlaceAvatar extends StatelessWidget {
  const PlaceAvatar({super.key, required this.place, this.size = AppSizes.holdingAvatar});

  final HoldingPlace place;
  final double size;

  @override
  Widget build(BuildContext context) {
    final HoldingPlaceStyle st = HoldingPlaceStyle.forPlace(place);
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: st.color(AppColors.of(context)), shape: BoxShape.circle),
        child: Icon(st.icon, size: size * 0.5, color: Colors.white),
      ),
    );
  }
}

/// Small rounded status pill (deposit maturity, "matured", etc.).
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.text,
    required this.background,
    required this.foreground,
    this.icon,
  });

  final String text;
  final Color background;
  final Color foreground;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
      decoration: BoxDecoration(color: background, borderRadius: AppRadius.brFull),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 14, color: foreground),
            const SizedBox(width: AppSpacing.xxs),
          ],
          Flexible(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: foreground),
            ),
          ),
        ],
      ),
    );
  }
}

/// Days until a deposit matures (negative once matured), or null.
int? daysToMaturity(DateTime? maturity, [DateTime? now]) {
  if (maturity == null) return null;
  final DateTime n = now ?? DateTime.now();
  final DateTime today = DateTime(n.year, n.month, n.day);
  final DateTime m = DateTime(maturity.year, maturity.month, maturity.day);
  return m.difference(today).inDays;
}
