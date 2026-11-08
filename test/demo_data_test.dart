import 'package:flutter_test/flutter_test.dart';
import 'package:vaulta/core/utils/money.dart';
import 'package:vaulta/demo/demo_store.dart';
import 'package:vaulta/models/models.dart';

int rs(num rupees) => (rupees * 100).round();

void main() {
  test('demo data adds up to the figures shown on the demo dashboard', () {
    final s = DemoStore();
    final sum = Summary.from(s.club.value.totalBudget, s.bills.value, s.income.value, s.events.value, s.reimbursements.value);

    expect(sum.gross, rs(135000));            // all active bills
    expect(sum.net, rs(38700));               // total spent after reimbursement
    expect(sum.appliedReimbursement, rs(96300));
    expect(sum.declared, rs(123000));
    expect(sum.received, rs(70000));
    expect(sum.left, rs(53000));              // left to receive
    expect(sum.leftToUse, rs(6700));          // received but not needed
    expect(sum.income, rs(30500));
    expect(sum.funds, rs(77200));
    expect(sum.remaining, rs(38500));
    expect(sum.warn, isFalse);
    expect(sum.over, isFalse);
    expect(Money.format(sum.remaining), '₹38,500');
  });

  test('demo data shows voided records and every event has a name', () {
    final s = DemoStore();
    expect(s.bills.value.where((b) => b.isVoid).length, 1);
    expect(s.income.value.where((i) => i.isVoid).length, 1);
    expect(s.reimbursements.value.where((r) => r.isVoid).length, 1);
    expect(s.events.value.every((e) => e.name.isNotEmpty), isTrue);
    // every bill belongs to a real event
    final ids = s.events.value.map((e) => e.id).toSet();
    expect(s.bills.value.every((b) => ids.contains(b.eventId)), isTrue);
  });

  test('lists are sorted newest first', () {
    final s = DemoStore();
    final dates = s.bills.value.map((b) => b.date).toList();
    for (var i = 1; i < dates.length; i++) {
      expect(dates[i - 1].isBefore(dates[i]), isFalse);
    }
  });
}
