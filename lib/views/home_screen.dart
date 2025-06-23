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

  bool _isListening = false;
  bool _speechAvailable = false;
  bool _isProcessing = false;
  String _text = '';
  String _status = 'Tap microphone to speak or type below';
  List<JournalEntry> _entries = [];
  double _confidenceLevel = 0.0;
  bool _showTextInput = false;

  // Add these new variables for continuous recording
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

  @override
void dispose() {
    _textController.dispose();
    _textFocusNode.dispose();
    _pulseController.dispose();
    _fadeController.dispose();
    _speechTimer?.cancel(); // Cancel timer on dispose
    super.dispose();
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
          _updateStatus('No speech detected - try speaking louder or closer to the microphone');
        });
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
      _updateStatus('Listening... Speak now');
    });

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
        _updateStatus('Type your journal entry below');
        Future.delayed(const Duration(milliseconds: 100), () {
          _textFocusNode.requestFocus();
        });
      } else {
        _updateStatus('Tap microphone to speak or type below');
        _textFocusNode.unfocus();
      }
    });
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
      _updateStatus('Entry saved successfully');
    });

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
                    Text(
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
              // Recording Indicator
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
                                  child: Icon(
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
                                    valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _isListening ? 'Listening...' : 'Processing...',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: _textPrimaryColor,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  _text.isEmpty ? 'Speak now...' : _text,
                                  style: TextStyle(
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
                              child: SizedBox(
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
                              Icon(Icons.error_rounded, color: _negativeColor, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _status,
                                  style: TextStyle(color: _negativeColor),
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

              // Status Message
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

              // Entries List
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
                                  color: Colors.grey.withOpacity(0.1),
                                  width: 1,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      entry.text,
                                      style: TextStyle(
                                        color: _textPrimaryColor,
                                        fontSize: 16,
                                        height: 1.5,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        _moodIcon(entry.mood),
                                        const SizedBox(width: 8),
                                        Text(
                                          '${entry.mood} • ${_formatDate(entry.date)}',
                                          style: TextStyle(
                                            color: _textSecondaryColor,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const Spacer(),
                                        IconButton(
                                          onPressed: () => _deleteEntry(index),
                                          icon: Icon(
                                            Icons.delete_outline_rounded,
                                            color: _textSecondaryColor,
                                            size: 20,
                                          ),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                        ),
                                      ],
                                    ),
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
                            );
                          },
                        ),
                      ),
              ),
            ],
          ),

          // Modern Text Input Overlay
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