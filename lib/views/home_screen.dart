// ignore_for_file: unused_import
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import '../services/auth_services.dart';
import '../services/sentiment_service.dart';
import '../models/journal_entry.dart';
import 'mood_stats_screen.dart';
import 'dart:async';
import 'dart:io' show Platform;
import '../services/journal_service.dart';
import 'package:flutter/foundation.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => HomeScreenState();
}


class HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final AuthService _auth = AuthService();
  final stt.SpeechToText _speech = stt.SpeechToText();
  final SentimentService _sentiment = SentimentService();
  final JournalService _journalService = JournalService(); 
  final TextEditingController _textController = TextEditingController();
  final FocusNode _textFocusNode = FocusNode();
  Set<int> _expandedEntries = <int>{};
  static const int _maxLinesPreview = 3;

  bool _isListening = false;
  bool _speechAvailable = false;
  bool _isProcessing = false;
  String _text = '';
  String _status = 'Tap microphone to speak or type below';
  List<JournalEntry> _entries = [];
  double _confidenceLevel = 0.0;
  bool _showTextInput = false;
  bool _isEditing = false;
  int? _editingIndex;
  String? _editingEntryId;
  Timer? _speechTimer;
  bool _shouldContinueListening = false;
  String _accumulatedText = '';
  
  late AnimationController _pulseController;
  late AnimationController _fadeController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _fadeAnimation;

  // Modern pastel color scheme
  static const Color _backgroundColor = Color(0xFFF8F9FE);
  static const Color _primaryColor = Color(0xFF6B73FF);
  static const Color _secondaryColor = Color(0xFFFFB3BA);
  static const Color _accentColor = Color(0xFFBAE1FF);
  static const Color _surfaceColor = Color(0xFFFFFFFF);
  static const Color _cardColor = Color(0xFFFFFFFF);
  static const Color _textPrimaryColor = Color(0xFF2D3748);
  static const Color _textSecondaryColor = Color(0xFF718096);
  static const Color _positiveColor = Color(0xFF68D391);
  static const Color _negativeColor = Color(0xFFFC8181);
  static const Color _neutralColor = Color(0xFFECC94B);

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _initAnimations();
    _loadEntries(); // Add this line
  }

  Future<void> _loadEntries() async {
    try {
      final userId = _auth.getCurrentUserId();
      if (userId == null) return;

      _journalService.getEntries(userId).listen((entries) {
        if (mounted) {
          setState(() {
            _entries = entries; // Now this works
          });
        }
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error loading entries: $e');
      }
    }
  }

  void _initAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(_fadeController);
    
    _pulseController.repeat(reverse: true);
    _fadeController.forward();
  }

  void _showFullEntryDialog(JournalEntry entry, int index) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: _surfaceColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
              maxWidth: MediaQuery.of(context).size.width * 0.9,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [entry.moodColor, entry.moodColor.withOpacity(0.7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                  ),
                  child: Row(
                    children: [
                      _moodIcon(entry.mood),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Journal Entry',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '${entry.mood.capitalize()} • ${_formatDate(entry.date)}',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Content
                Flexible(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Full entry text
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: _backgroundColor,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: entry.moodColor.withOpacity(0.2),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              entry.text,
                              style: TextStyle(
                                color: _textPrimaryColor,
                                fontSize: 16,
                                height: 1.6,
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 24),
                          
                          // Action buttons
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                    _showEditDialog(entry, index);
                                  },
                                  icon: const Icon(Icons.edit_rounded, size: 20),
                                  label: const Text('Edit Entry'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: _primaryColor,
                                    side: BorderSide(color: _primaryColor.withOpacity(0.3)),
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => Navigator.of(context).pop(),
                                  icon: const Icon(Icons.check_rounded, size: 20),
                                  label: const Text('Done'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _primaryColor,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 0,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }


  @override
  void dispose() {
    _textController.dispose();
    _textFocusNode.dispose();
    _pulseController.dispose();
    _fadeController.dispose();
    _speechTimer?.cancel(); // Cancel timer on dispose
    super.dispose();
  }

  void _showEditDialog(JournalEntry entry, int index) {
  final TextEditingController editController = TextEditingController(text: entry.text);
  final FocusNode focusNode = FocusNode();

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return WillPopScope(
        onWillPop: () async {
          editController.dispose();
          focusNode.dispose();
          return true;
        },
        child: Dialog(
          backgroundColor: _surfaceColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_primaryColor, _accentColor],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.edit_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Edit Journal Entry',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Content
                Flexible(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Original entry info
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: _backgroundColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: entry.moodColor.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                _moodIcon(entry.mood),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Original Entry',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: _textSecondaryColor,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Text(
                                        '${entry.mood.capitalize()} • ${_formatDate(entry.date)}',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: _textPrimaryColor,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          const SizedBox(height: 20),
                          
                          // Edit text field
                          const Text(
                            'Edit your thoughts:',
                            style: TextStyle(
                              fontSize: 16,
                              color: _textPrimaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            decoration: BoxDecoration(
                              color: _backgroundColor,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: _primaryColor.withOpacity(0.2),
                                width: 2,
                              ),
                            ),
                            child: TextField(
                              controller: editController,
                              focusNode: focusNode,
                              maxLines: 8,
                              minLines: 4,
                              autofocus: true,
                              style: const TextStyle(
                                color: _textPrimaryColor,
                                fontSize: 16,
                                height: 1.5,
                              ),
                              decoration: const InputDecoration(
                                hintText: 'Update your thoughts...',
                                hintStyle: TextStyle(
                                  color: _textSecondaryColor,
                                  fontSize: 16,
                                ),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.all(20),
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 24),
                          
                          // Action buttons
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                  },
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: _textSecondaryColor,
                                    side: BorderSide(color: _textSecondaryColor.withOpacity(0.3)),
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Text('Cancel'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () async {
                                    if (editController.text.trim().isEmpty) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: const Text('Entry cannot be empty'),
                                          backgroundColor: _negativeColor,
                                          behavior: SnackBarBehavior.floating,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                        ),
                                      );
                                      return;
                                    }
                                    
                                    Navigator.of(context).pop();
                                    await _updateEntry(entry, editController.text.trim(), index);
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _primaryColor,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.save_rounded, size: 20),
                                      SizedBox(width: 8),
                                      Text('Save Changes'),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  ).then((_) {
    // Dispose controllers when dialog is closed
    editController.dispose();
    focusNode.dispose();
  });
}

  // Add this new method to handle updating entries:
  Future<void> _updateEntry(JournalEntry originalEntry, String newText, int index) async {
    try {
      setState(() {
        _isEditing = true;
        _editingIndex = index;
      });

      _updateStatus('Analyzing updated entry...');

      // Analyze sentiment of the updated text
      final newMood = await _sentiment.analyzeSentiment(newText);
      
      // Create updated entry
      final updatedEntry = JournalEntry(
        text: newText,
        mood: newMood,
        date: originalEntry.date, // Keep original date
        confidence: 1.0, // High confidence for manually edited text
      );

      // Get current user ID
      final userId = _auth.getCurrentUserId();
      if (userId == null) {
        _updateStatus('Not authenticated - please sign in again');
        return;
      }

      // Update in Firebase
      await _journalService.updateEntry(originalEntry, updatedEntry, userId);

      // Update local list
      setState(() {
        _entries[index] = updatedEntry;
        _isEditing = false;
        _editingIndex = null;
      });

      _updateStatus('Entry updated successfully');
      
      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white),
                SizedBox(width: 8),
                Text('Entry updated successfully'),
              ],
            ),
            backgroundColor: _positiveColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }

    } catch (e) {
      _updateStatus('Failed to update entry: ${e.toString()}');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.error_rounded, color: Colors.white),
                SizedBox(width: 8),
                Text('Failed to update entry'),
              ],
            ),
            backgroundColor: _negativeColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isEditing = false;
          _editingIndex = null;
        });
      }
    }
  }

  Future<void> _initSpeech() async {
    try {
      var status = await Permission.microphone.status;
      if (!status.isGranted) {
        status = await Permission.microphone.request();
      }

      if (status.isGranted) {
        _speechAvailable = await _speech.initialize(
          onStatus: (status) {
            debugPrint('Speech status: $status');
            if (status == 'notListening' && _shouldContinueListening && mounted) {
              // Automatically restart listening if we want to continue
              _restartListening();
            } else if (status == 'notListening' && _isListening && mounted) {
              _handleListeningEnd();
            }
          },
          onError: (error) {
            debugPrint('Speech error: ${error.errorMsg}');
            if (mounted) {
              if (error.errorMsg == 'error_no_match' && _shouldContinueListening) {
                // Continue listening even if no match
                _restartListening();
              } else if (error.errorMsg == 'error_speech_timeout' && _shouldContinueListening) {
                // Restart on timeout
                _restartListening();
              } else {
                _updateStatus('Error: ${error.errorMsg}');
                if (_isListening) {
                  _handleListeningEnd();
                }
              }
            }
          },
          debugLogging: true,
        );
      } else {
        _updateStatus('Microphone permission denied');
      }
    } catch (e) {
      _updateStatus('Error initializing speech: $e');
    }
  }

  void _handleListeningEnd() {
    if (!mounted) return;

    _speechTimer?.cancel();
    _shouldContinueListening = false;

    setState(() {
      _isListening = false;
      _isProcessing = true;
      // Use accumulated text if available
      if (_accumulatedText.isNotEmpty) {
        _text = _accumulatedText;
      }
    });

    if (_text.trim().isNotEmpty) {
      _analyzeAndSaveEntry();
    } else {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
        _updateStatus('No speech detected - try speaking louder or closer to the microphone');
      }
    }
  }

  void _updateStatus(String message) {
    if (mounted) {
      setState(() => _status = message);
    }
    debugPrint(message);
  }

  void _listen() async {
    if (!_speechAvailable) {
      _updateStatus('Speech not available');
      return;
    }

    if (_isListening) {
      // Stop listening
      _shouldContinueListening = false;
      _speechTimer?.cancel();
      await _speech.stop();
      _handleListeningEnd();
      return;
    }

    // Start listening
    setState(() {
      _isListening = true;
      _shouldContinueListening = true;
      _text = '';
      _accumulatedText = '';
      _showTextInput = false;
    });
    _updateStatus('Listening... Speak now');

    _startListeningSession();
  }

  void _startListeningSession() async {
    if (!_shouldContinueListening) return;

    try {
      await _speech.listen(
        localeId: 'en_US',
        onResult: (result) {
          if (mounted) {
            setState(() {
              _text = result.recognizedWords;
              _confidenceLevel = result.confidence;
              
              // If we get a final result, add it to accumulated text
              if (result.finalResult && result.recognizedWords.trim().isNotEmpty) {
                if (_accumulatedText.isNotEmpty) {
                  _accumulatedText += ' ';
                }
                _accumulatedText += result.recognizedWords.trim();
                _text = _accumulatedText; // Show accumulated text
              }
            });
          }
        },
        // Shorter individual sessions but we'll restart them
        listenFor: const Duration(seconds: 15),
        pauseFor: const Duration(seconds: 3),
        cancelOnError: false,
        partialResults: true,
        listenMode: stt.ListenMode.confirmation,
        sampleRate: 16000,
        onSoundLevelChange: (level) {
          debugPrint('Sound level: $level');
        },
      );

      // Set up timer to restart listening before it times out
      _speechTimer = Timer(const Duration(seconds: 12), () {
        if (_shouldContinueListening && _isListening) {
          _restartListening();
        }
      });

      debugPrint('Listening session started');
    } catch (e) {
      debugPrint('Error in listening session: $e');
      if (_shouldContinueListening) {
        // Try to restart after a brief delay
        Timer(const Duration(milliseconds: 500), () {
          if (_shouldContinueListening) {
            _restartListening();
          }
        });
      }
    }
  }

  void _restartListening() async {
    if (!_shouldContinueListening || !mounted) return;

    debugPrint('Restarting listening session...');
    _speechTimer?.cancel();
    
    try {
      await _speech.stop();
      // Brief pause before restarting
      await Future.delayed(const Duration(milliseconds: 100));
      
      if (_shouldContinueListening && mounted) {
        _startListeningSession();
      }
    } catch (e) {
      debugPrint('Error restarting listening: $e');
    }
  }

  void _toggleInputMode() {
    setState(() {
      _showTextInput = !_showTextInput;
      if (_showTextInput) {
        _textFocusNode.requestFocus();
      } else {
        _textFocusNode.unfocus();
      }
    });
    
    if (_showTextInput) {
      _updateStatus('Type your journal entry below');
      Future.delayed(const Duration(milliseconds: 100), () {
        _textFocusNode.requestFocus();
      });
    } else {
      _updateStatus('Tap microphone to speak or type below');
    }
  }

  Future<void> _submitTextEntry() async {
    if (_textController.text.trim().isEmpty) {
      _updateStatus('Please enter some text');
      return;
    }

    setState(() {
      _text = _textController.text;
      _isProcessing = true;
      _confidenceLevel = 1.0;
      _textController.clear();
      _showTextInput = false;
    });

    await _analyzeAndSaveEntry();
  }

  Future<void> _analyzeAndSaveEntry() async {
    try {
      setState(() => _isProcessing = true);

      if (_text.trim().isEmpty) {
        _updateStatus('No content to analyze');
        return;
      }

      _updateStatus('Analyzing...');
      final mood = await _sentiment.analyzeSentiment(_text);
      
      // Create the entry
      final entry = JournalEntry(
        text: _text,
        mood: mood,
        date: DateTime.now(),
        confidence: _confidenceLevel,
      );

      // Get current user ID
      final userId = _auth.getCurrentUserId();
      if (userId == null) {
        _updateStatus('Not authenticated - please sign in again');
        return;
      }

      // Save to Firebase
      await _journalService.saveEntry(entry, userId);

      // Update UI
      setState(() {
        _entries.insert(0, entry);
        _text = '';
        _confidenceLevel = 0.0;
      });
      _updateStatus('Entry saved successfully');

    } catch (e) {
      _updateStatus('Failed to save entry: ${e.toString()}');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Widget _buildRecordingFAB() {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: (_isListening ? _negativeColor : _primaryColor).withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: FloatingActionButton.large(
        onPressed: _listen,
        backgroundColor: _isListening ? _negativeColor : _primaryColor,
        elevation: 0,
        child: AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _isListening ? _pulseAnimation.value : 1.0,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _isListening ? Icons.stop_rounded : Icons.mic_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                  if (_isListening)
                    const Text(
                      'TAP TO\nSTOP',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text(
          'Voice Journal',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: _textPrimaryColor,
          ),
        ),
        backgroundColor: _surfaceColor,
        elevation: 0,
        shadowColor: Colors.transparent,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: _accentColor.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.analytics_rounded, color: _primaryColor),
              onPressed: () => _showStats(),
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: _secondaryColor.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.logout_rounded, color: _textPrimaryColor),
              onPressed: () => _auth.signOut(),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Recording Indicator (existing code)
              if (_isListening || _isProcessing)
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _primaryColor.withOpacity(0.1),
                        _accentColor.withOpacity(0.1),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _primaryColor.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          AnimatedBuilder(
                            animation: _pulseAnimation,
                            builder: (context, child) {
                              return Transform.scale(
                                scale: _isListening ? _pulseAnimation.value : 1.0,
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: _isListening ? _negativeColor : _textSecondaryColor,
                                    shape: BoxShape.circle,
                                    boxShadow: _isListening ? [
                                      BoxShadow(
                                        color: _negativeColor.withOpacity(0.3),
                                        blurRadius: 10,
                                        spreadRadius: 2,
                                      ),
                                    ] : [],
                                  ),
                                  child: const Icon(
                                    Icons.mic_rounded,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  height: 4,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(2),
                                    color: Colors.grey[200],
                                  ),
                                  child: LinearProgressIndicator(
                                    value: _confidenceLevel,
                                    backgroundColor: Colors.transparent,
                                    valueColor: const AlwaysStoppedAnimation<Color>(_primaryColor),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _isListening ? 'Listening...' : 'Processing...',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: _textPrimaryColor,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  _text.isEmpty ? 'Speak now...' : _text,
                                  style: const TextStyle(
                                    color: _textSecondaryColor,
                                    fontSize: 14,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 2,
                                ),
                              ],
                            ),
                          ),
                          if (_isProcessing)
                            Container(
                              padding: const EdgeInsets.all(12),
                              child: const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (_status.contains('Error') || _status.contains('timeout'))
                        Container(
                          margin: const EdgeInsets.only(top: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _negativeColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _negativeColor.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_rounded, color: _negativeColor, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _status,
                                  style: const TextStyle(color: _negativeColor),
                                ),
                              ),
                              TextButton(
                                onPressed: _listen,
                                style: TextButton.styleFrom(
                                  foregroundColor: _negativeColor,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                ),
                                child: const Text('TRY AGAIN'),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),

              // Status Message (existing code)
              if (!(_isListening || _isProcessing))
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Text(
                    _status,
                    style: TextStyle(
                      color: _status.contains('Error') ? _negativeColor : _textSecondaryColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

              // Updated Entries List with truncation
              Expanded(
                child: _entries.isEmpty
                    ? Center(
                        child: FadeTransition(
                          opacity: _fadeAnimation,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: _accentColor.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.auto_stories_rounded,
                                  size: 64,
                                  color: _primaryColor,
                                ),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                'Your Journal Awaits',
                                style: TextStyle(
                                  color: _textPrimaryColor,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _showTextInput 
                                    ? 'Share your thoughts in writing'
                                    : 'Speak your mind and let your voice be heard',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: _textSecondaryColor,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : Container(
                        padding: const EdgeInsets.only(bottom: 160), // Space for FABs
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _entries.length,
                          itemBuilder: (context, index) {
                            final entry = _entries[index];
                            final isBeingEdited = _isEditing && _editingIndex == index;
                            final isExpanded = _expandedEntries.contains(index);
                            
                            // Check if text needs truncation
                            final textSpan = TextSpan(
                              text: entry.text,
                              style: TextStyle(
                                color: _textPrimaryColor,
                                fontSize: 16,
                                height: 1.5,
                              ),
                            );
                            final textPainter = TextPainter(
                              text: textSpan,
                              textDirection: TextDirection.ltr,
                              maxLines: _maxLinesPreview,
                            );
                            textPainter.layout(maxWidth: MediaQuery.of(context).size.width - 64);
                            final isTextTruncated = textPainter.didExceedMaxLines;
                            textPainter.dispose();

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: _cardColor,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.04),
                                    blurRadius: 10,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                                border: Border.all(
                                  color: isBeingEdited 
                                      ? _primaryColor.withOpacity(0.3)
                                      : Colors.grey.withOpacity(0.1),
                                  width: isBeingEdited ? 2 : 1,
                                ),
                              ),
                              child: Column(
                                children: [
                                  // Main content - tappable area for expansion
                                  InkWell(
                                    onTap: isBeingEdited ? null : () {
                                      if (isTextTruncated) {
                                        _showFullEntryDialog(entry, index);
                                      }
                                    },
                                    borderRadius: BorderRadius.circular(16),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Edit indicator
                                          if (isBeingEdited)
                                            Container(
                                              margin: const EdgeInsets.only(bottom: 12),
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: _primaryColor.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: _primaryColor.withOpacity(0.3),
                                                  width: 1,
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  SizedBox(
                                                    width: 12,
                                                    height: 12,
                                                    child: CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    'Updating...',
                                                    style: TextStyle(
                                                      color: _primaryColor,
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          
                                          // Entry text with truncation
                                          Text(
                                            entry.text,
                                            style: TextStyle(
                                              color: _textPrimaryColor,
                                              fontSize: 16,
                                              height: 1.5,
                                            ),
                                            maxLines: _maxLinesPreview,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          
                                          // "Tap to read more" indicator
                                          if (isTextTruncated && !isBeingEdited)
                                            Padding(
                                              padding: const EdgeInsets.only(top: 8),
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    Icons.touch_app_rounded,
                                                    size: 16,
                                                    color: _primaryColor,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    'Tap to read full entry',
                                                    style: TextStyle(
                                                      color: _primaryColor,
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          
                                          const SizedBox(height: 12),
                                          
                                          // Entry metadata
                                          Row(
                                            children: [
                                              _moodIcon(entry.mood),
                                              const SizedBox(width: 8),
                                              Text(
                                                '${entry.mood.capitalize()} • ${_formatDate(entry.date)}',
                                                style: TextStyle(
                                                  color: _textSecondaryColor,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              const Spacer(),
                                            ],
                                          ),
                                          
                                          // Confidence indicator
                                          if (entry.confidence < 1.0)
                                            Container(
                                              margin: const EdgeInsets.only(top: 8),
                                              height: 2,
                                              decoration: BoxDecoration(
                                                borderRadius: BorderRadius.circular(1),
                                                color: Colors.grey[200],
                                              ),
                                              child: LinearProgressIndicator(
                                                value: entry.confidence,
                                                backgroundColor: Colors.transparent,
                                                valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
                                                borderRadius: BorderRadius.circular(1),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  
                                  // Action buttons row (always visible)
                                  if (!isBeingEdited)
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        border: Border(
                                          top: BorderSide(
                                            color: Colors.grey.withOpacity(0.1),
                                            width: 1,
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: OutlinedButton.icon(
                                              onPressed: () => _showEditDialog(entry, index),
                                              icon: Icon(
                                                Icons.edit_outlined,
                                                size: 18,
                                                color: _primaryColor,
                                              ),
                                              label: Text(
                                                'Edit',
                                                style: TextStyle(color: _primaryColor),
                                              ),
                                              style: OutlinedButton.styleFrom(
                                                side: BorderSide(color: _primaryColor.withOpacity(0.3)),
                                                padding: const EdgeInsets.symmetric(vertical: 12),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: OutlinedButton.icon(
                                              onPressed: () => _deleteEntry(index),
                                              icon: Icon(
                                                Icons.delete_outline_rounded,
                                                size: 18,
                                                color: _negativeColor,
                                              ),
                                              label: Text(
                                                'Delete',
                                                style: TextStyle(color: _negativeColor),
                                              ),
                                              style: OutlinedButton.styleFrom(
                                                side: BorderSide(color: _negativeColor.withOpacity(0.3)),
                                                padding: const EdgeInsets.symmetric(vertical: 12),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
              ),
            ],
          ),

          // Text Input Overlay (existing code remains the same)
          if (_showTextInput)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.5),
                child: Center(
                  child: Container(
                    margin: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: _surfaceColor,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [_primaryColor, _accentColor],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(24),
                              topRight: Radius.circular(24),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.edit_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Write Your Thoughts',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                onPressed: _toggleInputMode,
                                icon: Icon(
                                  Icons.close_rounded,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        // Text Input
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: _backgroundColor,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: _primaryColor.withOpacity(0.2),
                                    width: 2,
                                  ),
                                ),
                                child: TextField(
                                  controller: _textController,
                                  focusNode: _textFocusNode,
                                  maxLines: 8,
                                  style: TextStyle(
                                    color: _textPrimaryColor,
                                    fontSize: 16,
                                    height: 1.5,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'What\'s on your mind today?',
                                    hintStyle: TextStyle(
                                      color: _textSecondaryColor,
                                      fontSize: 16,
                                    ),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.all(20),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: _toggleInputMode,
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: _textSecondaryColor,
                                        side: BorderSide(color: _textSecondaryColor.withOpacity(0.3)),
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.keyboard_voice_rounded, size: 20),
                                          const SizedBox(width: 8),
                                          Text('Switch to Voice'),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: _submitTextEntry,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: _primaryColor,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        elevation: 0,
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.save_rounded, size: 20),
                                          const SizedBox(width: 8),
                                          Text('Save Entry'),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: !_showTextInput ? Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Voice Recording FAB with updated design
          _buildRecordingFAB(),
          const SizedBox(height: 16),
          
          // Text Input Toggle FAB
          Container(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: _secondaryColor.withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: FloatingActionButton(
              onPressed: _toggleInputMode,
              backgroundColor: _secondaryColor,
              elevation: 0,
              child: Icon(
                Icons.keyboard_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
        ],
      ) : null,
    );
  }

  
  Widget _moodIcon(String mood) {
    IconData icon;
    Color color;

    switch (mood.toLowerCase()) {
      case 'positive':
        icon = Icons.sentiment_very_satisfied_rounded;
        color = _positiveColor;
        break;
      case 'negative':
        icon = Icons.sentiment_very_dissatisfied_rounded;
        color = _negativeColor;
        break;
      default:
        icon = Icons.sentiment_neutral_rounded;
        color = _neutralColor;
    }

    

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: 16),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')} • ${date.day}/${date.month}/${date.year}';
  }

Future<void> _deleteEntry(int index) async {
  try {
    final entry = _entries[index];
    final userId = _auth.getCurrentUserId();
    if (userId == null) return;

    await _journalService.deleteEntry(entry, userId);

    if (mounted) {
      setState(() {
        _entries.removeAt(index);
      });
    }
  } catch (e) {
    if (kDebugMode) {
      print('Error deleting entry: $e');
    }
    _updateStatus('Failed to delete entry');
  }
}



  void _showStats() {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => MoodStatsScreen(
        entries: _entries,
        primaryColor: _primaryColor,
        accentColor: _accentColor,
        textPrimaryColor: _textPrimaryColor,
        textSecondaryColor: _textSecondaryColor,
      ),
    ),
  );
}
}