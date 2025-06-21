// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ModuleCrudScreen extends StatefulWidget {
  const ModuleCrudScreen({super.key});

  @override
  State<ModuleCrudScreen> createState() => _ModuleCrudScreenState();
}

class _ModuleCrudScreenState extends State<ModuleCrudScreen> {
  String _search = '';

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
            Text(doc == null ? 'Add Module' : 'Edit Module', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            SizedBox(height: 16),
            TextField(controller: titleController, decoration: InputDecoration(labelText: 'Title')),
            SizedBox(height: 8),
            TextField(controller: descController, decoration: InputDecoration(labelText: 'Description')),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.isEmpty) return;
                try {
                  if (doc == null) {
                    await FirebaseFirestore.instance.collection('modules').add({
                      'title': titleController.text,
                      'description': descController.text,
                    });
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Module added')));
                  } else {
                    await doc.reference.update({
                      'title': titleController.text,
                      'description': descController.text,
                    });
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Module updated')));
                  }
                  Navigator.pop(context);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving module: '
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
        title: Text('Delete Module'),
        content: Text('Are you sure you want to delete this module?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              await doc.reference.delete();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Module deleted')));
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
        title: Text('Manage Modules'),
        actions: [
          IconButton(
            icon: Icon(Icons.add),
            onPressed: () => _showAddEditDialog(),
            tooltip: 'Add Module',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search modules...',
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
        stream: FirebaseFirestore.instance.collection('modules').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
          final modules = snapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>?;
            return data != null && (data['title']?.toLowerCase().contains(_search.toLowerCase()) ?? false);
          }).toList();
          if (modules.isEmpty) return Center(child: Text('No modules found. Add your first module to get started!', style: TextStyle(fontSize: 16, color: Colors.grey[700])));
          return ListView.builder(
            padding: EdgeInsets.all(16),
            itemCount: modules.length,
            itemBuilder: (context, index) {
              final doc = modules[index];
              final data = doc.data() as Map<String, dynamic>?;
              if (data == null || data['title'] == null) {
                return ListTile(
                  title: Text('Invalid module data', style: TextStyle(color: Colors.red)),
                  subtitle: Text('This module is missing required fields.'),
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