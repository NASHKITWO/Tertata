/// Kalkulator nominal untuk kolom jumlah. Mendukung + - × ÷ (juga * / x :), tanda kurung, dan minus unari.
///
/// Memakai format angka Indonesia: titik = pemisah ribuan (diabaikan), koma = desimal.
/// Mengembalikan null bila ekspresi tidak valid, dibagi nol, atau hasilnya tidak berhingga.
double? evalExpression(String input) {
  final s = input
      .replaceAll(RegExp(r'\s'), '')
      .replaceAll('×', '*')
      .replaceAll('x', '*')
      .replaceAll('X', '*')
      .replaceAll('÷', '/')
      .replaceAll(':', '/')
      .replaceAll('.', '')
      .replaceAll(',', '.');
  if (s.isEmpty || s.length > 80) return null;
  final p = _CalcParser(s);
  final v = p.expr();
  if (p.failed || p.i != s.length || !v.isFinite) return null;
  return v;
}

class _CalcParser {
  _CalcParser(this.s);
  final String s;
  int i = 0;
  bool failed = false;

  double expr() {
    var v = term();
    while (!failed && i < s.length && (s[i] == '+' || s[i] == '-')) {
      final op = s[i++];
      final r = term();
      v = op == '+' ? v + r : v - r;
    }
    return v;
  }

  double term() {
    var v = factor();
    while (!failed && i < s.length && (s[i] == '*' || s[i] == '/')) {
      final op = s[i++];
      final r = factor();
      if (op == '*') {
        v *= r;
      } else {
        if (r == 0) {
          failed = true;
          return 0;
        }
        v /= r;
      }
    }
    return v;
  }

  double factor() {
    if (i >= s.length) {
      failed = true;
      return 0;
    }
    final c = s[i];
    if (c == '-') {
      i++;
      return -factor();
    }
    if (c == '+') {
      i++;
      return factor();
    }
    if (c == '(') {
      i++;
      final v = expr();
      if (i < s.length && s[i] == ')') {
        i++;
      } else {
        failed = true;
      }
      return v;
    }
    final start = i;
    while (i < s.length && (RegExp(r'[0-9]').hasMatch(s[i]) || s[i] == '.')) {
      i++;
    }
    final v = start == i ? null : double.tryParse(s.substring(start, i));
    if (v == null) {
      failed = true;
      return 0;
    }
    return v;
  }
}
