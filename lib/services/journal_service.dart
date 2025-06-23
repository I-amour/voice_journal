import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/journal_entry.dart';

class JournalService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> saveEntry(JournalEntry entry, String userId) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('entries')
        .add(entry.toMap());
  }

  Stream<List<JournalEntry>> getEntries(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('entries')
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => JournalEntry.fromMap(doc.data()))
            .toList());
  }
}