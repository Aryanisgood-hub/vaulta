import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/utils/formatters.dart';
import '../core/utils/money.dart';
import '../models/models.dart';

class BillRepository {
  BillRepository([FirebaseFirestore? db]) : _injected = db;
  final FirebaseFirestore? _injected;
  FirebaseFirestore get _db => _injected ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String c) =>
      _db.collection('clubs').doc(c).collection('bills');

  Stream<List<Bill>> watch(String c) => _col(c).orderBy('date', descending: true)
      .snapshots().map((s) => s.docs.map(Bill.fromDoc).toList());

  Stream<List<HistoryEntry>> history(String c, String billId) => _col(c).doc(billId)
      .collection('history').orderBy('at', descending: true).snapshots()
      .map((s) => s.docs.map(HistoryEntry.fromDoc).toList());

  // ---------------------------------------------------------- receipts
  // Receipts live in Firestore (clubs/{club}/receipts/{id}) so the free Spark
  // plan is enough. Images are shrunk to <= 700 KB before upload.
  CollectionReference<Map<String, dynamic>> _receipts(String c) =>
      _db.collection('clubs').doc(c).collection('receipts');

  /// Returns the new receipt's id (stored on the bill as `receiptId`).
  Future<String> uploadReceipt(String clubId, Uint8List bytes, String fileName, String contentType) async {
    final ref = _receipts(clubId).doc();
    await ref.set({
      'data': Blob(bytes),
      'contentType': contentType,
      'name': fileName,
      'size': bytes.length,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Future<Uint8List?> receiptBytes(String clubId, String receiptId) async {
    final snap = await _receipts(clubId).doc(receiptId).get();
    final data = snap.data()?['data'];
    return data is Blob ? data.bytes : null;
  }

  // ------------------------------------------------------------- writes
  Map<String, dynamic> _stamp(DocumentReference ref, String action, String by, String summary) => {
        'action': action, 'by': by, 'summary': summary, 'at': FieldValue.serverTimestamp(),
      };

  Future<void> add(String clubId, Bill b) {
    final ref = _col(clubId).doc();
    final batch = _db.batch();
    batch.set(ref, {
      ...b.toMap(), 'status': 'active',
      'createdAt': FieldValue.serverTimestamp(), 'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.set(ref.collection('history').doc(),
        _stamp(ref, 'create', b.doneBy, 'Created bill of ${Money.format(b.amount)} for "${b.reason}"'));
    return batch.commit();
  }

  Future<void> edit(String clubId, Bill before, Bill after) {
    final ref = _col(clubId).doc(before.id);
    final changes = <String>[
      if (before.amount != after.amount) 'amount ${Money.format(before.amount)}  to  ${Money.format(after.amount)}',
      if (before.reason != after.reason) 'reason',
      if (before.eventId != after.eventId) 'event',
      if (before.category != after.category) 'category ${before.category}  to  ${after.category}',
      if (before.paidTo != after.paidTo) 'paid to',
      if (before.date != after.date) 'date ${fmtDate(before.date)}  to  ${fmtDate(after.date)}',
      if (before.receiptId != after.receiptId) 'receipt',
    ];
    final batch = _db.batch();
    batch.update(ref, {...after.toMap(), 'updatedAt': FieldValue.serverTimestamp()});
    batch.set(ref.collection('history').doc(), _stamp(ref, 'edit', after.doneBy,
        changes.isEmpty ? 'Saved with no field changes' : 'Changed ${changes.join(', ')}'));
    return batch.commit();
  }

  Future<void> voidBill(String clubId, Bill b, {required String by, required String reason}) {
    final ref = _col(clubId).doc(b.id);
    final batch = _db.batch();
    batch.update(ref, {
      'status': 'void', 'voidReason': reason,
      'voidedAt': FieldValue.serverTimestamp(), 'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.set(ref.collection('history').doc(), _stamp(ref, 'void', by, 'Voided: $reason'));
    return batch.commit();
  }
}
