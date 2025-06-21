import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class AnalyticsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> logStudyActivity({
    int lessonsCompleted = 0,
    int reviewsCompleted = 0,
    int studyTimeInSeconds = 0,
    double? score,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final userId = user.uid;
    final docRef = _firestore.collection('analytics').doc(userId);
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);

      if (!snapshot.exists) {
        transaction.set(docRef, {
          'userId': userId,
          'dailyStats': {
            'date': today,
            'lessonsCompleted': lessonsCompleted,
            'reviewsCompleted': reviewsCompleted,
            'studyTime': studyTimeInSeconds,
            'averageScore': score ?? 0,
            'scoreCount': score != null ? 1 : 0,
          },
          'weeklyStats': {},
          'monthlyStats': {},
        });
        return;
      }

      final data = snapshot.data() as Map<String, dynamic>;
      final dailyStats = Map<String, dynamic>.from(data['dailyStats'] as Map? ?? {});

      if (dailyStats['date'] != today) {
        // TODO: Implement weekly/monthly roll-up logic here
        dailyStats['date'] = today;
        dailyStats['lessonsCompleted'] = 0;
        dailyStats['reviewsCompleted'] = 0;
        dailyStats['studyTime'] = 0;
        dailyStats['averageScore'] = 0.0;
        dailyStats['scoreCount'] = 0;
      }

      dailyStats['lessonsCompleted'] = (dailyStats['lessonsCompleted'] ?? 0) + lessonsCompleted;
      dailyStats['reviewsCompleted'] = (dailyStats['reviewsCompleted'] ?? 0) + reviewsCompleted;
      dailyStats['studyTime'] = (dailyStats['studyTime'] ?? 0) + studyTimeInSeconds;

      if (score != null) {
        final currentTotalScore = (dailyStats['averageScore'] ?? 0.0) * (dailyStats['scoreCount'] ?? 0);
        final newScoreCount = (dailyStats['scoreCount'] ?? 0) + 1;
        dailyStats['averageScore'] = (currentTotalScore + score) / newScoreCount;
        dailyStats['scoreCount'] = newScoreCount;
      }

      transaction.update(docRef, {
        'dailyStats': dailyStats,
        'userId': userId,
      });
    });
  }
} 