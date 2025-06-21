import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/app_theme.dart';

class LessonListScreen extends StatefulWidget {
  final String? moduleId;

  const LessonListScreen({super.key, this.moduleId});

  @override
  _LessonListScreenState createState() => _LessonListScreenState();
}

class _LessonListScreenState extends State<LessonListScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  void _showLessonDialog({DocumentSnapshot? lesson}) {
    final _titleController = TextEditingController(text: lesson?['title']);
    final _contentController = TextEditingController(text: lesson?['content']);
    final _h5pContentIdController =
        TextEditingController(text: lesson?['h5pContentId']);
    final _h5pUrlController = TextEditingController(text: lesson?['h5pUrl']);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(lesson == null ? 'Create Lesson' : 'Edit Lesson'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                TextField(
                  controller: _contentController,
                  decoration: const InputDecoration(labelText: 'Content'),
                  maxLines: 5,
                ),
                TextField(
                  controller: _h5pContentIdController,
                  decoration: const InputDecoration(
                      labelText: 'H5P Content ID (for quizzes)'),
                ),
                TextField(
                  controller: _h5pUrlController,
                  decoration: const InputDecoration(
                      labelText: 'H5P URL (for embed)'),
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
                  'content': _contentController.text,
                  'h5pContentId': _h5pContentIdController.text.isNotEmpty
                      ? _h5pContentIdController.text
                      : null,
                  'h5pUrl': _h5pUrlController.text.isNotEmpty
                      ? _h5pUrlController.text
                      : null,
                  'updatedAt': FieldValue.serverTimestamp(),
                };

                if (lesson == null) {
                  // Create
                  data['createdAt'] = FieldValue.serverTimestamp();
                  _firestore.collection('lessons').add(data);
                } else {
                  // Update
                  _firestore.collection('lessons').doc(lesson.id).update(data);
                }
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _deleteLesson(String lessonId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Lesson'),
        content: const Text('Are you sure you want to delete this lesson? This cannot be undone.'),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
            onPressed: () {
              _firestore.collection('lessons').doc(lessonId).delete();
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Query query = _firestore.collection('lessons').orderBy('createdAt', descending: true);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Lessons'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: query.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'No lessons found. Add one to get started!',
                style: AppTheme.subtitleStyle,
              ),
            );
          }

          final lessons = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: lessons.length,
            itemBuilder: (context, index) {
              final lesson = lessons[index];
              final data = lesson.data() as Map<String, dynamic>;
              final title = data['title'] ?? 'No Title';
              final content = data['content'] ?? 'No content available.';
              
              return Card(
                elevation: 3,
                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  title: Text(title, style: AppTheme.titleStyle),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      content,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.bodyTextStyle,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: AppColors.primary),
                        onPressed: () => _showLessonDialog(lesson: lesson),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.redAccent),
                        onPressed: () => _deleteLesson(lesson.id),
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
        onPressed: () => _showLessonDialog(),
        label: const Text('Add Lesson'),
        icon: const Icon(Icons.add),
        backgroundColor: AppColors.primary,
      ),
    );
  }
}