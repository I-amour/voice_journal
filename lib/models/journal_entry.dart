import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart'; // For Color class

class JournalEntry {
  final String text;
  final String mood;
  final DateTime date;
  final double confidence;

  JournalEntry({
    required this.text,
    required this.mood,
    required this.date,
    required this.confidence,
  });

  factory JournalEntry.fromMap(Map<String, dynamic> map) {
    return JournalEntry(
      text: map['text'] ?? '',
      mood: map['mood'] ?? 'neutral',
      date: (map['date'] as Timestamp).toDate(),
      confidence: (map['confidence'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'mood': mood,
      'date': Timestamp.fromDate(date),
      'confidence': confidence,
    };
  }

  Color get moodColor {
    switch (mood.toLowerCase()) {
      case 'positive':
        return Colors.green;
      case 'negative':
        return Colors.red;
      default:
        return Colors.amber;
    }
  }

  String get moodEmoji {
    switch (mood.toLowerCase()) {
      case 'positive':
        return '😊';
      case 'negative':
        return '😞';
      default:
        return '😐';
    }
  }

  String get formattedDate {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}

