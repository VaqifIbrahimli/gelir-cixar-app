/// Tiny calculator behind the amount keypad (DESIGN.md §6.5).
///
/// The expression is kept with '.' as the decimal point and `+ - * /` as
/// operators. Each number allows at most 10 integer digits and 2 decimals.
class AmountCalc {
  AmountCalc([this._expr = '']);

  /// Starts from an existing minor amount, e.g. 1840 -> "18.4".
  factory AmountCalc.fromMinor(int minor) => AmountCalc(_minorToExpr(minor));

  static const String _ops = '+-*/';
  static const int maxIntDigits = 10;
  static const int maxDecimals = 2;

  String _expr;

  String get expr => _expr;
  bool get isEmpty => _expr.isEmpty;

  static bool _isOp(String c) => _ops.contains(c);

  /// True when an operator is pending, so ✓ acts as "=".
  bool get hasOperator {
    for (int i = 1; i < _expr.length; i++) {
      if (_isOp(_expr[i])) return true;
    }
    return false;
  }

  String get _current {
    int i = _expr.length - 1;
    while (i >= 0 && !_isOp(_expr[i])) {
      i--;
    }
    return _expr.substring(i + 1);
  }

  void digit(String d) {
    final String cur = _current;
    final int dot = cur.indexOf('.');
    if (dot >= 0) {
      if (cur.length - dot - 1 >= maxDecimals) return;
    } else {
      if (cur.length >= maxIntDigits) return;
      if (cur == '0') {
        // Replace a leading zero instead of producing "05".
        _expr = _expr.substring(0, _expr.length - 1) + d;
        return;
      }
    }
    _expr += d;
  }

  void decimal() {
    final String cur = _current;
    if (cur.contains('.')) return;
    _expr += cur.isEmpty ? '0.' : '.';
  }

  void operator(String op) {
    assert(_isOp(op));
    if (_expr.isEmpty) return;
    String last = _expr[_expr.length - 1];
    if (last == '.') {
      _expr = _expr.substring(0, _expr.length - 1);
      if (_expr.isEmpty) return;
      last = _expr[_expr.length - 1];
    }
    if (_isOp(last)) {
      _expr = _expr.substring(0, _expr.length - 1) + op;
    } else {
      _expr += op;
    }
  }

  void backspace() {
    if (_expr.isNotEmpty) _expr = _expr.substring(0, _expr.length - 1);
  }

  void clear() => _expr = '';

  /// Evaluates to minor units (rounded). Null on an invalid expression
  /// (e.g. division by zero). Empty evaluates to 0.
  int? evaluate() {
    if (_expr.isEmpty) return 0;
    final List<double> nums = <double>[];
    final List<String> ops = <String>[];
    String buf = '';
    for (int i = 0; i < _expr.length; i++) {
      final String c = _expr[i];
      if (_isOp(c)) {
        if (buf.isEmpty) return null;
        nums.add(double.parse(buf));
        ops.add(c);
        buf = '';
      } else {
        buf += c;
      }
    }
    if (buf.isNotEmpty && buf != '.') {
      nums.add(double.parse(buf));
    } else if (ops.isNotEmpty) {
      ops.removeLast(); // trailing operator
    }
    if (nums.isEmpty) return 0;

    // First pass: * and /.
    final List<double> terms = <double>[nums.first];
    final List<String> addOps = <String>[];
    for (int i = 0; i < ops.length; i++) {
      final double n = nums[i + 1];
      switch (ops[i]) {
        case '*':
          terms[terms.length - 1] *= n;
        case '/':
          if (n == 0) return null;
          terms[terms.length - 1] /= n;
        default:
          addOps.add(ops[i]);
          terms.add(n);
      }
    }
    double total = terms.first;
    for (int i = 0; i < addOps.length; i++) {
      total = addOps[i] == '+' ? total + terms[i + 1] : total - terms[i + 1];
    }
    final double minor = total * 100;
    if (minor.isNaN || minor.isInfinite || minor.abs() > 99999999999999) {
      return null;
    }
    return minor.round();
  }

  /// Replaces the expression with its evaluated value.
  bool collapse() {
    final int? v = evaluate();
    if (v == null) return false;
    _expr = v <= 0 ? '' : _minorToExpr(v);
    return true;
  }

  static String _minorToExpr(int minor) {
    if (minor <= 0) return '';
    final int whole = minor ~/ 100;
    final int frac = minor % 100;
    if (frac == 0) return '$whole';
    if (frac % 10 == 0) return '$whole.${frac ~/ 10}';
    return '$whole.${frac.toString().padLeft(2, '0')}';
  }

  /// Display text with the locale decimal separator and math glyphs.
  String display(String decimalSeparator) {
    if (_expr.isEmpty) return '0';
    final StringBuffer b = StringBuffer();
    for (int i = 0; i < _expr.length; i++) {
      final String c = _expr[i];
      b.write(switch (c) {
        '.' => decimalSeparator,
        '+' => ' + ',
        '-' => ' − ',
        '*' => ' × ',
        '/' => ' ÷ ',
        _ => c,
      });
    }
    return b.toString();
  }
}
