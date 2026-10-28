// Phase 1 keeps only a smoke test of pure logic; widget tests need a
// database and secure-storage fakes and arrive later.
import 'package:flutter_test/flutter_test.dart';
import 'package:gelir_cixar/core/format.dart';
import 'package:gelir_cixar/data/enums.dart';

void main() {
  test('formats amounts per DESIGN.md', () {
    expect(Fmt.money(123456, 'AZN', 'az'), '1 234,56 ₼');
    expect(Fmt.money(123456, 'AZN', 'en'), '₼1,234.56');
    expect(Fmt.signed(1840, 'AZN', TxType.expense, 'en'), '− ₼18.40');
    expect(Fmt.parseMinor('1 234,5'), 123450);
  });
}
