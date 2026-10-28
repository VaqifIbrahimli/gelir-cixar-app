import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';
import 'rate_sync_controller.dart';
import 'settings_controller.dart';

/// Localised message for a CBAR refresh failure.
String rateSyncErrorText(AppLocalizations l, CbarFailure f) => switch (f) {
      CbarFailure.offline => l.ratesErrorOffline,
      CbarFailure.server => l.ratesErrorServer,
      CbarFailure.parse => l.ratesErrorParse,
    };

/// One-line status: "Yeniləndi: 28 okt 2026, 09:12 · AMB tarixi: 27 okt 2026".
String rateSyncStatusText(AppLocalizations l, RateSyncState s, String lang) {
  if (s.fetchedAt == null) return l.ratesNeverUpdated;
  final String at = '${Fmt.date(s.fetchedAt!, lang)}, ${Fmt.time(s.fetchedAt!, lang)}';
  final String date =
      s.bulletinDate == null ? '' : ' · ${l.ratesBulletinDate(Fmt.date(s.bulletinDate!, lang))}';
  return '${l.ratesLastUpdated(at)}$date';
}

/// "USD 1,70 · EUR 1,95 · RUB 0,0185 · TRY 0,05".
String rateSummary(List<ExchangeRate> rows, String lang) => <String>[
      for (final Currency c in ExchangeRatesScreen.editable)
        if (rows.where((ExchangeRate r) => r.currency == c.code).firstOrNull case final ExchangeRate r)
          '${c.code} ${ExchangeRatesScreen.formatRate(r.rateToAzn, lang)}',
    ].join(' · ');

/// "bu gün 09:41" / "27 okt 09:12".
String _when(AppLocalizations l, DateTime t, String lang) => Fmt.sameDay(t, DateTime.now())
    ? '${l.today.toLowerCase()} ${Fmt.time(t, lang)}'
    : '${Fmt.date(t, lang)} ${Fmt.time(t, lang)}';

/// CBAR status row with "Yenilə" (DESIGN.md §16.2): success / loading /
/// offline / error / never fetched / stale.
class RateStatusRow extends ConsumerWidget {
  const RateStatusRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l = AppLocalizations.of(context);
    final String lang = ref.watch(languageProvider);
    final RateSyncState s = ref.watch(rateSyncProvider);
    final ThemeData theme = Theme.of(context);
    final AppColors c = AppColors.of(context);
    final DateTime? at = s.fetchedAt;
    final bool stale =
        at != null && DateTime.now().difference(at) > RateSyncController.staleWarning;

    final Widget icon;
    final String text;
    Color textColor = theme.colorScheme.onSurface;
    String action = l.ratesRefresh;
    if (s.busy) {
      icon = const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2));
      text = l.ratesUpdating;
      action = l.ratesUpdatingShort;
    } else if (s.error == CbarFailure.offline) {
      icon = Icon(Icons.cloud_off, size: 18, color: c.warning);
      text = at == null ? l.ratesNeverFetchedOffline : l.ratesOfflineSince(_when(l, at, lang));
      action = l.retry;
    } else if (s.error != null) {
      icon = Tooltip(
        message: rateSyncErrorText(l, s.error!),
        child: Icon(Icons.error_outline, size: 18, color: c.danger),
      );
      text = at == null ? l.ratesNotUpdated : l.ratesNotUpdatedSince(Fmt.date(at, lang));
    } else if (at == null) {
      icon = Icon(Icons.cloud_off, size: 18, color: theme.colorScheme.onSurfaceVariant);
      text = l.ratesNeverFetchedOffline;
    } else {
      icon = Icon(Icons.check_circle, size: 18, color: c.success);
      text = stale
          ? '${l.ratesLastUpdatedShort(_when(l, at, lang))} ${l.ratesStaleSuffix}'
          : l.ratesLastUpdatedShort(_when(l, at, lang));
      if (stale) textColor = c.warning;
    }

    Future<void> refresh() async {
      final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
      final CbarFailure? f = await ref.read(rateSyncProvider.notifier).refresh();
      if (f == null) {
        AppHaptics.confirm();
        messenger.showSnackBar(SnackBar(content: Text(l.ratesRefreshed)));
      } else {
        AppHaptics.error();
      }
    }

    return Semantics(
      liveRegion: true,
      child: Row(
        children: <Widget>[
          icon,
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: AnimatedSwitcher(
              duration: AppMotion.of(context, AppMotion.state),
              child: Text(
                text,
                key: ValueKey<String>(text),
                style: theme.textTheme.bodySmall?.copyWith(color: textColor),
              ),
            ),
          ),
          TextButton.icon(
            onPressed: s.busy ? null : refresh,
            icon: const Icon(Icons.refresh),
            label: Text(action),
          ),
        ],
      ),
    );
  }
}

/// Rates to AZN (DESIGN.md §16.3). With auto rates on, each row shows its
/// value and source chip; ✎ edits inline (making it a manual override) and
/// ✕ returns to the CBAR value. With auto rates off, every row is a field.
class ExchangeRatesScreen extends ConsumerStatefulWidget {
  const ExchangeRatesScreen({super.key});

  static final List<Currency> editable =
      Currency.values.where((Currency c) => c != Currency.base).toList();

  /// Parses "1,70" or "1.70"; null unless a finite positive number.
  static double? parseRate(String input) {
    final String s = input.trim().replaceAll(' ', '').replaceAll(',', '.');
    if (!RegExp(r'^\d+(\.\d+)?$').hasMatch(s)) return null;
    final double? v = double.tryParse(s);
    return v == null || !v.isFinite || v <= 0 ? null : v;
  }

  /// Up to 4 decimals for display, locale separator.
  static String formatRate(double v, String lang) {
    String s = v.toStringAsFixed(v < 0.1 ? 4 : (v < 10 ? 4 : 2));
    s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
    return lang == 'en' ? s : s.replaceAll('.', ',');
  }

  @override
  ConsumerState<ExchangeRatesScreen> createState() => _ExchangeRatesScreenState();
}

class _ExchangeRatesScreenState extends ConsumerState<ExchangeRatesScreen> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final Map<Currency, TextEditingController> _ctl = <Currency, TextEditingController>{
    for (final Currency c in ExchangeRatesScreen.editable) c: TextEditingController(),
  };

  /// Rows opened with ✎ (auto mode).
  final Set<Currency> _editing = <Currency>{};

  @override
  void dispose() {
    for (final TextEditingController c in _ctl.values) {
      c.dispose();
    }
    super.dispose();
  }

  static String _plain(double v, String lang) {
    String s = v.toStringAsFixed(6);
    s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
    return lang == 'en' ? s : s.replaceAll('.', ',');
  }

  void _openField(Currency c, List<ExchangeRate> rows, String lang) {
    final ExchangeRate? r = rows.where((ExchangeRate x) => x.currency == c.code).firstOrNull;
    _ctl[c]!.text = r == null ? '' : _plain(r.rateToAzn, lang);
  }

  Future<void> _save(bool auto) async {
    if (!_form.currentState!.validate()) return;
    final AppLocalizations l = AppLocalizations.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final RateRepository repo = ref.read(rateRepositoryProvider);
    final List<ExchangeRate> rows = ref.read(rateRowsProvider).value ?? const <ExchangeRate>[];
    for (final Currency c in ExchangeRatesScreen.editable) {
      if (auto && !_editing.contains(c)) continue;
      final double? v = ExchangeRatesScreen.parseRate(_ctl[c]!.text);
      if (v == null) continue;
      final double? stored = rows.where((ExchangeRate r) => r.currency == c.code).firstOrNull?.rateToAzn;
      // Only an actual change becomes a manual override.
      if (stored != v) await repo.setRate(c.code, v);
    }
    AppHaptics.confirm();
    messenger.showSnackBar(SnackBar(content: Text(l.ratesSaved)));
    if (mounted) context.pop();
  }

  Future<void> _reset(Currency c) async {
    final AppLocalizations l = AppLocalizations.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    setState(() => _editing.remove(c));
    final bool applied = await ref.read(rateRepositoryProvider).resetToAuto(c.code);
    if (applied) return;
    final CbarFailure? f = await ref.read(rateSyncProvider.notifier).refresh();
    if (f != null) messenger.showSnackBar(SnackBar(content: Text(rateSyncErrorText(l, f))));
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final String lang = ref.watch(languageProvider);
    final AsyncValue<List<ExchangeRate>> data = ref.watch(rateRowsProvider);
    final RateSyncState sync = ref.watch(rateSyncProvider);
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final bool auto = sync.enabled;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.exchangeRates),
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: FilledButton(onPressed: () => _save(auto), child: Text(l.save)),
          ),
        ],
      ),
      body: !data.hasValue
          ? const Center(child: CircularProgressIndicator())
          : _RatesForm(
              formKey: _form,
              rows: data.requireValue,
              auto: auto,
              lang: lang,
              editing: _editing,
              controllers: _ctl,
              header: auto && sync.bulletinDate != null
                  ? '${l.ratesUnitHeader} · ${l.rateSourceCbar}, ${Fmt.date(sync.bulletinDate!, lang)}'
                  : l.ratesUnitHeader,
              onEdit: (Currency c) => setState(() {
                _openField(c, data.requireValue, lang);
                _editing.add(c);
              }),
              onReset: _reset,
              chipColors: (bool manual) => manual
                  ? (cs.tertiaryContainer, cs.onTertiaryContainer)
                  : (cs.secondaryContainer, cs.onSecondaryContainer),
            ),
    );
  }
}

class _RatesForm extends StatefulWidget {
  const _RatesForm({
    required this.formKey,
    required this.rows,
    required this.auto,
    required this.lang,
    required this.editing,
    required this.controllers,
    required this.header,
    required this.onEdit,
    required this.onReset,
    required this.chipColors,
  });

  final GlobalKey<FormState> formKey;
  final List<ExchangeRate> rows;
  final bool auto;
  final String lang;
  final Set<Currency> editing;
  final Map<Currency, TextEditingController> controllers;
  final String header;
  final ValueChanged<Currency> onEdit;
  final ValueChanged<Currency> onReset;
  final (Color, Color) Function(bool manual) chipColors;

  @override
  State<_RatesForm> createState() => _RatesFormState();
}

class _RatesFormState extends State<_RatesForm> {
  bool _filled = false;

  @override
  void initState() {
    super.initState();
    _fill();
  }

  /// Manual mode: every field starts with the stored value.
  void _fill() {
    if (_filled) return;
    _filled = true;
    for (final Currency c in ExchangeRatesScreen.editable) {
      final ExchangeRate? r = widget.rows.where((ExchangeRate x) => x.currency == c.code).firstOrNull;
      if (r != null && widget.controllers[c]!.text.isEmpty) {
        widget.controllers[c]!.text = _ExchangeRatesScreenState._plain(r.rateToAzn, widget.lang);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    Widget row(Currency c) {
      final ExchangeRate? r = widget.rows.where((ExchangeRate x) => x.currency == c.code).firstOrNull;
      final bool manual = r?.isManual ?? false;
      final bool field = !widget.auto || widget.editing.contains(c);
      final (Color bg, Color fg) = widget.chipColors(manual);
      return ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
          child: Row(
            children: <Widget>[
              SizedBox(width: 52, child: Text(c.code, style: theme.textTheme.titleMedium)),
              Expanded(
                child: field
                    ? TextFormField(
                        controller: widget.controllers[c],
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: AppTheme.inputDecoration(
                          context,
                          label: l.rateLabel(c.code),
                          suffixIcon: const Padding(padding: EdgeInsets.all(AppSpacing.md), child: Text('₼')),
                        ),
                        validator: (String? v) =>
                            ExchangeRatesScreen.parseRate(v ?? '') == null ? l.ratePositive : null,
                      )
                    : Text(
                        r == null ? '—' : ExchangeRatesScreen.formatRate(r.rateToAzn, widget.lang),
                        style: AppTextStyles.amountTile,
                      ),
              ),
              if (widget.auto && r != null) ...<Widget>[
                const SizedBox(width: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
                  decoration: BoxDecoration(color: bg, borderRadius: AppRadius.brSm),
                  child: Text(
                    manual ? l.rateSourceManual : (r.source == RateSource.cbar ? l.rateSourceCbar : l.rateSourceDefault),
                    style: theme.textTheme.labelSmall?.copyWith(color: fg),
                  ),
                ),
                if (manual)
                  IconButton(
                    tooltip: l.resetToCbar,
                    icon: const Icon(Icons.close),
                    onPressed: () => widget.onReset(c),
                  )
                else if (!field)
                  IconButton(
                    tooltip: l.edit,
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => widget.onEdit(c),
                  )
                else
                  const SizedBox(width: AppSizes.minTouch),
              ],
            ],
          ),
        ),
      );
    }

    return Form(
      key: widget.formKey,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Text(widget.header, style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
          ),
          const SizedBox(height: AppSpacing.sm),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Material(
              color: cs.surfaceContainerLow,
              borderRadius: AppRadius.brMd,
              child: Column(children: <Widget>[for (final Currency c in ExchangeRatesScreen.editable) row(c)]),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(Icons.info_outline, size: 16, color: cs.onSurfaceVariant),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    widget.auto ? l.manualOverrideNote : l.exchangeRatesHint,
                    style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
          if (widget.auto)
            const Padding(
              padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.sm, 0),
              child: RateStatusRow(),
            ),
        ],
      ),
    );
  }
}
