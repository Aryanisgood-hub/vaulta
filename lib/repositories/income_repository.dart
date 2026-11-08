import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/models.dart';

class IncomeRepository {
  IncomeRepository([FirebaseFirestore? db]) : _injected = db;
  final FirebaseFirestore? _injected;
  FirebaseFirestore get _db => _injected ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String c) =>
      _db.collection('clubs').doc(c).collection('income');

  Stream<List<Income>> watch(String c) => _col(c).orderBy('date', descending: true)
      .snapshots().map((s) => s.docs.map(Income.fromDoc).toList());

  Future<void> add(String c, Income i) =>
      _col(c).add({...i.toMap(), 'createdAt': FieldValue.serverTimestamp()});

  /// Income is never edited or deleted, only voided.
  Future<void> voidIncome(String c, String id, String reason) => _col(c).doc(id).update({
        'status': 'void', 'voidReason': reason, 'voidedAt': FieldValue.serverTimestamp(),
      });
}
