import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../../utils/app_theme.dart';
import 'h5p_content_crud_screen.dart';
import 'lesson_list_screen.dart';
import 'modules_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  _AdminDashboardScreenState createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  Future<Map<String, dynamic>>? _adminDataFuture;

  @override
  void initState() {
    super.initState();
    _adminDataFuture = _fetchAdminData();
  }

  Future<bool> _isAdmin() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    final doc =
        await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    return doc.data()?['isAdmin'] == true;
  }

  Future<Map<String, dynamic>> _fetchAdminData() async {
    final isAdmin = await _isAdmin();
    if (!isAdmin) {
      throw Exception('Access Denied');
    }

    // Fetch all data in parallel
    final results = await Future.wait([
      FirebaseFirestore.instance.collection('users').get(),
      FirebaseFirestore.instance.collection('lessons').get(),
      FirebaseFirestore.instance.collection('modules').get(),
      FirebaseFirestore.instance.collection('h5pContent').get(),
      FirebaseFirestore.instance.collection('userProgress').get(),
      FirebaseFirestore.instance
          .collection('users')
          .orderBy('registrationDate', descending: true)
          .limit(5)
          .get(),
    ]);

    final users = results[0] as QuerySnapshot;
    final lessons = results[1] as QuerySnapshot;
    final modules = results[2] as QuerySnapshot;
    final content = results[3] as QuerySnapshot;
    final userProgress = results[4] as QuerySnapshot;
    final recentSignups = results[5] as QuerySnapshot;

    // Process user signups chart data
    final Map<String, int> signupsPerDay = {};
    for (final doc in users.docs) {
      final data = doc.data() as Map<String, dynamic>?;
      final ts = data?['registrationDate'] as Timestamp?;
      if (ts != null) {
        final day = DateFormat('yyyy-MM-dd').format(ts.toDate());
        signupsPerDay[day] = (signupsPerDay[day] ?? 0) + 1;
      }
    }

    // Process lesson completion chart data
    int completed = 0, inProgress = 0;
    for (final doc in userProgress.docs) {
      final data = doc.data() as Map<String, dynamic>?;
      if (data?['isCompleted'] == true) {
        completed++;
      } else {
        inProgress++;
      }
    }

    return {
      'userCount': users.size,
      'lessonCount': lessons.size,
      'moduleCount': modules.size,
      'contentCount': content.size,
      'signupsPerDay': signupsPerDay,
      'lessonCompletion': {'completed': completed, 'inProgress': inProgress},
      'recentSignups': recentSignups.docs,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: FutureBuilder<Map<String, dynamic>>(
        future: _adminDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
                child: Text('Error: ${snapshot.error}',
                    style: const TextStyle(color: Colors.red)));
          }
          if (!snapshot.hasData) {
            return const Center(child: Text('No data available.'));
          }

          final data = snapshot.data!;
          return _buildDashboard(context, data);
        },
      ),
    );
  }

  Widget _buildDashboard(BuildContext context, Map<String, dynamic> data) {
    final signupsPerDay = data['signupsPerDay'] as Map<String, int>;
    final lessonCompletion =
        data['lessonCompletion'] as Map<String, int>;
    final recentSignups = data['recentSignups'] as List<QueryDocumentSnapshot>;

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          expandedHeight: 120.0,
          pinned: true,
          flexibleSpace: FlexibleSpaceBar(
            title: const Text('Admin Dashboard',
                style: TextStyle(fontWeight: FontWeight.bold)),
            background: Container(color: AppColors.primary),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(16.0),
          sliver: SliverGrid.count(
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1.5,
            children: [
              _MetricCard(
                  label: 'Total Users',
                  value: data['userCount'].toString(),
                  icon: Icons.people_outline,
                  color: Colors.blue),
              _MetricCard(
                  label: 'Total Lessons',
                  value: data['lessonCount'].toString(),
                  icon: Icons.menu_book_outlined,
                  color: Colors.green),
              _MetricCard(
                  label: 'Total Modules',
                  value: data['moduleCount'].toString(),
                  icon: Icons.view_module_outlined,
                  color: Colors.orange),
              _MetricCard(
                  label: 'H5P Content',
                  value: data['contentCount'].toString(),
                  icon: Icons.widgets_outlined,
                  color: Colors.purple),
            ],
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Quick Actions', style: AppTheme.headlineStyle),
                const SizedBox(height: 16),
                _buildQuickActions(context),
                const SizedBox(height: 24),
                _buildChartCard(
                  title: 'User Signups Over Time',
                  chart: _UserSignupsChart(signupsPerDay: signupsPerDay),
                ),
                const SizedBox(height: 24),
                _buildChartCard(
                  title: 'Lesson Completion Rate',
                  chart: _LessonCompletionChart(completionData: lessonCompletion),
                ),
                const SizedBox(height: 24),
                _buildRecentSignups(recentSignups),
                 const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _ActionChip(
          icon: Icons.widgets_outlined,
          label: 'H5P Content',
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => H5PContentCrudScreen())),
        ),
        _ActionChip(
          icon: Icons.menu_book_outlined,
          label: 'Lessons',
          onTap: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => LessonListScreen())),
        ),
        _ActionChip(
          icon: Icons.view_module_outlined,
          label: 'Modules',
          onTap: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => ModulesScreen())),
        ),
      ],
    );
  }
  
  Widget _buildChartCard({required String title, required Widget chart}) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppTheme.subtitleStyle),
            const SizedBox(height: 24),
            SizedBox(height: 200, child: chart),
          ],
        ),
      ),
    );
  }
  
  Widget _buildRecentSignups(List<QueryDocumentSnapshot> signups) {
     return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Recent Signups', style: AppTheme.subtitleStyle),
            const SizedBox(height: 8),
            ...signups.map((doc) {
              final data = doc.data() as Map<String, dynamic>?;
              final name = data?['fullname'] ?? 'N/A';
              final email = data?['email'] ?? 'No email';
              final date = (data?['registrationDate'] as Timestamp?)?.toDate();
              final dateString = date != null ? DateFormat.yMMMd().format(date) : 'N/A';

              return ListTile(
                leading: const CircleAvatar(
                  backgroundColor: AppColors.primary,
                  child: Icon(Icons.person, color: Colors.white),
                ),
                title: Text(name),
                subtitle: Text(email),
                trailing: Text(dateString, style: AppTheme.bodyTextStyle.copyWith(color: AppColors.textFaded)),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [color.withOpacity(0.7), color],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 32, color: Colors.white),
            const Spacer(),
            Text(value,
                style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
            Text(label,
                style: const TextStyle(fontSize: 16, color: Colors.white70)),
          ],
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionChip({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            children: [
              Icon(icon, color: AppColors.primary, size: 28),
              const SizedBox(height: 8),
              Text(label, style: AppTheme.bodyTextStyle),
            ],
          ),
        ),
      ),
    );
  }
}


class _UserSignupsChart extends StatelessWidget {
  final Map<String, int> signupsPerDay;
  const _UserSignupsChart({required this.signupsPerDay});

  @override
  Widget build(BuildContext context) {
    final sortedDays = signupsPerDay.keys.toList()..sort();
    if (sortedDays.isEmpty) {
      return const Center(child: Text("No user signup data yet."));
    }
    
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        barTouchData: BarTouchData(enabled: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
              sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 28,
            interval: 1,
            getTitlesWidget: (value, meta) => Text(value.toInt().toString(), style: const TextStyle(fontSize: 10)),
          )),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < sortedDays.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(DateFormat.Md().format(DateTime.parse(sortedDays[index])), style: const TextStyle(fontSize: 10)),
                  );
                }
                return const Text('');
              },
            ),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 1,
          getDrawingHorizontalLine: (value) => const FlLine(color: AppColors.textFaded, strokeWidth: 0.5),
        ),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(sortedDays.length, (index) {
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: (signupsPerDay[sortedDays[index]] ?? 0).toDouble(),
                color: AppColors.primary,
                width: 16,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(4),
                ),
              )
            ],
          );
        }),
      ),
    );
  }
}

class _LessonCompletionChart extends StatelessWidget {
  final Map<String, int> completionData;
  const _LessonCompletionChart({required this.completionData});

  @override
  Widget build(BuildContext context) {
    final completed = completionData['completed']?.toDouble() ?? 0;
    final inProgress = completionData['inProgress']?.toDouble() ?? 0;
    final total = completed + inProgress;

    if (total == 0) {
      return const Center(child: Text("No lesson progress data yet."));
    }

    return PieChart(
      PieChartData(
        sectionsSpace: 4,
        centerSpaceRadius: 40,
        sections: [
          PieChartSectionData(
            value: completed,
            color: Colors.green.shade400,
            title: '${(completed / total * 100).toStringAsFixed(0)}%',
            radius: 50,
            titleStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
          PieChartSectionData(
            value: inProgress,
            color: Colors.orange.shade400,
            title: '${(inProgress / total * 100).toStringAsFixed(0)}%',
            radius: 50,
            titleStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ],
      ),
    );
  }
} 