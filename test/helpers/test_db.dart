// Shared fixtures for data-layer tests. Mirrors the setup in data_test.dart:
// an in-memory drift database per test, seeded by the app's own onCreate
// (account 1 "Nağd" in AZN, expense categories 1..10, income 11..14, and
// rates USD 1.70 / EUR 1.85 / RUB 0.019 / TRY 0.05).

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:gelir_cixar/data/database.dart';

/// Seeded ids (see AppDatabase._seed).
abstract final class Seed {
  static const int cashAccount = 1;

  static const int food = 1; // Yemək / Food
  static const int transport = 2; // Nəqliyyat
  static const int utilities = 3; // Kommunal
  static const int shopping = 4; // Alış-veriş
  static const int health = 5; // Sağlamlıq
  static const int fun = 6; // Əyləncə
  static const int education = 7; // Təhsil
  static const int rent = 8; // Kirayə
  static const int telecom = 9; // Rabitə
  static const int otherExpense = 10; // Digər / Other

  static const int salary = 11; // Maaş
  static const int gift = 13; // Hədiyyə
}

AppDatabase openTestDb() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  return AppDatabase(NativeDatabase.memory());
}

/// Typed insert helpers so tests read like the scenario they describe.
extension TestData on AppDatabase {
  Future<int> addAccount({
    String name = 'Kart',
    String currency = 'AZN',
    int initialBalance = 0,
    AccountType type = AccountType.card,
  }) =>
      into(accounts).insert(AccountsCompanion.insert(
        name: name,
        type: type,
        currency: currency,
        initialBalance: Value<int>(initialBalance),
      ));

  Future<int> addIncome(int amount, DateTime date,
          {int accountId = Seed.cashAccount, int? categoryId = Seed.salary, String note = ''}) =>
      into(transactions).insert(TransactionsCompanion.insert(
        type: TxType.income,
        accountId: accountId,
        categoryId: Value<int?>(categoryId),
        amount: amount,
        date: date,
        note: Value<String>(note),
      ));

  Future<int> addExpense(int amount, DateTime date,
          {int accountId = Seed.cashAccount, int? categoryId = Seed.food, String note = ''}) =>
      into(transactions).insert(TransactionsCompanion.insert(
        type: TxType.expense,
        accountId: accountId,
        categoryId: Value<int?>(categoryId),
        amount: amount,
        date: date,
        note: Value<String>(note),
      ));

  Future<int> addTransfer(int amount, DateTime date,
          {required int from, required int to, int? toAmount, String note = ''}) =>
      into(transactions).insert(TransactionsCompanion.insert(
        type: TxType.transfer,
        accountId: from,
        toAccountId: Value<int?>(to),
        amount: amount,
        toAmount: Value<int?>(toAmount),
        date: date,
        note: Value<String>(note),
      ));
}
