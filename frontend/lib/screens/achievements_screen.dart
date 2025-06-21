import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cogni_loop/utils/app_theme.dart';

/// Screen displaying user achievements and progress
class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  bool _isLoading = true;
  List<DocumentSnapshot> _allAchievements = [];
  Set<String> _unlockedAchievementIds = {};
  String _selectedCategory = 'All';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not logged in');

      // Fetch all possible achievements
      final allAchievementsSnapshot =
          await FirebaseFirestore.instance.collection('achievements').get();
      _allAchievements = allAchievementsSnapshot.docs;

      // Fetch user's unlocked achievement IDs
      final userAchievementsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('achievements')
          .get();
      _unlockedAchievementIds =
          userAchievementsSnapshot.docs.map((doc) => doc.id).toSet();
    } catch (e) {
      print('Failed to load achievements: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load achievements: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<DocumentSnapshot> get _filteredAchievements {
    if (_selectedCategory == 'All') {
      return _allAchievements;
    }
    return _allAchievements.where((doc) {
      final data = doc.data() as Map<String, dynamic>?;
      return (data?['category'] as String?) == _selectedCategory;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Achievements'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: _buildStatsSection(),
                    ),
                  ),
                  SliverAppBar(
                    pinned: true,
                    backgroundColor: AppColors.background,
                    flexibleSpace: _buildCategoryFilter(),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.all(24.0),
                    sliver: _buildAchievementsList(),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatsSection() {
    int unlockedCount = _unlockedAchievementIds.length;
    int totalCount = _allAchievements.length;
    double progress = totalCount > 0 ? unlockedCount / totalCount : 0;
    
    // Calculate total points from unlocked achievements
    int totalPoints = _allAchievements
        .where((doc) => _unlockedAchievementIds.contains(doc.id))
        .fold(0, (sum, doc) {
            final data = doc.data() as Map<String, dynamic>?;
            return sum + (data?['points'] as int? ?? 0);
        });

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('Unlocked', '$unlockedCount'),
                _buildStatItem('Total', '$totalCount'),
                _buildStatItem('Points', '$totalPoints'),
              ],
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: AppColors.lightGrey,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: AppColors.textLight)),
      ],
    );
  }
  
  Widget _buildCategoryFilter() {
    final categories = _allAchievements
        .map((doc) => (doc.data() as Map<String, dynamic>?)?['category'] as String?)
        .where((c) => c != null)
        .toSet()
        .toList();
    categories.insert(0, 'All');

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      color: AppColors.background,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: categories.map((category) {
            final isSelected = _selectedCategory == category;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: ChoiceChip(
                label: Text(category!),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) {
                    setState(() => _selectedCategory = category);
                  }
                },
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildAchievementsList() {
    final achievementsToShow = _filteredAchievements;
    if (achievementsToShow.isEmpty) {
      return const SliverToBoxAdapter(
          child: Center(child: Text('No achievements in this category.')));
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final doc = achievementsToShow[index];
          final data = doc.data() as Map<String, dynamic>? ?? {};
          final isUnlocked = _unlockedAchievementIds.contains(doc.id);

          final title = data['title'] as String? ?? 'Unnamed Achievement';
          final description = data['description'] as String? ?? 'No description.';
          final icon = data['icon'] as String? ?? '❓';
          final points = data['points'] as int? ?? 0;

          return Card(
            elevation: 0,
            color: isUnlocked ? Colors.white : AppColors.lightGrey.withOpacity(0.5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16.0),
              leading: Opacity(
                opacity: isUnlocked ? 1.0 : 0.4,
                child: Text(icon, style: const TextStyle(fontSize: 32)),
              ),
              title: Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isUnlocked ? AppColors.textDark : AppColors.textLight,
                ),
              ),
              subtitle: Text(
                description,
                style: TextStyle(
                  color: isUnlocked ? AppColors.textLight : AppColors.textLight.withOpacity(0.7),
                ),
              ),
              trailing: isUnlocked
                  ? Chip(
                      label: Text('+$points pts'),
                      backgroundColor: AppColors.primary.withOpacity(0.1),
                      labelStyle: const TextStyle(color: AppColors.primary),
                    )
                  : const Icon(Icons.lock_outline, color: AppColors.textLight),
            ),
          );
        },
        childCount: achievementsToShow.length,
      ),
    );
  }
} 