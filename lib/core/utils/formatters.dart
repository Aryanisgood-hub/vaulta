import 'package:intl/intl.dart';

final _date = DateFormat('d MMM y');
final _dateTime = DateFormat('d MMM y, h:mm a');
final _month = DateFormat('MMMM y');

String fmtDate(DateTime d) => _date.format(d);
String fmtDateTime(DateTime? d) => d == null ? '…' : _dateTime.format(d);
String fmtMonth(DateTime d) => _month.format(d);

String? requiredField(String? v, [String msg = 'Required']) =>
    (v == null || v.trim().isEmpty) ? msg : null;

/// At least 8 characters with a letter and a number.
String? passwordRule(String? v) {
  if (v == null || v.length < 8) return 'Use at least 8 characters';
  if (!RegExp(r'[A-Za-z]').hasMatch(v) || !RegExp(r'\d').hasMatch(v)) {
    return 'Include at least one letter and one number';
  }
  return null;
}
