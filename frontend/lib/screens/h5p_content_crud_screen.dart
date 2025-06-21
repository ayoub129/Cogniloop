import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import '../../utils/app_theme.dart';

class H5PContentCrudScreen extends StatefulWidget {
  const H5PContentCrudScreen({super.key});

  @override
  _H5PContentCrudScreenState createState() =>
      _H5PContentCrudScreenState();
}

class _H5PContentCrudScreenState extends State<H5PContentCrudScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  void _showH5PContentDialog({DocumentSnapshot? content}) {
    final _titleController = TextEditingController(text: content?['title']);
    final _jsonContentController = TextEditingController();
    final _urlContentController = TextEditingController();

    String _type = 'json'; // Default type
    if (content != null) {
      final data = content.data() as Map<String, dynamic>;
      if (data.containsKey('h5pUrl') && data['h5pUrl'] != null) {
        _type = 'url';
        _urlContentController.text = data['h5pUrl'];
      } else if (data.containsKey('questions') && data['questions'] != null) {
        _type = 'json';
        _jsonContentController.text =
            const JsonEncoder.withIndent('  ').convert(data['questions']);
      }
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(content == null ? 'Create H5P Content' : 'Edit H5P Content'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                          labelText: 'Title', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 20),
                    ToggleButtons(
                      isSelected: [_type == 'json', _type == 'url'],
                      onPressed: (index) {
                        setDialogState(() {
                          _type = index == 0 ? 'json' : 'url';
                        });
                      },
                      borderRadius: BorderRadius.circular(8),
                      children: const [
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Text('JSON'),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Text('URL'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    if (_type == 'json')
                      TextField(
                        controller: _jsonContentController,
                        decoration: const InputDecoration(
                          labelText: 'JSON Content (List of questions)',
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true,
                        ),
                        maxLines: 10,
                      )
                    else
                      TextField(
                        controller: _urlContentController,
                        decoration: const InputDecoration(
                          labelText: 'H5P URL',
                          border: OutlineInputBorder(),
                        ),
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
                    final title = _titleController.text;
                    if (title.isEmpty) return;

                    Map<String, dynamic> data = {
                      'title': title,
                      'updatedAt': FieldValue.serverTimestamp(),
                    };

                    if (_type == 'url') {
                      data['h5pUrl'] = _urlContentController.text;
                      data['questions'] = null;
                    } else {
                      try {
                        data['questions'] = jsonDecode(_jsonContentController.text);
                        data['h5pUrl'] = null;
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Invalid JSON format.'),
                              backgroundColor: Colors.red),
                        );
                        return;
                      }
                    }

                    if (content == null) {
                      data['createdAt'] = FieldValue.serverTimestamp();
                      _firestore.collection('h5pcontent').add(data);
                    } else {
                      _firestore
                          .collection('h5pcontent')
                          .doc(content.id)
                          .set(data, SetOptions(merge: true));
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

   void _deleteContent(String docId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Content'),
        content: const Text('Are you sure you want to delete this H5P content?'),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
            onPressed: () {
              _firestore.collection('h5pcontent').doc(docId).delete();
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
        title: const Text('Manage H5P Content'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('h5pcontent')
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
                child: Text('No H5P content found.', style: AppTheme.subtitleStyle));
          }

          final contents = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: contents.length,
            itemBuilder: (context, index) {
              final content = contents[index];
              final data = content.data() as Map<String, dynamic>;
              final title = data['title'] ?? 'No Title';
              final type = (data.containsKey('h5pUrl') && data['h5pUrl'] != null) ? 'URL' : 'JSON';
              
              return Card(
                elevation: 3,
                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                   contentPadding: const EdgeInsets.all(16),
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primary.withOpacity(0.1),
                    child: Text(type, style: const TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                  title: Text(title, style: AppTheme.titleStyle),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: AppColors.primary),
                        onPressed: () => _showH5PContentDialog(content: content),
                      ),
                       IconButton(
                        icon: const Icon(Icons.delete, color: Colors.redAccent),
                        onPressed: () => _deleteContent(content.id),
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
        onPressed: () => _showH5PContentDialog(),
        label: const Text('Add Content'),
        icon: const Icon(Icons.add),
        backgroundColor: AppColors.primary,
      ),
    );
  }
}
