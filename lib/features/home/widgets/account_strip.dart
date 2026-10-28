import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format.dart';
import '../../../core/motion.dart';
import '../../../core/router.dart';
import '../../../core/theme.dart';
import '../../../core/widgets.dart';
import '../../../data/providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../settings/settings_controller.dart';

/// Horizontal list of account chips with balances.
class AccountStrip extends ConsumerWidget {
  const AccountStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l = AppLocalizations.of(context);
    final String lang = ref.watch(languageProvider);
    final bool hidden = ref.watch(settingsProvider).hideBalance;
    final List<AccountWithBalance> accounts =
        ref.watch(accountBalancesProvider).value ??
        const <AccountWithBalance>[];
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SectionHeader(
          l.accounts,
          trailing: TextButton(
            onPressed: () => context.push(Routes.accounts),
            child: Text(l.seeAll),
          ),
        ),
        SizedBox(
          height: 72,
          child: ListView.separated(
            padding: AppSpacing.screen,
            scrollDirection: Axis.horizontal,
            itemCount: accounts.length + 1,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
            itemBuilder: (BuildContext context, int i) {
              if (i == accounts.length) {
                return ChipCard(
                  onTap: () => context.push(Routes.newAccount),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(Icons.add, color: theme.colorScheme.primary),
                      const SizedBox(width: AppSpacing.xs),
                      Text(l.addAccount, style: theme.textTheme.labelLarge),
                    ],
                  ),
                );
              }
              final AccountWithBalance a = accounts[i];
              return ChipCard(
                onTap: () => context.push(Routes.editAccount(a.account.id)),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: AppColors.of(context)
                                .category(a.account.colorIndex),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 140),
                          child: Text(
                            a.account.name,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      hidden
                          ? Fmt.masked(a.account.currency, lang)
                          : Fmt.money(a.balance, a.account.currency, lang),
                      style: AppTextStyles.amountTile.copyWith(
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class ChipCard extends StatelessWidget {
  const ChipCard({super.key, required this.child, required this.onTap});

  final Widget child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: AppRadius.brLg,
        child: InkWell(
          borderRadius: AppRadius.brLg,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 120),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Center(widthFactor: 1, child: child),
            ),
          ),
        ),
      ),
    );
  }
}
