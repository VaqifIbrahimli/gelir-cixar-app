import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format.dart';
import '../../../core/router.dart';
import '../../../core/theme.dart';
import '../../../core/widgets.dart';
import '../../../data/models.dart';
import '../../../l10n/app_localizations.dart';
import '../../settings/settings_controller.dart';

/// Transaction list tile (DESIGN.md §6.2).
class TxTile extends ConsumerWidget {
  const TxTile({super.key, required this.item, this.onTap, this.showTime = false});

  final TxDetails item;
  final VoidCallback? onTap;

  /// Show the time instead of the date (lists grouped by day).
  final bool showTime;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l = AppLocalizations.of(context);
    final String lang = ref.watch(languageProvider);
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final AppColors colors = AppColors.of(context);
    final TxType type = item.tx.type;

    final Widget avatar;
    final String title;
    if (type.isMove) {
      avatar = ExcludeSemantics(
        child: Container(
          width: AppSizes.categoryAvatar,
          height: AppSizes.categoryAvatar,
          decoration: BoxDecoration(
            color: type.isHoldingMove ? colors.holdingContainer : colors.transferContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(
            type.isHoldingMove
                ? (item.holding == null
                    ? HoldingPlaceStyle.featureIcon
                    : HoldingPlaceStyle.forPlace(item.holding!.placeType).icon)
                : Icons.swap_horiz,
            color: type.isHoldingMove ? colors.onHoldingContainer : colors.transfer,
            size: 20,
          ),
        ),
      );
      title = item.moveLabel!;
    } else if (item.category != null) {
      avatar = CategoryAvatar.category(item.category!);
      title = item.category!.localizedName(lang);
    } else {
      avatar = const CategoryAvatar(icon: Icons.help_outline, colorIndex: 7);
      title = l.uncategorized;
    }

    final String note = item.tx.note.trim();
    final String subtitle = type.isMove
        ? (note.isEmpty ? txTypeLabel(l, type) : note)
        : (note.isEmpty ? item.account.name : '${item.account.name} · $note');

    final String amount =
        Fmt.signed(item.tx.amount, item.account.currency, type, lang);
    final String semanticAmount =
        '${txTypeLabel(l, type)} ${Fmt.money(item.tx.amount, item.account.currency, lang)}';

    return Semantics(
      button: onTap != null,
      label: '$title, $semanticAmount, $subtitle',
      excludeSemantics: true,
      child: InkWell(
        // Holding moves are edited from their holding (they are two linked
        // records), not in the transaction editor.
        onTap: type.isHoldingMove && item.holding != null
            ? () => context.push(Routes.holding(item.holding!.id))
            : onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSizes.tileMinHeight),
          child: Padding(
            padding: AppSpacing.tile,
            child: Row(
              children: <Widget>[
                avatar,
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: theme.textTheme.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: cs.onSurfaceVariant),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Text(
                      amount,
                      style: AppTextStyles.amountTile
                          .copyWith(color: txTypeColor(context, type)),
                    ),
                    if (item.tx.toAmount != null && type.isMove)
                      Text(
                        Fmt.money(
                          item.tx.toAmount!,
                          item.toAccount?.currency ??
                              item.holding?.currency ??
                              item.account.currency,
                          lang,
                        ),
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: cs.onSurfaceVariant)
                            .merge(AppTextStyles.tabular),
                      )
                    else
                      Text(
                        showTime
                            ? Fmt.time(item.tx.date, lang)
                            : Fmt.date(item.tx.date, lang),
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: cs.onSurfaceVariant),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
