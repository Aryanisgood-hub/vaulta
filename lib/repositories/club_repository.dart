import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/app_info.dart';
import '../models/models.dart';

class ClubRepository {
  ClubRepository([FirebaseFirestore? db]) : _injected = db;
  final FirebaseFirestore? _injected;
  FirebaseFirestore get _db => _injected ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _ref(String id) => _db.collection('clubs').doc(id);

  Stream<Club?> watch(String id) =>
      _ref(id).snapshots().map((d) => d.exists ? Club.fromDoc(d) : null);

  /// Creates the club profile once (after email verification). Never overwrites.
  Future<void> createIfMissing(String id, String name, String email) {
    final ref = _ref(id);
    return _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) {
        tx.set(ref, {
          'name': name, 'email': email, 'totalBudget': 0,
          'categories': defaultCategories, 'members': <String>[],
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  /// Budget changes are always logged (old, new, who, why).
  Future<void> updateBudget(String id, {required int oldBudget, required int newBudget, required String by, required String reason}) {
    final batch = _db.batch();
    batch.update(_ref(id), {'totalBudget': newBudget});
    batch.set(_ref(id).collection('budgetLog').doc(), {
      'oldBudget': oldBudget, 'newBudget': newBudget, 'by': by, 'reason': reason,
      'at': FieldValue.serverTimestamp(),
    });
    return batch.commit();
  }

  Future<void> updateLists(String id, {List<String>? categories, List<String>? members}) =>
      _ref(id).update({
        if (categories != null) 'categories': categories,
        if (members != null) 'members': members,
      });

  Stream<List<BudgetLog>> watchBudgetLog(String id) => _ref(id)
      .collection('budgetLog').orderBy('at', descending: true).snapshots()
      .map((s) => s.docs.map(BudgetLog.fromDoc).toList());
}
