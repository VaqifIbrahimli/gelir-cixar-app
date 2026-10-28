// Keypad calculator (lib/features/transactions/amount_calc.dart).

import 'package:flutter_test/flutter_test.dart';
import 'package:gelir_cixar/features/transactions/amount_calc.dart';

/// Feeds keypad presses: digits, '.', and the operators + - * /.
AmountCalc type(String keys) {
  final AmountCalc c = AmountCalc();
  for (final String k in keys.split('')) {
    switch (k) {
      case '.':
        c.decimal();
      case '+' || '-' || '*' || '/':
        c.operator(k);
      default:
        c.digit(k);
    }
  }
  return c;
}

void main() {
  group('entry', () {
    test('empty evaluates to 0 and displays 0', () {
      final AmountCalc c = AmountCalc();
      expect(c.isEmpty, isTrue);
      expect(c.evaluate(), 0);
      expect(c.display(','), '0');
    });

    test('digits and decimals', () {
      expect(type('125').evaluate(), 12500);
      expect(type('1.5').evaluate(), 150);
      expect(type('.5').expr, '0.5', reason: 'a leading decimal point adds 0');
      expect(type('.5').evaluate(), 50);
      expect(type('12.').evaluate(), 1200);
    });

    test('at most two decimals and ten integer digits', () {
      expect(type('1.234').expr, '1.23');
      expect(type('1..5').expr, '1.5');
      expect(type('123456789012').expr, '1234567890');
      expect(type('1234567890.99').evaluate(), 123456789099);
    });

    test('a leading zero is replaced, not prefixed', () {
      expect(type('05').expr, '5');
      expect(type('00').expr, '0');
      expect(type('5+07').expr, '5+7');
      expect(type('0.05').evaluate(), 5);
    });

    test('backspace and clear', () {
      final AmountCalc c = type('12+3');
      c.backspace();
      expect(c.expr, '12+');
      c.clear();
      expect(c.isEmpty, isTrue);
      c.backspace();
      expect(c.isEmpty, isTrue);
    });

    test('display uses the locale separator and math glyphs', () {
      expect(type('12.5+3*4-1/2').display(','), '12,5 + 3 × 4 − 1 ÷ 2');
      expect(type('12.5').display('.'), '12.5');
    });
  });

  group('operators', () {
    test('+ − × ÷', () {
      expect(type('12+3').evaluate(), 1500);
      expect(type('10-2.5').evaluate(), 750);
      expect(type('2*3.5').evaluate(), 700);
      expect(type('10/4').evaluate(), 250);
    });

    test('× and ÷ bind tighter than + and −', () {
      expect(type('2+3*4').evaluate(), 1400);
      expect(type('10-4/2').evaluate(), 800);
      expect(type('1+2*3-8/4').evaluate(), 500);
    });

    test('division by zero is invalid, collapse keeps the expression', () {
      final AmountCalc c = type('5/0');
      expect(c.evaluate(), isNull);
      expect(c.collapse(), isFalse);
      expect(c.expr, '5/0');
      expect(type('5/0.0').evaluate(), isNull);
      expect(type('0/0').evaluate(), isNull);
    });

    test('decimal arithmetic rounds to minor units without float drift', () {
      expect(type('0.1+0.2').evaluate(), 30);
      expect(type('0.3-0.1').evaluate(), 20);
      expect(type('19.99*3').evaluate(), 5997);
      expect(type('10/3').evaluate(), 333);
      expect(type('2/3').evaluate(), 67);
    });

    test('operator handling: empty, replace, trailing dot, trailing operator', () {
      expect(type('+').isEmpty, isTrue);
      expect(type('5+*').expr, '5*');
      expect(type('5.+').expr, '5+');
      expect(type('5+').evaluate(), 500);
      expect(type('5+').hasOperator, isTrue);
      expect(type('5').hasOperator, isFalse);
    });

    test('results that overflow are invalid', () {
      expect(type('9999999999*9999999999').evaluate(), isNull);
    });
  });

  group('collapse / fromMinor', () {
    test('collapse replaces the expression with its value', () {
      AmountCalc c = type('12+3');
      expect(c.collapse(), isTrue);
      expect(c.expr, '15');
      c = type('1.5+1.25');
      c.collapse();
      expect(c.expr, '2.75');
      c = type('1.1+1');
      c.collapse();
      expect(c.expr, '2.1');
    });

    test('a zero or negative result collapses to empty', () {
      final AmountCalc c = type('5-10');
      expect(c.evaluate(), -500);
      expect(c.collapse(), isTrue);
      expect(c.isEmpty, isTrue);
    });

    test('fromMinor builds an editable expression', () {
      expect(AmountCalc.fromMinor(1840).expr, '18.4');
      expect(AmountCalc.fromMinor(1805).expr, '18.05');
      expect(AmountCalc.fromMinor(1800).expr, '18');
      expect(AmountCalc.fromMinor(0).expr, '');
      expect(AmountCalc.fromMinor(1805).evaluate(), 1805);
    });
  });
}
