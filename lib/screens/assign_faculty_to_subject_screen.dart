import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ritian_faculty/widgets/custom_navigation_drawer.dart';

class AssignFacultyToSubjectScreen extends StatefulWidget {
  const AssignFacultyToSubjectScreen({super.key});

  @override
  State<AssignFacultyToSubjectScreen> createState() =>
      _AssignFacultyToSubjectScreenState();
}

class _AssignFacultyToSubjectScreenState
    extends State<AssignFacultyToSubjectScreen> {
  List<Map<String, dynamic>> subjects = [];
  List<Map<String, dynamic>> faculty = [];
  List<String> classes = ['AIDS E', 'CSE A', 'ECE B', 'MECH C'];
  String? selectedClass;
  bool _isLoading = false;
  Map<String, String> subjectFacultyMapping = {};

  @override
  void initState() {
    super.initState();
    _fetchSubjects();
    _fetchFaculty();
  }

  Future<void> _fetchSubjects() async {
    final snapshot =
        await FirebaseFirestore.instance.collection('subjects').get();
    setState(() {
      subjects =
          snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList();
    });
  }

  Future<void> _fetchFaculty() async {
    final snapshot =
        await FirebaseFirestore.instance.collection('faculty_members').get();
    setState(() {
      faculty =
          snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList();
    });
  }

  Future<void> _saveMapping() async {
    if (selectedClass == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a class')));
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await FirebaseFirestore.instance
          .collection('subject_faculty_mapping')
          .doc(selectedClass)
          .set({
            'class': selectedClass,
            'mapping': subjectFacultyMapping,
            'updated_at': Timestamp.now(),
          });
      Navigator.pushReplacementNamed(context, '/home');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mapping saved successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save mapping: $e')));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Assign Faculty to Subjects')),
      drawer: const AppDrawer(),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            DropdownButton<String>(
              hint: const Text('Select Class'),
              value: selectedClass,
              onChanged: (value) {
                setState(() {
                  selectedClass = value;
                  subjectFacultyMapping.clear();
                });
              },
              items:
                  classes.map((className) {
                    return DropdownMenuItem<String>(
                      value: className,
                      child: Text(className),
                    );
                  }).toList(),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: subjects.length,
                itemBuilder: (context, index) {
                  final subject = subjects[index];
                  return ListTile(
                    title: Text(subject['subject_name']),
                    trailing: DropdownButton<String>(
                      hint: const Text('Select Faculty'),
                      value: subjectFacultyMapping[subject['subject_code']],
                      onChanged: (value) {
                        setState(() {
                          subjectFacultyMapping[subject['subject_code']] =
                              value!;
                        });
                      },
                      items:
                          faculty.map((fac) {
                            return DropdownMenuItem<String>(
                              value: fac['staff_code'],
                              child: Text(fac['name']),
                            );
                          }).toList(),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                  onPressed: _saveMapping,
                  child: const Text('Save Mapping'),
                ),
          ],
        ),
      ),
    );
  }
}
