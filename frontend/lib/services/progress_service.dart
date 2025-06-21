import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Service for calculating and managing user learning progress
class ProgressService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Calculate user's overall learning progress
  static Future<Map<String, dynamic>> calculateUserProgress(String userId) async {
    try {
      // Get user progress data
      final progressSnapshot = await _firestore
          .collection('userProgress')
          .where('userId', isEqualTo: userId)
          .get();

      // Get study sessions
      final sessionsSnapshot = await _firestore
          .collection('studySessions')
          .where('userId', isEqualTo: userId)
          .get();

      // Get all lessons for total count
      final lessonsSnapshot = await _firestore.collection('lessons').get();

      // Calculate progress metrics
      final progressData = _calculateProgressMetrics(
        progressSnapshot.docs,
        sessionsSnapshot.docs,
        lessonsSnapshot.docs,
      );

      // Get streak information
      final streakData = await _calculateStreak(userId);

      // Get recent activity
      final recentActivity = await _getRecentActivity(userId);

      return {
        ...progressData,
        ...streakData,
        'recentActivity': recentActivity,
      };
    } catch (e) {
      print('Error calculating user progress: $e');
      return _getDefaultProgress();
    }
  }

  /// Calculate progress metrics from user data
  static Map<String, dynamic> _calculateProgressMetrics(
    List<QueryDocumentSnapshot> progressDocs,
    List<QueryDocumentSnapshot> sessionDocs,
    List<QueryDocumentSnapshot> lessonDocs,
  ) {
    final totalLessons = lessonDocs.length;
    final completedLessons = progressDocs.where((doc) {
      final data = doc.data() as Map<String, dynamic>?;
      return data != null && data['isCompleted'] == true;
    }).length;
    final inProgressLessons = progressDocs.where((doc) {
      final data = doc.data() as Map<String, dynamic>?;
      return data != null && data['isCompleted'] == false && (data['currentStep'] ?? 0) > 0;
    }).length;

    // Calculate total study time
    int totalStudyTime = 0;
    for (final doc in sessionDocs) {
      final data = doc.data() as Map<String, dynamic>?;
      totalStudyTime += ((data?['duration'] ?? 0) as num).toInt();
    }

    // Calculate average session duration
    final avgSessionDuration = sessionDocs.isNotEmpty 
        ? totalStudyTime / sessionDocs.length 
        : 0;

    // Calculate completion rate
    final completionRate = totalLessons > 0 ? completedLessons / totalLessons : 0;

    // Calculate average review score
    double totalReviewScore = 0;
    int reviewCount = 0;
    for (final doc in progressDocs) {
      final data = doc.data() as Map<String, dynamic>?;
      final easinessFactor = data?['easinessFactor'];
      if (easinessFactor != null) {
        totalReviewScore += easinessFactor;
        reviewCount++;
      }
    }
    final avgReviewScore = reviewCount > 0 ? totalReviewScore / reviewCount : 2.5;

    return {
      'totalLessons': totalLessons,
      'completedLessons': completedLessons,
      'inProgressLessons': inProgressLessons,
      'notStartedLessons': totalLessons - completedLessons - inProgressLessons,
      'completionRate': completionRate,
      'totalStudyTime': totalStudyTime,
      'avgSessionDuration': avgSessionDuration,
      'totalSessions': sessionDocs.length,
      'avgReviewScore': avgReviewScore,
      'totalReviews': reviewCount,
    };
  }

  /// Calculate user's learning streak
  static Future<Map<String, dynamic>> _calculateStreak(String userId) async {
    try {
      // Get study sessions for the last 30 days
      final now = DateTime.now();
      final thirtyDaysAgo = now.subtract(Duration(days: 30));
      
      final sessionsSnapshot = await _firestore
          .collection('studySessions')
          .where('userId', isEqualTo: userId)
          .where('date', isGreaterThanOrEqualTo: thirtyDaysAgo)
          .orderBy('date', descending: true)
          .get();

      // Group sessions by date
      final sessionsByDate = <String, List<QueryDocumentSnapshot>>{};
      for (final doc in sessionsSnapshot.docs) {
        final date = (doc.data()['date'] as Timestamp).toDate();
        final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        sessionsByDate.putIfAbsent(dateStr, () => []).add(doc);
      }

      // Calculate current streak
      int currentStreak = 0;
      int longestStreak = 0;
      int tempStreak = 0;

      // Check consecutive days from today backwards
      for (int i = 0; i < 30; i++) {
        final checkDate = now.subtract(Duration(days: i));
        final dateStr = '${checkDate.year}-${checkDate.month.toString().padLeft(2, '0')}-${checkDate.day.toString().padLeft(2, '0')}';
        
        if (sessionsByDate.containsKey(dateStr)) {
          tempStreak++;
          if (i == 0) { // Today
            currentStreak = tempStreak;
          }
        } else {
          if (tempStreak > longestStreak) {
            longestStreak = tempStreak;
          }
          tempStreak = 0;
        }
      }

      // Update longest streak if current streak is longer
      if (tempStreak > longestStreak) {
        longestStreak = tempStreak;
      }

      return {
        'currentStreak': currentStreak,
        'longestStreak': longestStreak,
        'studyDaysThisMonth': sessionsByDate.length,
      };
    } catch (e) {
      print('Error calculating streak: $e');
      return {
        'currentStreak': 0,
        'longestStreak': 0,
        'studyDaysThisMonth': 0,
      };
    }
  }

  /// Get recent learning activity
  static Future<List<Map<String, dynamic>>> _getRecentActivity(String userId) async {
    try {
      // Get recent study sessions
      final sessionsSnapshot = await _firestore
          .collection('studySessions')
          .where('userId', isEqualTo: userId)
          .orderBy('date', descending: true)
          .limit(10)
          .get();

      // Get recent lesson completions
      final progressSnapshot = await _firestore
          .collection('userProgress')
          .where('userId', isEqualTo: userId)
          .where('isCompleted', isEqualTo: true)
          .orderBy('lastUpdated', descending: true)
          .limit(10)
          .get();

      final activities = <Map<String, dynamic>>[];

      // Add study sessions
      for (final doc in sessionsSnapshot.docs) {
        final data = doc.data();
        activities.add({
          'type': 'study_session',
          'date': (data['date'] as Timestamp).toDate(),
          'duration': data['duration'] ?? 0,
          'topic': data['topic'] ?? 'General',
        });
      }

      // Add lesson completions
      for (final doc in progressSnapshot.docs) {
        final data = doc.data();
        activities.add({
          'type': 'lesson_completed',
          'date': (data['lastUpdated'] as Timestamp).toDate(),
          'lessonId': data['lessonId'],
          'lessonTitle': data['lessonTitle'] ?? 'Unknown Lesson',
        });
      }

      // Sort by date and take the most recent 10
      activities.sort((a, b) => b['date'].compareTo(a['date']));
      return activities.take(10).toList();
    } catch (e) {
      print('Error getting recent activity: $e');
      return [];
    }
  }

  /// Get lesson-specific progress
  static Future<Map<String, dynamic>> getLessonProgress(String userId, String lessonId) async {
    try {
      final progressDoc = await _firestore
          .collection('userProgress')
          .where('userId', isEqualTo: userId)
          .where('lessonId', isEqualTo: lessonId)
          .get();

      if (progressDoc.docs.isEmpty) {
        return {
          'currentStep': 0,
          'isCompleted': false,
          'progress': 0.0,
          'lastUpdated': null,
          'timeSpent': 0,
        };
      }

      final data = progressDoc.docs.first.data();
      final currentStep = data['currentStep'] ?? 0;
      final isCompleted = data['isCompleted'] ?? false;
      final estimatedSteps = data['estimatedSteps'] ?? 1;
      final timeSpent = data['timeSpent'] ?? 0;

      double progress = 0.0;
      if (isCompleted) {
        progress = 1.0;
      } else if (estimatedSteps > 0) {
        progress = currentStep / estimatedSteps;
      }

      return {
        'currentStep': currentStep,
        'isCompleted': isCompleted,
        'progress': progress,
        'lastUpdated': data['lastUpdated'] != null 
            ? (data['lastUpdated'] as Timestamp).toDate() 
            : null,
        'timeSpent': timeSpent,
      };
    } catch (e) {
      print('Error getting lesson progress: $e');
      return {
        'currentStep': 0,
        'isCompleted': false,
        'progress': 0.0,
        'lastUpdated': null,
        'timeSpent': 0,
      };
    }
  }

  /// Update lesson progress
  static Future<void> updateLessonProgress(
    String userId,
    String lessonId,
    int currentStep,
    bool isCompleted,
    int timeSpent,
  ) async {
    try {
      final progressRef = _firestore
          .collection('userProgress')
          .doc('${userId}_${lessonId}');

      await progressRef.set({
        'userId': userId,
        'lessonId': lessonId,
        'currentStep': currentStep,
        'isCompleted': isCompleted,
        'timeSpent': FieldValue.increment(timeSpent),
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Record study session
      await _firestore.collection('studySessions').add({
        'userId': userId,
        'lessonId': lessonId,
        'duration': timeSpent,
        'date': FieldValue.serverTimestamp(),
        'type': 'lesson_progress',
      });
    } catch (e) {
      print('Error updating lesson progress: $e');
    }
  }

  /// Get weekly study data for charts
  static Future<List<double>> getWeeklyStudyData(String userId) async {
    try {
      final now = DateTime.now();
      final weekStart = now.subtract(Duration(days: now.weekday - 1));
      final weekData = List.filled(7, 0.0);

      final sessionsSnapshot = await _firestore
          .collection('studySessions')
          .where('userId', isEqualTo: userId)
          .where('date', isGreaterThanOrEqualTo: weekStart)
          .get();

      for (final doc in sessionsSnapshot.docs) {
        final date = (doc.data()['date'] as Timestamp).toDate();
        final weekday = date.weekday - 1; // 0 = Monday, 6 = Sunday
        final duration = doc.data()['duration'] ?? 0;
        weekData[weekday] += duration / 60.0; // Convert to hours
      }

      return weekData;
    } catch (e) {
      print('Error getting weekly study data: $e');
      return List.filled(7, 0.0);
    }
  }

  /// Get default progress data for error cases
  static Map<String, dynamic> _getDefaultProgress() {
    return {
      'totalLessons': 0,
      'completedLessons': 0,
      'inProgressLessons': 0,
      'notStartedLessons': 0,
      'completionRate': 0.0,
      'totalStudyTime': 0,
      'avgSessionDuration': 0,
      'totalSessions': 0,
      'avgReviewScore': 2.5,
      'totalReviews': 0,
      'currentStreak': 0,
      'longestStreak': 0,
      'studyDaysThisMonth': 0,
      'recentActivity': [],
    };
  }

  /// Get user's learning statistics
  static Future<Map<String, dynamic>> getUserStats(String userId) async {
    try {
      final progress = await calculateUserProgress(userId);
      final weeklyData = await getWeeklyStudyData(userId);

      return {
        ...progress,
        'weeklyStudyData': weeklyData,
        'totalStudyHours': (progress['totalStudyTime'] ?? 0) / 60,
        'avgDailyStudyTime': progress['studyDaysThisMonth'] > 0 
            ? (progress['totalStudyTime'] ?? 0) / (progress['studyDaysThisMonth'] * 60)
            : 0,
      };
    } catch (e) {
      print('Error getting user stats: $e');
      return _getDefaultProgress();
    }
  }
} 