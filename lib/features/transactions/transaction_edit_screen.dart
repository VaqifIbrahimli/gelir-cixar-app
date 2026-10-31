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
import 'widgets/route_sheets.dart';

/// Add / edit a transaction (DESIGN.md §6.5, §7.4).
class TransactionEditScreen extends ConsumerStatefulWidget {
  const TransactionEditScreen({
    super.key,
    this.transactionId,
    this.initialType = TxType.expense,
    this.initialAccountId,
    this.duplicateOf,
  });

  final int? transactionId;
  final TxType initialType;

  /// Account preselected (card long-press actions).
  final int? initialAccountId;

  /// "Təkrarla": a new transaction with every field of this one, dated now.
  final int? duplicateOf;

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
  late int? _accountId = widget.initialAccountId;
  int? _toAccountId;
  int? _categoryId;

  /// Taken when the screen opens; it does not keep ticking (§18.4.1).
  DateTime _date = DateTime.now();
  String _note = '';

  // ---- transport (§18.5) ----
  TransportMode? _mode;
  String? _routeCode;
  FareAutoFill _fill = const FareAutoFill();

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
    if (widget.isEdit || widget.duplicateOf != null) {
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
    final TransactionRepository repo = ref.read(transactionRepositoryProvider);
    MoneyTx? tx = await repo.byId(widget.transactionId ?? widget.duplicateOf!);
    // A bonus pair is edited as one: the loss row opens its transfer, and
    // the transfer's sent amount is arrived + loss (§18.6).
    int? sent;
    if (tx != null && tx.linkGroupId != null) {
      final List<MoneyTx> partners = await repo.linkedOf(tx);
      final MoneyTx? transfer = tx.type == TxType.transfer
          ? tx
          : partners.where((MoneyTx p) => p.type == TxType.transfer).firstOrNull;
      if (transfer != null) {
        final MoneyTx? loss = <MoneyTx>[tx, ...partners]
            .where((MoneyTx p) => p.type == TxType.expense)
            .firstOrNull;
        tx = transfer;
        sent = transfer.amount + (loss?.amount ?? 0);
      }
    }
    // Fares only decide whether the stored amount still equals fare × trips;
    // never hold the editor up for them.
    ResolvedFares? fares = ref.read(resolvedFaresProvider).value;
    if (fares == null && tx?.transportMode != null) {
      try {
        fares = await ref.read(resolvedFaresProvider.future).timeout(const Duration(seconds: 2));
      } on Object {
        fares = null;
      }
    }
    if (!mounted) return;
    final bool duplicate = widget.duplicateOf != null;
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
      _original = duplicate ? null : tx;
      _type = tx.type;
      if (sent != null) {
        // Bonus transfer: the keypad holds the sent amount, the received
        // field the arrived one.
        _amount = AmountCalc.fromMinor(sent);
        _toAmount = AmountCalc.fromMinor(tx.amount);
      } else {
        _amount = AmountCalc.fromMinor(tx.amount);
        _toAmount = tx.toAmount == null ? AmountCalc() : AmountCalc.fromMinor(tx.toAmount!);
      }
      _accountId = tx.accountId;
      _toAccountId = tx.toAccountId;
      _categoryId = tx.categoryId;
      _date = duplicate ? DateTime.now() : tx.date;
      _note = tx.note;
      _mode = tx.transportMode;
      _routeCode = tx.routeCode;
      final int? fare = _mode == null ? null : fares?.fareOf(_mode!, routeCode: _routeCode);
      _fill = FareAutoFill(fare: fare, trips: tx.trips, manual: fare == null || fare * tx.trips != tx.amount);
    });
  }

  // ---- transport -------------------------------------------------------------

  ResolvedFares? get _fares => ref.read(resolvedFaresProvider).value;

  bool get _showTransport => _type == TxType.expense && (_categoryById(_categoryId)?.isTransport ?? false);

  /// Writes fare × trips into the keypad unless the amount was typed.
  void _applyFill(FareAutoFill f) {
    _fill = f;
    final int? a = f.amount;
    if (a != null) {
      _amount = AmountCalc.fromMinor(a);
      _editingTo = false;
      _error = null;
    }
  }

  void _setMode(TransportMode m) {
    AppHaptics.key();
    setState(() {
      // A route / station belongs to one mode.
      if (m != _mode) _routeCode = null;
      _mode = m;
      final int? fare = _fares?.fareOf(m, routeCode: _routeCode);
      _applyFill(FareAutoFill(fare: fare, trips: TransportModeStyle.forMode(m).hasTrips ? _fill.trips : 1));
    });
  }

  void _setTrips(int n) {
    AppHaptics.key();
    setState(() => _applyFill(_fill.withTrips(n)));
  }

  Future<void> _pickRoute() async {
    final String? code = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext ctx) => BusRouteSheet(selected: _routeCode),
    );
    if (code == null || !mounted) return;
    // The own-route form may just have saved it: wait for the fares.
    final ResolvedFares fares = await ref.read(resolvedFaresProvider.future);
    if (!mounted) return;
    setState(() {
      _routeCode = code;
      _applyFill(_fill.withFare(fares.busRoute(code)?.fare ?? _fares?.busRoute(code)?.fare));
    });
  }

  Future<void> _pickStation() async {
    final String? s = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext ctx) => MetroStationSheet(selected: _routeCode),
    );
    if (s == null || !mounted) return;
    setState(() {
      _routeCode = s.isEmpty ? null : s;
      _applyFill(_fill.withFare(_fares?.metroFare));
    });
  }

  /// A transport category was chosen for a new row: preselect the mode used
  /// last (§18.5.2).
  Future<void> _preselectMode() async {
    if (_mode != null) return;
    final TransportMode? last = await ref.read(transactionRepositoryProvider).lastTransportMode();
    if (!mounted || _mode != null || !_showTransport) return;
    if (last != null) _setMode(last);
  }

  // ---- bonus (§18.6) ---------------------------------------------------------

  /// Source is a bonus account: the keypad amount is what leaves it.
  bool get _bonus => _type == TxType.transfer && _account(_effectiveAccountId)?.type == AccountType.bonus;

  int get _bonusRate => _account(_effectiveAccountId)?.bonusRatePercent ?? 100;

  /// Received amount: typed, or sent × rate.
  int? get _bonusReceived {
    final int? sent = _amount.evaluate();
    if (sent == null || sent <= 0) return null;
    return _toAmount.isEmpty ? bonusReceived(sent, _bonusRate) : _toAmount.evaluate();
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
      // Typing makes a transport amount manual (§18.5.2).
      if (!_editingTo && _fill.fare != null) _fill = _fill.typed();
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
      if (_bonus) return _saveBonus(l, accountId, _toAccountId!, amount);
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

    // Transport fields only while a transport category is chosen; a
    // category change drops them (§18.5.1).
    final TransportMode? mode = _showTransport ? _mode : null;
    final String? route =
        mode == TransportMode.bus || mode == TransportMode.metro ? _routeCode : null;
    final int trips = mode != null && TransportModeStyle.forMode(mode).hasTrips ? _fill.trips : 1;

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
          transportMode: Value<TransportMode?>(mode),
          routeCode: Value<String?>(route),
          trips: Value<int>(trips),
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
          transportMode: Value<TransportMode?>(mode),
          routeCode: Value<String?>(route),
          trips: trips,
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

  /// Bonus source: transfer of the arrived amount + bonus-loss expense,
  /// written together (TransactionRepository.saveBonusTransfer).
  Future<void> _saveBonus(AppLocalizations l, int fromId, int toId, int sent) async {
    final Account? to = _account(toId);
    if (to == null || to.currency != _account(fromId)?.currency) return _fail(l.bonusSameCurrencyOnly);
    final int? received = _bonusReceived;
    if (received == null || received <= 0) {
      setState(() => _editingTo = true);
      return _fail(l.enterReceivedAmount);
    }
    if (received > sent) {
      setState(() => _editingTo = true);
      return _fail(l.bonusReceivedTooBig);
    }
    _saving = true;
    try {
      await ref.read(transactionRepositoryProvider).saveBonusTransfer(
            transferId: _original?.id,
            fromId: fromId,
            toId: toId,
            sent: sent,
            received: received,
            date: _date,
            note: _note.trim(),
          );
    } finally {
      _saving = false;
    }
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
    final DeletedTransactions deleted;
    try {
      // A bonus transfer takes its loss row with it.
      deleted = await repo.deleteWithLinked(tx.id);
    } on HoldingAmountException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(holdingErrorText(l, e.reason))));
      return;
    }
    if (!mounted) return;
    context.pop();
    messenger.showSnackBar(SnackBar(
      content: Text(deleted.isPair ? l.pairDeleted : l.transactionDeleted),
      action: SnackBarAction(
        label: l.undo,
        onPressed: () async {
          try {
            await repo.restoreDeleted(deleted);
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
      if (_showTransport) {
        await _preselectMode();
      } else if (_fill.fare != null) {
        // Leaving a transport category: its values are not saved.
        setState(() => _fill = const FareAutoFill());
      }
    }
  }

  Future<void> _pickTime() async {
    final TimeOfDay? t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_date),
      initialEntryMode: TimePickerEntryMode.dial,
      builder: (BuildContext ctx, Widget? child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (t == null || !mounted) return;
    setState(() => _date = DateTime(_date.year, _date.month, _date.day, t.hour, t.minute));
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
    final bool bonus = _bonus;
    final bool cross = _crossCurrency && !bonus;
    final bool transport = _showTransport;
    final ResolvedFares? fares = ref.watch(resolvedFaresProvider).value;
    final DateTime now = DateTime.now();
    final String dateLabel = Fmt.sameDay(_date, now)
        ? l.today
        : Fmt.sameDay(_date, now.subtract(const Duration(days: 1)))
            ? l.yesterday
            : Fmt.shortDate(_date, lang, now);

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
                    if (transport && _fill.fare != null)
                      _FareHint(
                        fill: _fill,
                        fareText: Fmt.money(_fill.fare!, Currency.azn.code, lang),
                        onReset: () => setState(() => _applyFill(_fill.resetToFare())),
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
                    AnimatedSize(
                      duration: AppMotion.of(context, AppMotion.reveal),
                      curve: AppMotion.standard,
                      child: bonus
                          ? _BonusBox(
                              sent: _amount.evaluate() ?? 0,
                              received: _bonusReceived ?? 0,
                              rate: _bonusRate,
                              currency: from?.currency ?? Currency.base.code,
                              lang: lang,
                              sameCurrency: to == null || to.currency == from?.currency,
                              editing: _editingTo,
                              onEditReceived: () => setState(() => _editingTo = !_editingTo),
                              receivedTyped: !_toAmount.isEmpty,
                              receivedText: _toAmount.display(sep),
                            )
                          : const SizedBox(width: double.infinity),
                    ),
                    AnimatedSize(
                      duration: AppMotion.of(context, AppMotion.reveal),
                      curve: AppMotion.standard,
                      child: transport
                          ? _TransportPanel(
                              mode: _mode,
                              routeCode: _routeCode,
                              route: fares?.busRoute(_routeCode),
                              trips: _fill.trips,
                              lang: lang,
                              onMode: _setMode,
                              onTrips: _setTrips,
                              onPickRoute: _pickRoute,
                              onPickStation: _pickStation,
                            )
                          : const SizedBox(width: double.infinity),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xs,
                      alignment: WrapAlignment.center,
                      children: <Widget>[
                        Semantics(
                          label: '${l.date}: $dateLabel',
                          button: true,
                          excludeSemantics: true,
                          child: ActionChip(
                            avatar: const Icon(Icons.calendar_today_outlined, size: 18),
                            label: Text(dateLabel),
                            tooltip: l.date,
                            onPressed: _pickDate,
                          ),
                        ),
                        Semantics(
                          label: '${l.time}: ${Fmt.time(_date, lang)}',
                          button: true,
                          excludeSemantics: true,
                          child: ActionChip(
                            avatar: const Icon(Icons.schedule, size: 18),
                            label: Text(Fmt.time(_date, lang), style: AppTextStyles.tabular),
                            tooltip: l.time,
                            onPressed: _pickTime,
                          ),
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

/// "Tarif: 0,60 ₼ × 2", or "Məbləğ əl ilə dəyişdirilib · Tarifə qaytar".
class _FareHint extends StatelessWidget {
  const _FareHint({required this.fill, required this.fareText, required this.onReset});

  final FareAutoFill fill;
  final String fareText;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);
    final TextStyle? style = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    if (!fill.manual) return Text(l.fareHint(fareText, fill.trips), style: style?.merge(AppTextStyles.tabular));
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      alignment: WrapAlignment.center,
      children: <Widget>[
        Text('${l.fareManual} · ', style: style),
        TextButton(
          style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
          onPressed: onReset,
          child: Text(l.resetToFare),
        ),
      ],
    );
  }
}

/// Sent / arrived / loss box of a transfer out of a bonus account.
class _BonusBox extends StatelessWidget {
  const _BonusBox({
    required this.sent,
    required this.received,
    required this.rate,
    required this.currency,
    required this.lang,
    required this.sameCurrency,
    required this.editing,
    required this.onEditReceived,
    required this.receivedTyped,
    required this.receivedText,
  });

  final int sent;
  final int received;
  final int rate;
  final String currency;
  final String lang;
  final bool sameCurrency;
  final bool editing;
  final VoidCallback onEditReceived;
  final bool receivedTyped;
  final String receivedText;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final AppColors c = AppColors.of(context);
    final TextStyle? amountStyle = theme.textTheme.labelLarge?.merge(AppTextStyles.tabular);
    final int loss = sent - received;
    if (!sameCurrency) {
      return Padding(
        padding: const EdgeInsets.only(top: AppSpacing.sm),
        child: Text(l.bonusSameCurrencyOnly,
            textAlign: TextAlign.center, style: theme.textTheme.bodySmall?.copyWith(color: cs.error)),
      );
    }
    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.sm),
      decoration: BoxDecoration(color: cs.surfaceContainerLow, borderRadius: AppRadius.brMd),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          InkWell(
            onTap: onEditReceived,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: AppSpacing.sm,
                children: <Widget>[
                  Text(l.transferSent(Fmt.money(sent, currency, lang)), style: amountStyle),
                  const Icon(Icons.arrow_forward, size: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                    decoration: editing
                        ? BoxDecoration(border: Border.all(color: cs.primary, width: 2), borderRadius: AppRadius.brSm)
                        : null,
                    child: Text(
                      l.transferArrives(
                        receivedTyped ? receivedText : Fmt.money(received, currency, lang),
                        rate,
                      ),
                      style: amountStyle?.copyWith(color: c.transfer),
                    ),
                  ),
                  Icon(Icons.edit_outlined, size: 16, color: cs.onSurfaceVariant, semanticLabel: l.bonusReceivedEdit),
                ],
              ),
            ),
          ),
          if (loss > 0)
            Container(
              color: c.warningContainer,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              child: Row(
                children: <Widget>[
                  Icon(Icons.trending_down, size: 18, color: c.onWarningContainer),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      l.bonusLoss(Fmt.money(loss, currency, lang)),
                      style: theme.textTheme.bodyMedium?.copyWith(color: c.onWarningContainer),
                    ),
                  ),
                  Tooltip(
                    message: l.bonusLossExplain(rate),
                    triggerMode: TooltipTriggerMode.tap,
                    child: Icon(Icons.info_outline, size: 18, color: c.onWarningContainer),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Transport sub-picker under the selectors (DESIGN.md §18.5.2).
class _TransportPanel extends StatelessWidget {
  const _TransportPanel({
    required this.mode,
    required this.routeCode,
    required this.route,
    required this.trips,
    required this.lang,
    required this.onMode,
    required this.onTrips,
    required this.onPickRoute,
    required this.onPickStation,
  });

  final TransportMode? mode;
  final String? routeCode;
  final BusRoute? route;
  final int trips;
  final String lang;
  final ValueChanged<TransportMode> onMode;
  final ValueChanged<int> onTrips;
  final VoidCallback onPickRoute;
  final VoidCallback onPickStation;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final TransportModeStyle? style = mode == null ? null : TransportModeStyle.forMode(mode!);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(l.transportMode, style: theme.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.xs),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: <Widget>[
                for (final TransportMode m in TransportMode.values)
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: ChoiceChip(
                      avatar: Icon(TransportModeStyle.forMode(m).icon, size: 18),
                      label: Text(transportModeLabel(l, m)),
                      selected: mode == m,
                      showCheckmark: false,
                      onSelected: (_) => onMode(m),
                    ),
                  ),
              ],
            ),
          ),
          if (style != null && style.hasRoutes)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Material(
                color: cs.surfaceContainerLow,
                borderRadius: AppRadius.brMd,
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  minTileHeight: 56,
                  leading: routeCode == null
                      ? const Icon(Icons.directions_bus_outlined)
                      : RouteBadge(code: routeCode!, custom: route?.isCustom ?? false),
                  title: Text(routeCode == null ? l.chooseRoute : (route?.label.isNotEmpty ?? false) ? route!.label : routeCode!),
                  subtitle: route?.uncertain ?? false
                      ? Text(l.fareUncertain, style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant))
                      : Text(l.busRoute),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: onPickRoute,
                ),
              ),
            ),
          if (style != null && style.hasStations)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Material(
                color: cs.surfaceContainerLow,
                borderRadius: AppRadius.brMd,
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  minTileHeight: 56,
                  leading: const Icon(Icons.subway_outlined),
                  title: Text(routeCode ?? l.metroStation),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: onPickStation,
                ),
              ),
            ),
          if (style != null && style.hasTrips)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Row(
                children: <Widget>[
                  Expanded(child: Text(l.trips, style: theme.textTheme.bodyLarge)),
                  IconButton.outlined(
                    tooltip: '−',
                    icon: const Icon(Icons.remove),
                    onPressed: trips > 1 ? () => onTrips(trips - 1) : null,
                  ),
                  SizedBox(
                    width: 48,
                    child: Text(
                      '×$trips',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium?.merge(AppTextStyles.tabular),
                      semanticsLabel: l.tripsCount(trips),
                    ),
                  ),
                  IconButton.outlined(
                    tooltip: '+',
                    icon: const Icon(Icons.add),
                    onPressed: trips < FareAutoFill.maxTrips ? () => onTrips(trips + 1) : null,
                  ),
                ],
              ),
            ),
          if (mode == TransportMode.bakuCard)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(Icons.info_outline, size: 18, color: cs.onSurfaceVariant),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      l.bakuCardDoubleCountHint,
                      style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
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
    // The bonus-loss system category is written by bonus transfers only.
    final List<TxCategory> cats = (ref
                .watch(categoriesProvider((type: type, includeArchived: false)))
                .value ??
            const <TxCategory>[])
        .where((TxCategory c) => !c.isSystem)
        .toList();

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
