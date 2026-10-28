// Amount and date formatting (DESIGN.md §5).
//
// Amounts are int minor units (qəpik / cents). All supported currencies use
// two decimals. Formatting uses integer arithmetic so there is no float drift.
//
//   az: 1 234,56 ₼   −1 234,56 ₼   120,00 USD
//   en: ₼1,234.56    −₼1,234.56    120.00 USD
//
// Signed (transactions): income "+ " / expense "− " (thin space U+2009),
// transfers carry no sign.

import 'package:intl/intl.dart';

import '../data/enums.dart';

abstract final class Fmt {
  static const String minus = '−';
  static const String thinSpace = ' ';
  static const String nbsp = ' ';
  static const String mask = '•••••';

  static final NumberFormat _grouped = NumberFormat('#,##0', 'en');

  static bool _isAz(String lang) => lang != 'en';

  static String decimalSeparator(String lang) => _isAz(lang) ? ',' : '.';

  /// "1 234,56" / "1,234.56" without currency or sign.
  static String number(int minor, String lang) {
    final int abs = minor.abs();
    final String intPart = _grouped.format(abs ~/ 100);
    final String frac = (abs % 100).toString().padLeft(2, '0');
    if (_isAz(lang)) {
      return '${intPart.replaceAll(',', nbsp)},$frac';
    }
    return '$intPart.$frac';
  }

  /// Unsigned body with currency: "1 234,56 ₼", "₼1,234.56", "120,00 USD".
  static String _withCurrency(String body, String currency, String lang) {
    if (currency == Currency.azn.code) {
      return _isAz(lang) ? '$body$nbsp₼' : '₼$body';
    }
    return '$body$nbsp$currency';
  }

  /// Plain amount, "−" prefix only when negative (balances, totals).
  static String money(int minor, String currency, String lang) {
    final String s = _withCurrency(number(minor, lang), currency, lang);
    return minor < 0 ? '$minus$s' : s;
  }

  /// Amount in the base currency (AZN).
  static String base(int minor, String lang) =>
      money(minor, Currency.base.code, lang);

  /// Transaction amount with type sign.
  static String signed(int minor, String currency, TxType type, String lang) {
    final String s = _withCurrency(number(minor, lang), currency, lang);
    return switch (type) {
      TxType.income => '+$thinSpace$s',
      TxType.expense => '$minus$thinSpace$s',
      TxType.transfer || TxType.toHolding || TxType.fromHolding => s,
    };
  }

  /// Net amount (daily subtotal etc.): "+ x" / "− x" / "0,00 ₼".
  static String net(int minor, String lang) {
    final String s = _withCurrency(number(minor, lang), Currency.base.code, lang);
    if (minor > 0) return '+$thinSpace$s';
    if (minor < 0) return '$minus$thinSpace$s';
    return s;
  }

  /// Masked amount for the hidden-balance mode.
  static String masked(String currency, String lang) =>
      _withCurrency(mask, currency, lang);

  /// Parses user text ("1 234,5", "1234.50", "-12") into minor units.
  /// Returns null when it is not a valid amount with at most 2 decimals.
  static int? parseMinor(String input) {
    String s = input.trim().replaceAll(RegExp(r'[\s  ₼]'), '');
    if (s.isEmpty) return null;
    bool negative = false;
    if (s.startsWith('-') || s.startsWith(minus)) {
      negative = true;
      s = s.substring(1);
    }
    s = s.replaceAll(',', '.');
    final RegExpMatch? m = RegExp(r'^(\d{1,12})(?:\.(\d{0,2}))?$').firstMatch(s);
    if (m == null) return null;
    final int whole = int.parse(m.group(1)!);
    final String fracStr = (m.group(2) ?? '').padRight(2, '0');
    final int v = whole * 100 + int.parse(fracStr);
    return negative ? -v : v;
  }

  /// Editable text for a minor amount, e.g. "1234,50" (no grouping).
  static String editable(int minor, String lang) {
    final int abs = minor.abs();
    final String s =
        '${abs ~/ 100}${decimalSeparator(lang)}${(abs % 100).toString().padLeft(2, '0')}';
    return minor < 0 ? '-$s' : s;
  }

  // ---- dates --------------------------------------------------------------

  static String _cap(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  /// "Oktyabr 2026" / "October 2026".
  static String month(DateTime d, String lang) =>
      _cap(DateFormat.yMMMM(lang).format(d));

  /// "12 oktyabr 2026".
  static String date(DateTime d, String lang) =>
      DateFormat.yMMMd(lang).format(d);

  /// "12 oktyabr, B.e." style day header (relative labels are added by UI).
  static String dayHeader(DateTime d, String lang) =>
      DateFormat('d MMMM, EEE', lang).format(d);

  static String time(DateTime d, String lang) =>
      DateFormat.Hm(lang).format(d);

  static bool sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
