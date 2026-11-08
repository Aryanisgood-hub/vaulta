import '../../models/models.dart';

class MonthTotal {
  const MonthTotal(this.month, this.amount);
  final DateTime month; // first day of the month
  final int amount;     // paise
}

/// Active bills grouped by bill-date month, for the last [months] months (current month included).
List<MonthTotal> monthlyTotals(List<Bill> bills, int months, DateTime now) {
  final result = <MonthTotal>[];
  for (var i = months - 1; i >= 0; i--) {
    final m = DateTime(now.year, now.month - i, 1);
    var sum = 0;
    for (final b in bills) {
      if (!b.isVoid && b.date.year == m.year && b.date.month == m.month) sum += b.amount;
    }
    result.add(MonthTotal(m, sum));
  }
  return result;
}

class EventTotal {
  const EventTotal(this.event, this.stats);
  final EventItem event;
  final EventStats stats;
}

/// One entry per event, biggest expenditure (after reimbursement) first.
List<EventTotal> eventTotals(List<EventItem> events, List<Bill> bills, List<ReimbursementEntry> entries) {
  final list = [for (final e in events) EventTotal(e, EventStats.of(e, bills, entries))];
  list.sort((a, b) => b.stats.net.compareTo(a.stats.net));
  return list;
}
