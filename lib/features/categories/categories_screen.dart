import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router.dart';
import '../../core/widgets.dart';
import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';
import '../settings/settings_controller.dart';

/// Categories by type with usage counts (DESIGN.md §7.6).
class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return DefaultTabController(
      length: 2,
      child: Builder(
        builder: (BuildContext context) => Scaffold(
          appBar: AppBar(
            title: Text(l.categories),
            actions: <Widget>[
              IconButton(
                tooltip: l.newCategory,
                icon: const Icon(Icons.add),
                onPressed: () {
                  final int tab = DefaultTabController.of(context).index;
                  context.push(Routes.newCategory(
                    tab == 0 ? CategoryType.expense : CategoryType.income,
                  ));
                },
              ),
            ],
            bottom: TabBar(
              tabs: <Widget>[
                Tab(text: l.txTypeExpense),
                Tab(text: l.txTypeIncome),
              ],
            ),
          ),
          body: const TabBarView(
            children: <Widget>[
              _CategoryList(type: CategoryType.expense),
              _CategoryList(type: CategoryType.income),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryList extends ConsumerWidget {
  const _CategoryList({required this.type});

  final CategoryType type;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l = AppLocalizations.of(context);
    final String lang = ref.watch(languageProvider);
    final Map<int, int> usage = ref.watch(categoryUsageProvider).value ?? const <int, int>{};
    final AsyncValue<List<TxCategory>> data =
        ref.watch(categoriesProvider((type: type, includeArchived: true)));

    return data.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (Object e, _) => Center(child: Text(l.genericError)),
      data: (List<TxCategory> all) {
        final List<TxCategory> active = all.where((TxCategory c) => !c.isArchived).toList();
        final List<TxCategory> archived = all.where((TxCategory c) => c.isArchived).toList();
        if (all.isEmpty) {
          return EmptyState(
            icon: Icons.category_outlined,
            title: l.emptyCategoriesTitle,
            actionLabel: l.newCategory,
            onAction: () => context.push(Routes.newCategory(type)),
          );
        }
        Widget tile(TxCategory c) => ListTile(
              leading: CategoryAvatar.category(c),
              title: Text(c.localizedName(lang)),
              subtitle: Text(l.transactionCount(usage[c.id] ?? 0)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(Routes.editCategory(c.id)),
            );
        return ListView(
          children: <Widget>[
            for (final TxCategory c in active) tile(c),
            if (archived.isNotEmpty)
              ExpansionTile(
                title: Text(l.archivedCount(archived.length)),
                children: <Widget>[for (final TxCategory c in archived) tile(c)],
              ),
          ],
        );
      },
    );
  }
}
