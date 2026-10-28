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
import '../holdings/holding_sheets.dart' show holdingErrorText;
import 'tx_filter_controller.dart';
import 'widgets/tx_tile.dart';

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

/// A row of the grouped list: either a day header or a transaction.
sealed class _Row {}

class _DayRow extends _Row {
  _DayRow(this.day, this.net);
  final DateTime day;
  final int net;
}

class _TxRow extends _Row {
  _TxRow(this.item);
  final TxDetails item;
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  final TextEditingController _search = TextEditingController();
  bool _searching = false;

  /// Rows swiped away whose delete has not reached the stream yet.
  final Set<int> _dismissed = <int>{};

  /// Every row removed by a swipe (kept so its removal isn't animated twice).
  final Set<int> _swiped = <int>{};

  @override
  void initState() {
    super.initState();
    _search.text = ref.read(txFilterProvider).query;
    _searching = _search.text.isNotEmpty;
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<_Row> _group(List<TxDetails> items, Rates rates) {
    final List<_Row> rows = <_Row>[];
    _DayRow? header;
    int headerIndex = -1;
    int net = 0;
    for (final TxDetails t in items) {
      if (_dismissed.contains(t.tx.id)) continue;
      final DateTime d = DateTime(t.tx.date.year, t.tx.date.month, t.tx.date.day);
      if (header == null || header.day != d) {
        if (header != null) rows[headerIndex] = _DayRow(header.day, net);
        net = 0;
        header = _DayRow(d, 0);
        headerIndex = rows.length;
        rows.add(header);
      }
      final int v = rates.toBase(t.tx.amount, t.account.currency);
      if (t.tx.type == TxType.income) net += v;
      if (t.tx.type == TxType.expense) net -= v;
      rows.add(_TxRow(t));
    }
    if (header != null) rows[headerIndex] = _DayRow(header.day, net);
    return rows;
  }

  Future<void> _delete(TxDetails item) async {
    final AppLocalizations l = AppLocalizations.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final TransactionRepository repo = ref.read(transactionRepositoryProvider);
    AppHaptics.confirm();
    _swiped.add(item.tx.id);
    setState(() => _dismissed.add(item.tx.id));
    final List<HoldingEntry> linked;
    try {
      linked = await repo.delete(item.tx.id);
    } on HoldingAmountException catch (e) {
      // Deleting this move would take its holding below zero: bring it back.
      _swiped.remove(item.tx.id);
      if (mounted) setState(() => _dismissed.remove(item.tx.id));
      messenger.showSnackBar(SnackBar(content: Text(holdingErrorText(l, e.reason))));
      return;
    }
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(l.transactionDeleted),
        action: SnackBarAction(
          label: l.undo,
          onPressed: () async {
            try {
              await repo.restore(item.tx, entries: linked);
            } on HoldingAmountException catch (e) {
              messenger.showSnackBar(SnackBar(content: Text(holdingErrorText(l, e.reason))));
              return;
            }
            _swiped.remove(item.tx.id);
            if (mounted) setState(() => _dismissed.remove(item.tx.id));
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final String lang = ref.watch(languageProvider);
    final TxFilter filter = ref.watch(txFilterProvider);
    final AsyncValue<List<TxDetails>> data =
        ref.watch(transactionsProvider(filter));
    final Rates rates = ref.watch(ratesProvider).value ?? Rates.defaults;
    final ThemeData theme = Theme.of(context);

    // Forget dismissed ids once the stream no longer contains them.
    final List<TxDetails> items = data.value ?? const <TxDetails>[];
    _dismissed.retainWhere((int id) => items.any((TxDetails t) => t.tx.id == id));

    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                controller: _search,
                autofocus: true,
                textInputAction: TextInputAction.search,
                decoration: AppTheme.inputDecoration(
                  context,
                  hint: l.searchNotes,
                  prefixIcon: const Icon(Icons.search),
                ),
                onChanged: ref.read(txFilterProvider.notifier).setQuery,
              )
            : Text(l.navTransactions),
        actions: <Widget>[
          IconButton(
            tooltip: _searching ? l.closeSearch : l.search,
            icon: Icon(_searching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() => _searching = !_searching);
              if (!_searching) {
                _search.clear();
                ref.read(txFilterProvider.notifier).setQuery('');
              }
            },
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          const _FilterBar(),
          Expanded(
            child: data.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (Object e, _) => Center(child: Text(l.genericError)),
              data: (List<TxDetails> all) {
                final List<_Row> rows = _group(all, rates);
                if (rows.isEmpty) {
                  return filter.isActive
                      ? EmptyState(
                          icon: Icons.filter_alt_off_outlined,
                          title: l.emptyFilteredTitle,
                          actionLabel: l.resetFilters,
                          onAction: () {
                            _search.clear();
                            setState(() => _searching = false);
                            ref.read(txFilterProvider.notifier).reset();
                          },
                        )
                      : EmptyState(
                          icon: Icons.receipt_long,
                          title: l.emptyTransactionsTitle,
                          body: l.emptyTransactionsBody,
                          actionLabel: l.addTransaction,
                          onAction: () => context.push(Routes.newTransaction()),
                        );
                }
                int income = 0;
                int expense = 0;
                for (final TxDetails t in all) {
                  if (_dismissed.contains(t.tx.id)) continue;
                  final int v = rates.toBase(t.tx.amount, t.account.currency);
                  if (t.tx.type == TxType.income) income += v;
                  if (t.tx.type == TxType.expense) expense += v;
                }
                return Column(
                  children: <Widget>[
                    _SummaryStrip(income: income, expense: expense, lang: lang),
                    Expanded(
                      child: CustomScrollView(
                        slivers: <Widget>[
                          AnimatedDiffSliverList<_Row>(
                            items: rows,
                            keyOf: (_Row r) => switch (r) {
                              _DayRow(:final DateTime day) => 'd${day.millisecondsSinceEpoch}',
                              _TxRow(:final TxDetails item) => 't${item.tx.id}',
                            },
                            // A swiped row already collapsed: don't replay it.
                            removedBuilder: (BuildContext context, _Row r) => switch (r) {
                              _TxRow(:final TxDetails item) when _swiped.contains(item.tx.id) =>
                                const SizedBox.shrink(),
                              _TxRow(:final TxDetails item) => TxTile(item: item, showTime: true),
                              _DayRow() => _DayHeader(row: r, lang: lang),
                            },
                            itemBuilder: (BuildContext context, _Row row, int i) => switch (row) {
                              _DayRow() => _DayHeader(row: row, lang: lang),
                              _TxRow(:final TxDetails item) => Dismissible(
                                  key: ValueKey<int>(item.tx.id),
                                  direction: DismissDirection.endToStart,
                                  background: Container(
                                    color: AppColors.of(context).dangerContainer,
                                    alignment: Alignment.centerRight,
                                    padding: const EdgeInsets.only(right: AppSpacing.xl),
                                    child: Icon(
                                      Icons.delete_outline,
                                      color: AppColors.of(context).onDangerContainer,
                                      semanticLabel: l.delete,
                                    ),
                                  ),
                                  onDismissed: (_) => _delete(item),
                                  child: TxTile(
                                    item: item,
                                    showTime: true,
                                    onTap: () => context.push(Routes.editTransaction(item.tx.id)),
                                  ),
                                ),
                            },
                          ),
                          const SliverToBoxAdapter(child: SizedBox(height: 96)),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      // Keeps the theme's text styles available to the summary.
      backgroundColor: theme.colorScheme.surface,
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.row, required this.lang});

  final _DayRow row;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);
    final DateTime now = DateTime.now();
    final String label;
    if (Fmt.sameDay(row.day, now)) {
      label = l.today;
    } else if (Fmt.sameDay(row.day, now.subtract(const Duration(days: 1)))) {
      label = l.yesterday;
    } else {
      label = Fmt.dayHeader(row.day, lang);
    }
    final TextStyle? style =
        theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    return Container(
      color: theme.colorScheme.surfaceContainerLow,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Semantics(
        header: true,
        child: Row(
          children: <Widget>[
            Expanded(child: Text(label, style: style)),
            Text(
              Fmt.net(row.net, lang),
              style: style?.merge(AppTextStyles.tabular),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({
    required this.income,
    required this.expense,
    required this.lang,
  });

  final int income;
  final int expense;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final AppColors c = AppColors.of(context);
    final TextStyle? base = Theme.of(context)
        .textTheme
        .bodySmall
        ?.merge(AppTextStyles.tabular);
    final Color variant = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xs,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Wrap(
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.xxs,
        children: <Widget>[
          Text.rich(TextSpan(style: base?.copyWith(color: variant), children: <InlineSpan>[
            TextSpan(text: '${l.income} '),
            TextSpan(
              text: Fmt.signed(income, Currency.base.code, TxType.income, lang),
              style: TextStyle(color: c.income),
            ),
          ])),
          Text.rich(TextSpan(style: base?.copyWith(color: variant), children: <InlineSpan>[
            TextSpan(text: '${l.expense} '),
            TextSpan(
              text: Fmt.signed(expense, Currency.base.code, TxType.expense, lang),
              style: TextStyle(color: c.expense),
            ),
          ])),
          Text(
            '${l.net} ${Fmt.net(income - expense, lang)}',
            style: base?.copyWith(color: variant),
          ),
        ],
      ),
    );
  }
}

/// Type chips + account / category / date filters.
class _FilterBar extends ConsumerWidget {
  const _FilterBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l = AppLocalizations.of(context);
    final String lang = ref.watch(languageProvider);
    final TxFilter f = ref.watch(txFilterProvider);
    final TxFilterController ctl = ref.read(txFilterProvider.notifier);
    final List<Account> accounts =
        ref.watch(allAccountsProvider).value ?? const <Account>[];
    final List<TxCategory> categories = ref
            .watch(categoriesProvider((type: null, includeArchived: true)))
            .value ??
        const <TxCategory>[];

    // The "Kənar yer" chip covers both holding move directions.
    final TxType? type = f.types.isEmpty ? null : f.types.first;
    final Account? account =
        accounts.where((Account a) => a.id == f.accountId).firstOrNull;
    final TxCategory? category =
        categories.where((TxCategory c) => c.id == f.categoryId).firstOrNull;

    Widget typeChip(String label, TxType? t) => Padding(
          padding: const EdgeInsets.only(right: AppSpacing.sm),
          child: ChoiceChip(
            label: Text(label),
            selected: type == t,
            onSelected: (_) => ctl.setTypes(switch (t) {
              null => const <TxType>[],
              TxType.toHolding || TxType.fromHolding => const <TxType>[TxType.toHolding, TxType.fromHolding],
              _ => <TxType>[t],
            }),
          ),
        );

    Future<void> pickAccount() async {
      final int? id = await showModalBottomSheet<int>(
        context: context,
        builder: (BuildContext ctx) => _PickerSheet(
          title: l.account,
          allLabel: l.allAccounts,
          entries: <(int, String, Widget?)>[
            for (final Account a in accounts)
              (a.id, a.isArchived ? '${a.name} (${l.archived})' : a.name, null),
          ],
          selected: f.accountId,
        ),
      );
      if (id != null) ctl.setAccount(id < 0 ? null : id);
    }

    Future<void> pickCategory() async {
      final Iterable<TxCategory> list = categories.where(
        (TxCategory c) =>
            type == null ||
            (type == TxType.income && c.type == CategoryType.income) ||
            (type == TxType.expense && c.type == CategoryType.expense),
      );
      final int? id = await showModalBottomSheet<int>(
        context: context,
        isScrollControlled: true,
        builder: (BuildContext ctx) => _PickerSheet(
          title: l.category,
          allLabel: l.allCategories,
          entries: <(int, String, Widget?)>[
            for (final TxCategory c in list)
              (
                c.id,
                c.isArchived
                    ? '${c.localizedName(lang)} (${l.archived})'
                    : c.localizedName(lang),
                CategoryAvatar.category(c, size: 32),
              ),
          ],
          selected: f.categoryId,
        ),
      );
      if (id != null) ctl.setCategory(id < 0 ? null : id);
    }

    Future<void> pickDates() async {
      final DateTimeRange? r = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
        initialDateRange: f.window == null
            ? null
            : DateTimeRange(
                start: f.window!.start,
                end: f.window!.end.subtract(const Duration(days: 1)),
              ),
      );
      if (r != null) ctl.setWindow(DateWindow.days(r.start, r.end));
    }

    String? dateLabel;
    if (f.window != null) {
      final DateTime last = f.window!.end.subtract(const Duration(days: 1));
      dateLabel = '${Fmt.date(f.window!.start, lang)} – ${Fmt.date(last, lang)}';
    }

    return Column(
      children: <Widget>[
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Row(
            children: <Widget>[
              typeChip(l.all, null),
              typeChip(l.txTypeIncome, TxType.income),
              typeChip(l.txTypeExpense, TxType.expense),
              typeChip(l.txTypeTransfer, TxType.transfer),
              typeChip(l.holdingMoveChip, TxType.toHolding),
            ],
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Row(
            children: <Widget>[
              _DropChip(
                label: account?.name ?? l.account,
                active: f.accountId != null,
                onTap: pickAccount,
                onClear: () => ctl.setAccount(null),
                clearTooltip: l.clear,
              ),
              if (type == null || !type.isMove)
                _DropChip(
                  label: category?.localizedName(lang) ?? l.category,
                  active: f.categoryId != null,
                  onTap: pickCategory,
                  onClear: () => ctl.setCategory(null),
                  clearTooltip: l.clear,
                ),
              _DropChip(
                label: dateLabel ?? l.dateRange,
                active: f.window != null,
                onTap: pickDates,
                onClear: () => ctl.setWindow(null),
                clearTooltip: l.clear,
              ),
              if (f.isActive)
                TextButton(onPressed: ctl.reset, child: Text(l.resetFilters)),
            ],
          ),
        ),
      ],
    );
  }
}

class _DropChip extends StatelessWidget {
  const _DropChip({
    required this.label,
    required this.active,
    required this.onTap,
    required this.onClear,
    required this.clearTooltip,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback onClear;
  final String clearTooltip;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: active
          ? InputChip(
              label: Text(label),
              selected: true,
              showCheckmark: false,
              onPressed: onTap,
              onDeleted: onClear,
              deleteButtonTooltipMessage: clearTooltip,
            )
          : ActionChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(label),
                  const Icon(Icons.arrow_drop_down, size: 18),
                ],
              ),
              onPressed: onTap,
            ),
    );
  }
}

/// Bottom-sheet single choice list. Pops the id, or -1 for "all".
class _PickerSheet extends StatelessWidget {
  const _PickerSheet({
    required this.title,
    required this.allLabel,
    required this.entries,
    required this.selected,
  });

  final String title;
  final String allLabel;
  final List<(int, String, Widget?)> entries;
  final int? selected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: ListView(
          shrinkWrap: true,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Text(title, style: Theme.of(context).textTheme.titleLarge),
            ),
            ListTile(
              title: Text(allLabel),
              trailing: selected == null ? const Icon(Icons.check) : null,
              onTap: () => Navigator.of(context).pop(-1),
            ),
            for (final (int id, String name, Widget? leading) in entries)
              ListTile(
                leading: leading,
                title: Text(name),
                trailing: selected == id ? const Icon(Icons.check) : null,
                onTap: () => Navigator.of(context).pop(id),
              ),
          ],
        ),
      ),
    );
  }
}
