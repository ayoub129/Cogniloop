import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../utils/app_theme.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  late Future<Map<String, dynamic>> _analyticsDataFuture;

  @override
  void initState() {
    super.initState();
    _analyticsDataFuture = _fetchAnalyticsData();
  }

  Future<Map<String, dynamic>> _fetchAnalyticsData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('No authenticated user found');
    }

    final analyticsRef =
        FirebaseFirestore.instance.collection('analytics').doc(user.uid);
    final aggregateDoc = await analyticsRef.get();
    final aggregateData = aggregateDoc.data() ?? {};

    final today = DateTime.now().toUtc();
    final weeklyDataPoints = <FlSpot>[];
    final dayLabels = <String>[];

    for (int i = 6; i >= 0; i--) {
      final day = today.subtract(Duration(days: i));
      final dateString = DateFormat('yyyy-MM-dd').format(day);
      dayLabels.add(DateFormat('E').format(day)); // 'Mon', 'Tue', etc.

      final dailyDoc = await analyticsRef.collection('daily').doc(dateString).get();
      double learningHours = 0;
      if (dailyDoc.exists) {
        final studyTimeSeconds = (dailyDoc.data()?['studyTime'] ?? 0) as int;
        learningHours = studyTimeSeconds / 3600.0;
      }
      weeklyDataPoints.add(FlSpot(6.0 - i, learningHours));
    }

    return {
      'aggregates': aggregateData,
      'weeklyPoints': weeklyDataPoints,
      'dayLabels': dayLabels,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('CogniLoop', style: AppTheme.headlineStyle),
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary, width: 2),
            ),
            child: const Icon(Icons.psychology, color: AppColors.primary, size: 24),
          ),
        ),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _analyticsDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No analytics data available.'));
          }

          final data = snapshot.data!;
          final aggregates = data['aggregates'] as Map<String, dynamic>;
          final weeklyPoints = data['weeklyPoints'] as List<FlSpot>;
          final dayLabels = data['dayLabels'] as List<String>;

          final totalHours = (aggregates['totalStudyTime'] ?? 0) / 3600;
          final lessonsCompleted = aggregates['totalLessonsCompleted'] ?? 0;
          final modulesCompleted = aggregates['totalModulesCompleted'] ?? 0;
          final currentStreak = aggregates['currentStreak'] ?? 0;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Progress', style: AppTheme.headlineStyle),
                const SizedBox(height: 24),
                _buildWeeklyChart(weeklyPoints, dayLabels),
                const SizedBox(height: 32),
                _buildStatsGrid(
                  totalHours,
                  modulesCompleted,
                  lessonsCompleted,
                ),
                const SizedBox(height: 24),
                _buildStreakCard(currentStreak),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildWeeklyChart(List<FlSpot> spots, List<String> dayLabels) {
    return AspectRatio(
      aspectRatio: 1.7,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
          child: LineChart(
            LineChartData(
              gridData: FlGridData(show: false),
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    interval: 1,
                    getTitlesWidget: (value, meta) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          dayLabels[value.toInt()],
                          style: const TextStyle(
                            color: AppColors.textFaded,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: AppColors.primary,
                  barWidth: 4,
                  isStrokeCapRound: true,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    color: AppColors.primary.withOpacity(0.1),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsGrid(
      double totalHours, int modulesCompleted, int lessonsCompleted) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            title: 'Total Hours',
            value: '${totalHours.toStringAsFixed(1)}h',
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _StatCard(
            title: 'Modules completed',
            value: modulesCompleted.toString(),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _StatCard(
            title: 'Lessons completed',
            value: lessonsCompleted.toString(),
          ),
        ),
      ],
    );
  }

  Widget _buildStreakCard(int streak) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Current Streak', style: AppTheme.subtitleStyle),
            Text(
              '$streak days',
              style: AppTheme.titleStyle.copyWith(color: AppColors.primary),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;

  const _StatCard({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTheme.bodyTextStyle.copyWith(color: AppColors.textFaded),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: AppTheme.headlineStyle.copyWith(fontSize: 28),
            ),
          ],
        ),
      ),
    );
  }
}