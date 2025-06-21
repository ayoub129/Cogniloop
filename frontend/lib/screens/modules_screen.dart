import 'package:cogni_loop/utils/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ModulesScreen extends StatefulWidget {
  const ModulesScreen({super.key});

  @override
  State<ModulesScreen> createState() => _ModulesScreenState();
}

class _ModulesScreenState extends State<ModulesScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  void _showModuleDialog({DocumentSnapshot? module}) {
    final _titleController = TextEditingController(text: module?['title']);
    final _descriptionController =
        TextEditingController(text: module?['description']);
    final _topicController = TextEditingController(text: module?['topic']);
    List<String> _lessonIds =
        module != null ? List<String>.from(module['lessonIds']) : [];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(module == null ? 'Create Module' : 'Edit Module'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _titleController,
                      decoration: const InputDecoration(labelText: 'Title'),
                    ),
                    TextField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(labelText: 'Description'),
                    ),
                    TextField(
                      controller: _topicController,
                      decoration: const InputDecoration(labelText: 'Topic'),
                    ),
                    const SizedBox(height: 20),
                    const Text('Lessons in this Module',
                        style: AppTheme.subtitleStyle),
                    ..._lessonIds.map(
                      (id) => ListTile(
                        title: Text(id,
                            style: const TextStyle(fontSize: 12)),
                        trailing: IconButton(
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: () =>
                              setDialogState(() => _lessonIds.remove(id)),
                        ),
                      ),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Add Lesson'),
                      onPressed: () async {
                        final _lessonIdController = TextEditingController();
                        final newLessonId = await showDialog<String>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Add Lesson ID'),
                            content: TextField(
                              controller: _lessonIdController,
                              decoration:
                                  const InputDecoration(labelText: 'Lesson ID'),
                            ),
                            actions: [
                              TextButton(
                                child: const Text('Cancel'),
                                onPressed: () => Navigator.pop(context),
                              ),
                              ElevatedButton(
                                child: const Text('Add'),
                                onPressed: () => Navigator.pop(
                                    context, _lessonIdController.text),
                              ),
                            ],
                          ),
                        );
                        if (newLessonId != null && newLessonId.isNotEmpty) {
                          setDialogState(() => _lessonIds.add(newLessonId));
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                ElevatedButton(
                  child: const Text('Save'),
                  onPressed: () {
                    final data = {
                      'title': _titleController.text,
                      'description': _descriptionController.text,
                      'topic': _topicController.text,
                      'lessonIds': _lessonIds,
                      'updatedAt': FieldValue.serverTimestamp(),
                    };

                    if (module == null) {
                      data['createdAt'] = FieldValue.serverTimestamp();
                      _firestore.collection('modules').add(data);
                    } else {
                      _firestore
                          .collection('modules')
                          .doc(module.id)
                          .update(data);
                    }
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _deleteModule(String moduleId) {
     showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Module'),
        content: const Text('Are you sure you want to delete this module?'),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
            onPressed: () {
              _firestore.collection('modules').doc(moduleId).delete();
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Modules'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('modules')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
                child: Text('No modules found.', style: AppTheme.subtitleStyle));
          }

          final modules = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: modules.length,
            itemBuilder: (context, index) {
              final module = modules[index];
              final data = module.data() as Map<String, dynamic>;
              final title = data['title'] ?? 'No Title';
              final lessonCount =
                  (data['lessonIds'] as List<dynamic>? ?? []).length;
              final topic = data['topic'] ?? 'General';

              return Card(
                elevation: 3,
                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  title: Text(title, style: AppTheme.titleStyle),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Row(
                      children: [
                        _buildInfoChip('$lessonCount Lessons', Icons.list_alt),
                        const SizedBox(width: 12),
                        _buildInfoChip(topic, Icons.category_outlined),
                      ],
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: AppColors.primary),
                        onPressed: () => _showModuleDialog(module: module),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.redAccent),
                        onPressed: () => _deleteModule(module.id),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showModuleDialog(),
        label: const Text('Add Module'),
        icon: const Icon(Icons.add),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  Widget _buildInfoChip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
} 