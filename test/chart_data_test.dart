import 'package:flutter_test/flutter_test.dart';
import 'package:vaulta/core/utils/chart_data.dart';
import 'package:vaulta/core/utils/money.dart';
import 'package:vaulta/models/models.dart';

Bill _b(int amount, DateTime date, {String status = 'active', String event = 'e1'}) => Bill(
      eventId: event, eventName: event, amount: amount, reason: 'r', date: date, doneBy: 'A', status: status,
    );

void main() {
  group('monthlyTotals', () {
    final now = DateTime(2026, 10, 29);

    test('groups active bills by month and fills empty months with zero', () {
      final r = monthlyTotals([
        _b(1000, DateTime(2026, 10, 1)),
        _b(500, DateTime(2026, 10, 28)),
        _b(700, DateTime(2026, 8, 15)),
        _b(9999, DateTime(2026, 9, 3), status: 'void'),
      ], 4, now);
      expect(r.map((m) => m.month.month).toList(), [7, 8, 9, 10]);
      expect(r.map((m) => m.amount).toList(), [0, 700, 0, 1500]);
    });

    test('crosses the year boundary correctly', () {
      final r = monthlyTotals([_b(100, DateTime(2025, 12, 5))], 3, DateTime(2026, 1, 20));
      expect(r.map((m) => '${m.month.year}-${m.month.month}').toList(), ['2025-11', '2025-12', '2026-1']);
      expect(r[1].amount, 100);
    });

    test('ignores bills older than the window', () {
      final r = monthlyTotals([_b(100, DateTime(2024, 1, 1))], 6, now);
      expect(r.fold<int>(0, (a, m) => a + m.amount), 0);
    });
  });

  group('eventTotals', () {
    test('sorts by expenditure after reimbursement, biggest first', () {
      final events = [
        EventItem(id: 'a', name: 'A', date: DateTime(2026), reimbursementAvailable: true, reimbursementAmount: 9000),
        EventItem(id: 'b', name: 'B', date: DateTime(2026)),
      ];
      final r = eventTotals(events, [_b(10000, DateTime(2026), event: 'a'), _b(5000, DateTime(2026), event: 'b')], const []);
      expect(r.first.event.id, 'b'); // a: 10000 - 9000 = 1000, b: 5000
      expect(r.first.stats.net, 5000);
      expect(r.last.stats.net, 1000);
    });
  });

  group('Money.compact', () {
    test('short labels', () {
      expect(Money.compact(85000), '₹850');
      expect(Money.compact(1250000), '₹12.5k');
      expect(Money.compact(100000), '₹1k');
      expect(Money.compact(12000000), '₹1.2L');
      expect(Money.compact(3000000000), '₹3Cr');
    });
  });
}
