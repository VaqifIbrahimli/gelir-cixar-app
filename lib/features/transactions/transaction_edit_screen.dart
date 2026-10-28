import 'dart:math' as math;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/router.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';
import '../budgets/budget_alerts.dart';
import '../holdings/holding_sheets.dart' show holdingErrorText;
import '../settings/settings_controller.dart';
import 'amount_calc.dart';
import 'widgets/amount_keypad.dart';

/// Add / edit a transaction (DESIGN.md §6.5, §7.4).
class TransactionEditScreen extends ConsumerStatefulWidget {
  const TransactionEditScreen({
    super.key,
    this.transactionId,
    this.initialType = TxType.expense,
  });

  final int? transactionId;
  final TxType initialType;

  bool get isEdit => transactionId != null;

  @override
  ConsumerState<TransactionEditScreen> createState() =>
      _TransactionEditScreenState();
}

class _TransactionEditScreenState extends ConsumerState<TransactionEditScreen>
    with SingleTickerProviderStateMixin {
  late TxType _type = widget.initialType;
  AmountCalc _amount = AmountCalc();
  AmountCalc _toAmount = AmountCalc();

  /// Keypad writes into [_toAmount] when true.
  bool _editingTo = false;
  int? _accountId;
  int? _toAccountId;
  int? _categoryId;
  DateTime _date = DateTime.now();
  String _note = '';

  MoneyTx? _original;
  bool _loading = false;
  bool _notFound = false;

  /// Set when the id belongs to a holding move, which is edited from its holding.
  int? _holdingMoveOf;
  bool _saving = false;
  String? _error;

  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  );

  @override
  void initState() {
    super.initState();
    if (widget.isEdit) {
      _loading = true;
      _load();
    }
  }

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final MoneyTx? tx =
        await ref.read(transactionRepositoryProvider).byId(widget.transactionId!);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (tx == null) {
        _notFound = true;
        return;
      }
      if (tx.type.isHoldingMove) {
        _holdingMoveOf = tx.holdingId;
        return;
      }
      _original = tx;
      _type = tx.type;
      _amount = AmountCalc.fromMinor(tx.amount);
      _toAmount =
          tx.toAmount == null ? AmountCalc() : AmountCalc.fromMinor(tx.toAmount!);
      _accountId = tx.accountId;
      _toAccountId = tx.toAccountId;
      _categoryId = tx.categoryId;
      _date = tx.date;
      _note = tx.note;
    });
  }

  // ---- derived -------------------------------------------------------------

  List<Account> get _allAccounts =>
      ref.read(allAccountsProvider).value ?? const <Account>[];

  Account? _account(int? id) =>
      id == null ? null : _allAccounts.where((Account a) => a.id == id).firstOrNull;

  /// Explicit choice, or the first active account.
  int? get _effectiveAccountId {
    if (_accountId != null) return _accountId;
    return _allAccounts.where((Account a) => !a.isArchived).firstOrNull?.id;
  }

  bool get _crossCurrency {
    if (_type != TxType.transfer) return false;
    final Account? from = _account(_effectiveAccountId);
    final Account? to = _account(_toAccountId);
    return from != null && to != null && from.currency != to.currency;
  }

  /// Suggested received amount from the stored rates.
  int? get _suggestedToAmount {
    final Account? from = _account(_effectiveAccountId);
    final Account? to = _account(_toAccountId);
    final int? a = _amount.evaluate();
    if (from == null || to == null || a == null || a <= 0) return null;
    final Rates rates = ref.read(ratesProvider).value ?? Rates.defaults;
    return (a * rates.rateOf(from.currency) / rates.rateOf(to.currency)).round();
  }

  // ---- keypad --------------------------------------------------------------

  AmountCalc get _target => _editingTo ? _toAmount : _amount;

  void _key(void Function(AmountCalc c) f) {
    AppHaptics.key();
    setState(() {
      f(_target);
      _error = null;
    });
  }

  void _onCheck() {
    if (_target.hasOperator) {
      AppHaptics.key();
      setState(() {
        if (!_target.collapse()) _error = AppLocalizations.of(context).invalidAmount;
      });
      return;
    }
    _save();
  }

  // ---- actions -------------------------------------------------------------

  Future<void> _fail(String message) async {
    setState(() => _error = message);
    AppHaptics.error();
    if (!MediaQuery.disableAnimationsOf(context)) {
      await _shake.forward(from: 0);
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    final AppLocalizations l = AppLocalizations.of(context);
    final int? amount = _amount.evaluate();
    if (amount == null || amount <= 0) {
      setState(() => _editingTo = false);
      return _fail(l.enterAmount);
    }
    final int? accountId = _effectiveAccountId;
    if (accountId == null) return _fail(l.selectAccount);

    int? toAccountId;
    int? toAmount;
    int? categoryId;
    if (_type == TxType.transfer) {
      if (_toAccountId == null) return _fail(l.selectToAccount);
      if (_toAccountId == accountId) return _fail(l.sameAccountError);
      toAccountId = _toAccountId;
      if (_crossCurrency) {
        toAmount = _toAmount.isEmpty ? _suggestedToAmount : _toAmount.evaluate();
        if (toAmount == null || toAmount <= 0) {
          setState(() => _editingTo = true);
          return _fail(l.enterReceivedAmount);
        }
      }
    } else {
      categoryId = _categoryId;
      if (categoryId == null) return _fail(l.selectCategory);
    }

    _saving = true;
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final TransactionRepository repo = ref.read(transactionRepositoryProvider);
    final String note = _note.trim();
    try {
      if (_original == null) {
        await repo.insert(TransactionsCompanion.insert(
          type: _type,
          accountId: accountId,
          toAccountId: Value<int?>(toAccountId),
          categoryId: Value<int?>(categoryId),
          amount: amount,
          toAmount: Value<int?>(toAmount),
          date: _date,
          note: Value<String>(note),
        ));
      } else {
        await repo.update(_original!.copyWith(
          type: _type,
          accountId: accountId,
          toAccountId: Value<int?>(toAccountId),
          categoryId: Value<int?>(categoryId),
          amount: amount,
          toAmount: Value<int?>(toAmount),
          date: _date,
          note: note,
        ));
      }
    } finally {
      _saving = false;
    }
    if (!mounted) return;
    // Runs before pop: `ref` is unusable once this screen is disposed.
    await checkBudgetAlerts(
      ref: ref,
      messenger: messenger,
      l: l,
      categoryId: categoryId,
      type: _type,
      date: _date,
    );
    AppHaptics.confirm();
    if (mounted) context.pop();
  }

  Future<void> _delete() async {
    final AppLocalizations l = AppLocalizations.of(context);
    final MoneyTx? tx = _original;
    if (tx == null) return;
    final bool ok = await confirmDialog(
      context,
      title: l.deleteTransactionTitle,
      message: l.deleteTransactionBody,
      confirmLabel: l.delete,
      destructive: true,
    );
    if (!ok || !mounted) return;
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final TransactionRepository repo = ref.read(transactionRepositoryProvider);
    final List<HoldingEntry> linked;
    try {
      linked = await repo.delete(tx.id);
    } on HoldingAmountException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(holdingErrorText(l, e.reason))));
      return;
    }
    if (!mounted) return;
    context.pop();
    messenger.showSnackBar(SnackBar(
      content: Text(l.transactionDeleted),
      action: SnackBarAction(
        label: l.undo,
        onPressed: () async {
          try {
            await repo.restore(tx, entries: linked);
          } on HoldingAmountException catch (e) {
            messenger.showSnackBar(SnackBar(content: Text(holdingErrorText(l, e.reason))));
          }
        },
      ),
    ));
  }

  void _setType(TxType t) {
    setState(() {
      _type = t;
      _error = null;
      _editingTo = false;
      if (t == TxType.transfer) {
        _categoryId = null;
      } else {
        final TxCategory? c = _categoryById(_categoryId);
        if (c != null && c.type != t.categoryType) _categoryId = null;
      }
    });
  }

  TxCategory? _categoryById(int? id) {
    if (id == null) return null;
    final List<TxCategory> all = ref
            .read(categoriesProvider((type: null, includeArchived: true)))
            .value ??
        const <TxCategory>[];
    return all.where((TxCategory c) => c.id == id).firstOrNull;
  }

  Future<void> _pickAccount({required bool destination}) async {
    final AppLocalizations l = AppLocalizations.of(context);
    final int? current = destination ? _toAccountId : _effectiveAccountId;
    int? id = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext ctx) => _AccountSheet(
        title: destination ? l.toAccount : (_type == TxType.transfer ? l.fromAccount : l.account),
        selected: current,
      ),
    );
    if (id == _AccountSheet.createNew && mounted) {
      id = await context.push<int>(Routes.newAccount);
    }
    if (id == null || !mounted) return;
    setState(() {
      _error = null;
      if (destination) {
        _toAccountId = id;
      } else {
        _accountId = id;
      }
      if (!_crossCurrency) _editingTo = false;
    });
  }

  Future<void> _pickCategory() async {
    final CategoryType? ct = _type.categoryType;
    if (ct == null) return;
    final Object? r = await showModalBottomSheet<Object>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext ctx) => _CategorySheet(type: ct, selected: _categoryId),
    );
    if (!mounted) return;
    int? id;
    if (r == _CategorySheet.createNew) {
      id = await context.push<int>(Routes.newCategory(ct));
    } else if (r is int) {
      id = r;
    }
    if (id != null && mounted) {
      setState(() {
        _categoryId = id;
        _error = null;
      });
    }
  }

  Future<void> _pickDate() async {
    final DateTime? d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d == null || !mounted) return;
    setState(() => _date = DateTime(
          d.year,
          d.month,
          d.day,
          _date.hour,
          _date.minute,
          _date.second,
        ));
  }

  Future<void> _editNote() async {
    final AppLocalizations l = AppLocalizations.of(context);
    final TextEditingController ctl = TextEditingController(text: _note);
    final String? r = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(l.note),
        content: TextField(
          controller: ctl,
          autofocus: true,
          maxLength: 200,
          maxLines: 3,
          minLines: 1,
          textCapitalization: TextCapitalization.sentences,
          decoration: AppTheme.inputDecoration(ctx, hint: l.noteHint),
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(l.cancel)),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(ctl.text),
            child: Text(l.save),
          ),
        ],
      ),
    );
    ctl.dispose();
    if (r != null && mounted) setState(() => _note = r);
  }

  // ---- build -----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final String lang = ref.watch(languageProvider);
    // Keep pickers and labels fresh.
    ref.watch(allAccountsProvider);
    ref.watch(ratesProvider);
    final List<TxCategory> allCats = ref
            .watch(categoriesProvider((type: null, includeArchived: true)))
            .value ??
        const <TxCategory>[];

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_notFound) {
      return Scaffold(
        appBar: AppBar(),
        body: EmptyState(icon: Icons.search_off, title: l.transactionNotFound),
      );
    }
    if (_holdingMoveOf != null) {
      return Scaffold(
        appBar: AppBar(),
        body: EmptyState(
          icon: Icons.savings_outlined,
          title: l.holdingMoveEditElsewhere,
          actionLabel: l.holdingOpen,
          onAction: () => context.pushReplacement(Routes.holding(_holdingMoveOf!)),
        ),
      );
    }

    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final AppColors colors = AppColors.of(context);
    final Account? from = _account(_effectiveAccountId);
    final Account? to = _account(_toAccountId);
    final TxCategory? category =
        allCats.where((TxCategory c) => c.id == _categoryId).firstOrNull;
    final String sep = Fmt.decimalSeparator(lang);
    final bool cross = _crossCurrency;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: l.close,
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        title: Text(widget.isEdit ? l.editTransaction : l.newTransaction),
        actions: <Widget>[
          if (widget.isEdit)
            IconButton(
              tooltip: l.delete,
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: FilledButton(onPressed: _save, child: Text(l.save)),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.sm,
                ),
                child: Column(
                  children: <Widget>[
                    _TypeSelector(type: _type, onChanged: _setType),
                    const SizedBox(height: AppSpacing.lg),
                    AnimatedBuilder(
                      animation: _shake,
                      builder: (BuildContext context, Widget? child) =>
                          Transform.translate(
                        offset: Offset(
                          math.sin(_shake.value * math.pi * 4) * 10,
                          0,
                        ),
                        child: child,
                      ),
                      child: _AmountDisplay(
                        label: cross ? l.amountSent : null,
                        text: _amountText(_amount.display(sep), from?.currency, lang),
                        color: txTypeColor(context, _type),
                        sign: switch (_type) {
                          TxType.income => '+',
                          TxType.expense => Fmt.minus,
                          TxType.transfer || TxType.toHolding || TxType.fromHolding => '',
                        },
                        active: !_editingTo,
                        onTap: cross ? () => setState(() => _editingTo = false) : null,
                        semanticsLabel:
                            '${txTypeLabel(l, _type)} ${_amount.display(sep)} ${from?.currency ?? ''}',
                      ),
                    ),
                    if (cross)
                      _AmountDisplay(
                        label: l.amountReceived,
                        text: _toAmount.isEmpty
                            ? _amountText(
                                _suggestedToAmount == null
                                    ? '0'
                                    : AmountCalc.fromMinor(_suggestedToAmount!)
                                        .display(sep),
                                to?.currency,
                                lang,
                              )
                            : _amountText(_toAmount.display(sep), to?.currency, lang),
                        color: _toAmount.isEmpty ? cs.onSurfaceVariant : colors.transfer,
                        sign: '',
                        small: true,
                        active: _editingTo,
                        onTap: () => setState(() => _editingTo = true),
                        semanticsLabel: '${l.amountReceived} ${_toAmount.display(sep)} ${to?.currency ?? ''}',
                      ),
                    SizedBox(
                      height: 24,
                      child: _error == null
                          ? null
                          : Text(
                              _error!,
                              style: theme.textTheme.bodySmall?.copyWith(color: cs.error),
                            ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    if (_type == TxType.transfer)
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: _SelectorButton(
                              icon: Icons.call_made,
                              label: from?.name ?? l.fromAccount,
                              onTap: () => _pickAccount(destination: false),
                              tooltip: l.fromAccount,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                            child: Icon(Icons.arrow_forward, color: cs.onSurfaceVariant),
                          ),
                          Expanded(
                            child: _SelectorButton(
                              icon: Icons.call_received,
                              label: to?.name ?? l.toAccount,
                              onTap: () => _pickAccount(destination: true),
                              tooltip: l.toAccount,
                            ),
                          ),
                        ],
                      )
                    else
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: _SelectorButton(
                              icon: Icons.account_balance_wallet_outlined,
                              label: from?.name ?? l.account,
                              onTap: () => _pickAccount(destination: false),
                              tooltip: l.account,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: _SelectorButton(
                              icon: Icons.category_outlined,
                              leading: category == null
                                  ? null
                                  : CategoryAvatar.category(category, size: 24),
                              label: category?.localizedName(lang) ?? l.category,
                              onTap: _pickCategory,
                              tooltip: l.category,
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xs,
                      alignment: WrapAlignment.center,
                      children: <Widget>[
                        ActionChip(
                          avatar: const Icon(Icons.calendar_today_outlined, size: 18),
                          label: Text(
                            Fmt.sameDay(_date, DateTime.now())
                                ? l.today
                                : Fmt.date(_date, lang),
                          ),
                          tooltip: l.date,
                          onPressed: _pickDate,
                        ),
                        ActionChip(
                          avatar: const Icon(Icons.edit_note, size: 18),
                          label: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 200),
                            child: Text(
                              _note.trim().isEmpty ? l.addNote : _note.trim(),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          tooltip: l.note,
                          onPressed: _editNote,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            AmountKeypad(
              decimalLabel: sep,
              checkIsEquals: _target.hasOperator,
              onDigit: (String d) => _key((AmountCalc c) => c.digit(d)),
              onDoubleZero: () => _key((AmountCalc c) => c
                ..digit('0')
                ..digit('0')),
              onDecimal: () => _key((AmountCalc c) => c.decimal()),
              onOperator: (String op) => _key((AmountCalc c) => c.operator(op)),
              onBackspace: () => _key((AmountCalc c) => c.backspace()),
              onClear: () => _key((AmountCalc c) => c.clear()),
              onCheck: _onCheck,
            ),
          ],
        ),
      ),
    );
  }

  static String _amountText(String body, String? currency, String lang) {
    final String code = currency ?? Currency.base.code;
    if (code == Currency.azn.code) {
      return lang == 'en' ? '₼$body' : '$body ₼';
    }
    return '$body $code';
  }
}

class _TypeSelector extends StatelessWidget {
  const _TypeSelector({required this.type, required this.onChanged});

  final TxType type;
  final ValueChanged<TxType> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final AppColors c = AppColors.of(context);
    final (Color bg, Color fg) = switch (type) {
      TxType.income => (c.incomeContainer, c.onIncomeContainer),
      TxType.expense => (c.expenseContainer, c.onExpenseContainer),
      TxType.transfer || TxType.toHolding || TxType.fromHolding => (c.transferContainer, c.onTransferContainer),
    };
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<TxType>(
        showSelectedIcon: false,
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith(
            (Set<WidgetState> s) => s.contains(WidgetState.selected) ? bg : null,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (Set<WidgetState> s) => s.contains(WidgetState.selected) ? fg : null,
          ),
        ),
        segments: <ButtonSegment<TxType>>[
          ButtonSegment<TxType>(value: TxType.expense, label: Text(l.txTypeExpense)),
          ButtonSegment<TxType>(value: TxType.income, label: Text(l.txTypeIncome)),
          ButtonSegment<TxType>(value: TxType.transfer, label: Text(l.txTypeTransfer)),
        ],
        selected: <TxType>{type},
        onSelectionChanged: (Set<TxType> s) => onChanged(s.first),
      ),
    );
  }
}

class _AmountDisplay extends StatelessWidget {
  const _AmountDisplay({
    required this.text,
    required this.color,
    required this.sign,
    required this.active,
    required this.semanticsLabel,
    this.label,
    this.onTap,
    this.small = false,
  });

  final String? label;
  final String text;
  final String sign;
  final Color color;
  final bool active;
  final bool small;
  final VoidCallback? onTap;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final TextStyle style = small
        ? (theme.textTheme.headlineMedium ?? const TextStyle()).merge(AppTextStyles.tabular)
        : AppTextStyles.amountInput;
    final bool framed = onTap != null;
    return Semantics(
      label: semanticsLabel,
      button: onTap != null,
      selected: framed && active,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.brLg,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.sm,
            horizontal: AppSpacing.md,
          ),
          decoration: framed
              ? BoxDecoration(
                  borderRadius: AppRadius.brLg,
                  border: Border.all(
                    color: active ? cs.primary : cs.outlineVariant,
                    width: active ? 2 : 1,
                  ),
                )
              : null,
          child: Column(
            children: <Widget>[
              if (label != null)
                Text(
                  label!,
                  style: theme.textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  sign.isEmpty ? text : '$sign${Fmt.thinSpace}$text',
                  style: style.copyWith(color: color),
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectorButton extends StatelessWidget {
  const _SelectorButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.tooltip,
    this.leading,
  });

  final IconData icon;
  final Widget? leading;
  final String label;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: FilledButton.tonal(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        ),
        onPressed: onTap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            leading ?? Icon(icon, size: 18),
            const SizedBox(width: AppSpacing.sm),
            Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
            const Icon(Icons.arrow_drop_down, size: 20),
          ],
        ),
      ),
    );
  }
}

/// Account picker sheet with balances. Pops the chosen account id.
class _AccountSheet extends ConsumerWidget {
  const _AccountSheet({required this.title, required this.selected});

  /// Popped when the user wants to create an account.
  static const int createNew = -1;

  final String title;
  final int? selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l = AppLocalizations.of(context);
    final String lang = ref.watch(languageProvider);
    final List<AccountWithBalance> all =
        ref.watch(allAccountBalancesProvider).value ?? const <AccountWithBalance>[];
    final List<AccountWithBalance> list = all
        .where((AccountWithBalance a) => !a.account.isArchived || a.account.id == selected)
        .toList();
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.7),
        child: ListView(
          shrinkWrap: true,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Text(title, style: Theme.of(context).textTheme.titleLarge),
            ),
            for (final AccountWithBalance a in list)
              ListTile(
                leading: CategoryAvatar(
                  icon: accountTypeIcon(a.account.type),
                  colorIndex: a.account.colorIndex,
                ),
                title: Text(a.account.name),
                subtitle: Text(
                  Fmt.money(a.balance, a.account.currency, lang),
                  style: AppTextStyles.tabular,
                ),
                trailing: a.account.id == selected ? const Icon(Icons.check) : null,
                onTap: () => Navigator.of(context).pop(a.account.id),
              ),
            ListTile(
              leading: const Icon(Icons.add),
              title: Text(l.addAccount),
              onTap: () => Navigator.of(context).pop(createNew),
            ),
          ],
        ),
      ),
    );
  }
}

/// Category grid sheet (DESIGN.md §6.3). Pops an id or [createNew].
class _CategorySheet extends ConsumerWidget {
  const _CategorySheet({required this.type, required this.selected});

  static const String createNew = 'new';

  final CategoryType type;
  final int? selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l = AppLocalizations.of(context);
    final String lang = ref.watch(languageProvider);
    final ThemeData theme = Theme.of(context);
    final List<TxCategory> cats = ref
            .watch(categoriesProvider((type: type, includeArchived: false)))
            .value ??
        const <TxCategory>[];

    Widget cell({
      required Widget avatar,
      required String label,
      required bool isSelected,
      required VoidCallback onTap,
    }) =>
        Semantics(
          button: true,
          selected: isSelected,
          label: label,
          excludeSemantics: true,
          child: InkWell(
            borderRadius: AppRadius.brMd,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Column(
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? theme.colorScheme.primary : Colors.transparent,
                        width: 3,
                      ),
                    ),
                    child: avatar,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    label,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        );

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.75),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Text(l.category, style: theme.textTheme.titleLarge),
            ),
            const SizedBox(height: AppSpacing.sm),
            Flexible(
              child: GridView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 96,
                  mainAxisExtent: 104,
                ),
                itemCount: cats.length + 1,
                itemBuilder: (BuildContext context, int i) {
                  if (i == cats.length) {
                    return cell(
                      avatar: Container(
                        width: AppSizes.categoryPickerAvatar,
                        height: AppSizes.categoryPickerAvatar,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: theme.colorScheme.surfaceContainerHigh,
                        ),
                        child: Icon(Icons.add, color: theme.colorScheme.primary),
                      ),
                      label: l.newCategory,
                      isSelected: false,
                      onTap: () => Navigator.of(context).pop(createNew),
                    );
                  }
                  final TxCategory c = cats[i];
                  return cell(
                    avatar: CategoryAvatar.category(c, size: AppSizes.categoryPickerAvatar),
                    label: c.localizedName(lang),
                    isSelected: c.id == selected,
                    onTap: () => Navigator.of(context).pop(c.id),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
