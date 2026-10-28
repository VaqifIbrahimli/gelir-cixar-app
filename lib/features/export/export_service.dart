import 'dart:convert';
import 'dart:io';

import 'package:excel/excel.dart' as xl;
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/format.dart';
import '../../core/share_files.dart';
import '../../core/widgets.dart' show holdingPlaceLabel;
import '../../data/models.dart';
import '../../l10n/app_localizations.dart';

enum ExportFormat { csv, xlsx, pdf }

/// Everything an export needs, already loaded.
class ExportInput {
  const ExportInput({
    required this.items,
    required this.window,
    required this.accountName,
    required this.rates,
    required this.lang,
    required this.l,
    this.holdings = const <HoldingWithValue>[],
  });

  /// Current "Kənar yerlər" (not limited to the period: holdings are a
  /// snapshot of where money sits now).
  final List<HoldingWithValue> holdings;

  int get holdingsTotal => holdings.fold(0, (int s, HoldingWithValue h) => s + h.azn);

  String placeLabel(HoldingPlace p) => holdingPlaceLabel(l, p);

  /// Newest first, as the repository returns them.
  final List<TxDetails> items;
  final DateWindow window;

  /// Null for all accounts.
  final String? accountName;
  final Rates rates;
  final String lang;
  final AppLocalizations l;

  DateTime get lastDay => window.end.subtract(const Duration(days: 1));

  String get periodLabel => '${Fmt.date(window.start, lang)} – ${Fmt.date(lastDay, lang)}';

  int azn(TxDetails t) => rates.toBase(t.tx.amount, t.account.currency);

  PeriodTotals get totals {
    int i = 0;
    int e = 0;
    for (final TxDetails t in items) {
      if (t.tx.type == TxType.income) i += azn(t);
      if (t.tx.type == TxType.expense) e += azn(t);
    }
    return PeriodTotals(income: i, expense: e);
  }

  /// (name, AZN minor) per category for [type], descending.
  List<(String, int)> categoryTotals(TxType type) {
    final Map<String, int> m = <String, int>{};
    for (final TxDetails t in items) {
      if (t.tx.type != type) continue;
      final String name = t.category?.localizedName(lang) ?? l.uncategorized;
      m[name] = (m[name] ?? 0) + azn(t);
    }
    return m.entries.map((MapEntry<String, int> e) => (e.key, e.value)).toList()
      ..sort(((String, int) a, (String, int) b) => b.$2.compareTo(a.$2));
  }

  String typeLabel(TxType t) => switch (t) {
        TxType.income => l.txTypeIncome,
        TxType.expense => l.txTypeExpense,
        TxType.transfer => l.txTypeTransfer,
        TxType.toHolding => l.txTypeToHolding,
        TxType.fromHolding => l.txTypeFromHolding,
      };

  // En dash, not "→": the bundled Noto Sans has no U+2192 glyph for the PDF.
  String categoryLabel(TxDetails t) => switch (t.tx.type) {
        TxType.transfer => '${t.account.name} – ${t.toAccount?.name ?? ''}',
        TxType.toHolding => '${t.account.name} – ${t.holding?.name ?? ''}',
        TxType.fromHolding => '${t.holding?.name ?? ''} – ${t.account.name}',
        TxType.income || TxType.expense => t.category?.localizedName(lang) ?? l.uncategorized,
      };

  /// "To" column: the destination account, or the holding of a move.
  String counterpart(TxDetails t) => t.toAccount?.name ?? t.holding?.name ?? '';
}

/// Writes export files into the app's private cache (no storage permission
/// needed) for sharing. The caller deletes the file after sharing
/// ([ShareFiles.delete]); leftovers are purged on the next start.
class ExportService {
  const ExportService();

  Future<File> export(ExportFormat format, ExportInput input) async {
    final String stamp =
        '${monthKey(input.window.start)}_${monthKey(input.lastDay)}'.replaceAll('-', '');
    final List<int> bytes = switch (format) {
      ExportFormat.csv => _csv(input),
      ExportFormat.xlsx => _xlsx(input),
      ExportFormat.pdf => await _pdf(input),
    };
    return ShareFiles.write('gelir_cixar_$stamp.${format.name}', bytes);
  }

  /// One CSV field of user-entered text. Text a spreadsheet would read as a
  /// formula (leading `= + - @`, tab or CR) gets a leading `'`, so a note
  /// like `=HYPERLINK(...)` stays text (CSV / formula injection, CWE-1236).
  @visibleForTesting
  static String csvText(String v) =>
      csvField(v.isNotEmpty && '=+-@\t\r'.contains(v[0]) ? "'$v" : v);

  /// Quotes a CSV field when it contains a comma, quote or line break.
  @visibleForTesting
  static String csvField(String v) =>
      RegExp(r'[",\r\n]').hasMatch(v) ? '"${v.replaceAll('"', '""')}"' : v;

  /// Machine-friendly decimal ("1234.50") for CSV / Excel.
  static String _plain(int minor) {
    final String s = '${minor.abs() ~/ 100}.${(minor.abs() % 100).toString().padLeft(2, '0')}';
    return minor < 0 ? '-$s' : s;
  }

  static String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  List<String> _header(ExportInput i) => <String>[
        i.l.exportColDate,
        i.l.exportColType,
        i.l.account,
        i.l.category,
        i.l.exportColAmount,
        i.l.currency,
        i.l.exportColAmountAzn,
        i.l.toAccount,
        i.l.exportColToAmount,
        i.l.note,
      ];

  List<String> _holdingHeader(ExportInput i) => <String>[
        i.l.name,
        i.l.holdingPlace,
        i.l.exportColAmount,
        i.l.currency,
        i.l.exportColAmountAzn,
        i.l.note,
      ];

  // ---- CSV ------------------------------------------------------------------

  List<int> _csv(ExportInput i) {
    // User text (names, categories, note) goes through csvText; generated
    // values (dates, amounts, codes) through csvField, so numbers stay numbers.
    final StringBuffer b = StringBuffer()..write(_header(i).map(csvText).join(','))..write('\r\n');
    for (final TxDetails t in i.items.reversed) {
      b
        ..write(<String>[
          csvField(_isoDate(t.tx.date)),
          csvText(i.typeLabel(t.tx.type)),
          csvText(t.account.name),
          csvText(t.tx.type.isMove ? '' : i.categoryLabel(t)),
          csvField(_plain(t.tx.amount)),
          csvField(t.account.currency),
          csvField(_plain(i.azn(t))),
          csvText(i.counterpart(t)),
          csvField(t.tx.toAmount == null ? '' : _plain(t.tx.toAmount!)),
          csvText(t.tx.note),
        ].join(','))
        ..write('\r\n');
    }
    if (i.holdings.isNotEmpty) {
      b
        ..write('\r\n')
        ..write(csvText(i.l.exportHoldingsSection))
        ..write('\r\n')
        ..write(_holdingHeader(i).map(csvText).join(','))
        ..write('\r\n');
      for (final HoldingWithValue h in i.holdings) {
        b
          ..write(<String>[
            csvText(h.holding.name),
            csvText(i.placeLabel(h.holding.placeType)),
            csvField(_plain(h.amount)),
            csvField(h.holding.currency),
            csvField(_plain(h.azn)),
            csvText(h.holding.note),
          ].join(','))
          ..write('\r\n');
      }
    }
    // UTF-8 BOM so Excel detects the encoding (ə, ş, ğ ...).
    return <int>[0xEF, 0xBB, 0xBF, ...utf8.encode(b.toString())];
  }

  // ---- XLSX -----------------------------------------------------------------

  List<int> _xlsx(ExportInput i) {
    final xl.Excel book = xl.Excel.createExcel();
    final String defaultSheet = book.getDefaultSheet() ?? 'Sheet1';
    final String txSheet = _sheetName(i.l.navTransactions);
    final String catSheet = _sheetName(i.l.categories);
    book.rename(defaultSheet, txSheet);

    final xl.Sheet tx = book[txSheet];
    tx.appendRow(_header(i).map((String h) => xl.TextCellValue(h)).toList());
    for (final TxDetails t in i.items.reversed) {
      tx.appendRow(<xl.CellValue?>[
        xl.DateCellValue(year: t.tx.date.year, month: t.tx.date.month, day: t.tx.date.day),
        xl.TextCellValue(i.typeLabel(t.tx.type)),
        xl.TextCellValue(t.account.name),
        xl.TextCellValue(t.tx.type.isMove ? '' : i.categoryLabel(t)),
        xl.DoubleCellValue(t.tx.amount / 100),
        xl.TextCellValue(t.account.currency),
        xl.DoubleCellValue(i.azn(t) / 100),
        xl.TextCellValue(i.counterpart(t)),
        t.tx.toAmount == null ? null : xl.DoubleCellValue(t.tx.toAmount! / 100),
        xl.TextCellValue(t.tx.note),
      ]);
    }

    final xl.Sheet cs = book[catSheet];
    cs.appendRow(<xl.CellValue?>[
      xl.TextCellValue(i.l.exportColType),
      xl.TextCellValue(i.l.category),
      xl.TextCellValue(i.l.exportColAmountAzn),
    ]);
    for (final TxType type in <TxType>[TxType.expense, TxType.income]) {
      for (final (String name, int v) in i.categoryTotals(type)) {
        cs.appendRow(<xl.CellValue?>[
          xl.TextCellValue(i.typeLabel(type)),
          xl.TextCellValue(name),
          xl.DoubleCellValue(v / 100),
        ]);
      }
    }
    if (i.holdings.isNotEmpty) {
      final xl.Sheet hs = book[_sheetName(i.l.holdings)];
      hs.appendRow(_holdingHeader(i).map((String h) => xl.TextCellValue(h)).toList());
      for (final HoldingWithValue h in i.holdings) {
        hs.appendRow(<xl.CellValue?>[
          xl.TextCellValue(h.holding.name),
          xl.TextCellValue(i.placeLabel(h.holding.placeType)),
          xl.DoubleCellValue(h.amount / 100),
          xl.TextCellValue(h.holding.currency),
          xl.DoubleCellValue(h.azn / 100),
          xl.TextCellValue(h.holding.note),
        ]);
      }
    }
    book.setDefaultSheet(txSheet);
    return book.encode() ?? <int>[];
  }

  /// Excel sheet names: max 31 chars, no []:*?/\ .
  static String _sheetName(String s) {
    final String clean = s.replaceAll(RegExp(r'[\[\]:*?/\\]'), ' ');
    return clean.length > 31 ? clean.substring(0, 31) : clean;
  }

  // ---- PDF ------------------------------------------------------------------

  Future<List<int>> _pdf(ExportInput i) async {
    // Noto Sans covers every Azerbaijani letter and ₼; Helvetica lacks ə.
    final pw.Font regular = pw.Font.ttf(await rootBundle.load('assets/fonts/NotoSans-Regular.ttf'));
    final pw.Font bold = pw.Font.ttf(await rootBundle.load('assets/fonts/NotoSans-Bold.ttf'));
    final pw.Document doc = pw.Document(
      title: i.l.exportPdfTitle,
      creator: i.l.appTitle,
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
    );
    final PeriodTotals totals = i.totals;
    const PdfColor headerBg = PdfColor.fromInt(0xFFE0E6E5);
    const PdfColor incomeColor = PdfColor.fromInt(0xFF17763A);
    const PdfColor expenseColor = PdfColor.fromInt(0xFFC0262D);
    final pw.TextStyle small = const pw.TextStyle(fontSize: 9);
    final pw.TextStyle h2 = pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold);

    pw.Widget totalBox(String label, String value, PdfColor color) => pw.Expanded(
          child: pw.Container(
            margin: const pw.EdgeInsets.only(right: 8),
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey400),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: <pw.Widget>[
                pw.Text(label, style: small),
                pw.Text(value, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: color)),
              ],
            ),
          ),
        );

    pw.Widget categoryTable(TxType type) {
      final List<(String, int)> rows = i.categoryTotals(type);
      final int sum = rows.fold(0, (int s, (String, int) r) => s + r.$2);
      return pw.TableHelper.fromTextArray(
        headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
        cellStyle: const pw.TextStyle(fontSize: 10),
        headerDecoration: const pw.BoxDecoration(color: headerBg),
        cellAlignments: <int, pw.Alignment>{1: pw.Alignment.centerRight, 2: pw.Alignment.centerRight},
        headers: <String>[i.l.category, i.l.exportColAmountAzn, '%'],
        data: <List<String>>[
          for (final (String name, int v) in rows)
            <String>[name, Fmt.base(v, i.lang), sum == 0 ? '' : '${(v * 100 / sum).toStringAsFixed(1)}%'],
        ],
      );
    }

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      footer: (pw.Context ctx) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text('${ctx.pageNumber} / ${ctx.pagesCount}', style: small),
      ),
      build: (pw.Context ctx) => <pw.Widget>[
        pw.Text(i.l.exportPdfTitle, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        pw.Text('${i.l.exportPeriod}: ${i.periodLabel}'),
        pw.Text('${i.l.account}: ${i.accountName ?? i.l.allAccounts}'),
        pw.Text('${i.l.exportGenerated}: ${Fmt.date(DateTime.now(), i.lang)}', style: small),
        pw.SizedBox(height: 12),
        pw.Row(children: <pw.Widget>[
          totalBox(i.l.income, Fmt.signed(totals.income, Currency.base.code, TxType.income, i.lang), incomeColor),
          totalBox(i.l.expense, Fmt.signed(totals.expense, Currency.base.code, TxType.expense, i.lang), expenseColor),
          totalBox(i.l.net, Fmt.net(totals.net, i.lang), PdfColors.black),
        ]),
        pw.SizedBox(height: 16),
        pw.Text('${i.l.categories}: ${i.l.txTypeExpense}', style: h2),
        pw.SizedBox(height: 4),
        categoryTable(TxType.expense),
        pw.SizedBox(height: 12),
        pw.Text('${i.l.categories}: ${i.l.txTypeIncome}', style: h2),
        pw.SizedBox(height: 4),
        categoryTable(TxType.income),
        if (i.holdings.isNotEmpty) ...<pw.Widget>[
          pw.SizedBox(height: 12),
          pw.Text(i.l.exportHoldingsSection, style: h2),
          pw.SizedBox(height: 4),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
            cellStyle: const pw.TextStyle(fontSize: 10),
            headerDecoration: const pw.BoxDecoration(color: headerBg),
            cellAlignments: <int, pw.Alignment>{
              2: pw.Alignment.centerRight,
              3: pw.Alignment.centerRight,
            },
            headers: <String>[i.l.name, i.l.holdingPlace, i.l.exportColAmount, i.l.exportColAmountAzn],
            data: <List<String>>[
              for (final HoldingWithValue h in i.holdings)
                <String>[
                  h.holding.name,
                  i.placeLabel(h.holding.placeType),
                  Fmt.money(h.amount, h.holding.currency, i.lang),
                  Fmt.base(h.azn, i.lang),
                ],
              <String>[i.l.total, '', '', Fmt.base(i.holdingsTotal, i.lang)],
            ],
          ),
        ],
        pw.SizedBox(height: 16),
        pw.Text(i.l.navTransactions, style: h2),
        pw.SizedBox(height: 4),
        pw.TableHelper.fromTextArray(
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
          cellStyle: const pw.TextStyle(fontSize: 9),
          headerDecoration: const pw.BoxDecoration(color: headerBg),
          columnWidths: <int, pw.TableColumnWidth>{
            0: const pw.FixedColumnWidth(58),
            1: const pw.FixedColumnWidth(52),
            2: const pw.FlexColumnWidth(2),
            3: const pw.FlexColumnWidth(2),
            4: const pw.FixedColumnWidth(82),
          },
          cellAlignments: <int, pw.Alignment>{4: pw.Alignment.centerRight},
          headers: <String>[i.l.exportColDate, i.l.exportColType, i.l.category, i.l.note, i.l.exportColAmount],
          data: <List<String>>[
            for (final TxDetails t in i.items)
              <String>[
                Fmt.date(t.tx.date, i.lang),
                i.typeLabel(t.tx.type),
                t.tx.type.isMove ? i.categoryLabel(t) : '${i.categoryLabel(t)} · ${t.account.name}',
                t.tx.note,
                Fmt.signed(t.tx.amount, t.account.currency, t.tx.type, i.lang),
              ],
          ],
        ),
      ],
    ));
    return doc.save();
  }
}
