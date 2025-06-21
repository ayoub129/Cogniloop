// ignore_for_file: avoid_print, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:async';

import '../../services/analytics_service.dart';
import '../../utils/app_theme.dart';

enum PlayerViewState { loading, content, quiz, h5pUrl, completed }

class LessonPlayerScreen extends StatefulWidget {
  final String lessonId;
  final String lessonTitle;
  final String? reviewId;
  final bool isReviewMode;

  const LessonPlayerScreen({
    super.key,
    required this.lessonId,
    required this.lessonTitle,
    this.reviewId,
    this.isReviewMode = false,
  });

  @override
  State<LessonPlayerScreen> createState() => _LessonPlayerScreenState();
}

class _LessonPlayerScreenState extends State<LessonPlayerScreen> {
  PlayerViewState _viewState = PlayerViewState.loading;

  // Services
  final AnalyticsService _analyticsService = AnalyticsService();

  // Data
  Map<String, dynamic>? _lessonData;
  Map<String, dynamic>? _h5pData;
  List<dynamic> _quizQuestions = [];

  // State
  int _currentQuestionIndex = 0;
  bool _isCompleted = false;
  DateTime _sessionStartTime = DateTime.now();
  final Stopwatch _stopwatch = Stopwatch();
  Map<int, dynamic> _userAnswers = {};

  @override
  void initState() {
    super.initState();
    _stopwatch.start();
    _loadLessonData();
  }

  @override
  void dispose() {
    _stopwatch.stop();
    super.dispose();
  }

  Future<void> _loadLessonData() async {
    setState(() => _viewState = PlayerViewState.loading);
    try {
      // Fetch the main lesson document
      final lessonDoc = await FirebaseFirestore.instance
          .collection('lessons')
          .doc(widget.lessonId)
          .get();

      if (!lessonDoc.exists) {
        throw Exception('Lesson not found');
      }
      _lessonData = lessonDoc.data();

      // Check if there is H5P content to load (either from a collection or a direct URL)
      if (_lessonData?['h5pUrl'] != null) {
        // H5P content is a direct URL
      } else if (_lessonData?['h5pContentId'] != null) {
        // H5P content is a quiz in the 'h5pcontent' collection
        final h5pDoc = await FirebaseFirestore.instance
            .collection('h5pcontent')
            .doc(_lessonData!['h5pContentId'])
            .get();

        if (h5pDoc.exists) {
          _h5pData = h5pDoc.data();
          _quizQuestions = _h5pData?['questions'] ?? [];
        }
      }

      // Load user progress
      await _loadProgress();

      // Determine the initial view
      if (_isCompleted) {
        setState(() => _viewState = PlayerViewState.completed);
      } else {
        setState(() => _viewState = PlayerViewState.content);
      }
    } catch (e) {
      print('Error loading lesson data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading lesson: $e')),
        );
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _loadProgress() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final progressRef = FirebaseFirestore.instance
          .collection('userProgress')
          .doc('${user.uid}_${widget.lessonId}');
      final progressDoc = await progressRef.get();

      if (progressDoc.exists) {
        _isCompleted = progressDoc.data()?['isCompleted'] ?? false;
      } else {
        // This is the first time the user is accessing this lesson.
        // Create the initial progress and schedule the first review.
        await _createInitialProgressAndReview(progressRef, user.uid);
        _isCompleted = false;
      }
    }
  }

  Future<void> _createInitialProgressAndReview(
      DocumentReference progressRef, String userId) async {
    final now = DateTime.now();
    final reviewDate = now.add(const Duration(days: 3));

    // Create the review document
    final reviewRef = FirebaseFirestore.instance.collection('reviews').doc();
    final reviewData = {
      'userId': userId,
      'lessonId': widget.lessonId,
      'reviewDate': Timestamp.fromDate(reviewDate),
      'lastReviewed': null,
      'nextReviewDate': Timestamp.fromDate(reviewDate),
      'easeFactor': 2.5, // Starting ease factor
      'repetitions': 0,
      'interval': 1, // Start with a 1-day interval, to be updated on first review
      'status': 'scheduled',
    };

    // Create the progress document
    final progressData = {
      'userId': userId,
      'lessonId': widget.lessonId,
      'isCompleted': false,
      'lastAccessed': FieldValue.serverTimestamp(),
      'startedAt': FieldValue.serverTimestamp(),
    };

    // Use a batch write to ensure both documents are created atomically
    final batch = FirebaseFirestore.instance.batch();
    batch.set(progressRef, progressData);
    batch.set(reviewRef, reviewData);
    await batch.commit();
  }

  void _onContentFinished() {
    if (_lessonData?['h5pUrl'] != null) {
      setState(() => _viewState = PlayerViewState.h5pUrl);
    } else if (_quizQuestions.isNotEmpty) {
      setState(() => _viewState = PlayerViewState.quiz);
    } else {
      _markAsCompleted();
    }
  }

  void _onQuizFinished() {
    _markAsCompleted();
  }

  void _markAsCompleted() {
    if (widget.isReviewMode) {
      _showRecallRatingDialog();
    } else {
      setState(() {
        _viewState = PlayerViewState.completed;
        _isCompleted = true;
      });
      _analyticsService.logStudyActivity(
        lessonsCompleted: 1,
        studyTimeInSeconds: _stopwatch.elapsed.inSeconds,
      );
      _saveProgress(completed: true);
      _saveStudySession();
    }
  }

  Future<void> _showRecallRatingDialog() async {
    int? recallRating;

    // Simple logic for auto-rating based on quiz score
    if (_quizQuestions.isNotEmpty) {
      int correctAnswers = 0;
      for (int i = 0; i < _quizQuestions.length; i++) {
        final question = _quizQuestions[i];
        final correctAnswer = question['answer'] ?? question['correct'];
        if (_userAnswers[i] == correctAnswer) {
          correctAnswers++;
        }
      }
      double score = correctAnswers / _quizQuestions.length;
      if (score > 0.8) recallRating = 5; // Easy
      else if (score > 0.5) recallRating = 4; // Good
      else recallRating = 2; // Hard
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Rate Your Recall'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('How well did you remember this content?'),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildRatingButton(context, setDialogState, 'Hard', 2, recallRating),
                      _buildRatingButton(context, setDialogState, 'Good', 4, recallRating),
                      _buildRatingButton(context, setDialogState, 'Easy', 5, recallRating),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: recallRating == null
                      ? null
                      : () {
                          Navigator.of(context).pop();
                          _submitReview(recallRating);
                        },
                  child: const Text('Submit'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildRatingButton(BuildContext context, StateSetter setDialogState, String label, int value, int? currentRating) {
    final isSelected = currentRating == value;
    return ElevatedButton(
      onPressed: () => setDialogState(() => currentRating = value),
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? AppColors.primary : Colors.grey[200],
        foregroundColor: isSelected ? Colors.white : AppColors.textDark,
      ),
      child: Text(label),
    );
  }

  Future<void> _submitReview(int rating) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || widget.reviewId == null) return;
    
    // Log analytics event for review completion
    _analyticsService.logStudyActivity(
      reviewsCompleted: 1,
      studyTimeInSeconds: _stopwatch.elapsed.inSeconds,
      score: rating.toDouble(),
    );

    // This should point to your deployed backend URL
    const backendUrl = 'http://localhost:8000'; 
    final url = Uri.parse('$backendUrl/review/sm2');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': user.uid,
          'item_id': widget.reviewId,
          'recall_rating': rating,
        }),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Review submitted! The next one is scheduled.')),
        );
      } else {
        throw Exception('Failed to submit review: ${response.body}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      // Navigate back regardless of success or failure
      Navigator.of(context).pop();
    }
  }

  Future<void> _saveProgress({required bool completed}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance
          .collection('userProgress')
          .doc('${user.uid}_${widget.lessonId}')
          .set({
        'userId': user.uid,
        'lessonId': widget.lessonId,
        'isCompleted': completed,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  Future<void> _saveStudySession() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final duration = DateTime.now().difference(_sessionStartTime);
      await FirebaseFirestore.instance.collection('studySessions').add({
        'userId': user.uid,
        'lessonId': widget.lessonId,
        'lessonTitle': widget.lessonTitle,
        'duration': duration.inSeconds,
        'completed': true,
        'completedAt': FieldValue.serverTimestamp(),
        'sessionDate': DateFormat('yyyy-MM-dd').format(DateTime.now()),
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.lessonTitle),
        backgroundColor: Colors.white,
        elevation: 1,
      ),
      body: _buildBody(),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildBody() {
    switch (_viewState) {
      case PlayerViewState.loading:
        return const Center(child: CircularProgressIndicator());
      case PlayerViewState.content:
        return _buildContentView();
      case PlayerViewState.quiz:
        return _buildQuizView();
      case PlayerViewState.h5pUrl:
        return _buildH5pView();
      case PlayerViewState.completed:
        return _buildCompletedView();
    }
  }

  Widget _buildContentView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _lessonData?['title'] ?? widget.lessonTitle,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Text(
            _lessonData?['content'] ?? 'No content available.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.6),
          ),
        ],
      ),
    );
  }

  Widget _buildQuizView() {
    if (_quizQuestions.isEmpty) {
      return const Center(child: Text('No quiz questions found.'));
    }
    final question = _quizQuestions[_currentQuestionIndex];
    if (question is! Map) {
      return const Center(child: Text('Invalid question format.'));
    }
    final questionType = question['type'] as String? ?? '';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Question ${_currentQuestionIndex + 1} of ${_quizQuestions.length}',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Text(
            question['question'] ?? 'No question text.',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 32),
          if (questionType == 'multiple_choice')
            _buildMultipleChoiceOptions((question['options'] as List<dynamic>?) ?? []),
          if (questionType == 'true_false')
            _buildTrueFalseOptions(),
          // Add other question types here
        ],
      ),
    );
  }

  Widget _buildMultipleChoiceOptions(List<dynamic> options) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: options.length,
      itemBuilder: (context, index) {
        final isSelected = _userAnswers[_currentQuestionIndex] == index;
        return Card(
          color: isSelected ? Colors.blue.withOpacity(0.1) : Colors.white,
          child: ListTile(
            title: Text(options[index]?.toString() ?? 'Invalid Option'),
            onTap: () {
              setState(() {
                _userAnswers[_currentQuestionIndex] = index;
              });
            },
          ),
        );
      },
    );
  }

   Widget _buildTrueFalseOptions() {
    return Column(
      children: [
        Card(
           color: _userAnswers[_currentQuestionIndex] == true ? Colors.blue.withOpacity(0.1) : Colors.white,
          child: ListTile(
            title: const Text('True'),
            onTap: () {
               setState(() {
                _userAnswers[_currentQuestionIndex] = true;
              });
            },
          ),
        ),
        Card(
           color: _userAnswers[_currentQuestionIndex] == false ? Colors.blue.withOpacity(0.1) : Colors.white,
          child: ListTile(
            title: const Text('False'),
            onTap: () {
               setState(() {
                _userAnswers[_currentQuestionIndex] = false;
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildH5pView() {
    final url = _lessonData?['h5pUrl'];
    if (url == null || url.isEmpty) {
      return const Center(child: Text('H5P content URL is missing.'));
    }
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(Uri.parse(url));

    return WebViewWidget(controller: controller);
  }

  Widget _buildCompletedView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 80),
          const SizedBox(height: 24),
          const Text(
            'Lesson Completed!',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Back to Lessons'),
          ),
        ],
      ),
    );
  }
  
  Widget? _buildBottomBar() {
    if (_viewState == PlayerViewState.content) {
       return Padding(
         padding: const EdgeInsets.all(16.0),
         child: ElevatedButton(
           onPressed: _onContentFinished,
           child: Text((_quizQuestions.isNotEmpty || _lessonData?['h5pUrl'] != null) ? 'Continue to Quiz' : 'Mark as Completed'),
         ),
       );
    }
     if (_viewState == PlayerViewState.quiz) {
       return Padding(
         padding: const EdgeInsets.all(16.0),
         child: ElevatedButton(
           onPressed: () {
             // Basic validation: move to next question or finish
             if (_currentQuestionIndex < _quizQuestions.length - 1) {
                setState(() => _currentQuestionIndex++);
             } else {
                _onQuizFinished();
             }
           },
           child: Text(_currentQuestionIndex < _quizQuestions.length - 1 ? 'Next Question' : 'Finish Quiz'),
         ),
       );
    }
    return null;
  }
}

class H5PJsonViewerScreen extends StatelessWidget {
  final String title;
  final dynamic jsonContent;
  const H5PJsonViewerScreen({required this.title, required this.jsonContent, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    String prettyJson;
    try {
      prettyJson = const JsonEncoder.withIndent('  ').convert(jsonContent);
    } catch (e) {
      prettyJson = jsonContent.toString();
    }
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: SelectableText(prettyJson, style: TextStyle(fontFamily: 'monospace', fontSize: 14)),
        ),
      ),
    );
  }
} 