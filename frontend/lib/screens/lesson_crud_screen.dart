// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LessonCrudScreen extends StatefulWidget {
  const LessonCrudScreen({super.key});

  @override
  State<LessonCrudScreen> createState() => _LessonCrudScreenState();
}

class _LessonCrudScreenState extends State<LessonCrudScreen> {
  String _search = '';
  String? _selectedH5PContentId;
  List<QueryDocumentSnapshot>? _h5pContents;

  @override
  void initState() {
    super.initState();
    _loadH5PContents();
  }

  Future<void> _loadH5PContents() async {
    final snapshot = await FirebaseFirestore.instance.collection('h5pContent').get();
    setState(() {
      _h5pContents = snapshot.docs;
    });
  }

  void _showAddEditDialog({DocumentSnapshot? doc}) {
    final titleController = TextEditingController(text: doc?.get('title') ?? '');
    final descController = TextEditingController(text: doc?.get('description') ?? '');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(doc == null ? 'Add Lesson' : 'Edit Lesson', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            SizedBox(height: 16),
            TextField(controller: titleController, decoration: InputDecoration(labelText: 'Title')),
            SizedBox(height: 8),
            TextField(controller: descController, decoration: InputDecoration(labelText: 'Description')),
            SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedH5PContentId,
              decoration: InputDecoration(labelText: 'H5P Content'),
              items: _h5pContents?.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return DropdownMenuItem(
                  value: doc.id,
                  child: Text(data['title'] ?? doc.id),
                );
              }).toList(),
              onChanged: (val) => setState(() => _selectedH5PContentId = val),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.isEmpty) return;
                try {
                  if (doc == null) {
                    await FirebaseFirestore.instance.collection('lessons').add({
                      'title': titleController.text,
                      'description': descController.text,
                      'h5pContentId': _selectedH5PContentId,
                    });
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lesson added')));
                  } else {
                    await doc.reference.update({
                      'title': titleController.text,
                      'description': descController.text,
                      'h5pContentId': _selectedH5PContentId,
                    });
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lesson updated')));
                  }
                  Navigator.pop(context);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving lesson: '
                      'A$e', style: TextStyle(color: Colors.red))));
                }
              },
              child: Text(doc == null ? 'Add' : 'Update'),
            ),
            SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(DocumentSnapshot doc) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Lesson'),
        content: Text('Are you sure you want to delete this lesson?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              await doc.reference.delete();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lesson deleted')));
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Manage Lessons'),
        actions: [
          IconButton(
            icon: Icon(Icons.add),
            onPressed: () => _showAddEditDialog(),
            tooltip: 'Add Lesson',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search lessons...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                filled: true,
                fillColor: Colors.white,
              ),
              onChanged: (val) => setState(() => _search = val),
            ),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('lessons').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
          final lessons = snapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>?;
            return data != null && (data['title']?.toLowerCase().contains(_search.toLowerCase()) ?? false);
          }).toList();
          if (lessons.isEmpty) return Center(child: Text('No lessons found. Add your first lesson to get started!', style: TextStyle(fontSize: 16, color: Colors.grey[700])));
          return ListView.builder(
            padding: EdgeInsets.all(16),
            itemCount: lessons.length,
            itemBuilder: (context, index) {
              final doc = lessons[index];
              final data = doc.data() as Map<String, dynamic>?;
              if (data == null || data['title'] == null) {
                return ListTile(
                  title: Text('Invalid lesson data', style: TextStyle(color: Colors.red)),
                  subtitle: Text('This lesson is missing required fields.'),
                  leading: Icon(Icons.error, color: Colors.red),
                );
              }
              return Card(
                margin: EdgeInsets.only(bottom: 16),
                elevation: 3,
                child: ListTile(
                  title: Text(data['title'] ?? 'Untitled', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(data['description'] ?? 'No description.'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => _showAddEditDialog(doc: doc),
                        tooltip: 'Edit',
                      ),
                      IconButton(
                        icon: Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _confirmDelete(doc),
                        tooltip: 'Delete',
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
} 