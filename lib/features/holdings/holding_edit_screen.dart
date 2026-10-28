import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';
import '../settings/exchange_rates_screen.dart';
import '../settings/settings_controller.dart';
import 'holding_sheets.dart';

/// Create / edit a holding. On create, pops the new id.
class HoldingEditScreen extends ConsumerStatefulWidget {
  const HoldingEditScreen({super.key, this.holdingId});

  final int? holdingId;

  @override
  ConsumerState<HoldingEditScreen> createState() => _HoldingEditScreenState();
}

class _HoldingEditScreenState extends ConsumerState<HoldingEditScreen> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _note = TextEditingController();
  final TextEditingController _initial = TextEditingController();
  final TextEditingController _interest = TextEditingController();
  HoldingPlace _place = HoldingPlace.homeCash;
  String _currency = Currency.base.code;
  DateTime? _maturity;
  int _color = 0;
  Holding? _original;
  bool _hasEntries = false;
  bool _loading = false;
  bool _saving = false;
  String? _error;

  /// New holdings only: take the initial amount from an account.
  bool _fromAccount = false;
  int? _accountId;

  bool get _isEdit => widget.holdingId != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      _loading = true;
      _load();
    }
  }

  Future<void> _load() async {
    final HoldingDetail? d = await ref
        .read(holdingRepositoryProvider)
        .watchDetail(widget.holdingId!)
        .first;
    if (!mounted) return;
    final String lang = ref.read(languageProvider);
    setState(() {
      _loading = false;
      if (d == null) return;
      final Holding h = d.holding;
      _original = h;
      _hasEntries = d.entries.isNotEmpty;
      _name.text = h.name;
      _note.text = h.note;
      _place = h.placeType;
      _currency = h.currency;
      _maturity = h.maturityDate;
      _color = h.colorIndex;
      _interest.text = h.interestRate == null
          ? ''
          : (lang == 'en'
                ? '${h.interestRate}'
                : '${h.interestRate}'.replaceAll('.', ','));
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _note.dispose();
    _initial.dispose();
    _interest.dispose();
    super.dispose();
  }

  double? get _interestValue => _interest.text.trim().isEmpty
      ? null
      : ExchangeRatesScreen.parseRate(_interest.text);

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    final AppLocalizations l = AppLocalizations.of(context);
    final HoldingRepository repo = ref.read(holdingRepositoryProvider);
    final bool deposit = _place == HoldingPlace.bankDeposit;
    final DateTime now = DateTime.now();
    final bool maturityChanged = _maturity != _original?.maturityDate;
    if (deposit &&
        _maturity != null &&
        maturityChanged &&
        !_maturity!.isAfter(DateTime(now.year, now.month, now.day))) {
      setState(() => _error = l.maturityAfterToday);
      AppHaptics.error();
      return;
    }
    final int? initial = _initial.text.trim().isEmpty
        ? null
        : Fmt.parseMinor(_initial.text);
    final List<Account> sources = _sourceAccounts();
    final int? account = _fromAccount && sources.isNotEmpty
        ? (_accountId ?? sources.first.id)
        : null;
    _saving = true;
    int? id;
    try {
      if (_original == null) {
        id = await repo.create(
          name: _name.text.trim(),
          placeType: _place,
          currency: _currency,
          note: _note.text.trim(),
          interestRate: deposit ? _interestValue : null,
          maturityDate: deposit ? _maturity : null,
          colorIndex: _color,
          initialAmount: account == null ? initial : null,
        );
        if (account != null && initial != null && initial > 0) {
          await repo.move(
            accountId: account,
            holdingId: id,
            toHolding: true,
            amount: initial,
            date: DateTime.now(),
          );
        }
      } else {
        await repo.update(
          _original!.copyWith(
            name: _name.text.trim(),
            placeType: _place,
            currency: _currency,
            note: _note.text.trim(),
            interestRate: Value<double?>(deposit ? _interestValue : null),
            maturityDate: Value<DateTime?>(deposit ? _maturity : null),
            colorIndex: _color,
          ),
        );
      }
    } on HoldingAmountException catch (e) {
      setState(() => _error = holdingErrorText(l, e.reason));
      return;
    } finally {
      _saving = false;
    }
    AppHaptics.confirm();
    if (mounted) context.pop(id);
  }

  /// Accounts in the holding's currency (a move needs one currency).
  List<Account> _sourceAccounts() =>
      (ref.read(accountBalancesProvider).value ?? const <AccountWithBalance>[])
          .map((AccountWithBalance a) => a.account)
          .where((Account a) => a.currency == _currency)
          .toList();

  String _nameHint(AppLocalizations l) => switch (_place) {
    HoldingPlace.homeCash => l.holdingNameHint,
    HoldingPlace.person => l.holdingNameHintPerson,
    HoldingPlace.bankDeposit => l.holdingNameHintDeposit,
    HoldingPlace.gold => l.holdingNameHintGold,
    HoldingPlace.other => l.holdingNameHint,
  };

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final String lang = ref.watch(languageProvider);
    final ThemeData theme = Theme.of(context);
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_isEdit && _original == null) {
      return Scaffold(
        appBar: AppBar(),
        body: EmptyState(icon: Icons.search_off, title: l.holdingNotFound),
      );
    }
    final bool deposit = _place == HoldingPlace.bankDeposit;

    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? l.editHolding : l.addHolding)),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: <Widget>[
              TextFormField(
                controller: _name,
                maxLength: 40,
                textCapitalization: TextCapitalization.sentences,
                decoration: AppTheme.inputDecoration(
                  context,
                  label: l.name,
                  hint: _nameHint(l),
                ),
                validator: (String? v) =>
                    (v ?? '').trim().isEmpty ? l.nameRequired : null,
              ),
              Text(l.holdingPlace, style: theme.textTheme.titleSmall),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: <Widget>[
                  for (final HoldingPlace p in HoldingPlace.values)
                    ChoiceChip(
                      avatar: Icon(holdingPlaceIcon(p), size: 18),
                      label: Text(holdingPlaceLabel(l, p)),
                      selected: _place == p,
                      showCheckmark: false,
                      onSelected: (_) {
                        AppHaptics.key();
                        setState(() => _place = p);
                      },
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              DropdownButtonFormField<String>(
                initialValue: _currency,
                decoration: AppTheme.inputDecoration(
                  context,
                  label: l.currency,
                ),
                items: <DropdownMenuItem<String>>[
                  for (final Currency c in Currency.values)
                    DropdownMenuItem<String>(
                      value: c.code,
                      child: Text('${c.code}  ${c.symbol}'),
                    ),
                ],
                onChanged: _hasEntries
                    ? null
                    : (String? v) => setState(() => _currency = v ?? _currency),
              ),
              if (_hasEntries)
                Padding(
                  padding: const EdgeInsets.only(
                    top: AppSpacing.xs,
                    left: AppSpacing.lg,
                  ),
                  child: Text(
                    l.holdingCurrencyLockedHelper,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              if (!_isEdit) ...<Widget>[
                const SizedBox(height: AppSpacing.lg),
                TextFormField(
                  controller: _initial,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: AppTheme.inputDecoration(
                    context,
                    label: l.holdingInitialAmount,
                    hint: Fmt.editable(0, lang),
                    suffixIcon: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Text(_currency),
                    ),
                  ),
                  validator: (String? v) {
                    if ((v ?? '').trim().isEmpty) return null;
                    final int? m = Fmt.parseMinor(v!);
                    return m == null || m < 0 ? l.positiveAmountRequired : null;
                  },
                ),
                if (_sourceAccounts().isNotEmpty)
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          title: Text(l.holdingFromAccount),
                          value: _fromAccount,
                          onChanged: (bool? v) =>
                              setState(() => _fromAccount = v ?? false),
                        ),
                      ),
                      if (_fromAccount)
                        DropdownButton<int>(
                          value: _accountId ?? _sourceAccounts().first.id,
                          items: <DropdownMenuItem<int>>[
                            for (final Account a in _sourceAccounts())
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
              AnimatedSize(
                duration: AppMotion.of(context, AppMotion.medium1),
                curve: AppMotion.standard,
                child: !deposit
                    ? const SizedBox(width: double.infinity)
                    : Column(
                        children: <Widget>[
                          const SizedBox(height: AppSpacing.lg),
                          TextFormField(
                            controller: _interest,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: AppTheme.inputDecoration(
                              context,
                              label: l.holdingInterestRate,
                              suffixIcon: const Padding(
                                padding: EdgeInsets.all(AppSpacing.md),
                                child: Text('%'),
                              ),
                            ),
                            validator: (String? v) {
                              if ((v ?? '').trim().isEmpty) return null;
                              final double? r = ExchangeRatesScreen.parseRate(
                                v!,
                              );
                              return r == null || r > 100
                                  ? l.holdingInterestInvalid
                                  : null;
                            },
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.event_outlined),
                            title: Text(l.holdingMaturityDate),
                            subtitle: Text(
                              _maturity == null
                                  ? l.notSet
                                  : Fmt.date(_maturity!, lang),
                            ),
                            trailing: _maturity == null
                                ? null
                                : IconButton(
                                    tooltip: l.clear,
                                    icon: const Icon(Icons.close),
                                    onPressed: () =>
                                        setState(() => _maturity = null),
                                  ),
                            onTap: () async {
                              final DateTime? d = await showDatePicker(
                                context: context,
                                initialDate: _maturity ?? DateTime.now(),
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                              );
                              if (d != null) setState(() => _maturity = d);
                            },
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _note,
                maxLength: 200,
                maxLines: 3,
                minLines: 1,
                decoration: AppTheme.inputDecoration(context, label: l.note),
              ),
              Text(l.color, style: theme.textTheme.titleSmall),
              const SizedBox(height: AppSpacing.sm),
              ColorPalettePicker(
                selected: _color,
                onChanged: (int i) => setState(() => _color = i),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.md),
                  child: Text(
                    _error!,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
              const SizedBox(height: AppSpacing.xl),
              FilledButton(onPressed: _save, child: Text(l.save)),
            ],
          ),
        ),
      ),
    );
  }
}
