import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/models.dart';

class EventRepository {
  EventRepository([FirebaseFirestore? db]) : _injected = db;
  final FirebaseFirestore? _injected;
  FirebaseFirestore get _db => _injected ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String c) =>
      _db.collection('clubs').doc(c).collection('events');

  Stream<List<EventItem>> watch(String c) => _col(c).orderBy('date', descending: true)
      .snapshots().map((s) => s.docs.map(EventItem.fromDoc).toList());

  Future<void> add(
    String c, {
    required String name,
    required DateTime date,
    String description = '',
    bool reimbursementAvailable = false,
    int reimbursementAmount = 0,
  }) =>
      _col(c).add({
        'name': name.trim(),
        'description': description.trim(),
        'date': Timestamp.fromDate(date),
        'reimbursementAvailable': reimbursementAvailable,
        'reimbursementAmount': reimbursementAvailable ? reimbursementAmount : 0,
        'createdAt': FieldValue.serverTimestamp(),
      });

  /// Rename / re-date an event. The reimbursement fields are re-sent unchanged so older
  /// events (created before reimbursements existed) also pass the security rules.
  Future<void> updateDetails(String c, EventItem e, {required String name, required DateTime date, required String description}) =>
      _col(c).doc(e.id).update({
        'name': name.trim(),
        'description': description.trim(),
        'date': Timestamp.fromDate(date),
        'reimbursementAvailable': e.reimbursementAvailable,
        'reimbursementAmount': e.reimbursementAvailable ? e.reimbursementAmount : 0,
      });

  Future<void> setReimbursement(String c, String eventId, {required bool available, required int amount}) =>
      _col(c).doc(eventId).update({
        'reimbursementAvailable': available,
        'reimbursementAmount': available ? amount : 0,
      });
}
