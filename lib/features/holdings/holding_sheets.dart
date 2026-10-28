import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';
import '../settings/settings_controller.dart';
import '../transactions/amount_calc.dart';
import '../transactions/widgets/amount_keypad.dart';

/// Localised message for a rejected holding change.
String holdingErrorText(AppLocalizations l, HoldingAmountFailure f) =>
    switch (f) {
      HoldingAmountFailure.negative => l.holdingErrorNegative,
      HoldingAmountFailure.invalidAmount => l.positiveAmountRequired,
      HoldingAmountFailure.currencyLocked => l.holdingCurrencyLocked,
      HoldingAmountFailure.notFound => l.genericError,
    };

/// Opens the "adjust amount" sheet on [kind].
Future<void> showAdjustSheet(
  BuildContext context,
  Holding holding,
  int current, {
  HoldingEntryKind kind = HoldingEntryKind.add,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (_) =>
      AdjustHoldingSheet(holding: holding, current: current, initialKind: kind),
);

/// Delete (or archive, if account moves use it) after confirmation.
/// Returns true when something changed.
Future<bool> deleteHoldingFlow(
  BuildContext context,
  WidgetRef ref,
  Holding h,
) async {
  final AppLocalizations l = AppLocalizations.of(context);
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  final HoldingDetail? d = await ref
      .read(holdingRepositoryProvider)
      .watchDetail(h.id)
      .first;
  if (d == null || !context.mounted) return false;
  final bool ok = await confirmDialog(
    context,
    title: l.holdingDeleteConfirm(h.name),
    message: d.usedByTransactions
        ? l.deleteHoldingUsedBody
        : l.deleteHoldingBody,
    confirmLabel: d.usedByTransactions ? l.archive : l.delete,
    destructive: !d.usedByTransactions,
  );
  if (!ok) return false;
  final bool deleted = await ref
      .read(holdingRepositoryProvider)
      .deleteOrArchive(h.id);
  messenger.showSnackBar(
    SnackBar(content: Text(deleted ? l.holdingDeleted : l.holdingArchived)),
  );
  return true;
}

/// DESIGN.md §14.6: add / withdraw / set value with the keypad, a live
/// preview of the new amount, and an optional link to an account (a
/// toHolding / fromHolding move, same currency only).
class AdjustHoldingSheet extends ConsumerStatefulWidget {
  const AdjustHoldingSheet({
    super.key,
    required this.holding,
    required this.current,
    this.initialKind = HoldingEntryKind.add,
  });

  final Holding holding;
  final int current;
  final HoldingEntryKind initialKind;

  @override
  ConsumerState<AdjustHoldingSheet> createState() => _AdjustHoldingSheetState();
}

class _AdjustHoldingSheetState extends ConsumerState<AdjustHoldingSheet>
    with SingleTickerProviderStateMixin {
  late HoldingEntryKind _kind = widget.initialKind;
  final AmountCalc _amount = AmountCalc();
  DateTime _date = DateTime.now();
  String _note = '';
  bool _link = false;
  int? _accountId;
  String? _error;
  bool _saving = false;
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: AppMotion.short4,
  );

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  int get _value => _amount.evaluate() ?? 0;

  int get _after => switch (_kind) {
    HoldingEntryKind.add => widget.current + _value,
    HoldingEntryKind.withdraw => widget.current - _value,
    HoldingEntryKind.setValue => _value,
  };

  bool get _valid =>
      _after >= 0 &&
      (_kind == HoldingEntryKind.setValue ? !_amount.isEmpty : _value > 0);

  Future<void> _fail(String msg) async {
    setState(() => _error = msg);
    AppHaptics.error();
    if (!AppMotion.reduced(context)) await _shake.forward(from: 0);
  }

  Future<void> _save(List<Account> accounts) async {
    final AppLocalizations l = AppLocalizations.of(context);
    if (_saving) return;
    if (_after < 0) return _fail(l.withdrawTooMuch);
    if (!_valid) return _fail(l.enterAmount);
    final bool link =
        _link && _kind != HoldingEntryKind.setValue && accounts.isNotEmpty;
    final int? account =
        _accountId ?? (accounts.isEmpty ? null : accounts.first.id);
    final NavigatorState nav = Navigator.of(context);
    _saving = true;
    try {
      final HoldingRepository repo = ref.read(holdingRepositoryProvider);
      if (link && account != null) {
        await repo.move(
          accountId: account,
          holdingId: widget.holding.id,
          toHolding: _kind == HoldingEntryKind.add,
          amount: _value,
          date: _date,
          note: _note.trim(),
        );
      } else {
        await repo.addEntry(
          holdingId: widget.holding.id,
          kind: _kind,
          amount: _value,
          date: _date,
          note: _note.trim(),
        );
      }
      AppHaptics.confirm();
      nav.pop();
    } on HoldingAmountException catch (e) {
      await _fail(holdingErrorText(l, e.reason));
    } finally {
      _saving = false;
    }
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
          decoration: AppTheme.inputDecoration(ctx, hint: l.noteHint),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l.cancel),
          ),
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

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final String lang = ref.watch(languageProvider);
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final AppColors c = AppColors.of(context);
    final Holding h = widget.holding;
    final List<Account> accounts =
        (ref.watch(accountBalancesProvider).value ??
                const <AccountWithBalance>[])
            .map((AccountWithBalance a) => a.account)
            .where((Account a) => a.currency == h.currency)
            .toList();
    final String sep = Fmt.decimalSeparator(lang);
    final String sign = switch (_kind) {
      HoldingEntryKind.add => '+${Fmt.thinSpace}',
      HoldingEntryKind.withdraw => '${Fmt.minus}${Fmt.thinSpace}',
      HoldingEntryKind.setValue => '',
    };
    final String body = _amount.display(sep);
    final String shown = h.currency == Currency.azn.code
        ? (lang == 'en' ? '₼$body' : '$body ₼')
        : '$body ${h.currency}';
    final bool negative = _after < 0;
    final String preview = _kind == HoldingEntryKind.setValue
        ? l.holdingDifference(
            Fmt.signed(
              (_after - widget.current).abs(),
              h.currency,
              _after >= widget.current ? TxType.income : TxType.expense,
              lang,
            ),
          )
        : l.holdingNewBalance(Fmt.money(_after, h.currency, lang));

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(h.name, style: theme.textTheme.titleMedium),
                Text(
                  l.holdingCurrentAmount(
                    Fmt.money(widget.current, h.currency, lang),
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                SegmentedButton<HoldingEntryKind>(
                  showSelectedIcon: false,
                  segments: <ButtonSegment<HoldingEntryKind>>[
                    ButtonSegment<HoldingEntryKind>(
                      value: HoldingEntryKind.add,
                      icon: const Icon(Icons.add),
                      label: Text(l.holdingEntryAdd),
                    ),
                    ButtonSegment<HoldingEntryKind>(
                      value: HoldingEntryKind.withdraw,
                      icon: const Icon(Icons.remove),
                      label: Text(l.holdingEntryWithdraw),
                    ),
                    ButtonSegment<HoldingEntryKind>(
                      value: HoldingEntryKind.setValue,
                      icon: const Icon(Icons.drag_handle),
                      label: Text(l.holdingEntrySetValue),
                    ),
                  ],
                  selected: <HoldingEntryKind>{_kind},
                  onSelectionChanged: (Set<HoldingEntryKind> s) {
                    AppHaptics.key();
                    setState(() {
                      _kind = s.first;
                      _error = null;
                    });
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                AnimatedBuilder(
                  animation: _shake,
                  builder: (BuildContext context, Widget? child) =>
                      Transform.translate(
                        offset: Offset(
                          math.sin(_shake.value * math.pi * 4) * 8,
                          0,
                        ),
                        child: child,
                      ),
                  child: Semantics(
                    liveRegion: true,
                    label: '${holdingEntryKindLabel(l, _kind)} $shown',
                    excludeSemantics: true,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '$sign$shown',
                        style: AppTextStyles.amountInput.copyWith(
                          color: cs.onSurface,
                        ),
                      ),
                    ),
                  ),
                ),
                Text(
                  _error ?? (negative ? l.withdrawTooMuch : preview),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: _error != null || negative
                        ? c.danger
                        : cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  alignment: WrapAlignment.center,
                  children: <Widget>[
                    ActionChip(
                      avatar: const Icon(
                        Icons.calendar_today_outlined,
                        size: 18,
                      ),
                      label: Text(
                        Fmt.sameDay(_date, DateTime.now())
                            ? l.today
                            : Fmt.date(_date, lang),
                      ),
                      onPressed: () async {
                        final DateTime? d = await showDatePicker(
                          context: context,
                          initialDate: _date,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (d != null) {
                          setState(
                            () => _date = DateTime(
                              d.year,
                              d.month,
                              d.day,
                              _date.hour,
                              _date.minute,
                            ),
                          );
                        }
                      },
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.edit_note, size: 18),
                      label: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 160),
                        child: Text(
                          _note.trim().isEmpty ? l.addNote : _note.trim(),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      onPressed: _editNote,
                    ),
                  ],
                ),
                if (_kind != HoldingEntryKind.setValue && accounts.isNotEmpty)
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          title: Text(
                            _kind == HoldingEntryKind.add
                                ? l.linkFromAccount
                                : l.linkToAccount,
                          ),
                          value: _link,
                          onChanged: (bool? v) =>
                              setState(() => _link = v ?? false),
                        ),
                      ),
                      if (_link)
                        DropdownButton<int>(
                          value: _accountId ?? accounts.first.id,
                          items: <DropdownMenuItem<int>>[
                            for (final Account a in accounts)
                              DropdownMenuItem<int>(
                                value: a.id,
                                child: Text(a.name),
                              ),
                          ],
                          onChanged: (int? v) => setState(() => _accountId = v),
                        ),
                    ],
                  ),
              ],
            ),
          ),
          AmountKeypad(
            decimalLabel: sep,
            checkIsEquals: false,
            showOperators: false,
            checkEnabled: _valid,
            onDigit: (String d) => setState(() {
              _amount.digit(d);
              _error = null;
            }),
            onDoubleZero: () => setState(
              () => _amount
                ..digit('0')
                ..digit('0'),
            ),
            onDecimal: () => setState(_amount.decimal),
            onOperator: (_) {},
            onBackspace: () => setState(_amount.backspace),
            onClear: () => setState(_amount.clear),
            onCheck: () => _save(accounts),
          ),
        ],
      ),
    );
  }
}

/// Edit an entry's date / note, or delete it (DESIGN.md §14.4).
class HoldingEntrySheet extends ConsumerStatefulWidget {
  const HoldingEntrySheet({super.key, required this.entry});

  final HoldingEntry entry;

  @override
  ConsumerState<HoldingEntrySheet> createState() => _HoldingEntrySheetState();
}

class _HoldingEntrySheetState extends ConsumerState<HoldingEntrySheet> {
  late DateTime _date = widget.entry.date;
  late final TextEditingController _note = TextEditingController(
    text: widget.entry.note,
  );
  String? _error;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() f) async {
    final AppLocalizations l = AppLocalizations.of(context);
    final NavigatorState nav = Navigator.of(context);
    try {
      await f();
      AppHaptics.confirm();
      nav.pop();
    } on HoldingAmountException catch (e) {
      AppHaptics.error();
      setState(() => _error = holdingErrorText(l, e.reason));
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final String lang = ref.watch(languageProvider);
    final HoldingRepository repo = ref.read(holdingRepositoryProvider);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                holdingEntryKindLabel(l, widget.entry.kind),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.md),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today_outlined),
                title: Text(Fmt.date(_date, lang)),
                onTap: () async {
                  final DateTime? d = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (d != null) {
                    setState(
                      () => _date = DateTime(
                        d.year,
                        d.month,
                        d.day,
                        _date.hour,
                        _date.minute,
                      ),
                    );
                  }
                },
              ),
              TextField(
                controller: _note,
                maxLength: 200,
                decoration: AppTheme.inputDecoration(
                  context,
                  label: l.note,
                  errorText: _error,
                ),
              ),
              if (widget.entry.transactionId != null)
                Text(
                  l.deleteHoldingEntryLinkedBody,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: <Widget>[
                  TextButton.icon(
                    onPressed: () async {
                      final bool ok = await confirmDialog(
                        context,
                        title: l.deleteHoldingEntryTitle,
                        confirmLabel: l.delete,
                        destructive: true,
                      );
                      if (ok) {
                        await _run(() => repo.deleteEntry(widget.entry.id));
                      }
                    },
                    icon: const Icon(Icons.delete_outline),
                    label: Text(l.delete),
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () => _run(
                      () => repo.updateEntry(
                        widget.entry.id,
                        date: _date,
                        note: _note.text.trim(),
                      ),
                    ),
                    child: Text(l.save),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
