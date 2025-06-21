import 'package:cogni_loop/utils/app_theme.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_svg/flutter_svg.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _userName;

  @override
  void initState() {
    super.initState();
    _fetchUserName();
  }

  Future<void> _fetchUserName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (userDoc.exists && userDoc.data() != null) {
        final data = userDoc.data()!;
        final firstName = (data['fullName'] as String? ?? '').split(' ').first;
        setState(() {
          _userName = firstName;
        });
      }
    }
    if (_userName == null) {
      setState(() {
        _userName = "User";
      });
    }
  }

  String getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good Morning';
    } else if (hour < 17) {
      return 'Good Afternoon';
    } else {
      return 'Good Evening';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 32),
              _buildTodaysSessionCard(),
              const SizedBox(height: 32),
              _buildSectionTitle('Continue Learning'),
              const SizedBox(height: 16),
              _buildContinueLearningCard(),
              const SizedBox(height: 16),
              _buildInfoCards(),
              const SizedBox(height: 32),
              _buildSectionTitle('Study Time'),
              const SizedBox(height: 16),
              _buildStudyTimeChart(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        SvgPicture.asset(
          'assets/images/logo.svg',
          height: 32,
          colorFilter:
              const ColorFilter.mode(AppColors.primary, BlendMode.srcIn),
        ),
        const SizedBox(width: 12),
        const Text(
          'CogniLoop',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildTodaysSessionCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _userName != null ? '${getGreeting()}, $_userName' : getGreeting(),
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "You have 3 lessons scheduled for spaced repetition.",
                      style: TextStyle(
                        fontSize: 15,
                        color: AppColors.primary.withOpacity(0.8),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Image.asset('assets/images/todays_session.png', height: 80),
            ],
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
            ),
            child:
                const Text('Start Session', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: AppColors.textDark,
      ),
    );
  }

  Widget _buildContinueLearningCard() {
    return _buildCard(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.psychology_outlined,
                color: AppColors.primary, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Cognitive Load Theory',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Expanded(
                      child: LinearProgressIndicator(
                        value: 0.6,
                        backgroundColor: AppColors.lightGrey,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(AppColors.primary),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('lesson 2 - in progress',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textLight)),
                  ],
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCards() {
    return Row(
      children: [
        Expanded(
          child: _buildCard(
            color: AppColors.primary.withOpacity(0.08),
            child: _buildInfoItem(
                icon: Icons.calendar_today_outlined,
                title: 'Next review',
                value: 'in 6 hours'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildCard(
            color: AppColors.primary.withOpacity(0.08),
            child: _buildInfoItem(
                icon: Icons.timer_outlined,
                title: "Today's study time",
                value: '1h 30m'),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoItem(
      {required IconData icon, required String title, required String value}) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 24),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textDark.withOpacity(0.8))),
            const SizedBox(height: 4),
            Text(value,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark)),
          ],
        ),
      ],
    );
  }

  Widget _buildStudyTimeChart() {
    return AspectRatio(
      aspectRatio: 1.7,
      child: _buildCard(
        child: Padding(
          padding: const EdgeInsets.only(top: 16.0),
          child: LineChart(
            LineChartData(
              gridData: FlGridData(show: false),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      switch (value.toInt()) {
                        case 0:
                          return Text('0h',
                              style: TextStyle(
                                  color: AppColors.textLight, fontSize: 12));
                        case 1:
                          return Text('1h',
                              style: TextStyle(
                                  color: AppColors.textLight, fontSize: 12));
                        case 2:
                          return Text('2h',
                              style: TextStyle(
                                  color: AppColors.textLight, fontSize: 12));
                      }
                      return const Text('');
                    },
                    reservedSize: 30,
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      const style = TextStyle(
                          color: AppColors.textLight,
                          fontWeight: FontWeight.bold,
                          fontSize: 12);
                      Widget text;
                      switch (value.toInt()) {
                        case 0:
                          text = const Text('S', style: style);
                          break;
                        case 1:
                          text = const Text('M', style: style);
                          break;
                        case 2:
                          text = const Text('T', style: style);
                          break;
                        case 3:
                          text = const Text('W', style: style);
                          break;
                        case 4:
                          text = const Text('T', style: style);
                          break;
                        case 5:
                          text = const Text('F', style: style);
                          break;
                        case 6:
                          text = const Text('S', style: style);
                          break;
                        default:
                          text = const Text('', style: style);
                          break;
                      }
                      return SideTitleWidget(axisSide: meta.axisSide, child: text);
                    },
                    reservedSize: 30,
                  ),
                ),
                rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: const [
                    FlSpot(0, 0.2),
                    FlSpot(1, 1.2),
                    FlSpot(2, 0.8),
                    FlSpot(3, 1.5),
                    FlSpot(4, 1.8),
                    FlSpot(5, 1.0),
                    FlSpot(6, 1.4),
                  ],
                  isCurved: true,
                  color: AppColors.primary,
                  barWidth: 4,
                  isStrokeCapRound: true,
                  dotData: FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary.withOpacity(0.3),
                        AppColors.primary.withOpacity(0.0),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard({Widget? child, Color? color}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color ?? Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}