import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/models.dart';

/// Reimbursement money actually received for events. Append-only (can be voided).
class ReimbursementRepository {
  ReimbursementRepository([FirebaseFirestore? db]) : _injected = db;
  final FirebaseFirestore? _injected;
  FirebaseFirestore get _db => _injected ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String c) =>
      _db.collection('clubs').doc(c).collection('reimbursements');

  Stream<List<ReimbursementEntry>> watch(String c) => _col(c).orderBy('date', descending: true)
      .snapshots().map((s) => s.docs.map(ReimbursementEntry.fromDoc).toList());

  Future<void> add(String c, ReimbursementEntry e) =>
      _col(c).add({...e.toMap(), 'createdAt': FieldValue.serverTimestamp()});

  Future<void> voidEntry(String c, String id, String reason) => _col(c).doc(id).update({
        'status': 'void', 'voidReason': reason, 'voidedAt': FieldValue.serverTimestamp(),
      });
}
