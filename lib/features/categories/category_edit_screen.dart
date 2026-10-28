import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/category_icons.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';

/// Create / edit a category: names (az/en), icon, colour. On create, pops
/// the new id.
class CategoryEditScreen extends ConsumerStatefulWidget {
  const CategoryEditScreen({
    super.key,
    this.categoryId,
    this.initialType = CategoryType.expense,
  });

  final int? categoryId;
  final CategoryType initialType;

  @override
  ConsumerState<CategoryEditScreen> createState() => _CategoryEditScreenState();
}

class _CategoryEditScreenState extends ConsumerState<CategoryEditScreen> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _nameAz = TextEditingController();
  final TextEditingController _nameEn = TextEditingController();
  late CategoryType _type = widget.initialType;
  int _icon = CategoryIcons.all.first.codePoint;
  int _color = 0;

  TxCategory? _original;
  bool _used = false;
  bool _loading = false;
  bool _saving = false;

  bool get _isEdit => widget.categoryId != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      _loading = true;
      _load();
    }
  }

  Future<void> _load() async {
    final TxCategory? c = (await ref
            .read(categoryRepositoryProvider)
            .watch(includeArchived: true)
            .first)
        .where((TxCategory c) => c.id == widget.categoryId)
        .firstOrNull;
    final bool used =
        c != null && await ref.read(categoryRepositoryProvider).isUsed(c.id);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _original = c;
      _used = used;
      if (c != null) {
        _nameAz.text = c.nameAz;
        _nameEn.text = c.nameEn;
        _type = c.type;
        _icon = c.iconCodePoint;
        _color = c.colorIndex;
      }
    });
  }

  @override
  void dispose() {
    _nameAz.dispose();
    _nameEn.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    _saving = true;
    final CategoryRepository repo = ref.read(categoryRepositoryProvider);
    int? id;
    try {
      if (_original == null) {
        id = await repo.create(
          nameAz: _nameAz.text.trim(),
          nameEn: _nameEn.text.trim(),
          iconCodePoint: _icon,
          colorIndex: _color,
          type: _type,
        );
      } else {
        await repo.update(_original!.copyWith(
          nameAz: _nameAz.text.trim(),
          nameEn: _nameEn.text.trim(),
          iconCodePoint: _icon,
          colorIndex: _color,
          type: _type,
        ));
      }
    } finally {
      _saving = false;
    }
    if (mounted) context.pop(id);
  }

  Future<void> _toggleArchive() async {
    final TxCategory? c = _original;
    if (c == null) return;
    await ref.read(categoryRepositoryProvider).setArchived(c.id, !c.isArchived);
    if (mounted) context.pop();
  }

  Future<void> _delete() async {
    final AppLocalizations l = AppLocalizations.of(context);
    final TxCategory? c = _original;
    if (c == null) return;
    final bool ok = await confirmDialog(
      context,
      title: l.deleteCategoryTitle,
      message: _used ? l.deleteCategoryUsedBody : l.deleteCategoryBody,
      confirmLabel: _used ? l.archive : l.delete,
      destructive: !_used,
    );
    if (!ok || !mounted) return;
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final bool deleted =
        await ref.read(categoryRepositoryProvider).deleteOrArchive(c.id);
    if (!mounted) return;
    context.pop();
    messenger.showSnackBar(
      SnackBar(content: Text(deleted ? l.categoryDeleted : l.categoryArchived)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_isEdit && _original == null) {
      return Scaffold(
        appBar: AppBar(),
        body: EmptyState(icon: Icons.search_off, title: l.categoryNotFound),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? l.editCategory : l.newCategory),
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
              Center(
                child: CategoryAvatar(
                  icon: CategoryIcons.byCodePoint(_icon),
                  colorIndex: _color,
                  size: 64,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              // A used category keeps its type so past entries stay consistent.
              SegmentedButton<CategoryType>(
                segments: <ButtonSegment<CategoryType>>[
                  ButtonSegment<CategoryType>(
                    value: CategoryType.expense,
                    label: Text(l.txTypeExpense),
                  ),
                  ButtonSegment<CategoryType>(
                    value: CategoryType.income,
                    label: Text(l.txTypeIncome),
                  ),
                ],
                selected: <CategoryType>{_type},
                onSelectionChanged: _used
                    ? null
                    : (Set<CategoryType> s) => setState(() => _type = s.first),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                controller: _nameAz,
                maxLength: 60,
                textCapitalization: TextCapitalization.sentences,
                decoration: AppTheme.inputDecoration(context, label: l.nameAz),
                validator: (String? v) =>
                    (v ?? '').trim().isEmpty ? l.nameRequired : null,
              ),
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                controller: _nameEn,
                maxLength: 60,
                textCapitalization: TextCapitalization.sentences,
                decoration: AppTheme.inputDecoration(
                  context,
                  label: l.nameEn,
                  hint: l.nameEnHint,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(l.icon, style: theme.textTheme.titleSmall),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: <Widget>[
                  for (final IconData icon in CategoryIcons.all)
                    Semantics(
                      button: true,
                      selected: icon.codePoint == _icon,
                      label: l.icon,
                      child: InkWell(
                        borderRadius: AppRadius.brMd,
                        onTap: () => setState(() => _icon = icon.codePoint),
                        child: Container(
                          width: AppSizes.minTouch,
                          height: AppSizes.minTouch,
                          decoration: BoxDecoration(
                            borderRadius: AppRadius.brMd,
                            color: icon.codePoint == _icon
                                ? cs.primaryContainer
                                : cs.surfaceContainerHigh,
                          ),
                          child: Icon(
                            icon,
                            color: icon.codePoint == _icon
                                ? cs.onPrimaryContainer
                                : cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(l.color, style: theme.textTheme.titleSmall),
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
