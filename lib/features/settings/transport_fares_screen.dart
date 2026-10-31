import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';
import '../transactions/widgets/route_sheets.dart' show RouteBadge;
import 'settings_controller.dart';

/// Parses a fare typed by the user ("0,6", "0.60") into minor units, or
/// null when it is outside 0,01 – 99,99.
int? parseFare(String text) {
  final int? v = Fmt.parseMinor(text);
  return v != null && TransportFareRepository.fareOk(v) ? v : null;
}

/// Add / edit one of the user's own bus routes (DESIGN.md §18.5.4). Returns
/// the saved code, or null when cancelled.
Future<String?> showOwnRouteSheet(
  BuildContext context,
  WidgetRef ref, {
  BusRoute? editing,
  String initialCode = '',
}) =>
    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext ctx) => _OwnRouteForm(editing: editing, initialCode: initialCode),
    );

class _OwnRouteForm extends ConsumerStatefulWidget {
  const _OwnRouteForm({this.editing, this.initialCode = ''});

  final BusRoute? editing;
  final String initialCode;

  @override
  ConsumerState<_OwnRouteForm> createState() => _OwnRouteFormState();
}

class _OwnRouteFormState extends ConsumerState<_OwnRouteForm> {
  late final TextEditingController _code =
      TextEditingController(text: widget.editing?.code ?? widget.initialCode);
  late final TextEditingController _from = TextEditingController(text: widget.editing?.from ?? '');
  late final TextEditingController _to = TextEditingController(text: widget.editing?.to ?? '');
  late final TextEditingController _fare = TextEditingController(
    text: widget.editing == null ? '' : Fmt.editable(widget.editing!.fare, ref.read(languageProvider)),
  );

  @override
  void dispose() {
    _code.dispose();
    _from.dispose();
    _to.dispose();
    _fare.dispose();
    super.dispose();
  }

  Set<String> get _taken {
    final ResolvedFares? f = ref.read(resolvedFaresProvider).value;
    return <String>{for (final BusRoute b in f?.bus ?? const <BusRoute>[]) b.code}..remove(widget.editing?.code);
  }

  String? get _codeError {
    final AppLocalizations l = AppLocalizations.of(context);
    final String c = _code.text.trim();
    if (c.isEmpty) return null;
    if (!TransportFareRepository.codePattern.hasMatch(c)) return l.routeCodeInvalid;
    if (_taken.contains(c)) return l.routeCodeExists;
    return null;
  }

  bool get _valid =>
      _code.text.trim().isNotEmpty &&
      _codeError == null &&
      _from.text.trim().isNotEmpty &&
      _to.text.trim().isNotEmpty &&
      parseFare(_fare.text) != null;

  Future<void> _save() async {
    final String code = _code.text.trim();
    try {
      await ref.read(transportFareRepositoryProvider).saveCustomRoute(
            previousCode: widget.editing?.code,
            code: code,
            fromName: _from.text,
            toName: _to.text,
            fare: parseFare(_fare.text)!,
            takenCodes: _taken,
          );
    } on StateError {
      setState(() {});
      return;
    }
    if (mounted) Navigator.of(context).pop(code);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    void changed(String _) => setState(() {});
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.lg + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(widget.editing == null ? l.addOwnRoute : l.editOwnRoute,
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _code,
            maxLength: 6,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            decoration: AppTheme.inputDecoration(context, label: l.routeCode).copyWith(errorText: _codeError),
            onChanged: changed,
          ),
          TextField(
            controller: _from,
            maxLength: 60,
            decoration: AppTheme.inputDecoration(context, label: l.routeFrom),
            onChanged: changed,
          ),
          TextField(
            controller: _to,
            maxLength: 60,
            decoration: AppTheme.inputDecoration(context, label: l.routeTo),
            onChanged: changed,
          ),
          TextField(
            controller: _fare,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
            decoration: AppTheme.inputDecoration(context, label: l.fare, suffixIcon: const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: Text('₼'),
            )).copyWith(
              errorText: _fare.text.isNotEmpty && parseFare(_fare.text) == null ? l.fareInvalid : null,
            ),
            onChanged: changed,
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(onPressed: _valid ? _save : null, child: Text(l.save)),
        ],
      ),
    );
  }
}

/// Settings → Məlumat → "Nəqliyyat tarifləri": edit the bundled fares, add
/// or delete own routes, reset to the standard fare (DESIGN.md §18.5.4).
/// Editing a fare never changes past transactions.
class TransportFaresScreen extends ConsumerStatefulWidget {
  const TransportFaresScreen({super.key});

  @override
  ConsumerState<TransportFaresScreen> createState() => _TransportFaresScreenState();
}

class _TransportFaresScreenState extends ConsumerState<TransportFaresScreen> {
  String _query = '';

  Future<void> _editFare(TransportMode mode, String code, int? current, String title) async {
    final AppLocalizations l = AppLocalizations.of(context);
    final String lang = ref.read(languageProvider);
    final TextEditingController ctl =
        TextEditingController(text: current == null ? '' : Fmt.editable(current, lang));
    final int? v = await showDialog<int>(
      context: context,
      builder: (BuildContext ctx) => StatefulBuilder(
        builder: (BuildContext ctx, StateSetter set) {
          final int? parsed = parseFare(ctl.text);
          return AlertDialog(
            title: Text(title),
            content: TextField(
              controller: ctl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
              decoration: AppTheme.inputDecoration(ctx, label: l.fare).copyWith(
                errorText: ctl.text.isNotEmpty && parsed == null ? l.fareInvalid : null,
                suffixText: '₼',
              ),
              onChanged: (_) => set(() {}),
              onSubmitted: (_) {
                if (parsed != null) Navigator.of(ctx).pop(parsed);
              },
            ),
            actions: <Widget>[
              TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(l.cancel)),
              FilledButton(
                onPressed: parsed == null ? null : () => Navigator.of(ctx).pop(parsed),
                child: Text(l.save),
              ),
            ],
          );
        },
      ),
    );
    ctl.dispose();
    if (v != null) await ref.read(transportFareRepositoryProvider).setFare(mode, code, v);
  }

  Future<void> _customMenu(BusRoute r) async {
    final AppLocalizations l = AppLocalizations.of(context);
    final String? v = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text(l.edit),
              onTap: () => Navigator.of(ctx).pop('edit'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: Text(l.delete),
              onTap: () => Navigator.of(ctx).pop('delete'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (v == 'edit') await showOwnRouteSheet(context, ref, editing: r);
    if (v == 'delete') await ref.read(transportFareRepositoryProvider).deleteCustomRoute(r.code);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final String lang = ref.watch(languageProvider);
    final ThemeData theme = Theme.of(context);
    final Color variant = theme.colorScheme.onSurfaceVariant;
    final ResolvedFares? fares = ref.watch(resolvedFaresProvider).value;
    final TransportFareRepository repo = ref.read(transportFareRepositoryProvider);
    String money(int v) => Fmt.money(v, Currency.azn.code, lang);

    Widget editedChip() => Container(
          margin: const EdgeInsets.only(top: AppSpacing.xxs),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
          decoration: BoxDecoration(
            color: theme.colorScheme.tertiaryContainer,
            borderRadius: AppRadius.brFull,
          ),
          child: Text(
            l.fareEdited,
            style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onTertiaryContainer),
          ),
        );

    Widget singleFare(TransportMode mode, int? fare, bool edited) => ListTile(
          minTileHeight: 64,
          leading: Icon(TransportModeStyle.forMode(mode).icon),
          title: Text(transportModeLabel(l, mode)),
          subtitle: edited ? Align(alignment: Alignment.centerLeft, child: editedChip()) : null,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(fare == null ? l.fareNotSet : money(fare), style: AppTextStyles.tabular),
              IconButton(
                tooltip: l.edit,
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => _editFare(mode, '', fare, transportModeLabel(l, mode)),
              ),
              if (edited)
                IconButton(
                  tooltip: l.resetFare,
                  icon: const Icon(Icons.close),
                  onPressed: () => repo.resetFare(mode, ''),
                ),
            ],
          ),
        );

    final List<BusRoute> routes = fares?.search(_query) ?? const <BusRoute>[];
    final DateTime? verified = fares?.catalog.verifiedAt;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.transportFares),
        actions: <Widget>[
          IconButton(
            tooltip: l.addOwnRoute,
            icon: const Icon(Icons.add),
            onPressed: () => showOwnRouteSheet(context, ref),
          ),
        ],
      ),
      body: fares == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 0),
                  child: SearchBar(
                    hintText: l.search,
                    leading: const Icon(Icons.search),
                    onChanged: (String v) => setState(() => _query = v),
                  ),
                ),
                if (_query.trim().isEmpty) ...<Widget>[
                  SectionHeader(l.metroAndTrain),
                  singleFare(TransportMode.metro, fares.metroFare, fares.metroEdited),
                  singleFare(TransportMode.train, fares.trainFare, fares.trainEdited),
                ],
                SectionHeader(l.transportBus),
                for (final BusRoute r in routes)
                  ListTile(
                    minTileHeight: 64,
                    leading: RouteBadge(code: r.code, custom: r.isCustom),
                    title: Text(r.label.isEmpty ? r.code : r.label, maxLines: 2, overflow: TextOverflow.ellipsis),
                    subtitle: r.isCustom
                        ? Text(l.myRoute, style: theme.textTheme.labelSmall)
                        : r.isEdited
                            ? Align(alignment: Alignment.centerLeft, child: editedChip())
                            : r.uncertain
                                ? Text(l.fareUncertain, style: theme.textTheme.bodySmall?.copyWith(color: variant))
                                : null,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(money(r.fare), style: AppTextStyles.tabular),
                        if (r.isCustom)
                          IconButton(
                            tooltip: l.more,
                            icon: const Icon(Icons.more_vert),
                            onPressed: () => _customMenu(r),
                          )
                        else if (r.isEdited)
                          IconButton(
                            tooltip: l.resetFare,
                            icon: const Icon(Icons.close),
                            onPressed: () => repo.resetFare(TransportMode.bus, r.code),
                          )
                        else
                          IconButton(
                            tooltip: l.edit,
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () => _editFare(TransportMode.bus, r.code, r.fare, r.code),
                          ),
                      ],
                    ),
                    onTap: r.isCustom
                        ? () => _customMenu(r)
                        : () => _editFare(TransportMode.bus, r.code, r.fare, r.code),
                  ),
                if (routes.isEmpty)
                  ListTile(title: Text(l.noRouteFound)),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Icon(Icons.info_outline, size: 18, color: variant),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          verified == null ? '' : l.faresVerifiedAt(Fmt.date(verified, lang)),
                          style: theme.textTheme.bodySmall?.copyWith(color: variant),
                        ),
                      ),
                    ],
                  ),
                ),
                if (fares.catalog.sources.isNotEmpty) ...<Widget>[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xs),
                    child: Text(l.faresSources, style: theme.textTheme.titleSmall),
                  ),
                  // Plain, selectable text: no network is needed or used.
                  for (final TransportSource s in fares.catalog.sources)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm),
                      child: SelectableText(
                        '${s.title}\n${s.url}',
                        style: theme.textTheme.bodySmall?.copyWith(color: variant),
                      ),
                    ),
                ],
              ],
            ),
    );
  }
}
