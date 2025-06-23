import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SentimentService {
  // Hugging Face API key - get yours at https://huggingface.co/settings/tokens
  final String _apiKey = dotenv.env['HUGG_API_KEY'] ?? '';
  final String _model = 'finiteautomata/bertweet-base-sentiment-analysis';

  Future<String> analyzeSentiment(String text) async {
    try {
      final response = await http.post(
        Uri.parse('https://api-inference.huggingface.co/models/$_model'),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'inputs': text}),
      );

      if (kDebugMode) {
        print('Hugging Face API response: ${response.statusCode} - ${response.body}');
      }

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        
        // Handle both single and batch response formats
        final results = jsonResponse is List ? jsonResponse[0] : jsonResponse;
        
        if (results is List && results.isNotEmpty) {
          // Results are sorted by score (highest first)
          final bestMatch = results[0];
          final label = bestMatch['label'].toString().toLowerCase();
          
          // Convert Hugging Face labels to our format
          return _convertLabel(label);
        }
      }
      
      // If API fails, use fallback
      return _fallbackSentimentAnalysis(text);
      
    } catch (e) {
      if (kDebugMode) {
        print('Error analyzing sentiment: $e');
      }
      return _fallbackSentimentAnalysis(text);
    }
  }

  // Convert Hugging Face labels to our standard format
  String _convertLabel(String label) {
    switch (label) {
      case 'positive':
      case 'pos':
        return 'positive';
      case 'negative':
      case 'neg':
        return 'negative';
      default:
        return 'neutral';
    }
  }

  // Fallback method when API fails
  String _fallbackSentimentAnalysis(String text) {
    final lowerText = text.toLowerCase();
    
    final positiveWords = [
      'happy', 'joy', 'great', 'wonderful', 'love', 'amazing',
      'good', 'excellent', 'positive', 'awesome', 'fantastic'
    ];
    
    final negativeWords = [
      'sad', 'angry', 'hate', 'terrible', 'awful', 'depressed',
      'bad', 'horrible', 'negative', 'upset', 'worst'
    ];

    final positiveCount = positiveWords.where((w) => lowerText.contains(w)).length;
    final negativeCount = negativeWords.where((w) => lowerText.contains(w)).length;

    if (positiveCount > negativeCount) return 'positive';
    if (negativeCount > positiveCount) return 'negative';
    return 'neutral';
  }
}