import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ritian_faculty/widgets/custom_navigation_drawer.dart';

class AnnouncementScreen extends StatefulWidget {
  const AnnouncementScreen({super.key});

  @override
  State<AnnouncementScreen> createState() => _AnnouncementScreenState();
}

class _AnnouncementScreenState extends State<AnnouncementScreen> {
  final TextEditingController _announcementController = TextEditingController();
  String? _selectedViewer;
  String? _selectedClass;
  String? _selectedFaculty;
  String? _selectedDepartment;
  String? _facultyType;
  List<String> _classes = [];
  List<Map<String, dynamic>> _faculties = [];
  List<String> _departments = [];
  List<String> _viewerOptions = [];
  bool _isDataLoaded = false;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    await Future.wait([
      _fetchFacultyType(),
      _fetchClasses(),
      _fetchFaculties(),
      _fetchDepartments(),
    ]);
    setState(() {
      _isDataLoaded = true;
    });
  }

  Future<void> _fetchFacultyType() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc =
        await FirebaseFirestore.instance
            .collection('faculty_members')
            .doc(user.uid)
            .get();
    if (doc.exists) {
      _facultyType = doc.data()!['faculty_type'] as String?;
      print('Fetched faculty_type: $_facultyType');
      if (_facultyType != null) {
        final facultyTypeLower = _facultyType!.toLowerCase();
        if (facultyTypeLower == 'associate professor') {
          _viewerOptions = ['Students'];
        } else if (facultyTypeLower == 'hod' || facultyTypeLower == 'admin') {
          _viewerOptions = [
            'Students',
            'All Faculties',
            'Individual Faculties',
            'Department Faculties', // New option for HoD and Admin
            if (facultyTypeLower == 'admin') 'Everyone',
          ];
        } else {
          _viewerOptions = ['Students'];
          print(
            'Unexpected faculty_type: $_facultyType, defaulting to Students',
          );
        }
      } else {
        _viewerOptions = ['Students'];
        print('faculty_type is null, defaulting to Students');
      }
      print('Viewer options set to: $_viewerOptions');
    }
  }

  Future<void> _fetchClasses() async {
    final snapshot =
        await FirebaseFirestore.instance.collection('timetables').get();
    final classSet = <String>{};
    for (var doc in snapshot.docs) {
      classSet.add(doc.data()['class'] as String);
    }
    _classes = classSet.toList()..sort();
  }

  Future<void> _fetchFaculties() async {
    final snapshot =
        await FirebaseFirestore.instance.collection('faculty_members').get();
    _faculties =
        snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList();
  }

  Future<void> _fetchDepartments() async {
    final snapshot =
        await FirebaseFirestore.instance.collection('faculty_members').get();
    final deptSet = <String>{};
    for (var doc in snapshot.docs) {
      final dept = doc.data()['department'] as String?;
      if (dept != null) deptSet.add(dept);
    }
    _departments = deptSet.toList()..sort();
  }

  Future<void> _postAnnouncement() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null ||
        _announcementController.text.isEmpty ||
        _selectedViewer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields')),
      );
      return;
    }

    if (_selectedViewer == 'Students' && _selectedClass == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a class')));
      return;
    }
    if (_selectedViewer == 'Individual Faculties' && _selectedFaculty == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a faculty')));
      return;
    }
    if (_selectedViewer == 'Department Faculties' &&
        _selectedDepartment == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a department')),
      );
      return;
    }

    final doc =
        await FirebaseFirestore.instance
            .collection('faculty_members')
            .doc(user.uid)
            .get();
    final announcerName = doc.data()!['name'] as String? ?? 'Unknown';

    final announcementData = {
      'announcement': _announcementController.text.trim(),
      'announcer': announcerName,
      'timestamp': Timestamp.now(),
      'viewers': _selectedViewer,
      'facultyType': _facultyType,
    };

    if (_selectedViewer == 'Students') {
      announcementData['class'] = _selectedClass;
    } else if (_selectedViewer == 'Individual Faculties') {
      announcementData['facultyId'] = _selectedFaculty;
    } else if (_selectedViewer == 'Department Faculties') {
      announcementData['department'] = _selectedDepartment;
    }

    await FirebaseFirestore.instance
        .collection('announcements')
        .add(announcementData);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Announcement posted successfully')),
    );

    setState(() {
      _announcementController.clear();
      _selectedViewer = null;
      _selectedClass = null;
      _selectedFaculty = null;
      _selectedDepartment = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Post Announcement')),
      drawer: const AppDrawer(),
      body:
          !_isDataLoaded
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _announcementController,
                        decoration: const InputDecoration(
                          labelText: 'Announcement',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _selectedViewer,
                        items:
                            _viewerOptions.map((option) {
                              return DropdownMenuItem(
                                value: option,
                                child: Text(option),
                              );
                            }).toList(),
                        onChanged:
                            _viewerOptions.isEmpty
                                ? null
                                : (value) {
                                  setState(() {
                                    _selectedViewer = value;
                                    _selectedClass = null;
                                    _selectedFaculty = null;
                                    _selectedDepartment = null;
                                  });
                                },
                        decoration: const InputDecoration(
                          labelText: 'Target Audience',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_selectedViewer == 'Students') ...[
                        DropdownButtonFormField<String>(
                          value: _selectedClass,
                          items: [
                            ..._classes.map((className) {
                              return DropdownMenuItem(
                                value: className,
                                child: Text(className),
                              );
                            }),
                            const DropdownMenuItem(
                              value: 'All Classes',
                              child: Text('All Classes'),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _selectedClass = value;
                            });
                          },
                          decoration: const InputDecoration(
                            labelText: 'Select Class',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (_selectedViewer == 'Individual Faculties') ...[
                        DropdownButtonFormField<String>(
                          value: _selectedFaculty,
                          items:
                              _faculties.map((faculty) {
                                return DropdownMenuItem(
                                  value: faculty['id'] as String,
                                  child: Text(faculty['name'] as String),
                                );
                              }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedFaculty = value;
                            });
                          },
                          decoration: const InputDecoration(
                            labelText: 'Select Faculty',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (_selectedViewer == 'Department Faculties') ...[
                        DropdownButtonFormField<String>(
                          value: _selectedDepartment,
                          items:
                              _departments.map((dept) {
                                return DropdownMenuItem(
                                  value: dept,
                                  child: Text(dept),
                                );
                              }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedDepartment = value;
                            });
                          },
                          decoration: const InputDecoration(
                            labelText: 'Select Department',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      ElevatedButton(
                        onPressed: _postAnnouncement,
                        child: const Text('Post Announcement'),
                      ),
                    ],
                  ),
                ),
              ),
    );
  }
}
