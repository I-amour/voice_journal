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

Future<void> updateEntry(JournalEntry originalEntry, JournalEntry updatedEntry, String userId) async {
  try {
    // Query to find the document with matching content and timestamp
    final querySnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('entries')
        .where('text', isEqualTo: originalEntry.text)
        .where('mood', isEqualTo: originalEntry.mood)
        .limit(1)
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      // Update the existing document
      final docId = querySnapshot.docs.first.id;
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('entries')
          .doc(docId)
          .update({
        'text': updatedEntry.text,
        'mood': updatedEntry.mood,
        'confidence': updatedEntry.confidence,
        'updated_at': FieldValue.serverTimestamp(), // Track when it was updated
      });
    } else {
      throw Exception('Entry not found for update');
    }
  } catch (e) {
    throw Exception('Failed to update entry: $e');
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