// Amount formatting and parsing (lib/core/format.dart, DESIGN.md §5).

import 'package:flutter_test/flutter_test.dart';
import 'package:gelir_cixar/core/format.dart';
import 'package:gelir_cixar/data/enums.dart';
import 'package:intl/date_symbol_data_local.dart';

// Spelled out as code points so a regression to ASCII spaces/hyphens fails.
const String nb = ' '; // no-break space: grouping and before ₼ in az
const String thin = ' '; // thin space after a sign
const String minus = '−'; // typographic minus

void main() {
  setUpAll(() async {
    await initializeDateFormatting('az');
    await initializeDateFormatting('en');
  });

  test('typographic constants', () {
    expect(Fmt.nbsp, nb);
    expect(Fmt.thinSpace, thin);
    expect(Fmt.minus, minus);
  });

  group('money: az', () {
    test('positive, negative, zero', () {
      expect(Fmt.money(123456, 'AZN', 'az'), '1${nb}234,56$nb₼');
      expect(Fmt.money(-123456, 'AZN', 'az'), '${minus}1${nb}234,56$nb₼');
      expect(Fmt.money(0, 'AZN', 'az'), '0,00$nb₼');
      expect(Fmt.money(5, 'AZN', 'az'), '0,05$nb₼');
      expect(Fmt.money(-5, 'AZN', 'az'), '${minus}0,05$nb₼');
    });

    test('large numbers group every three digits', () {
      expect(Fmt.money(123456789012, 'AZN', 'az'), '1${nb}234${nb}567${nb}890,12$nb₼');
      expect(Fmt.money(100000000, 'AZN', 'az'), '1${nb}000${nb}000,00$nb₼');
      expect(Fmt.number(99999999999999, 'az'), '999${nb}999${nb}999${nb}999,99');
    });

    test('other currencies use the ISO code after the number', () {
      expect(Fmt.money(12000, 'USD', 'az'), '120,00${nb}USD');
      expect(Fmt.money(-150075, 'EUR', 'az'), '${minus}1${nb}500,75${nb}EUR');
      expect(Fmt.money(0, 'TRY', 'az'), '0,00${nb}TRY');
    });

    test('unknown language codes fall back to az', () {
      expect(Fmt.money(123456, 'AZN', 'ru'), Fmt.money(123456, 'AZN', 'az'));
    });
  });

  group('money: en', () {
    test('positive, negative, zero', () {
      expect(Fmt.money(123456, 'AZN', 'en'), '₼1,234.56');
      expect(Fmt.money(-123456, 'AZN', 'en'), '$minus₼1,234.56');
      expect(Fmt.money(0, 'AZN', 'en'), '₼0.00');
    });

    test('large numbers', () {
      expect(Fmt.money(123456789012, 'AZN', 'en'), '₼1,234,567,890.12');
    });

    test('other currencies', () {
      expect(Fmt.money(12000, 'USD', 'en'), '120.00${nb}USD');
      expect(Fmt.money(-1, 'RUB', 'en'), '${minus}0.01${nb}RUB');
    });
  });

  group('signed / net / base / masked', () {
    test('signed carries the transaction sign, transfers none', () {
      expect(Fmt.signed(1840, 'AZN', TxType.income, 'az'), '+${thin}18,40$nb₼');
      expect(Fmt.signed(1840, 'AZN', TxType.expense, 'az'), '$minus${thin}18,40$nb₼');
      expect(Fmt.signed(1840, 'AZN', TxType.transfer, 'az'), '18,40$nb₼');
      expect(Fmt.signed(1840, 'USD', TxType.expense, 'en'), '$minus${thin}18.40${nb}USD');
    });

    test('net signs positive and negative, not zero', () {
      expect(Fmt.net(500, 'en'), '+$thin₼5.00');
      expect(Fmt.net(-500, 'en'), '$minus$thin₼5.00');
      expect(Fmt.net(0, 'en'), '₼0.00');
      expect(Fmt.net(0, 'az'), '0,00$nb₼');
    });

    test('base is AZN; masked hides digits', () {
      expect(Fmt.base(100, 'az'), Fmt.money(100, 'AZN', 'az'));
      expect(Fmt.masked('AZN', 'az'), '•••••$nb₼');
      expect(Fmt.masked('AZN', 'en'), '₼•••••');
      expect(Fmt.masked('USD', 'en'), '•••••${nb}USD');
    });
  });

  group('parseMinor', () {
    test('comma or dot as the decimal separator', () {
      expect(Fmt.parseMinor('12,5'), 1250);
      expect(Fmt.parseMinor('12.5'), 1250);
      expect(Fmt.parseMinor('12,50'), 1250);
      expect(Fmt.parseMinor('12.05'), 1205);
      expect(Fmt.parseMinor('0,01'), 1);
      expect(Fmt.parseMinor('12'), 1200);
      expect(Fmt.parseMinor('12.'), 1200);
      expect(Fmt.parseMinor('0'), 0);
    });

    test('ignores spaces, no-break spaces and the manat sign', () {
      expect(Fmt.parseMinor('1 234,56'), 123456);
      expect(Fmt.parseMinor('1${nb}234,56$nb₼'), 123456);
      expect(Fmt.parseMinor('  ₼ 7 '), 700);
    });

    test('negative with ASCII hyphen or typographic minus', () {
      expect(Fmt.parseMinor('-12,34'), -1234);
      expect(Fmt.parseMinor('${minus}12.34'), -1234);
    });

    test('rejects invalid input', () {
      for (final String s in <String>['', '   ', 'abc', '12,345', '1,2,3', '1.2.3', '--5', '12a', '+5']) {
        expect(Fmt.parseMinor(s), isNull, reason: '"$s"');
      }
    });

    test('never silently misreads English digit grouping', () {
      // A comma is always a decimal separator, so "1,234.56" can't be valid;
      // it must be rejected rather than become 12.34 or 1.23.
      expect(Fmt.parseMinor('1,234.56'), isNull);
      expect(Fmt.parseMinor('1,500'), isNull);
    });

    test('round-trips Fmt.editable and the az display format', () {
      for (final int v in <int>[0, 1, 99, 100, 1840, 123456, -5, -123456, 99999999999]) {
        expect(Fmt.parseMinor(Fmt.editable(v, 'az')), v);
        expect(Fmt.parseMinor(Fmt.editable(v, 'en')), v);
      }
      expect(Fmt.parseMinor(Fmt.money(123456, 'AZN', 'az')), 123456);
    });

    test('editable has no grouping and the locale separator', () {
      expect(Fmt.editable(123450, 'az'), '1234,50');
      expect(Fmt.editable(123450, 'en'), '1234.50');
      expect(Fmt.editable(-5, 'en'), '-0.05');
    });
  });

  group('dates', () {
    test('month title and same-day', () {
      expect(Fmt.month(DateTime(2026, 10, 15), 'en'), 'October 2026');
      expect(Fmt.month(DateTime(2026, 10, 15), 'az'), contains('2026'));
      expect(Fmt.sameDay(DateTime(2026, 10, 1, 0, 0), DateTime(2026, 10, 1, 23, 59)), isTrue);
      expect(Fmt.sameDay(DateTime(2026, 10, 1, 23, 59), DateTime(2026, 10, 2)), isFalse);
    });
  });
}
