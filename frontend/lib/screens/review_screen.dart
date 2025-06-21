// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cogni_loop/utils/app_theme.dart';
import 'package:intl/intl.dart';
import 'lesson_player_screen.dart'; // We will navigate to the lesson player for the review

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _dueReviews = [];
  List<Map<String, dynamic>> _reviewHistory = [];

  @override
  void initState() {
    super.initState();
    _fetchReviewData();
  }

  Future<void> _fetchReviewData() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not logged in');

      final now = Timestamp.now();
      final reviewSnapshot = await FirebaseFirestore.instance
          .collection('reviews')
          .where('userId', isEqualTo: user.uid)
          .orderBy('nextReview')
          .get();

      final due = <Map<String, dynamic>>[];
      final history = <Map<String, dynamic>>[];

      for (final doc in reviewSnapshot.docs) {
        final data = doc.data();
        data['id'] = doc.id;
        final nextReview = data['nextReview'] as Timestamp?;
        
        // Fetch lesson title
        final lessonId = data['lessonId'] as String?;
        if (lessonId != null && lessonId.isNotEmpty) {
           final lessonDoc = await FirebaseFirestore.instance.collection('lessons').doc(lessonId).get();
           if(lessonDoc.exists){
             data['lessonTitle'] = lessonDoc.data()?['title'] ?? 'Untitled Lesson';
           }
        }
        
        if (nextReview != null && nextReview.compareTo(now) <= 0) {
          due.add(data);
        } else {
          history.add(data);
        }
      }

      setState(() {
        _dueReviews = due;
        // Sort history to show most recent first
        _reviewHistory = history..sort((a, b) => (b['nextReview'] as Timestamp).compareTo(a['nextReview'] as Timestamp));
      });
    } catch (e) {
      print('Error fetching reviews: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load review data: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _startReviewSession() {
    if (_dueReviews.isNotEmpty) {
      final firstReviewItem = _dueReviews.first;
      final lessonId = firstReviewItem['lessonId'] as String?;
      final lessonTitle = firstReviewItem['lessonTitle'] as String? ?? 'Review';
      
      if (lessonId != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => LessonPlayerScreen(
                lessonId: lessonId,
                lessonTitle: lessonTitle,
                // We'll need to modify LessonPlayerScreen to handle this
                // isReviewMode: true, 
                // reviewId: firstReviewItem['id'],
              ),
            ),
          ).then((_) {
            // When we come back from a review, refresh the data
            _fetchReviewData();
          });
      } else {
         ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This review item is missing a lesson link.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('CogniLoop'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchReviewData,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Review Queue',
                      style: TextStyle(
                          fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const Divider(height: 32),
                    _buildSectionTitle('To Review Today'),
                    const SizedBox(height: 16),
                    _buildDueReviewsList(),
                    const SizedBox(height: 32),
                    _buildSectionTitle('Review History'),
                    const SizedBox(height: 16),
                    _buildReviewHistoryList(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
    );
  }

  Widget _buildDueReviewsList() {
    if (_dueReviews.isEmpty) {
      return const Text('Nothing to review today. Great job!');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ..._dueReviews.map((review) {
          final title = review['lessonTitle'] as String? ?? 'Review Item';
          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text('• $title', style: const TextStyle(fontSize: 16)),
          );
        }).toList(),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _startReviewSession,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: const Text('Start Review Session'),
        ),
      ],
    );
  }

  Widget _buildReviewHistoryList() {
    if (_reviewHistory.isEmpty) {
      return const Text('No past reviews found.');
    }
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _reviewHistory.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = _reviewHistory[index];
        final title = item['lessonTitle'] as String? ?? 'Reviewed Item';
        final nextReview = item['nextReview'] as Timestamp?;
        final formattedDate = nextReview != null
            ? 'Next review on ${DateFormat.yMMMd().format(nextReview.toDate())}'
            : 'Review date not set';

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.lightGrey.withOpacity(0.5),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Icon(Icons.history_toggle_off, color: AppColors.textLight),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(formattedDate, style: const TextStyle(color: AppColors.textLight, fontSize: 12)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
} 