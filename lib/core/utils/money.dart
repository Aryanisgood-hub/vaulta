import 'package:intl/intl.dart';

/// All money is stored as integer paise (₹1 = 100 paise). Never doubles.
class Money {
  /// Parses "1250", "1,250.5" or "0.05" into paise. Throws [FormatException].
  static int toPaise(String input) {
    final cleaned = input.replaceAll(',', '').replaceAll('₹', '').trim();
    if (cleaned.isEmpty) throw const FormatException('Enter an amount');
    final parts = cleaned.split('.');
    if (parts.length > 2 || !RegExp(r'^\d*$').hasMatch(parts[0])) {
      throw const FormatException('Enter a valid amount');
    }
    final rupees = int.parse(parts[0].isEmpty ? '0' : parts[0]);
    var paise = 0;
    if (parts.length == 2) {
      final frac = parts[1];
      if (frac.length > 2 || !RegExp(r'^\d*$').hasMatch(frac)) {
        throw const FormatException('Use at most 2 decimal places');
      }
      paise = int.parse(frac.padRight(2, '0'));
    }
    return rupees * 100 + paise;
  }

  /// "₹1,250" or "₹1,250.50" (Indian digit grouping).
  static String format(int paise) {
    final f = NumberFormat.currency(
        locale: 'en_IN', symbol: '₹', decimalDigits: paise % 100 == 0 ? 0 : 2);
    return f.format(paise / 100);
  }

  /// Short labels for chart bars: ₹850, ₹12.5k, ₹1.2L, ₹3Cr.
  static String compact(int paise) {
    final r = paise / 100;
    String t(double v) => v.toStringAsFixed(1).replaceFirst(RegExp(r'\.0$'), '');
    if (r >= 10000000) return '₹${t(r / 10000000)}Cr';
    if (r >= 100000) return '₹${t(r / 100000)}L';
    if (r >= 1000) return '₹${t(r / 1000)}k';
    return '₹${r.round()}';
  }

  /// PDF's built-in fonts have no ₹ glyph, so reports use "Rs.".
  static String forPdf(int paise) => format(paise).replaceFirst('₹', 'Rs. ');

  /// Plain text for editing in a field, e.g. 125050 -> "1250.50".
  static String toInput(int paise) =>
      paise % 100 == 0 ? '${paise ~/ 100}' : (paise / 100).toStringAsFixed(2);

  static String? validate(String? v) {
    try {
      if (toPaise(v ?? '') <= 0) return 'Must be more than zero';
      return null;
    } on FormatException catch (e) {
      return e.message;
    }
  }
}
