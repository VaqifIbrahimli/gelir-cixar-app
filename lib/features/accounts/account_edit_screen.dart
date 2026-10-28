import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';
import '../settings/settings_controller.dart';

/// Create / edit an account. On create, pops the new id.
class AccountEditScreen extends ConsumerStatefulWidget {
  const AccountEditScreen({super.key, this.accountId});

  final int? accountId;

  @override
  ConsumerState<AccountEditScreen> createState() => _AccountEditScreenState();
}

class _AccountEditScreenState extends ConsumerState<AccountEditScreen> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _initial = TextEditingController();
  AccountType _type = AccountType.cash;
  String _currency = Currency.base.code;
  int _color = 0;

  Account? _original;
  bool _used = false;
  bool _loading = false;
  bool _saving = false;

  bool get _isEdit => widget.accountId != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      _loading = true;
      _load();
    }
  }

  Future<void> _load() async {
    final AccountRepository repo = ref.read(accountRepositoryProvider);
    final Account? a = await repo.byId(widget.accountId!);
    final bool used = a != null && await repo.isUsed(a.id);
    if (!mounted) return;
    final String lang = ref.read(languageProvider);
    setState(() {
      _loading = false;
      _original = a;
      _used = used;
      if (a != null) {
        _name.text = a.name;
        _initial.text = a.initialBalance == 0 ? '' : Fmt.editable(a.initialBalance, lang);
        _type = a.type;
        _currency = a.currency;
        _color = a.colorIndex;
      }
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _initial.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    _saving = true;
    final AccountRepository repo = ref.read(accountRepositoryProvider);
    final int initial = Fmt.parseMinor(_initial.text) ?? 0;
    final String name = _name.text.trim();
    int? id;
    try {
      if (_original == null) {
        id = await repo.create(
          name: name,
          type: _type,
          currency: _currency,
          initialBalance: initial,
          colorIndex: _color,
        );
      } else {
        await repo.update(_original!.copyWith(
          name: name,
          type: _type,
          currency: _currency,
          initialBalance: initial,
          colorIndex: _color,
        ));
      }
    } on StateError {
      // The data layer refuses a currency change once transactions exist
      // (the field is locked then, so this is only a safety net).
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).currencyLockedHint)),
        );
      }
      return;
    } finally {
      _saving = false;
    }
    if (mounted) context.pop(id);
  }

  Future<void> _toggleArchive() async {
    final Account? a = _original;
    if (a == null) return;
    await ref.read(accountRepositoryProvider).setArchived(a.id, !a.isArchived);
    if (mounted) context.pop();
  }

  Future<void> _delete() async {
    final AppLocalizations l = AppLocalizations.of(context);
    final Account? a = _original;
    if (a == null) return;
    final bool ok = await confirmDialog(
      context,
      title: l.deleteAccountTitle,
      message: _used ? l.deleteAccountUsedBody : l.deleteAccountBody,
      confirmLabel: _used ? l.archive : l.delete,
      destructive: !_used,
    );
    if (!ok || !mounted) return;
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final bool deleted = await ref.read(accountRepositoryProvider).deleteOrArchive(a.id);
    if (!mounted) return;
    context.pop();
    messenger.showSnackBar(
      SnackBar(content: Text(deleted ? l.accountDeleted : l.accountArchived)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final String lang = ref.watch(languageProvider);
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_isEdit && _original == null) {
      return Scaffold(
        appBar: AppBar(),
        body: EmptyState(icon: Icons.search_off, title: l.accountNotFound),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? l.editAccount : l.newAccount),
        actions: <Widget>[
          if (_isEdit)
            PopupMenuButton<String>(
              tooltip: l.more,
              onSelected: (String v) => v == 'archive' ? _toggleArchive() : _delete(),
              itemBuilder: (BuildContext ctx) => <PopupMenuEntry<String>>[
                PopupMenuItem<String>(
                  value: 'archive',
                  child: Text(_original!.isArchived ? l.unarchive : l.archive),
                ),
                PopupMenuItem<String>(value: 'delete', child: Text(l.delete)),
              ],
            ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: <Widget>[
              TextFormField(
                controller: _name,
                maxLength: 60,
                textCapitalization: TextCapitalization.sentences,
                decoration: AppTheme.inputDecoration(context, label: l.name),
                validator: (String? v) =>
                    (v ?? '').trim().isEmpty ? l.nameRequired : null,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(l.accountType, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: <Widget>[
                  for (final AccountType t in AccountType.values)
                    ChoiceChip(
                      avatar: Icon(accountTypeIcon(t), size: 18),
                      label: Text(accountTypeLabel(l, t)),
                      selected: _type == t,
                      showCheckmark: false,
                      onSelected: (_) => setState(() => _type = t),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              DropdownButtonFormField<String>(
                initialValue: _currency,
                decoration: AppTheme.inputDecoration(context, label: l.currency),
                items: <DropdownMenuItem<String>>[
                  for (final Currency c in Currency.values)
                    DropdownMenuItem<String>(
                      value: c.code,
                      child: Text('${c.code}  ${c.symbol}'),
                    ),
                ],
                onChanged: _used ? null : (String? v) => setState(() => _currency = v ?? _currency),
              ),
              if (_used)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs, left: AppSpacing.lg),
                  child: Text(
                    l.currencyLockedHint,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ),
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                controller: _initial,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                decoration: AppTheme.inputDecoration(
                  context,
                  label: l.initialBalance,
                  hint: Fmt.editable(0, lang),
                  suffixIcon: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Text(_currency),
                  ),
                ),
                validator: (String? v) => (v ?? '').trim().isEmpty ||
                        Fmt.parseMinor(v!) != null
                    ? null
                    : l.invalidAmount,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(l.color, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: AppSpacing.sm),
              ColorPalettePicker(
                selected: _color,
                onChanged: (int i) => setState(() => _color = i),
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
