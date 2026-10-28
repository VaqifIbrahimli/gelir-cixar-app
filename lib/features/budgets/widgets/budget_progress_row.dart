import 'package:flutter/material.dart';

import '../../../core/format.dart';
import '../../../core/theme.dart';
import '../../../core/widgets.dart';
import '../../../data/models.dart';
import '../../../data/database.dart';
import '../../../l10n/app_localizations.dart';

/// Animated budget bar coloured by state (DESIGN.md §2.2, §6.4).
class BudgetBar extends StatelessWidget {
  const BudgetBar({super.key, required this.ratio, required this.normalColor});

  final double ratio;
  final Color normalColor;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final BudgetState state = AppColors.budgetState(ratio, 1);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: ratio.clamp(0.0, 1.0)),
      duration: AppDurations.of(context, AppDurations.slow),
      curve: Curves.easeOutCubic,
      builder: (BuildContext context, double v, _) => ClipRRect(
        borderRadius: AppRadius.brXs,
        child: LinearProgressIndicator(
          value: v,
          minHeight: AppSizes.progressHeight,
          color: c.budgetFill(state, normalColor),
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        ),
      ),
    );
  }
}

/// One budget: name + percentage, bar, spent / limit and remaining.
class BudgetProgressRow extends StatelessWidget {
  const BudgetProgressRow({
    super.key,
    required this.progress,
    required this.category,
    required this.lang,
    this.onTap,
  });

  final BudgetProgress progress;
  final TxCategory? category;
  final String lang;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final AppColors c = AppColors.of(context);
    final BudgetProgress p = progress;
    final BudgetState state = AppColors.budgetState(p.spent.toDouble(), p.limit.toDouble());
    final int pct = (p.ratio * 100).round();
    final String name = category?.localizedName(lang) ?? l.category;
    final Color normal = category == null ? cs.primary : c.category(category!.colorIndex);
    final Color stateText = c.budgetText(state, cs.onSurfaceVariant);

    final String stateWord = switch (state) {
      BudgetState.normal => '',
      BudgetState.warning => ', ${l.budgetStateWarning}',
      BudgetState.danger => ', ${l.budgetStateOver}',
    };

    return Semantics(
      button: onTap != null,
      label: '${l.budgetSemantics(name, pct)}$stateWord',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: AppSpacing.tile,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  if (category != null) CategoryAvatar.category(category!, size: 24),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      name,
                      style: theme.textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '$pct%',
                    style: theme.textTheme.labelLarge
                        ?.merge(AppTextStyles.tabular)
                        .copyWith(color: stateText),
                  ),
                  if (state != BudgetState.normal) ...<Widget>[
                    const SizedBox(width: AppSpacing.xs),
                    Icon(
                      state == BudgetState.danger ? Icons.error_outline : Icons.warning_amber,
                      size: 18,
                      color: stateText,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              BudgetBar(ratio: p.ratio, normalColor: normal),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      '${Fmt.base(p.spent, lang)} / ${Fmt.base(p.limit, lang)}',
                      style: theme.textTheme.bodySmall
                          ?.merge(AppTextStyles.tabular)
                          .copyWith(color: cs.onSurfaceVariant),
                    ),
                  ),
                  Text(
                    p.remaining >= 0
                        ? l.budgetRemaining(Fmt.base(p.remaining, lang))
                        : l.budgetOverBy(Fmt.base(-p.remaining, lang)),
                    style: theme.textTheme.bodySmall?.merge(AppTextStyles.tabular).copyWith(
                          color: p.remaining >= 0 ? cs.onSurfaceVariant : c.danger,
                        ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
