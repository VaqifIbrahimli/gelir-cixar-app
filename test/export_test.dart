// Export builders (lib/features/export/export_service.dart). The service
// writes under getTemporaryDirectory(), so the path_provider channel is
// answered with a per-test temp folder; data comes from a seeded in-memory DB.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:excel/excel.dart' as xl;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:gelir_cixar/data/providers.dart';
import 'package:gelir_cixar/features/export/export_service.dart';
import 'package:gelir_cixar/l10n/app_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'helpers/test_db.dart';

/// Minimal RFC 4180 reader: quoted fields, doubled quotes, embedded CR/LF.
List<List<String>> parseCsv(String s) {
  final List<List<String>> rows = <List<String>>[];
  List<String> row = <String>[];
  final StringBuffer f = StringBuffer();
  bool quoted = false;
  for (int i = 0; i < s.length; i++) {
    final String c = s[i];
    if (quoted) {
      if (c == '"' && i + 1 < s.length && s[i + 1] == '"') {
        f.write('"');
        i++;
      } else if (c == '"') {
        quoted = false;
      } else {
        f.write(c);
      }
    } else if (c == '"') {
      quoted = true;
    } else if (c == ',') {
      row.add(f.toString());
      f.clear();
    } else if (c == '\r' && i + 1 < s.length && s[i + 1] == '\n') {
      row.add(f.toString());
      f.clear();
      rows.add(row);
      row = <String>[];
      i++;
    } else {
      f.write(c);
    }
  }
  expect(quoted, isFalse, reason: 'unterminated quoted field');
  if (f.isNotEmpty || row.isNotEmpty) rows.add(<String>[...row, f.toString()]);
  return rows;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const String tricky = 'Ərzaq, "bazar"\nikinci sətir; şəkər';
  late AppDatabase db;
  late Directory tmp;
  late ExportInput input;
  final AppLocalizations az = lookupAppLocalizations(const Locale('az'));

  setUpAll(() async {
    await initializeDateFormatting('az');
    await initializeDateFormatting('en');
  });

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('gelir_export_test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall call) async => tmp.path,
    );

    db = openTestDb();
    final int usd = await db.addAccount(name: 'Dollar, kart', currency: 'USD');
    await db.addIncome(150000, DateTime(2026, 10, 1, 9), note: 'Maaş');
    await db.addExpense(1250, DateTime(2026, 10, 2, 12), note: tricky);
    await db.addExpense(1000, DateTime(2026, 10, 3), accountId: usd, categoryId: Seed.rent);
    await db.addTransfer(17000, DateTime(2026, 10, 4),
        from: Seed.cashAccount, to: usd, toAmount: 10000, note: '=1+1');

    final DateWindow oct = DateWindow.month(DateTime(2026, 10));
    input = ExportInput(
      items: await TransactionRepository(db).watch(TxFilter(window: oct)).first,
      window: oct,
      accountName: null,
      rates: const Rates(<String, double>{'USD': 1.7}),
      lang: 'az',
      l: az,
    );
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
    await db.close();
    tmp.deleteSync(recursive: true);
  });

  group('ExportInput', () {
    test('totals in AZN exclude transfers', () {
      expect(input.items, hasLength(4));
      expect(input.totals.income, 150000);
      expect(input.totals.expense, 1250 + 1700);
    });

    test('category totals are AZN, descending', () {
      expect(input.categoryTotals(TxType.expense), <(String, int)>[('Kirayə', 1700), ('Yemək', 1250)]);
      expect(input.categoryTotals(TxType.income), <(String, int)>[('Maaş', 150000)]);
    });

    test('lastDay is the last day of the window', () {
      expect(input.lastDay, DateTime(2026, 10, 31));
    });
  });

  group('CSV', () {
    late List<int> bytes;
    late List<List<String>> rows;
    late File file;

    setUp(() async {
      file = await const ExportService().export(ExportFormat.csv, input);
      bytes = await file.readAsBytes();
      rows = parseCsv(utf8.decode(bytes.sublist(3)));
    });

    test('file name carries the period', () {
      expect(file.path, endsWith('gelir_cixar_202610_202610.csv'));
      expect(file.path, startsWith(tmp.path), reason: 'inside the app temp dir');
    });

    test('starts with a UTF-8 BOM', () {
      expect(bytes.take(3), <int>[0xEF, 0xBB, 0xBF]);
    });

    test('header row in the UI language', () {
      expect(rows.first, <String>[
        az.exportColDate,
        az.exportColType,
        az.account,
        az.category,
        az.exportColAmount,
        az.currency,
        az.exportColAmountAzn,
        az.toAccount,
        az.exportColToAmount,
        az.note,
      ]);
      expect(rows.first.first, 'Tarix');
    });

    test('rows are oldest first, CRLF-terminated, machine-friendly numbers', () {
      final String text = utf8.decode(bytes.sublist(3));
      expect(text, endsWith('\r\n'));
      expect(rows, hasLength(1 + 4));
      expect(rows.skip(1).map((List<String> r) => r.first),
          <String>['2026-10-01', '2026-10-02', '2026-10-03', '2026-10-04']);
      expect(rows[1].sublist(0, 7),
          <String>['2026-10-01', 'Gəlir', 'Nağd', 'Maaş', '1500.00', 'AZN', '1500.00']);
      expect(rows[3].sublist(2, 7), <String>['Dollar, kart', 'Kirayə', '10.00', 'USD', '17.00']);
      // Transfer: no category, destination and received amount filled.
      expect(rows[4].sublist(1, 9),
          <String>['Transfer', 'Nağd', '', '170.00', 'AZN', '170.00', 'Dollar, kart', '100.00']);
    });

    test('quotes, commas, newlines and Azerbaijani letters survive escaping', () {
      expect(rows[2].last, tricky);
      final String raw = utf8.decode(bytes.sublist(3));
      expect(raw, contains('"Ərzaq, ""bazar""\nikinci sətir; şəkər"'));
      expect(raw, contains('"Dollar, kart"'));
      expect(raw, contains(',Nağd,'), reason: 'plain fields are not quoted');
      for (final List<String> r in rows) {
        expect(r, hasLength(10));
      }
    });
  });

  group('CSV formula injection', () {
    test('user text starting with = + - @ tab or CR is neutralised', () {
      expect(ExportService.csvText('=1+1'), "'=1+1");
      expect(ExportService.csvText('+994 50'), "'+994 50");
      expect(ExportService.csvText('-taksi'), "'-taksi");
      expect(ExportService.csvText('@cmd'), "'@cmd");
      expect(ExportService.csvText('\tx'), "'\tx");
      expect(ExportService.csvText('\rx'), "\"'\rx\"", reason: 'prefixed and quoted');
      expect(ExportService.csvText('=HYPERLINK("x","y")'), '"\'=HYPERLINK(""x"",""y"")"');
      expect(ExportService.csvText('Ərzaq'), 'Ərzaq');
      expect(ExportService.csvText(''), '');
    });

    test('generated numbers are never prefixed', () {
      expect(ExportService.csvField('-12.50'), '-12.50');
      expect(ExportService.csvField('2026-10-01'), '2026-10-01');
    });

    test('a note in the exported file is neutralised', () async {
      final File f = await const ExportService().export(ExportFormat.csv, input);
      final List<List<String>> rows = parseCsv(utf8.decode((await f.readAsBytes()).sublist(3)));
      expect(rows.last.last, "'=1+1", reason: 'transfer note "=1+1"');
    });
  });

  group('XLSX and PDF', () {
    test('XLSX is a non-empty workbook with both sheets', () async {
      final File f = await const ExportService().export(ExportFormat.xlsx, input);
      final List<int> bytes = await f.readAsBytes();
      expect(bytes, isNotEmpty);
      expect(bytes.take(2), <int>[0x50, 0x4B], reason: 'zip container ("PK")');

      final xl.Excel book = xl.Excel.decodeBytes(bytes);
      expect(book.tables.keys, containsAll(<String>[az.navTransactions, az.categories]));
      final xl.Sheet tx = book.tables[az.navTransactions]!;
      expect(tx.maxRows, 1 + 4);
      expect(tx.row(0).first?.value.toString(), az.exportColDate);
      expect(tx.row(2).last?.value.toString(), tricky);
    });

    test('PDF is non-empty and well-formed', () async {
      final File f = await const ExportService().export(ExportFormat.pdf, input);
      final List<int> bytes = await f.readAsBytes();
      expect(bytes.length, greaterThan(1000));
      expect(ascii.decode(bytes.take(5).toList()), '%PDF-');
      expect(latin1.decode(bytes.sublist(bytes.length - 8)), contains('%%EOF'));
    });

    test(
      'PDF has a glyph for every character it prints (transfer rows)',
      () async {
        // The pdf package reports missing glyphs through print().
        final List<String> log = <String>[];
        await runZoned(
          () => const ExportService().export(ExportFormat.pdf, input),
          zoneSpecification: ZoneSpecification(
            print: (Zone self, ZoneDelegate parent, Zone zone, String line) => log.add(line),
          ),
        );
        expect(log.where((String m) => m.contains('Unable to find a font')), isEmpty);
      },
    );

    test('empty period still exports every format', () async {
      final ExportInput empty = ExportInput(
        items: const <TxDetails>[],
        window: input.window,
        accountName: 'Nağd',
        rates: input.rates,
        lang: 'en',
        l: lookupAppLocalizations(const Locale('en')),
      );
      for (final ExportFormat fmt in ExportFormat.values) {
        final File f = await const ExportService().export(fmt, empty);
        expect(await f.length(), greaterThan(0), reason: fmt.name);
      }
    });
  });
}
