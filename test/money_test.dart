import 'package:flutter_test/flutter_test.dart';
import 'package:vaulta/core/utils/money.dart';
import 'package:vaulta/models/models.dart';

Bill _b(int amount, {String status = 'active', String cat = 'Food', String event = 'e1'}) => Bill(
      eventId: event, eventName: 'E', amount: amount, reason: 'r', category: cat,
      date: DateTime(2026, 1, 1), doneBy: 'A', status: status,
    );

EventItem _e(String id, {bool reimb = false, int amount = 0}) => EventItem(
      id: id, name: id, date: DateTime(2026, 1, 1), reimbursementAvailable: reimb, reimbursementAmount: amount,
    );

ReimbursementEntry _r(String eventId, int amount, {String status = 'active'}) => ReimbursementEntry(
      eventId: eventId, eventName: eventId, amount: amount, date: DateTime(2026, 1, 2), doneBy: 'A', status: status,
    );

void main() {
  group('Money', () {
    test('parses rupees into integer paise', () {
      expect(Money.toPaise('1'), 100);
      expect(Money.toPaise('1,250'), 125000);
      expect(Money.toPaise('12.5'), 1250);
      expect(Money.toPaise('0.05'), 5);
      expect(Money.toPaise('₹50,000'), 5000000);
    });
    test('rejects bad input', () {
      expect(() => Money.toPaise(''), throwsFormatException);
      expect(() => Money.toPaise('1.234'), throwsFormatException);
      expect(() => Money.toPaise('abc'), throwsFormatException);
      expect(() => Money.toPaise('1.2.3'), throwsFormatException);
    });
    test('validate requires > 0', () {
      expect(Money.validate('0'), isNotNull);
      expect(Money.validate('10'), isNull);
    });
    test('formats with Indian grouping', () {
      expect(Money.format(125000), '₹1,250');
      expect(Money.format(10050), '₹100.50');
      expect(Money.format(10000000), '₹1,00,000');
    });
    test('no float traps in paise', () {
      expect(Money.toPaise('0.1') + Money.toPaise('0.2'), Money.toPaise('0.3'));
    });
  });

  group('renaming events', () {
    test('withEventName changes only the name', () {
      final b = _b(5000).withEventName('New name');
      expect(b.eventName, 'New name');
      expect(b.amount, 5000);
      expect(b.eventId, 'e1');
      final r = _r('e1', 700).withEventName('New name');
      expect(r.eventName, 'New name');
      expect(r.amount, 700);
    });
  });

  group('EventStats', () {
    test('reimbursement reduces the event expenditure', () {
      final e = _e('e1', reimb: true, amount: 30000);
      final st = EventStats.of(e, [_b(50000), _b(20000)], [_r('e1', 10000)]);
      expect(st.gross, 70000);
      expect(st.net, 40000);
      expect(st.received, 10000);
      expect(st.left, 20000);
    });
    test('received money the bills did not need becomes "left to use"', () {
      final e = _e('e1', reimb: true, amount: 50000);
      final st = EventStats.of(e, [_b(30000)], [_r('e1', 50000)]);
      expect(st.received, 50000);
      expect(st.used, 30000);
      expect(st.leftToUse, 20000);
      expect(st.left, 0);
      expect(st.net, 0);
    });
    test('nothing is left to use while bills still need the money', () {
      final st = EventStats.of(_e('e1', reimb: true, amount: 50000), [_b(30000)], [_r('e1', 10000)]);
      expect(st.leftToUse, 0);
      expect(st.left, 40000);
    });
    test('no reimbursement means net equals bills', () {
      final st = EventStats.of(_e('e1'), [_b(50000)], const []);
      expect(st.net, 50000);
      expect(st.left, 0);
    });
    test('reimbursement never pushes expenditure below zero', () {
      final st = EventStats.of(_e('e1', reimb: true, amount: 99999), [_b(1000)], const []);
      expect(st.net, 0);
    });
    test('voided bills and voided receipts do not count', () {
      final e = _e('e1', reimb: true, amount: 30000);
      final st = EventStats.of(e, [_b(50000), _b(99999, status: 'void')], [_r('e1', 10000), _r('e1', 5000, status: 'void')]);
      expect(st.gross, 50000);
      expect(st.received, 10000);
    });
  });

  group('Summary', () {
    test('totals combine events, reimbursements and income', () {
      final events = [_e('e1', reimb: true, amount: 30000), _e('e2')];
      final s = Summary.from(
        100000,
        [_b(50000), _b(20000, event: 'e2', cat: 'Travel'), _b(30000, status: 'void')],
        [Income(amount: 5000, source: 's', type: 'Grant', date: DateTime(2026), doneBy: 'A')],
        events,
        [_r('e1', 10000)],
      );
      expect(s.gross, 70000);
      expect(s.net, 40000);
      expect(s.appliedReimbursement, 30000);
      expect(s.declared, 30000);
      expect(s.received, 10000);
      expect(s.left, 20000);
      expect(s.funds, 105000);
      expect(s.remaining, 65000);
      expect(s.byCategory['Travel'], 20000);
    });
    test('unused reimbursement money is added to the funds', () {
      final events = [_e('e1', reimb: true, amount: 50000)];
      final s = Summary.from(100000, [_b(30000)], const [], events, [_r('e1', 50000)]);
      expect(s.net, 0);
      expect(s.leftToUse, 20000);
      expect(s.funds, 120000);
      expect(s.remaining, 120000);
      // real cash: 100000 budget - 30000 bills + 50000 received = 120000
    });
    test('alert thresholds use spending after reimbursement', () {
      expect(Summary.from(100, [_b(79)], const [], [_e('e1')], const []).warn, isFalse);
      expect(Summary.from(100, [_b(80)], const [], [_e('e1')], const []).warn, isTrue);
      expect(Summary.from(100, [_b(100)], const [], [_e('e1')], const []).over, isTrue);
      expect(Summary.from(100, [_b(100)], const [], [_e('e1', reimb: true, amount: 50)], const []).over, isFalse);
    });
  });
}
