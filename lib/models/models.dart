import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/app_info.dart';

DateTime? _ts(dynamic v) => v is Timestamp ? v.toDate() : null;
int _int(dynamic v) => v is num ? v.toInt() : 0;
List<String> _strings(dynamic v) => v is List ? v.map((e) => e.toString()).toList() : <String>[];

typedef Doc = DocumentSnapshot<Map<String, dynamic>>;

// ---------------------------------------------------------------- Club
class Club {
  const Club({required this.id, required this.name, required this.email, required this.totalBudget, required this.categories, required this.members});
  final String id, name, email;
  final int totalBudget; // paise
  final List<String> categories, members;

  factory Club.fromDoc(Doc d) {
    final m = d.data()!;
    final cats = _strings(m['categories']);
    return Club(
      id: d.id,
      name: (m['name'] ?? '') as String,
      email: (m['email'] ?? '') as String,
      totalBudget: _int(m['totalBudget']),
      categories: cats.isEmpty ? defaultCategories : cats,
      members: _strings(m['members']),
    );
  }
}

// ---------------------------------------------------------------- Event
class EventItem {
  const EventItem({
    required this.id, required this.name, required this.date, this.description = '',
    this.reimbursementAvailable = false, this.reimbursementAmount = 0,
  });
  final String id, name, description;
  final DateTime date;

  /// Will someone (college, department, sponsor) pay part of this event back?
  final bool reimbursementAvailable;
  final int reimbursementAmount; // paise; 0 unless available

  factory EventItem.fromDoc(Doc d) {
    final m = d.data()!;
    return EventItem(
      id: d.id,
      name: (m['name'] ?? '') as String,
      description: (m['description'] ?? '') as String,
      date: _ts(m['date']) ?? DateTime.now(),
      reimbursementAvailable: m['reimbursementAvailable'] == true,
      reimbursementAmount: _int(m['reimbursementAmount']),
    );
  }
}

// ---------------------------------------------------------------- Bill
class Bill {
  const Bill({
    this.id = '', required this.eventId, required this.eventName, required this.amount,
    required this.reason, this.paidTo = '', this.category = 'Other', required this.date,
    this.receiptId, this.receiptName, required this.doneBy, this.status = 'active',
    this.voidReason, this.createdAt, this.voidedAt,
  });

  final String id, eventId, eventName, reason, paidTo, category, doneBy, status;
  final int amount; // paise
  final DateTime date;
  final String? receiptId, receiptName, voidReason;
  final DateTime? createdAt, voidedAt;

  bool get isVoid => status == 'void';

  /// Same bill, showing the event's current name (events can be renamed).
  Bill withEventName(String name) => Bill(
        id: id, eventId: eventId, eventName: name, amount: amount, reason: reason, paidTo: paidTo,
        category: category, date: date, receiptId: receiptId, receiptName: receiptName, doneBy: doneBy,
        status: status, voidReason: voidReason, createdAt: createdAt, voidedAt: voidedAt,
      );

  factory Bill.fromDoc(Doc d) {
    final m = d.data()!;
    return Bill(
      id: d.id,
      eventId: (m['eventId'] ?? '') as String,
      eventName: (m['eventName'] ?? '') as String,
      amount: _int(m['amount']),
      reason: (m['reason'] ?? '') as String,
      paidTo: (m['paidTo'] ?? '') as String,
      category: (m['category'] ?? 'Other') as String,
      date: _ts(m['date']) ?? DateTime.now(),
      receiptId: m['receiptId'] as String?,
      receiptName: m['receiptName'] as String?,
      doneBy: (m['doneBy'] ?? '') as String,
      status: (m['status'] ?? 'active') as String,
      voidReason: m['voidReason'] as String?,
      createdAt: _ts(m['createdAt']),
      voidedAt: _ts(m['voidedAt']),
    );
  }

  /// Editable fields only (timestamps are added by the repository).
  Map<String, dynamic> toMap() => {
        'eventId': eventId,
        'eventName': eventName,
        'amount': amount,
        'reason': reason,
        'paidTo': paidTo,
        'category': category,
        'date': Timestamp.fromDate(date),
        'receiptId': receiptId,
        'receiptName': receiptName,
        'doneBy': doneBy,
      };
}

// ---------------------------------------------------------------- Income
class Income {
  const Income({
    this.id = '', required this.amount, required this.source, required this.type,
    required this.date, this.note = '', required this.doneBy, this.status = 'active', this.voidReason,
  });
  final String id, source, type, note, doneBy, status;
  final String? voidReason;
  final int amount;
  final DateTime date;
  bool get isVoid => status == 'void';

  factory Income.fromDoc(Doc d) {
    final m = d.data()!;
    return Income(
      id: d.id,
      amount: _int(m['amount']),
      source: (m['source'] ?? '') as String,
      type: (m['type'] ?? 'Other') as String,
      note: (m['note'] ?? '') as String,
      doneBy: (m['doneBy'] ?? '') as String,
      status: (m['status'] ?? 'active') as String,
      voidReason: m['voidReason'] as String?,
      date: _ts(m['date']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'amount': amount, 'source': source, 'type': type, 'note': note,
        'doneBy': doneBy, 'status': 'active', 'date': Timestamp.fromDate(date),
      };
}

// --------------------------------------------- Reimbursement money received
/// A payment actually received towards an event's reimbursement.
class ReimbursementEntry {
  const ReimbursementEntry({
    this.id = '', required this.eventId, required this.eventName, required this.amount,
    required this.date, this.note = '', required this.doneBy, this.status = 'active', this.voidReason,
  });
  final String id, eventId, eventName, note, doneBy, status;
  final String? voidReason;
  final int amount;
  final DateTime date;
  bool get isVoid => status == 'void';

  ReimbursementEntry withEventName(String name) => ReimbursementEntry(
        id: id, eventId: eventId, eventName: name, amount: amount, date: date, note: note,
        doneBy: doneBy, status: status, voidReason: voidReason,
      );

  factory ReimbursementEntry.fromDoc(Doc d) {
    final m = d.data()!;
    return ReimbursementEntry(
      id: d.id,
      eventId: (m['eventId'] ?? '') as String,
      eventName: (m['eventName'] ?? '') as String,
      amount: _int(m['amount']),
      date: _ts(m['date']) ?? DateTime.now(),
      note: (m['note'] ?? '') as String,
      doneBy: (m['doneBy'] ?? '') as String,
      status: (m['status'] ?? 'active') as String,
      voidReason: m['voidReason'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'eventId': eventId, 'eventName': eventName, 'amount': amount,
        'date': Timestamp.fromDate(date), 'note': note, 'doneBy': doneBy, 'status': 'active',
      };
}

// ------------------------------------------------------- Logs & history
class BudgetLog {
  const BudgetLog({required this.oldBudget, required this.newBudget, required this.by, required this.reason, this.at});
  final int oldBudget, newBudget;
  final String by, reason;
  final DateTime? at;
  factory BudgetLog.fromDoc(Doc d) {
    final m = d.data()!;
    return BudgetLog(
      oldBudget: _int(m['oldBudget']), newBudget: _int(m['newBudget']),
      by: (m['by'] ?? '') as String, reason: (m['reason'] ?? '') as String, at: _ts(m['at']),
    );
  }
}

class HistoryEntry {
  const HistoryEntry({required this.action, required this.by, required this.summary, this.at});
  final String action, by, summary;
  final DateTime? at;
  factory HistoryEntry.fromDoc(Doc d) {
    final m = d.data()!;
    return HistoryEntry(
      action: (m['action'] ?? '') as String, by: (m['by'] ?? '') as String,
      summary: (m['summary'] ?? '') as String, at: _ts(m['at']),
    );
  }
}

// ---------------------------------------------------------- Event money
/// Money picture of one event.
///  gross    = active bills
///  declared = reimbursement the club expects for the event
///  applied  = the part of it that reduces spending (never more than gross)
///  net      = gross - applied  ("expenditure" of the event)
///  received = reimbursement money actually received so far
///  left     = declared - received (still to come)  -> "left to receive"
///  used     = the part of what was received that this event's bills have needed
///  leftToUse= received - used: reimbursement money in hand that nothing has needed yet
class EventStats {
  const EventStats({required this.gross, required this.declared, required this.received});
  final int gross, declared, received;

  int get applied => declared < gross ? declared : gross;
  int get net => gross - applied;
  int get left => declared > received ? declared - received : 0;
  int get used => received < gross ? received : gross;
  int get leftToUse => received - used;

  static EventStats of(EventItem e, Iterable<Bill> bills, Iterable<ReimbursementEntry> entries) {
    var g = 0, r = 0;
    for (final b in bills) {
      if (b.eventId == e.id && !b.isVoid) g += b.amount;
    }
    for (final x in entries) {
      if (x.eventId == e.id && !x.isVoid) r += x.amount;
    }
    return EventStats(gross: g, declared: e.reimbursementAvailable ? e.reimbursementAmount : 0, received: r);
  }
}

// ---------------------------------------------------------------- Summary
class Summary {
  const Summary({
    required this.budget, required this.income, required this.gross, required this.net,
    required this.declared, required this.received, required this.left, required this.leftToUse, required this.byCategory,
  });
  final int budget, income;
  final int gross;    // all active bills
  final int net;      // total spent after reimbursements are applied
  final int declared; // reimbursement expected across events
  final int received; // reimbursement actually received
  final int left;     // reimbursement still to receive
  final int leftToUse; // reimbursement received but not yet needed by bills
  final Map<String, int> byCategory;

  int get spent => net;
  int get appliedReimbursement => gross - net;
  /// Budget + income + reimbursement money that arrived beyond what the bills needed.
  int get funds => budget + income + leftToUse;
  int get remaining => funds - net;
  double get utilization => funds <= 0 ? (net > 0 ? 1.5 : 0) : net / funds;
  bool get warn => utilization >= 0.8 && utilization < 1;
  bool get over => utilization >= 1;

  /// Voided bills / income / reimbursements never count.
  factory Summary.from(int budget, List<Bill> bills, List<Income> income, List<EventItem> events, List<ReimbursementEntry> entries) {
    final cats = <String, int>{};
    var gross = 0;
    for (final b in bills.where((b) => !b.isVoid)) {
      gross += b.amount;
      cats[b.category] = (cats[b.category] ?? 0) + b.amount;
    }
    var net = 0, declared = 0, received = 0, left = 0, leftToUse = 0;
    final known = <String>{};
    for (final e in events) {
      known.add(e.id);
      final s = EventStats.of(e, bills, entries);
      net += s.net;
      declared += s.declared;
      received += s.received;
      left += s.left;
      leftToUse += s.leftToUse;
    }
    for (final b in bills.where((b) => !b.isVoid && !known.contains(b.eventId))) {
      net += b.amount;
    }
    var inc = 0;
    for (final i in income.where((i) => !i.isVoid)) {
      inc += i.amount;
    }
    return Summary(budget: budget, income: inc, gross: gross, net: net, declared: declared, received: received, left: left, leftToUse: leftToUse, byCategory: cats);
  }
}
