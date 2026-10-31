import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format.dart';
import '../../../core/router.dart';
import '../../../core/theme.dart';
import '../../../core/widgets.dart';
import '../../../data/providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../holdings/holding_sheets.dart' show holdingErrorText;
import '../../settings/settings_controller.dart';

/// Opens the transaction detail sheet (DESIGN.md §18.4.3).
Future<void> showTxDetailSheet(BuildContext context, TxDetails item) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext ctx) => TxDetailSheet(item: item),
    );

/// Deletes [id] with its linked partner and offers undo for all of them.
Future<void> deleteTransactionWithUndo({
  required WidgetRef ref,
  required ScaffoldMessengerState messenger,
  required AppLocalizations l,
  required int id,
  VoidCallback? onRestored,
  VoidCallback? onFailed,
}) async {
  final TransactionRepository repo = ref.read(transactionRepositoryProvider);
  final DeletedTransactions deleted;
  try {
    deleted = await repo.deleteWithLinked(id);
  } on HoldingAmountException catch (e) {
    onFailed?.call();
    messenger.showSnackBar(SnackBar(content: Text(holdingErrorText(l, e.reason))));
    return;
  }
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(SnackBar(
    content: Text(deleted.isPair ? l.pairDeleted : l.transactionDeleted),
    action: SnackBarAction(
      label: l.undo,
      onPressed: () async {
        try {
          await repo.restoreDeleted(deleted);
        } on HoldingAmountException catch (e) {
          messenger.showSnackBar(SnackBar(content: Text(holdingErrorText(l, e.reason))));
          return;
        }
        onRestored?.call();
      },
    ),
  ));
}

class TxDetailSheet extends ConsumerWidget {
  const TxDetailSheet({super.key, required this.item});

  final TxDetails item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l = AppLocalizations.of(context);
    final String lang = ref.watch(languageProvider);
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final AppColors colors = AppColors.of(context);
    final MoneyTx tx = item.tx;
    final TxDetails? loss = item.linkedLoss;
    final String currency = item.account.currency;
    final ResolvedFares? fares = ref.watch(resolvedFaresProvider).value;

    final String title = item.moveLabel ??
        item.category?.localizedName(lang) ??
        l.uncategorized;
    final Widget avatar = item.tx.type.isMove || item.category == null
        ? Container(
            width: AppSizes.categoryAvatar,
            height: AppSizes.categoryAvatar,
            decoration: BoxDecoration(color: colors.transferContainer, shape: BoxShape.circle),
            child: Icon(item.tx.type.isMove ? Icons.swap_horiz : Icons.help_outline, color: colors.transfer, size: 20),
          )
        : CategoryAvatar.category(item.category!);

    Widget row(String label, String value) => ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Row(
            children: <Widget>[
              SizedBox(
                width: 120,
                child: Text(label, style: theme.textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant)),
              ),
              Expanded(child: Text(value, style: theme.textTheme.bodyLarge)),
            ],
          ),
        );

    String? routeText;
    final TransportMode? mode = tx.transportMode;
    if (mode != null) {
      final String? code = tx.routeCode;
      if (mode == TransportMode.bus && code != null) {
        final String label = fares?.busRoute(code)?.label ?? '';
        routeText = label.isEmpty ? code : '$code · $label';
      } else {
        routeText = transportChipText(l, mode, code, 1);
      }
      if (tx.trips > 1) routeText = '$routeText · ${l.tripsCount(tx.trips)}';
    }

    final bool edited = tx.updatedAt != null && tx.updatedAt!.difference(tx.createdAt).inSeconds > 60;
    final bool holdingMove = tx.type.isHoldingMove;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              children: <Widget>[
                avatar,
                const SizedBox(width: AppSpacing.md),
                Expanded(child: Text(title, style: theme.textTheme.titleLarge)),
                Text(
                  Fmt.signed(tx.amount, currency, tx.type, lang),
                  style: AppTextStyles.amountDetail.copyWith(color: txTypeColor(context, tx.type)),
                ),
              ],
            ),
            if (mode != null)
              Padding(
                padding: const EdgeInsets.only(left: AppSizes.categoryAvatar + AppSpacing.md, top: AppSpacing.xs),
                child: TransportChip(mode: mode, route: tx.routeCode, trips: tx.trips),
              ),
            const Divider(height: AppSpacing.xl),
            row(l.date, Fmt.longDate(tx.date, lang)),
            row(l.time, Fmt.time(tx.date, lang)),
            if (tx.type == TxType.transfer) ...<Widget>[
              row(l.fromAccount, item.account.name),
              row(l.toAccount, item.toAccount?.name ?? '?'),
            ] else if (holdingMove)
              row(tx.type == TxType.toHolding ? l.fromAccount : l.toAccount, item.account.name)
            else
              row(l.account, item.account.name),
            if (loss != null) ...<Widget>[
              row(l.amountSent, Fmt.money(item.sentAmount, currency, lang)),
              row(l.amountReceived, Fmt.money(tx.amount, currency, lang)),
              row(l.bonusLossLabel, Fmt.signed(loss.tx.amount, currency, TxType.expense, lang)),
            ],
            if (tx.toAmount != null && tx.type.isMove)
              row(l.amountReceived, Fmt.money(tx.toAmount!, item.toAccount?.currency ?? item.holding?.currency ?? currency, lang)),
            if (routeText != null) row(l.busRoute, routeText),
            if (tx.note.trim().isNotEmpty) row(l.note, tx.note.trim()),
            const Divider(height: AppSpacing.xl),
            Text(
              l.addedAt(Fmt.dateTime(tx.createdAt, lang)),
              style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            if (edited)
              Text(
                l.editedAt(Fmt.dateTime(tx.updatedAt!, lang)),
                style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: <Widget>[
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: colors.danger, minimumSize: const Size(48, 48)),
                  onPressed: holdingMove
                      ? null
                      : () async {
                          final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
                          Navigator.of(context).pop();
                          await deleteTransactionWithUndo(ref: ref, messenger: messenger, l: l, id: tx.id);
                        },
                  child: Text(l.delete),
                ),
                if (!holdingMove)
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
                    onPressed: () {
                      Navigator.of(context).pop();
                      context.push(Routes.duplicateTransaction(tx.id));
                    },
                    child: Text(l.duplicate),
                  ),
                FilledButton(
                  style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
                  onPressed: () {
                    Navigator.of(context).pop();
                    if (holdingMove && item.holding != null) {
                      context.push(Routes.holding(item.holding!.id));
                    } else {
                      context.push(Routes.editTransaction(tx.id));
                    }
                  },
                  child: Text(l.edit),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
