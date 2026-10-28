import 'package:xml/xml.dart';
import 'package:xml/xml_events.dart' as ev;

/// One CBAR (Azərbaycan Mərkəzi Bankı) daily bulletin, reduced to foreign
/// currencies: AZN per one unit (Value / Nominal).
class CbarBulletin {
  const CbarBulletin({required this.date, required this.rates});

  /// `ValCurs/@Date`: the date the rates are valid from. The server answers
  /// a weekend or future date with the latest earlier bulletin, so this can
  /// be earlier than the requested day.
  final DateTime date;

  /// ISO code → AZN per unit, e.g. RUB 2.1036 / 100 = 0.021036.
  final Map<String, double> rates;
}

class CbarParseException implements Exception {
  const CbarParseException(this.message);

  final String message;

  @override
  String toString() => 'CbarParseException($message)';
}

/// Parses `https://www.cbar.az/currencies/DD.MM.YYYY.xml`.
///
/// ```xml
/// <ValCurs Date="27.10.2026" Name="AZN məzənnələri" Description="...">
///   <ValType Type="Bank metalları"> ... </ValType>
///   <ValType Type="Xarici valyutalar">
///     <Valute Code="USD"><Nominal>1</Nominal><Name>1 ABŞ dolları</Name><Value>1.7</Value></Valute>
///     <Valute Code="RUB"><Nominal>100</Nominal><Name>100 Rusiya rublu</Name><Value>2.1036</Value></Valute>
///   </ValType>
/// </ValCurs>
/// ```
abstract final class CbarParser {
  static const String foreignCurrencies = 'Xarici valyutalar';

  /// Largest document accepted, in UTF-16 code units. The real bulletin is
  /// about 30 KB; the client caps the download at the same size.
  static const int maxLength = 512 * 1024;

  /// Deepest element nesting accepted. The real feed is 4 deep
  /// (ValCurs > ValType > Valute > Value).
  static const int maxDepth = 8;

  static final RegExp _date = RegExp(r'^(\d{2})\.(\d{2})\.(\d{4})$');
  static final RegExp _code = RegExp(r'^[A-Z]{3}$');

  /// Plain ASCII decimal, no sign, exponent, locale separator, NaN or
  /// Infinity, and a bounded number of digits.
  static final RegExp _number = RegExp(r'^\d{1,9}(\.\d{1,12})?$');

  static CbarBulletin parse(String xml) {
    if (xml.trim().isEmpty) throw const CbarParseException('empty');
    if (xml.length > maxLength) throw const CbarParseException('too large');
    final XmlDocument doc = XmlDocument(const ev.XmlNodeDecoder().convert(_events(xml)));
    final XmlElement root;
    try {
      root = doc.rootElement;
    } on StateError {
      throw const CbarParseException('root');
    }
    if (root.name.local != 'ValCurs') throw const CbarParseException('root');

    final RegExpMatch? d = _date.firstMatch(root.getAttribute('Date')?.trim() ?? '');
    if (d == null) throw const CbarParseException('date');
    final int year = int.parse(d[3]!), month = int.parse(d[2]!), day = int.parse(d[1]!);
    final DateTime date = DateTime(year, month, day);
    // DateTime normalises 31.02 to 03.03; a real bulletin date round-trips.
    if (date.year != year || date.month != month || date.day != day) {
      throw const CbarParseException('date');
    }

    final XmlElement? section = root
        .findElements('ValType')
        .where((XmlElement e) => e.getAttribute('Type')?.trim() == foreignCurrencies)
        .firstOrNull;
    if (section == null) throw const CbarParseException('no foreign currencies');

    final Map<String, double> rates = <String, double>{};
    for (final XmlElement v in section.findElements('Valute')) {
      final String code = v.getAttribute('Code')?.trim() ?? '';
      final double? nominal = _num(v.getElement('Nominal')?.innerText);
      final double? value = _num(v.getElement('Value')?.innerText);
      if (!_code.hasMatch(code) || nominal == null || value == null || nominal <= 0) continue;
      // First occurrence wins: a repeated code can't override a value.
      if (rates.containsKey(code)) continue;
      final double rate = value / nominal;
      if (rate.isFinite && rate > 0) rates[code] = rate;
    }
    if (rates.isEmpty) throw const CbarParseException('no rates');
    return CbarBulletin(date: date, rates: rates);
  }

  /// Tokenises [xml] with the fixed XML-only entity table (`&lt;` etc. and
  /// numeric references; the package never reads DTDs or external entities)
  /// and rejects anything the bulletin never contains: a DOCTYPE (so no
  /// entity declarations at all) or nesting deeper than [maxDepth].
  static List<ev.XmlEvent> _events(String xml) {
    final List<ev.XmlEvent> out = <ev.XmlEvent>[];
    int depth = 0;
    try {
      for (final ev.XmlEvent e in ev.parseEvents(
        xml,
        // Pinned rather than the package's mutable global default.
        entityMapping: const XmlDefaultEntityMapping.xml(),
        validateNesting: true,
        validateDocument: true,
      )) {
        if (e is ev.XmlDoctypeEvent) throw const CbarParseException('doctype');
        if (e is ev.XmlStartElementEvent && !e.isSelfClosing) {
          if (++depth > maxDepth) throw const CbarParseException('too deep');
        } else if (e is ev.XmlEndElementEvent) {
          depth--;
        }
        out.add(e);
      }
    } on XmlException catch (e) {
      throw CbarParseException('xml: ${e.message}');
    }
    return out;
  }

  /// "100", "1.7"; metals use "1 t.u." which is rejected (not needed here).
  static double? _num(String? s) {
    final String t = (s ?? '').trim();
    return _number.hasMatch(t) ? double.parse(t) : null;
  }
}
