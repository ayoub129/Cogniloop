import 'package:animated_bottom_navigation_bar/animated_bottom_navigation_bar.dart';
import 'package:cogni_loop/utils/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'home_screen.dart';
import 'lesson_list_screen.dart';
import 'modules_screen.dart';
import 'lesson_crud_screen.dart';
import 'module_crud_screen.dart';
import 'review_screen.dart';
import 'achievements_screen.dart';
import 'profile_screen.dart';
import 'admin_dashboard_screen.dart';
import 'analytics_screen.dart';
import 'h5p_content_crud_screen.dart';

/// Main navigation screen with bottom navigation bar
class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  bool _isAdmin = false;
  bool _isLoading = true;

  // Screens for regular users
  final List<Widget> _userScreens = [
    HomeScreen(),
    LessonListScreen(),
    ModulesScreen(),
    ReviewScreen(),
    AchievementsScreen(),
    ProfileScreen(),
  ];

  // Screens for admin users
  final List<Widget> _adminScreens = [
    AdminDashboardScreen(),
    LessonCrudScreen(),
    ModuleCrudScreen(),
    H5PContentCrudScreen(),
    AnalyticsScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _checkUserRole();
  }

  /// Check if current user is an admin
  Future<void> _checkUserRole() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        
        if (userDoc.exists) {
          final userData = userDoc.data()!;
          setState(() {
            _isAdmin = userData['role'] == 'admin';
            _isLoading = false;
          });
        } else {
          setState(() {
            _isAdmin = false;
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _isAdmin = false;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error checking user role: $e');
      setState(() {
        _isAdmin = false;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final screens = _isAdmin ? _adminScreens : _userScreens;
    final navItems =
        _isAdmin ? _getAdminBottomNavItems() : _getUserBottomNavItems();

    return Scaffold(
      extendBody: true, // Allows the body to go behind the floating nav bar
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: _buildCustomBottomNav(navItems),
    );
  }

  Widget _buildCustomBottomNav(List<Map<String, dynamic>> items) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
        child: Container(
          height: 65,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(32.5),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (index) {
              final item = items[index];
              final isSelected = _currentIndex == index;
              return _buildNavItem(
                icon: item['icon'],
                isSelected: isSelected,
                onTap: () {
                  setState(() => _currentIndex = index);
                },
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 250),
        scale: isSelected ? 1.2 : 1.0,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.all(12.0),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isSelected
                ? Colors.white.withOpacity(0.15)
                : Colors.transparent,
          ),
          child: Icon(
            icon,
            color: isSelected ? Colors.white : Colors.white.withOpacity(0.7),
            size: 26,
          ),
        ),
      ),
    );
  }

  /// Get bottom navigation items for regular users
  List<Map<String, dynamic>> _getUserBottomNavItems() {
    return [
      {'icon': Icons.home_filled, 'label': 'Home'},
      {'icon': Icons.menu_book, 'label': 'Lessons'},
      {'icon': Icons.grid_view_rounded, 'label': 'Modules'},
      {'icon': Icons.history_edu_outlined, 'label': 'Review'},
      {'icon': Icons.emoji_events, 'label': 'Awards'},
      {'icon': Icons.person, 'label': 'Profile'},
    ];
  }

  /// Get bottom navigation items for admin users
  List<Map<String, dynamic>> _getAdminBottomNavItems() {
    return [
      {'icon': Icons.dashboard_rounded, 'label': 'Dashboard'},
      {'icon': Icons.menu_book, 'label': 'Lessons'},
      {'icon': Icons.grid_view_rounded, 'label': 'Modules'},
      {'icon': Icons.extension, 'label': 'H5P'},
      {'icon': Icons.analytics, 'label': 'Analytics'},
      {'icon': Icons.person, 'label': 'Profile'},
    ];
  }

  Widget? _buildAdminButton(bool isAdmin) {
    if (!isAdmin) return null;
    return PopupMenuButton<String>(
      onSelected: (value) {
        if (value == 'dashboard') {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminDashboardScreen()));
        } else if (value == 'h5p') {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const H5PContentCrudScreen()));
        }
      },
      icon: const Icon(Icons.admin_panel_settings, color: AppColors.textDark),
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        const PopupMenuItem<String>(
          value: 'dashboard',
          child: Text('Dashboard'),
        ),
        const PopupMenuItem<String>(
          value: 'h5p',
          child: Text('H5P Content'),
        ),
      ],
    );
  }
} 