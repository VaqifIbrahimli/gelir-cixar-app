import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/format.dart';
import '../../core/share_files.dart';
import '../../core/theme.dart';
import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';
import '../settings/settings_controller.dart';
import 'export_service.dart';

enum _Period { thisMonth, lastMonth, thisYear, custom }

/// Settings → Export (DESIGN.md §7.9): CSV / Excel / PDF, shared via the
/// system share sheet.
class ExportScreen extends ConsumerStatefulWidget {
  const ExportScreen({super.key});

  @override
  ConsumerState<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends ConsumerState<ExportScreen> {
  ExportFormat _format = ExportFormat.csv;
  _Period _period = _Period.thisMonth;
  DateWindow? _custom;
  int? _accountId;
  bool _busy = false;

  DateWindow get _window {
    final DateTime now = DateTime.now();
    return switch (_period) {
      _Period.thisMonth => DateWindow.month(now),
      _Period.lastMonth => DateWindow.month(DateTime(now.year, now.month - 1)),
      _Period.thisYear => DateWindow(DateTime(now.year), DateTime(now.year + 1)),
      _Period.custom => _custom ?? DateWindow.month(now),
    };
  }

  Future<void> _pickCustom() async {
    final DateWindow w = _window;
    final DateTimeRange? r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: DateTimeRange(start: w.start, end: w.end.subtract(const Duration(days: 1))),
    );
    if (r == null) return;
    setState(() {
      _custom = DateWindow.days(r.start, r.end);
      _period = _Period.custom;
    });
  }

  Future<void> _export() async {
    if (_busy) return;
    final AppLocalizations l = AppLocalizations.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final String lang = ref.read(languageProvider);
    setState(() => _busy = true);
    File? file;
    try {
      final DateWindow w = _window;
      final List<TxDetails> items = await ref
          .read(transactionRepositoryProvider)
          .watch(TxFilter(window: w, accountId: _accountId))
          .first;
      if (items.isEmpty) {
        messenger.showSnackBar(SnackBar(content: Text(l.exportNothing)));
        return;
      }
      final List<Account> accounts = ref.read(allAccountsProvider).value ?? const <Account>[];
      final Rates rates = ref.read(ratesProvider).value ?? Rates.defaults;
      // Holdings are not tied to an account, so they belong to the
      // "all accounts" export only.
      final List<HoldingWithValue> holdings = _accountId == null
          ? await ref.read(holdingRepositoryProvider).getHoldings(rates)
          : const <HoldingWithValue>[];
      file = await const ExportService().export(
        _format,
        ExportInput(
          items: items,
          window: w,
          accountName: accounts.where((Account a) => a.id == _accountId).firstOrNull?.name,
          rates: rates,
          lang: lang,
          l: l,
          holdings: holdings,
        ),
      );
      final String mime = switch (_format) {
        ExportFormat.csv => 'text/csv',
        ExportFormat.xlsx => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        ExportFormat.pdf => 'application/pdf',
      };
      await SharePlus.instance.share(ShareParams(
        files: <XFile>[XFile(file.path, mimeType: mime)],
        subject: l.exportPdfTitle,
        title: l.exportShareTitle,
      ));
    } on Exception catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l.exportFailed)));
    } finally {
      // share_plus has copied the file by now; don't leave it in the cache.
      if (file != null) await ShareFiles.delete(file);
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final String lang = ref.watch(languageProvider);
    final List<Account> accounts = ref.watch(allAccountsProvider).value ?? const <Account>[];
    final DateWindow w = _window;
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l.export)),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: <Widget>[
                  Text(l.exportFormat, style: theme.textTheme.titleSmall),
                  const SizedBox(height: AppSpacing.sm),
                  SegmentedButton<ExportFormat>(
                    segments: const <ButtonSegment<ExportFormat>>[
                      ButtonSegment<ExportFormat>(value: ExportFormat.csv, label: Text('CSV')),
                      ButtonSegment<ExportFormat>(value: ExportFormat.xlsx, label: Text('Excel')),
                      ButtonSegment<ExportFormat>(value: ExportFormat.pdf, label: Text('PDF')),
                    ],
                    selected: <ExportFormat>{_format},
                    onSelectionChanged: (Set<ExportFormat> s) => setState(() => _format = s.first),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text(l.exportPeriod, style: theme.textTheme.titleSmall),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.xs,
                    children: <Widget>[
                      for (final (_Period p, String label) in <(_Period, String)>[
                        (_Period.thisMonth, l.periodThisMonth),
                        (_Period.lastMonth, l.periodLastMonth),
                        (_Period.thisYear, l.periodThisYear),
                        (_Period.custom, l.periodCustom),
                      ])
                        ChoiceChip(
                          label: Text(label),
                          selected: _period == p,
                          onSelected: (_) =>
                              p == _Period.custom ? _pickCustom() : setState(() => _period = p),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '${Fmt.date(w.start, lang)} – ${Fmt.date(w.end.subtract(const Duration(days: 1)), lang)}',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  DropdownButtonFormField<int?>(
                    initialValue: _accountId,
                    isExpanded: true,
                    decoration: AppTheme.inputDecoration(context, label: l.account),
                    items: <DropdownMenuItem<int?>>[
                      DropdownMenuItem<int?>(child: Text(l.allAccounts)),
                      for (final Account a in accounts)
                        DropdownMenuItem<int?>(
                          value: a.id,
                          child: Text(a.isArchived ? '${a.name} (${l.archived})' : a.name),
                        ),
                    ],
                    onChanged: (int? v) => setState(() => _accountId = v),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    l.exportHint,
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _busy ? null : _export,
                  icon: _busy
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.ios_share),
                  label: Text(l.exportAction),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
