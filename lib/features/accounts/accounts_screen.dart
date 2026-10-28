import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/motion.dart';
import '../../core/router.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';
import '../settings/settings_controller.dart';

/// Accounts list with balances (DESIGN.md §7.5).
class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l = AppLocalizations.of(context);
    final String lang = ref.watch(languageProvider);
    final AsyncValue<List<AccountWithBalance>> data = ref.watch(
      allAccountBalancesProvider,
    );
    final int? total = ref.watch(totalBalanceProvider).value;
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.accounts),
        actions: <Widget>[
          IconButton(
            tooltip: l.addAccount,
            icon: const Icon(Icons.add),
            onPressed: () => context.push(Routes.newAccount),
          ),
        ],
      ),
      body: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, _) => Center(child: Text(l.genericError)),
        data: (List<AccountWithBalance> all) {
          final List<AccountWithBalance> active = all
              .where((AccountWithBalance a) => !a.account.isArchived)
              .toList();
          final List<AccountWithBalance> archived = all
              .where((AccountWithBalance a) => a.account.isArchived)
              .toList();
          if (all.isEmpty) {
            return EmptyState(
              icon: Icons.account_balance_wallet_outlined,
              title: l.emptyAccountsTitle,
              actionLabel: l.addAccount,
              onAction: () => context.push(Routes.newAccount),
            );
          }
          return ListView(
            padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.lg,
                  AppSpacing.lg,
                ),
                child: Text(
                  '${l.total}: ${total == null ? '…' : Fmt.base(total, lang)}',
                  style: theme.textTheme.headlineSmall?.merge(
                    AppTextStyles.tabular,
                  ),
                ),
              ),
              for (final AccountWithBalance a in active) _AccountCard(item: a),
              if (archived.isNotEmpty)
                ExpansionTile(
                  title: Text(l.archivedCount(archived.length)),
                  children: <Widget>[
                    for (final AccountWithBalance a in archived)
                      _AccountCard(item: a),
                  ],
                ),
              const _HoldingsLink(),
            ],
          );
        },
      ),
    );
  }
}

class _AccountCard extends ConsumerWidget {
  const _AccountCard({required this.item});

  final AccountWithBalance item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l = AppLocalizations.of(context);
    final String lang = ref.watch(languageProvider);
    final Rates rates = ref.watch(ratesProvider).value ?? Rates.defaults;
    final ThemeData theme = Theme.of(context);
    final Account a = item.account;
    final bool foreign = a.currency != Currency.base.code;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: PressScale(
        child: Material(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: AppRadius.brLg,
          child: InkWell(
            borderRadius: AppRadius.brLg,
            onTap: () => context.push(Routes.editAccount(a.id)),
            child: Padding(
              padding: AppSpacing.card,
              child: Row(
                children: <Widget>[
                  CategoryAvatar(
                    icon: accountTypeIcon(a.type),
                    colorIndex: a.colorIndex,
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          a.name,
                          style: theme.textTheme.titleMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          a.isArchived
                              ? '${accountTypeLabel(l, a.type)} · ${l.archived}'
                              : accountTypeLabel(l, a.type),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      Text(
                        Fmt.money(item.balance, a.currency, lang),
                        style: AppTextStyles.amountTile.copyWith(
                          color: item.balance < 0
                              ? AppColors.of(context).expense
                              : theme.colorScheme.onSurface,
                        ),
                      ),
                      if (foreign)
                        Text(
                          '≈ ${Fmt.base(rates.toBase(item.balance, a.currency), lang)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Entry point to Kənar yerlər at the bottom of Accounts (DESIGN.md §14.1).
class _HoldingsLink extends ConsumerWidget {
  const _HoldingsLink();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l = AppLocalizations.of(context);
    final String lang = ref.watch(languageProvider);
    final int? total = ref.watch(holdingsTotalProvider).value;
    final AppColors c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: c.holdingContainer,
          child: Icon(
            HoldingPlaceStyle.featureIcon,
            color: c.onHoldingContainer,
          ),
        ),
        title: Text(l.holdings),
        subtitle: Text(
          total == null || total == 0
              ? l.holdingsSubtitle
              : '${l.holdingsElsewhere}: ${Fmt.base(total, lang)}',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push(Routes.holdings),
      ),
    );
  }
}
