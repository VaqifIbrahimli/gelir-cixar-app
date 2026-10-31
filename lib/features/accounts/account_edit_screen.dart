import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';
import '../lock/system_dialog_guard.dart';
import '../settings/settings_controller.dart';
import 'widgets/account_card.dart';

/// Create / edit an account. On create, pops the new id.
class AccountEditScreen extends ConsumerStatefulWidget {
  const AccountEditScreen({super.key, this.accountId});

  final int? accountId;

  @override
  ConsumerState<AccountEditScreen> createState() => _AccountEditScreenState();
}

/// "Kart dizaynı" (DESIGN.md §18.2.1): live preview, preset mini cards and
/// the photo tile.
class _DesignSection extends StatelessWidget {
  const _DesignSection({
    required this.preview,
    required this.previewImage,
    required this.designId,
    required this.hasPhoto,
    required this.lang,
    required this.onDesign,
    required this.onPickPhoto,
    required this.onRemovePhoto,
  });

  final Account preview;
  final ImageProvider? previewImage;
  final String designId;
  final bool hasPhoto;
  final String lang;
  final ValueChanged<String> onDesign;
  final VoidCallback onPickPhoto;
  final VoidCallback onRemovePhoto;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final AppCardDesign selected = AppCardDesigns.byId(designId);

    Widget mini({required Widget child, required bool isSelected, required String label, required VoidCallback onTap}) =>
        Semantics(
          button: true,
          selected: isSelected,
          label: isSelected ? l.selectedItem(label) : label,
          excludeSemantics: true,
          child: InkWell(
            onTap: onTap,
            borderRadius: AppRadius.brSm,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.all(Radius.circular(11)),
                  border: Border.all(color: isSelected ? cs.primary : Colors.transparent, width: 3),
                ),
                child: SizedBox(width: 56, height: 36, child: child),
              ),
            ),
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(l.cardDesign, style: theme.textTheme.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        AspectRatio(
          aspectRatio: AppCardDesigns.aspectRatio,
          child: AccountCardView(account: preview, balance: preview.initialBalance, previewImage: previewImage),
        ),
        const SizedBox(height: AppSpacing.sm),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: <Widget>[
              for (final AppCardDesign d in AppCardDesigns.presets)
                mini(
                  isSelected: d.id == designId,
                  label: d.label(lang),
                  onTap: () => onDesign(d.id),
                  child: DecoratedBox(
                    decoration: BoxDecoration(gradient: d.gradient, borderRadius: AppRadius.brSm),
                    child: d.id == designId ? Icon(Icons.check, size: 18, color: d.onCard) : null,
                  ),
                ),
              mini(
                isSelected: designId == AppCardDesigns.photoId,
                label: l.cardDesignPhoto,
                onTap: onPickPhoto,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: cs.surfaceContainerHigh, borderRadius: AppRadius.brSm),
                  child: Icon(Icons.add_photo_alternate_outlined, size: 20, color: cs.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
        Text(selected.label(lang), style: theme.textTheme.bodySmall),
        if (hasPhoto)
          Row(
            children: <Widget>[
              TextButton(onPressed: onPickPhoto, child: Text(l.cardChangePhoto)),
              TextButton(onPressed: onRemovePhoto, child: Text(l.cardRemovePhoto)),
            ],
          ),
      ],
    );
  }
}

class _AccountEditScreenState extends ConsumerState<AccountEditScreen> {
  /// What the card looks like with the form's current values.
  Account _previewAccount() {
    final String? last4 = RegExp(r'^\d{4}$').hasMatch(_last4.text.trim()) ? _last4.text.trim() : null;
    final int rate = (int.tryParse(_rate.text.trim()) ?? 50).clamp(1, 100);
    return Account(
      id: _original?.id ?? 0,
      name: _name.text.trim().isEmpty ? AppLocalizations.of(context).name : _name.text.trim(),
      type: _type,
      currency: _currency,
      initialBalance: Fmt.parseMinor(_initial.text) ?? 0,
      colorIndex: _color,
      isArchived: false,
      createdAt: _original?.createdAt ?? DateTime(2026),
      cardDesignId: _effectiveDesign,
      cardImagePath: _removePhoto ? null : _original?.cardImagePath,
      cardLast4: last4,
      bonusRatePercent: rate,
    );
  }

  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _initial = TextEditingController();
  final TextEditingController _last4 = TextEditingController();
  final TextEditingController _rate = TextEditingController(text: '50');
  AccountType _type = AccountType.cash;
  String _currency = Currency.base.code;
  int _color = 0;

  /// Card design (§18.2); null until the user picks one on a new account
  /// (then the type's default is used).
  String? _designId;

  /// Photo picked in this session, not yet stored (re-encoded JPEG).
  Uint8List? _newPhoto;

  /// The stored photo is to be removed on save.
  bool _removePhoto = false;
  bool _picking = false;

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
        _designId = a.cardDesignId;
        _last4.text = a.cardLast4 ?? '';
        _rate.text = '${a.bonusRatePercent}';
      }
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _initial.dispose();
    _last4.dispose();
    _rate.dispose();
    super.dispose();
  }

  String get _effectiveDesign =>
      _designId ?? AccountTypeStyle.forType(_type).defaultDesignId;

  /// Gallery pick, re-encoded to JPEG q80 with the long side <= 1200 px.
  /// The picker runs inside the lock's system-dialog guard, so the
  /// "lock immediately" setting does not fire while the gallery is open.
  Future<void> _pickPhoto() async {
    if (_picking) return;
    _picking = true;
    final AppLocalizations l = AppLocalizations.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      final XFile? file = await SystemDialogGuard.run(
        () => ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 2400, maxHeight: 2400),
      );
      if (file == null) return;
      final Uint8List raw = await file.readAsBytes();
      final Uint8List? jpeg = await compute(CardImageStore.reencode, raw);
      if (jpeg == null) {
        messenger.showSnackBar(SnackBar(content: Text(l.cardPhotoFailed)));
        return;
      }
      if (!mounted) return;
      setState(() {
        _newPhoto = jpeg;
        _removePhoto = false;
        _designId = AppCardDesigns.photoId;
      });
    } on PlatformException {
      messenger.showSnackBar(SnackBar(content: Text(l.cardPhotoFailed)));
    } finally {
      _picking = false;
    }
  }

  /// Stores a newly picked photo and deletes the replaced one. Returns the
  /// file name the account keeps.
  Future<String?> _commitPhoto(CardImageStore store) async {
    final String? old = _original?.cardImagePath;
    if (_effectiveDesign != AppCardDesigns.photoId || _removePhoto) {
      await store.delete(old);
      return null;
    }
    if (_newPhoto != null) {
      final String name = await store.saveJpeg(_newPhoto!);
      await store.delete(old);
      return name;
    }
    return old;
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    _saving = true;
    final AccountRepository repo = ref.read(accountRepositoryProvider);
    final int initial = Fmt.parseMinor(_initial.text) ?? 0;
    final String name = _name.text.trim();
    final String? last4 = _last4.text.trim().isEmpty ? null : _last4.text.trim();
    final int rate = int.tryParse(_rate.text.trim()) ?? 50;
    final CardImageStore store = ref.read(cardImageStoreProvider);
    int? id;
    try {
      final String? image = await _commitPhoto(store);
      final String design =
          _effectiveDesign == AppCardDesigns.photoId && image == null ? AppCardDesigns.defaultId : _effectiveDesign;
      if (_original == null) {
        id = await repo.create(
          name: name,
          type: _type,
          currency: _currency,
          initialBalance: initial,
          colorIndex: _color,
          cardDesignId: design,
          cardImagePath: image,
          cardLast4: last4,
          bonusRatePercent: rate,
        );
      } else {
        await repo.update(_original!.copyWith(
          name: name,
          type: _type,
          currency: _currency,
          initialBalance: initial,
          colorIndex: _color,
          cardDesignId: design,
          cardImagePath: Value<String?>(image),
          cardLast4: Value<String?>(last4),
          bonusRatePercent: rate,
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
    // A deleted account takes its card photo with it (archived ones keep it).
    if (deleted) await ref.read(cardImageStoreProvider).delete(a.cardImagePath);
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
                onChanged: (_) => setState(() {}),
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
              AnimatedSize(
                duration: AppMotion.of(context, AppMotion.reveal),
                curve: AppMotion.standard,
                child: _type == AccountType.bonus
                    ? Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.lg),
                        child: TextFormField(
                          controller: _rate,
                          keyboardType: TextInputType.number,
                          inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly],
                          maxLength: 3,
                          decoration: AppTheme.inputDecoration(context, label: l.bonusRate)
                              .copyWith(helperText: l.bonusRateHelper, counterText: ''),
                          onChanged: (_) => setState(() {}),
                          validator: (String? v) {
                            final int? n = int.tryParse((v ?? '').trim());
                            return n == null || n < 1 || n > 100 ? l.bonusRateInvalid : null;
                          },
                        ),
                      )
                    : const SizedBox(width: double.infinity),
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
                onChanged: (_) => setState(() {}),
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
              _DesignSection(
                preview: _previewAccount(),
                previewImage: _newPhoto == null ? null : MemoryImage(_newPhoto!),
                designId: _effectiveDesign,
                hasPhoto: _effectiveDesign == AppCardDesigns.photoId &&
                    !_removePhoto &&
                    (_newPhoto != null || _original?.cardImagePath != null),
                lang: lang,
                onDesign: (String id) => setState(() => _designId = id),
                onPickPhoto: _pickPhoto,
                onRemovePhoto: () => setState(() {
                  _newPhoto = null;
                  _removePhoto = true;
                  _designId = AppCardDesigns.defaultId;
                }),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _last4,
                keyboardType: TextInputType.number,
                inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly],
                maxLength: 4,
                decoration: AppTheme.inputDecoration(context, label: l.cardLast4Label)
                    .copyWith(helperText: l.cardLast4Helper, helperMaxLines: 2),
                onChanged: (_) => setState(() {}),
                validator: (String? v) {
                  final String s = (v ?? '').trim();
                  return s.isEmpty || RegExp(r'^\d{4}$').hasMatch(s) ? null : l.cardLast4Invalid;
                },
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
