/// Exact finite decimal quantities. Resource bounds are input limits, not an
/// invented numerical tolerance; grading uses only the reviewed tolerance.
class QuizDecimal {
  const QuizDecimal._(this.coefficient, this.scale);
  final BigInt coefficient;
  final int scale;
  static QuizDecimal? parse(String raw) {
    if (raw.length > 256) return null;
    final text = String.fromCharCodes(
      raw.trim().runes.map((c) {
        if (c >= 0x660 && c <= 0x669) return 0x30 + c - 0x660;
        if (c >= 0x6f0 && c <= 0x6f9) return 0x30 + c - 0x6f0;
        return c == 0x66b ? 0x2e : c;
      }),
    );
    final match = RegExp(
      r'^([+-]?)(?:(\d+)(?:\.(\d*))?|\.(\d+))(?:[eE]([+-]?\d+))?$',
    ).firstMatch(text);
    if (match == null) return null;
    final fraction = match[3] ?? match[4] ?? '';
    final digits = (match[2] ?? '0') + fraction;
    final exponent = int.tryParse(match[5] ?? '0');
    if (digits.length > 128 || exponent == null || exponent.abs() > 128) {
      return null;
    }
    var coefficient = BigInt.parse(digits);
    if (match[1] == '-') coefficient = -coefficient;
    var scale = fraction.length - exponent;
    if (scale < 0) {
      coefficient *= BigInt.from(10).pow(-scale);
      scale = 0;
    }
    if (scale > 256) return null;
    return QuizDecimal._(coefficient, scale);
  }

  bool within(QuizDecimal reference, QuizDecimal tolerance) {
    final common = [
      scale,
      reference.scale,
      tolerance.scale,
    ].reduce((a, b) => a > b ? a : b);
    BigInt aligned(QuizDecimal v) =>
        v.coefficient * BigInt.from(10).pow(common - v.scale);
    return (aligned(this) - aligned(reference)).abs() <= aligned(tolerance);
  }
}
