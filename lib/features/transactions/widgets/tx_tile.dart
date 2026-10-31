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

/// Transaction list tile (DESIGN.md §6.2, §18.4.2, §18.5.5, §18.6.3).
///
/// A bonus transfer whose loss row was grouped with it ([TxDetails.linkedLoss])
/// is drawn as one block: the transfer (arrived amount, "x sent") and a
/// child "Bonus itkisi" row joined by a connector line.
class TxTile extends ConsumerWidget {
  const TxTile({super.key, required this.item, this.onTap, this.showTime = false});

  final TxDetails item;
  final VoidCallback? onTap;

  /// Show only the time (lists grouped by day); otherwise "28 okt, 14:32".
  final bool showTime;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l = AppLocalizations.of(context);
    final String lang = ref.watch(languageProvider);
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final AppColors colors = AppColors.of(context);
    final TxType type = item.tx.type;
    final TxDetails? loss = item.linkedLoss;

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
    final String subtitle;
    if (loss != null) {
      subtitle = l.sentSubtitle(Fmt.money(item.sentAmount, item.account.currency, lang));
    } else if (type.isMove) {
      subtitle = note.isEmpty ? txTypeLabel(l, type) : note;
    } else {
      subtitle = note.isEmpty ? item.account.name : '${item.account.name} · $note';
    }
    final TransportMode? mode = item.tx.transportMode;

    final String amount = Fmt.signed(item.tx.amount, item.account.currency, type, lang);
    final String when = showTime
        ? Fmt.time(item.tx.date, lang)
        : '${Fmt.shortDate(item.tx.date, lang)}, ${Fmt.time(item.tx.date, lang)}';
    final String semanticAmount =
        '${txTypeLabel(l, type)} ${Fmt.money(item.tx.amount, item.account.currency, lang)}';
    final String lossSemantics = loss == null
        ? ''
        : ', ${l.bonusLoss(Fmt.money(loss.tx.amount, loss.account.currency, lang))}';
    final String transportSemantics =
        mode == null ? '' : ', ${transportChipText(l, mode, item.tx.routeCode, item.tx.trips)}';

    final TextStyle? subStyle = theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant);
    final Widget main = ConstrainedBox(
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
                  Text(title, style: theme.textTheme.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                  Row(
                    children: <Widget>[
                      if (mode != null) ...<Widget>[
                        Flexible(
                          flex: 0,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 140),
                            child: TransportChip(mode: mode, route: item.tx.routeCode, trips: item.tx.trips),
                          ),
                        ),
                        Text(' · ', style: subStyle),
                      ],
                      Expanded(
                        child: Text(subtitle, style: subStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Text(amount, style: AppTextStyles.amountTile.copyWith(color: txTypeColor(context, type))),
                if (item.tx.toAmount != null && type.isMove)
                  Text(
                    Fmt.money(
                      item.tx.toAmount!,
                      item.toAccount?.currency ?? item.holding?.currency ?? item.account.currency,
                      lang,
                    ),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: cs.onSurfaceVariant)
                        .merge(AppTextStyles.tabular),
                  )
                else
                  Text(
                    when,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: cs.onSurfaceVariant)
                        .merge(AppTextStyles.tabular),
                  ),
              ],
            ),
          ],
        ),
      ),
    );

    final Widget body = loss == null
        ? main
        : Container(
            margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
            decoration: BoxDecoration(color: cs.surfaceContainerLow, borderRadius: AppRadius.brMd),
            child: Column(
              children: <Widget>[
                main,
                _LossRow(amount: Fmt.signed(loss.tx.amount, loss.account.currency, TxType.expense, lang)),
              ],
            ),
          );

    return Semantics(
      button: onTap != null,
      label: '$title, $semanticAmount, $subtitle$transportSemantics$lossSemantics',
      excludeSemantics: true,
      child: InkWell(
        // Holding moves are edited from their holding (they are two linked
        // records), not in the transaction editor.
        onTap: type.isHoldingMove && item.holding != null
            ? () => context.push(Routes.holding(item.holding!.id))
            : onTap,
        child: body,
      ),
    );
  }
}

/// Child row of a grouped bonus transfer: "↘ Bonus itkisi   − 2,50 ₼".
class _LossRow extends StatelessWidget {
  const _LossRow({required this.amount});

  final String amount;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);
    final AppColors c = AppColors.of(context);
    return SizedBox(
      height: 48,
      child: Row(
        children: <Widget>[
          // Connector from the centre of the 40dp avatar above.
          SizedBox(
            width: AppSpacing.lg + AppSizes.categoryAvatar / 2 + 1,
            child: Align(
              alignment: Alignment.topRight,
              child: Container(width: 2, height: 24, color: theme.colorScheme.outlineVariant),
            ),
          ),
          Container(width: 12, height: 2, color: theme.colorScheme.outlineVariant),
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(color: c.warningContainer, shape: BoxShape.circle),
            child: Icon(Icons.trending_down, size: 16, color: c.onWarningContainer),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(l.bonusLossLabel, style: theme.textTheme.bodyMedium)),
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.lg),
            child: Text(amount, style: theme.textTheme.labelLarge?.copyWith(color: c.warning).merge(AppTextStyles.tabular)),
          ),
        ],
      ),
    );
  }
}
