import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ritian_faculty/widgets/custom_navigation_drawer.dart'; // Import the AppDrawer

class AddSubjectScreen extends StatefulWidget {
  const AddSubjectScreen({super.key});

  @override
  State<AddSubjectScreen> createState() => _AddSubjectScreenState();
}

class _AddSubjectScreenState extends State<AddSubjectScreen> {
  final _subjectNameController = TextEditingController();
  final _subjectCodeController = TextEditingController();
  bool _isLoading = false;

  Future<void> _addSubject() async {
    final subjectName = _subjectNameController.text.trim();
    final subjectCode = _subjectCodeController.text.trim();

    if (subjectName.isEmpty || subjectCode.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please fill all fields')));
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await FirebaseFirestore.instance.collection('subjects').add({
        'subject_name': subjectName,
        'subject_code': subjectCode,
        'created_at': Timestamp.now(),
      });
      // Navigate to the home screen instead of popping
      Navigator.pushReplacementNamed(context, '/add_subject');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Subject added successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to add subject: $e')));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _subjectNameController.dispose();
    _subjectCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Subject')),
      drawer: const AppDrawer(), // Add the AppDrawer here
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _subjectNameController,
              decoration: const InputDecoration(labelText: 'Subject Name'),
            ),
            TextField(
              controller: _subjectCodeController,
              decoration: const InputDecoration(labelText: 'Subject Code'),
            ),
            const SizedBox(height: 20),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                  onPressed: _addSubject,
                  child: const Text('Add Subject'),
                ),
          ],
        ),
      ),
    );
  }
}
