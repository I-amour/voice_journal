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

  // Add this method to your JournalService class
Future<void> deleteEntry(JournalEntry entry, String userId) async {
  final query = await _firestore
      .collection('users')
      .doc(userId)
      .collection('entries')
      .where('text', isEqualTo: entry.text)
      .where('date', isEqualTo: Timestamp.fromDate(entry.date))
      .limit(1)
      .get();

  if (query.docs.isNotEmpty) {
    await query.docs.first.reference.delete();
  }
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