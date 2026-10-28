import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';
import '../settings/settings_controller.dart';
import 'budget_alerts.dart';
import 'widgets/budget_progress_row.dart';

/// Budgets tab (DESIGN.md §7.8).
class BudgetsScreen extends ConsumerStatefulWidget {
  const BudgetsScreen({super.key});

  @override
  ConsumerState<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends ConsumerState<BudgetsScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  String get _key => monthKey(_month);

  void _shift(int delta) =>
      setState(() => _month = DateTime(_month.year, _month.month + delta));

  Future<void> _copyLastMonth() async {
    final AppLocalizations l = AppLocalizations.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final int n = await ref.read(budgetRepositoryProvider).copyMonth(
          from: monthKey(DateTime(_month.year, _month.month - 1)),
          to: _key,
        );
    messenger.showSnackBar(SnackBar(
      content: Text(n == 0 ? l.budgetsCopyNone : l.budgetsCopied(n)),
    ));
    if (n > 0) await ensureNotificationPermission(ref);
  }

  Future<void> _edit({BudgetProgress? existing}) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext ctx) => _BudgetSheet(month: _key, existing: existing),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final String lang = ref.watch(languageProvider);
    final AsyncValue<List<BudgetProgress>> data = ref.watch(budgetProgressProvider(_key));
    final List<TxCategory> cats =
        ref.watch(categoriesProvider((type: null, includeArchived: true))).value ??
            const <TxCategory>[];
    TxCategory? cat(int id) => cats.where((TxCategory c) => c.id == id).firstOrNull;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.navBudgets),
        actions: <Widget>[
          IconButton(
            tooltip: l.budgetsCopyLastMonth,
            icon: const Icon(Icons.content_copy_outlined),
            onPressed: _copyLastMonth,
          ),
          IconButton(
            tooltip: l.addBudget,
            icon: const Icon(Icons.add),
            onPressed: () => _edit(),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          MonthStepper(
            month: _month,
            lang: lang,
            onPrevious: () => _shift(-1),
            onNext: () => _shift(1),
          ),
          Expanded(
            child: data.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (Object e, _) => Center(child: Text(l.genericError)),
              data: (List<BudgetProgress> list) {
                if (list.isEmpty) {
                  return SingleChildScrollView(
                    child: Column(
                      children: <Widget>[
                        EmptyState(
                          icon: Icons.savings_outlined,
                          title: l.emptyBudgetsTitle,
                          body: l.emptyBudgetsBody,
                          actionLabel: l.addBudget,
                          onAction: () => _edit(),
                        ),
                        TextButton.icon(
                          onPressed: _copyLastMonth,
                          icon: const Icon(Icons.content_copy_outlined),
                          label: Text(l.budgetsCopyLastMonth),
                        ),
                      ],
                    ),
                  );
                }
                final List<BudgetProgress> sorted = <BudgetProgress>[...list]
                  ..sort((BudgetProgress a, BudgetProgress b) => b.ratio.compareTo(a.ratio));
                final int nearLimit = list
                    .where((BudgetProgress p) =>
                        p.ratio * 100 >= BudgetThresholds.warning)
                    .length;
                return ListView(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
                  children: <Widget>[
                    _OverallCard(month: _month, budgets: list, lang: lang),
                    if (nearLimit > 0) _WarningBanner(count: nearLimit),
                    for (final BudgetProgress p in sorted)
                      BudgetProgressRow(
                        progress: p,
                        category: cat(p.budget.categoryId),
                        lang: lang,
                        onTap: () => _edit(existing: p),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// ‹ Oktyabr 2026 › stepper.
class MonthStepper extends StatelessWidget {
  const MonthStepper({
    super.key,
    required this.month,
    required this.lang,
    required this.onPrevious,
    required this.onNext,
  });

  final DateTime month;
  final String lang;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Row(
        children: <Widget>[
          IconButton(
            tooltip: l.previousMonth,
            icon: const Icon(Icons.chevron_left),
            onPressed: onPrevious,
          ),
          Expanded(
            child: Text(
              Fmt.month(month, lang),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          IconButton(
            tooltip: l.nextMonth,
            icon: const Icon(Icons.chevron_right),
            onPressed: onNext,
          ),
        ],
      ),
    );
  }
}

class _OverallCard extends StatelessWidget {
  const _OverallCard({required this.month, required this.budgets, required this.lang});

  final DateTime month;
  final List<BudgetProgress> budgets;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final AppColors c = AppColors.of(context);
    final int spent = budgets.fold(0, (int s, BudgetProgress p) => s + p.spent);
    final int limit = budgets.fold(0, (int s, BudgetProgress p) => s + p.limit);
    final double ratio = limit <= 0 ? 0 : spent / limit;
    final int pct = (ratio * 100).round();
    final BudgetState state = AppColors.budgetState(spent.toDouble(), limit.toDouble());
    final int remaining = limit - spent;

    // Daily allowance for the rest of the current month.
    final DateTime now = DateTime.now();
    String? daily;
    if (month.year == now.year && month.month == now.month && remaining > 0) {
      final int daysInMonth = DateTime(now.year, now.month + 1, 0).day;
      final int daysLeft = daysInMonth - now.day + 1;
      daily = l.budgetDailyAllowance(Fmt.base(remaining ~/ daysLeft, lang), daysLeft);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.sm),
      child: Container(
        padding: AppSpacing.card,
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: AppRadius.brLg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(l.budgetTotal, style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: <Widget>[
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${Fmt.base(spent, lang)} / ${Fmt.base(limit, lang)}',
                      style: theme.textTheme.titleLarge?.merge(AppTextStyles.tabular),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  '$pct%',
                  style: theme.textTheme.titleMedium?.merge(AppTextStyles.tabular).copyWith(
                        color: c.budgetText(state, cs.onSurfaceVariant),
                      ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            BudgetBar(ratio: ratio, normalColor: cs.primary),
            const SizedBox(height: AppSpacing.sm),
            Text(
              remaining >= 0
                  ? l.budgetRemaining(Fmt.base(remaining, lang))
                  : l.budgetOverBy(Fmt.base(-remaining, lang)),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: remaining >= 0 ? cs.onSurfaceVariant : c.danger,
              ),
            ),
            if (daily != null)
              Text(
                daily,
                style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
          ],
        ),
      ),
    );
  }
}

class _WarningBanner extends StatelessWidget {
  const _WarningBanner({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: c.warningContainer,
          borderRadius: AppRadius.brMd,
        ),
        child: Row(
          children: <Widget>[
            Icon(Icons.warning_amber, color: c.onWarningContainer),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                AppLocalizations.of(context).budgetsNearLimit(count),
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: c.onWarningContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Add / edit / delete one budget.
class _BudgetSheet extends ConsumerStatefulWidget {
  const _BudgetSheet({required this.month, this.existing});

  final String month;
  final BudgetProgress? existing;

  @override
  ConsumerState<_BudgetSheet> createState() => _BudgetSheetState();
}

class _BudgetSheetState extends ConsumerState<_BudgetSheet> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  late final TextEditingController _limit = TextEditingController(
    text: widget.existing == null
        ? ''
        : Fmt.editable(widget.existing!.limit, ref.read(languageProvider)),
  );
  late int? _categoryId = widget.existing?.budget.categoryId;
  bool _saving = false;

  @override
  void dispose() {
    _limit.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    _saving = true;
    final NavigatorState nav = Navigator.of(context);
    await ref.read(budgetRepositoryProvider).upsert(
          categoryId: _categoryId!,
          month: widget.month,
          limitAmount: Fmt.parseMinor(_limit.text)!,
        );
    await ensureNotificationPermission(ref);
    _saving = false;
    nav.pop();
  }

  Future<void> _delete() async {
    final AppLocalizations l = AppLocalizations.of(context);
    final NavigatorState nav = Navigator.of(context);
    final bool ok = await confirmDialog(
      context,
      title: l.deleteBudgetTitle,
      confirmLabel: l.delete,
      destructive: true,
    );
    if (!ok) return;
    await ref.read(budgetRepositoryProvider).delete(widget.existing!.budget.id);
    nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final String lang = ref.watch(languageProvider);
    final List<TxCategory> expenseCats = ref
            .watch(categoriesProvider((type: CategoryType.expense, includeArchived: true)))
            .value ??
        const <TxCategory>[];
    final Set<int> taken = (ref.watch(budgetProgressProvider(widget.month)).value ??
            const <BudgetProgress>[])
        .map((BudgetProgress p) => p.budget.categoryId)
        .toSet();
    final List<TxCategory> options = expenseCats
        .where((TxCategory c) =>
            c.id == _categoryId || (!c.isArchived && !taken.contains(c.id)))
        .toList();
    final bool isEdit = widget.existing != null;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  isEdit ? l.editBudget : l.addBudget,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(
                  Fmt.month(monthFromKey(widget.month), lang),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: AppSpacing.lg),
                DropdownButtonFormField<int>(
                  initialValue: _categoryId,
                  isExpanded: true,
                  decoration: AppTheme.inputDecoration(context, label: l.category),
                  items: <DropdownMenuItem<int>>[
                    for (final TxCategory c in options)
                      DropdownMenuItem<int>(
                        value: c.id,
                        child: Row(
                          children: <Widget>[
                            CategoryAvatar.category(c, size: 24),
                            const SizedBox(width: AppSpacing.sm),
                            Flexible(
                              child: Text(c.localizedName(lang), overflow: TextOverflow.ellipsis),
                            ),
                          ],
                        ),
                      ),
                  ],
                  onChanged: isEdit ? null : (int? v) => setState(() => _categoryId = v),
                  validator: (int? v) => v == null ? l.selectCategory : null,
                ),
                if (!isEdit && options.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: Text(
                      l.budgetAllCategoriesUsed,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _limit,
                  autofocus: !isEdit,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: AppTheme.inputDecoration(
                    context,
                    label: l.budgetLimit,
                    hint: Fmt.editable(50000, lang),
                    suffixIcon: const Padding(
                      padding: EdgeInsets.all(AppSpacing.md),
                      child: Text('₼'),
                    ),
                  ),
                  validator: (String? v) {
                    final int? m = Fmt.parseMinor(v ?? '');
                    return m == null || m <= 0 ? l.positiveAmountRequired : null;
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: <Widget>[
                    if (isEdit)
                      TextButton.icon(
                        onPressed: _delete,
                        icon: const Icon(Icons.delete_outline),
                        label: Text(l.delete),
                        style: TextButton.styleFrom(
                          foregroundColor: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    const Spacer(),
                    FilledButton(onPressed: _save, child: Text(l.save)),
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
