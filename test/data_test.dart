import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelir_cixar/data/backup.dart';
import 'package:gelir_cixar/data/database.dart';
import 'package:gelir_cixar/data/models.dart';
import 'package:gelir_cixar/data/repositories/budget_repository.dart';
import 'package:gelir_cixar/data/repositories/report_repository.dart';

void main() {
  late AppDatabase db;
  const Rates rates = Rates(<String, double>{'USD': 1.7});

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<int> expense(int categoryId, int amount, DateTime date) =>
      db.into(db.transactions).insert(TransactionsCompanion.insert(
            type: TxType.expense,
            accountId: 1,
            categoryId: Value<int?>(categoryId),
            amount: amount,
            date: date,
          ));

  test('budget thresholds fire once each', () async {
    final BudgetRepository repo = BudgetRepository(db);
    final DateTime d = DateTime(2026, 10, 5);
    await repo.upsert(categoryId: 1, month: '2026-10', limitAmount: 10000);

    await expense(1, 5000, d);
    expect(await repo.checkThresholds(categoryId: 1, date: d, rates: rates), isNull);

    await expense(1, 3500, d);
    expect((await repo.checkThresholds(categoryId: 1, date: d, rates: rates))!.threshold, 80);
    expect(await repo.checkThresholds(categoryId: 1, date: d, rates: rates), isNull);

    await expense(1, 2000, d);
    expect((await repo.checkThresholds(categoryId: 1, date: d, rates: rates))!.threshold, 100);
    expect(await repo.checkThresholds(categoryId: 1, date: d, rates: rates), isNull);

    final List<BudgetProgress> p = await repo.getMonth('2026-10', rates);
    expect(p.single.spent, 10500);
    expect(await repo.copyMonth(from: '2026-10', to: '2026-11'), 1);
  });

  test('monthly series groups by local month', () async {
    await expense(1, 1000, DateTime(2026, 9, 30, 23, 30));
    await expense(1, 2000, DateTime(2026, 10, 1, 0, 30));
    final MonthlySeries s =
        await ReportRepository(db).watchMonthly(DateTime(2026, 10), 2, rates).first;
    expect(s.months.map((MonthTotals m) => m.totals.expense), <int>[1000, 2000]);
  });

  test('backup round-trips and a bad restore changes nothing', () async {
    await expense(1, 1234, DateTime(2026, 10, 2));
    final BackupService backup = BackupService(db);
    final String json = await backup.exportJson(appVersion: 'test');

    final BackupSummary s = await backup.restoreJson(json);
    expect(s.transactions, 1);
    expect((await db.select(db.categories).get()).length, 14);

    // A transaction pointing at a missing account must roll everything back.
    final Map<String, dynamic> broken = jsonDecode(json) as Map<String, dynamic>;
    ((broken['tables'] as Map<String, dynamic>)['transactions'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .first['accountId'] = 999;
    await expectLater(
      backup.restoreJson(jsonEncode(broken)),
      throwsA(isA<BackupException>()),
    );
    expect((await db.select(db.transactions).get()).single.amount, 1234);
    expect(
      () => backup.restoreJson('{"format":"other"}'),
      throwsA(isA<BackupException>()),
    );
  });
}
