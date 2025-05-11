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
  bool _isPosting = false;

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
      if (_facultyType != null) {
        final facultyTypeLower = _facultyType!.toLowerCase();
        if (facultyTypeLower == 'associate professor') {
          _viewerOptions = ['Students'];
        } else if (facultyTypeLower == 'hod' || facultyTypeLower == 'admin') {
          _viewerOptions = [
            'Students',
            'All Faculties',
            'Individual Faculties',
            'Department Faculties',
            if (facultyTypeLower == 'admin') 'Everyone',
          ];
        } else {
          _viewerOptions = ['Students'];
        }
      } else {
        _viewerOptions = ['Students'];
      }
    }
  }

  Future<void> _fetchClasses() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('academic').get();
      final classSet = <String>{};
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final deptClasses = List<String>.from(data['classes'] ?? []);
        classSet.addAll(deptClasses);
      }
      setState(() {
        _classes = classSet.toList()..sort();
      });
    } catch (e) {
      print('Error fetching classes: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to fetch classes: $e')));
      setState(() {
        _classes = [];
      });
    }
  }

  Future<void> _fetchFaculties() async {
    final snapshot =
        await FirebaseFirestore.instance.collection('faculty_members').get();
    _faculties =
        snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList();
  }

  Future<void> _fetchDepartments() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('academic').get();
      final deptSet = <String>{};
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final deptName = data['department']?.toString();
        if (deptName != null && deptName.isNotEmpty) {
          deptSet.add(deptName);
        }
      }
      setState(() {
        _departments = deptSet.toList()..sort();
      });
      if (deptSet.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No departments found in academic collection'),
          ),
        );
      }
    } catch (e) {
      print('Error fetching departments: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to fetch departments: $e')),
      );
      setState(() {
        _departments = [];
      });
    }
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

    setState(() {
      _isPosting = true;
    });

    try {
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
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to post announcement: $e')),
      );
    } finally {
      setState(() {
        _isPosting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isWeb = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Announcements',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF0C4D83),
        leading:
            isWeb
                ? null
                : Builder(
                  builder:
                      (context) => IconButton(
                        icon: const Icon(Icons.menu, color: Colors.white),
                        onPressed: () => Scaffold.of(context).openDrawer(),
                      ),
                ),
      ),
      drawer: isWeb ? null : const AppDrawer(),
      body:
          isWeb
              ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AppDrawer(),
                  Expanded(child: _buildContent(context, isWeb)),
                ],
              )
              : _buildContent(context, isWeb),
    );
  }

  Widget _buildContent(BuildContext context, bool isWeb) {
    return !_isDataLoaded
        ? const Center(child: CircularProgressIndicator())
        : LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: Padding(
                padding:
                    isWeb
                        ? const EdgeInsets.fromLTRB(24, 24, 24, 16)
                        : const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Post Announcement',
                      style: TextStyle(
                        fontSize: isWeb ? 28 : 24,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0C4D83),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      elevation: isWeb ? 8 : 6,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      child: Padding(
                        padding:
                            isWeb
                                ? const EdgeInsets.all(20.0)
                                : const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Announcement Details',
                              style: TextStyle(
                                fontSize: isWeb ? 20 : 18,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF0C4D83),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _announcementController,
                              decoration: InputDecoration(
                                labelText: 'Announcement',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
                                filled: true,
                                fillColor: Colors.grey[100],
                                contentPadding:
                                    isWeb
                                        ? const EdgeInsets.all(16)
                                        : const EdgeInsets.all(12),
                              ),
                              maxLines: 3,
                              style: TextStyle(fontSize: isWeb ? 16 : 14),
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              value: _selectedViewer,
                              items:
                                  _viewerOptions.map((option) {
                                    return DropdownMenuItem(
                                      value: option,
                                      child: Text(
                                        option,
                                        style: TextStyle(
                                          fontSize: isWeb ? 16 : 14,
                                        ),
                                      ),
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
                              decoration: InputDecoration(
                                labelText: 'Target Audience',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
                                filled: true,
                                fillColor: Colors.grey[100],
                                contentPadding:
                                    isWeb
                                        ? const EdgeInsets.all(16)
                                        : const EdgeInsets.all(12),
                              ),
                              style: TextStyle(fontSize: isWeb ? 16 : 14),
                            ),
                            const SizedBox(height: 8),
                            if (_selectedViewer == 'Students') ...[
                              DropdownButtonFormField<String>(
                                value: _selectedClass,
                                items: [
                                  ..._classes.map((className) {
                                    return DropdownMenuItem(
                                      value: className,
                                      child: Text(
                                        className,
                                        style: TextStyle(
                                          fontSize: isWeb ? 16 : 14,
                                        ),
                                      ),
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
                                decoration: InputDecoration(
                                  labelText: 'Select Class',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8.0),
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey[100],
                                  contentPadding:
                                      isWeb
                                          ? const EdgeInsets.all(16)
                                          : const EdgeInsets.all(12),
                                ),
                                style: TextStyle(fontSize: isWeb ? 16 : 14),
                              ),
                              const SizedBox(height: 8),
                            ],
                            if (_selectedViewer == 'Individual Faculties') ...[
                              DropdownButtonFormField<String>(
                                value: _selectedFaculty,
                                items:
                                    _faculties.map((faculty) {
                                      return DropdownMenuItem(
                                        value: faculty['id'] as String,
                                        child: Text(
                                          faculty['name'] as String,
                                          style: TextStyle(
                                            fontSize: isWeb ? 16 : 14,
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _selectedFaculty = value;
                                  });
                                },
                                decoration: InputDecoration(
                                  labelText: 'Select Faculty',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8.0),
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey[100],
                                  contentPadding:
                                      isWeb
                                          ? const EdgeInsets.all(16)
                                          : const EdgeInsets.all(12),
                                ),
                                style: TextStyle(fontSize: isWeb ? 16 : 14),
                              ),
                              const SizedBox(height: 8),
                            ],
                            if (_selectedViewer == 'Department Faculties') ...[
                              DropdownButtonFormField<String>(
                                value: _selectedDepartment,
                                items:
                                    _departments.map((dept) {
                                      return DropdownMenuItem(
                                        value: dept,
                                        child: Text(
                                          dept,
                                          style: TextStyle(
                                            fontSize: isWeb ? 16 : 14,
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _selectedDepartment = value;
                                  });
                                },
                                decoration: InputDecoration(
                                  labelText: 'Select Department',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8.0),
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey[100],
                                  contentPadding:
                                      isWeb
                                          ? const EdgeInsets.all(16)
                                          : const EdgeInsets.all(12),
                                ),
                                style: TextStyle(fontSize: isWeb ? 16 : 14),
                              ),
                              const SizedBox(height: 8),
                            ],
                            const SizedBox(height: 16),
                            Center(
                              child: ElevatedButton(
                                onPressed:
                                    _isPosting ? null : _postAnnouncement,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.teal,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8.0),
                                  ),
                                  padding:
                                      isWeb
                                          ? const EdgeInsets.symmetric(
                                            vertical: 14.0,
                                            horizontal: 30.0,
                                          )
                                          : const EdgeInsets.symmetric(
                                            vertical: 12.0,
                                            horizontal: 24.0,
                                          ),
                                  elevation: 6,
                                ),
                                child:
                                    _isPosting
                                        ? const CircularProgressIndicator(
                                          color: Colors.white,
                                        )
                                        : Text(
                                          'Post Announcement',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: isWeb ? 16 : 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
  }

  @override
  void dispose() {
    _announcementController.dispose();
    super.dispose();
  }
}
