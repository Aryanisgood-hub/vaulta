import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;

import '../core/utils/money.dart';
import '../models/models.dart';
import '../repositories/bill_repository.dart';
import '../repositories/club_repository.dart';
import '../repositories/event_repository.dart';
import '../repositories/income_repository.dart';
import '../repositories/reimbursement_repository.dart';
import 'demo_store.dart';

// These subclasses replace every Firestore call with in-memory work, so demo mode
// never reads or writes the real database (and works with no Firebase at all).

class DemoClubRepository extends ClubRepository {
  DemoClubRepository(this.s) : super();
  final DemoStore s;

  @override
  Stream<Club?> watch(String id) => s.club.watch();

  @override
  Future<void> createIfMissing(String id, String name, String email) async {}

  @override
  Future<void> updateBudget(String id, {required int oldBudget, required int newBudget, required String by, required String reason}) async {
    final c = s.club.value;
    s.club.value = Club(id: c.id, name: c.name, email: c.email, totalBudget: newBudget, categories: c.categories, members: c.members);
    s.budgetLog.value = [
      BudgetLog(oldBudget: oldBudget, newBudget: newBudget, by: by, reason: reason, at: DateTime.now()),
      ...s.budgetLog.value,
    ];
  }

  @override
  Future<void> updateLists(String id, {List<String>? categories, List<String>? members}) async {
    final c = s.club.value;
    s.club.value = Club(
      id: c.id, name: c.name, email: c.email, totalBudget: c.totalBudget,
      categories: categories ?? c.categories, members: members ?? c.members,
    );
  }

  @override
  Stream<List<BudgetLog>> watchBudgetLog(String id) => s.budgetLog.watch();
}

class DemoEventRepository extends EventRepository {
  DemoEventRepository(this.s) : super();
  final DemoStore s;

  @override
  Stream<List<EventItem>> watch(String c) => s.events.watch();

  @override
  Future<void> add(String c, {required String name, required DateTime date, String description = '', bool reimbursementAvailable = false, int reimbursementAmount = 0}) async {
    s.setEvents([
      ...s.events.value,
      EventItem(
        id: s.nextId('ev'), name: name.trim(), date: date, description: description.trim(),
        reimbursementAvailable: reimbursementAvailable, reimbursementAmount: reimbursementAvailable ? reimbursementAmount : 0,
      ),
    ]);
  }

  EventItem _copy(EventItem e, {String? name, String? description, DateTime? date, bool? available, int? amount}) => EventItem(
        id: e.id, name: name ?? e.name, description: description ?? e.description, date: date ?? e.date,
        reimbursementAvailable: available ?? e.reimbursementAvailable, reimbursementAmount: amount ?? e.reimbursementAmount,
      );

  @override
  Future<void> updateDetails(String c, EventItem e, {required String name, required DateTime date, required String description}) async {
    s.setEvents([for (final x in s.events.value) x.id == e.id ? _copy(x, name: name.trim(), date: date, description: description.trim()) : x]);
  }

  @override
  Future<void> setReimbursement(String c, String eventId, {required bool available, required int amount}) async {
    s.setEvents([for (final x in s.events.value) x.id == eventId ? _copy(x, available: available, amount: available ? amount : 0) : x]);
  }
}

class DemoBillRepository extends BillRepository {
  DemoBillRepository(this.s) : super();
  final DemoStore s;

  Bill _copy(Bill b, {String? id, String? status, String? voidReason, DateTime? createdAt, DateTime? voidedAt}) => Bill(
        id: id ?? b.id, eventId: b.eventId, eventName: b.eventName, amount: b.amount, reason: b.reason,
        paidTo: b.paidTo, category: b.category, date: b.date, receiptId: b.receiptId, receiptName: b.receiptName,
        doneBy: b.doneBy, status: status ?? b.status, voidReason: voidReason ?? b.voidReason,
        createdAt: createdAt ?? b.createdAt, voidedAt: voidedAt ?? b.voidedAt,
      );

  @override
  Stream<List<Bill>> watch(String c) => s.bills.watch();

  @override
  Stream<List<HistoryEntry>> history(String c, String billId) =>
      s.history.watch().map((m) => m[billId] ?? const <HistoryEntry>[]);

  @override
  Future<String> uploadReceipt(String clubId, Uint8List bytes, String fileName, String contentType) async {
    final id = s.nextId('rc');
    s.receipts[id] = bytes;
    return id;
  }

  @override
  Future<Uint8List?> receiptBytes(String clubId, String receiptId) async {
    final own = s.receipts[receiptId];
    if (own != null) return own;
    final data = await rootBundle.load('assets/demo/sample_receipt.jpg');
    return data.buffer.asUint8List();
  }

  @override
  Future<void> add(String clubId, Bill b) async {
    final id = s.nextId('db');
    final now = DateTime.now();
    s.setBills([...s.bills.value, _copy(b, id: id, status: 'active', createdAt: now)]);
    s.addHistory(id, HistoryEntry(action: 'create', by: b.doneBy, summary: 'Created bill of ${Money.format(b.amount)} for "${b.reason}"', at: now));
  }

  @override
  Future<void> edit(String clubId, Bill before, Bill after) async {
    final changes = <String>[
      if (before.amount != after.amount) 'amount ${Money.format(before.amount)} to ${Money.format(after.amount)}',
      if (before.reason != after.reason) 'reason',
      if (before.eventId != after.eventId) 'event',
      if (before.category != after.category) 'category ${before.category} to ${after.category}',
      if (before.paidTo != after.paidTo) 'paid to',
      if (before.receiptId != after.receiptId) 'receipt',
    ];
    final updated = Bill(
      id: before.id, eventId: after.eventId, eventName: after.eventName, amount: after.amount, reason: after.reason,
      paidTo: after.paidTo, category: after.category, date: after.date, receiptId: after.receiptId,
      receiptName: after.receiptName, doneBy: after.doneBy, status: before.status, createdAt: before.createdAt,
    );
    s.setBills([for (final x in s.bills.value) x.id == before.id ? updated : x]);
    s.addHistory(before.id, HistoryEntry(
      action: 'edit', by: after.doneBy, at: DateTime.now(),
      summary: changes.isEmpty ? 'Saved with no field changes' : 'Changed ${changes.join(', ')}',
    ));
  }

  @override
  Future<void> voidBill(String clubId, Bill b, {required String by, required String reason}) async {
    final now = DateTime.now();
    s.setBills([for (final x in s.bills.value) x.id == b.id ? _copy(x, status: 'void', voidReason: reason, voidedAt: now) : x]);
    s.addHistory(b.id, HistoryEntry(action: 'void', by: by, summary: 'Voided: $reason', at: now));
  }
}

class DemoIncomeRepository extends IncomeRepository {
  DemoIncomeRepository(this.s) : super();
  final DemoStore s;

  @override
  Stream<List<Income>> watch(String c) => s.income.watch();

  @override
  Future<void> add(String c, Income i) async {
    s.setIncome([
      ...s.income.value,
      Income(id: s.nextId('di'), amount: i.amount, source: i.source, type: i.type, date: i.date, note: i.note, doneBy: i.doneBy),
    ]);
  }

  @override
  Future<void> voidIncome(String c, String id, String reason) async {
    s.setIncome([
      for (final x in s.income.value)
        x.id == id
            ? Income(id: x.id, amount: x.amount, source: x.source, type: x.type, date: x.date, note: x.note, doneBy: x.doneBy, status: 'void', voidReason: reason)
            : x,
    ]);
  }
}

class DemoReimbursementRepository extends ReimbursementRepository {
  DemoReimbursementRepository(this.s) : super();
  final DemoStore s;

  @override
  Stream<List<ReimbursementEntry>> watch(String c) => s.reimbursements.watch();

  @override
  Future<void> add(String c, ReimbursementEntry e) async {
    s.setReimbursements([
      ...s.reimbursements.value,
      ReimbursementEntry(id: s.nextId('dr'), eventId: e.eventId, eventName: e.eventName, amount: e.amount, date: e.date, note: e.note, doneBy: e.doneBy),
    ]);
  }

  @override
  Future<void> voidEntry(String c, String id, String reason) async {
    s.setReimbursements([
      for (final x in s.reimbursements.value)
        x.id == id
            ? ReimbursementEntry(id: x.id, eventId: x.eventId, eventName: x.eventName, amount: x.amount, date: x.date, note: x.note, doneBy: x.doneBy, status: 'void', voidReason: reason)
            : x,
    ]);
  }
}
