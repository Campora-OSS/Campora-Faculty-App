import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ritian_faculty/widgets/custom_navigation_drawer.dart';

class AddStudentScreen extends StatefulWidget {
  const AddStudentScreen({super.key});

  @override
  _AddStudentScreenState createState() => _AddStudentScreenState();
}

class _AddStudentScreenState extends State<AddStudentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _regdNumberController = TextEditingController();
  final _searchController = TextEditingController();
  String? _selectedClass;
  String? _selectedDepartment;
  String? _selectedYear;
  final List<String> _classes = [
    'AIDS E',
    'CSE A',
    'ECE B',
    'MECH C',
  ]; // Example classes
  final List<String> _departments = ['AIDS', 'CSE', 'ECE', 'MECH'];
  final List<String> _years = [
    'First Year',
    'Second Year',
    'Third Year',
    'Fourth Year',
  ];
  bool _isLoading = false;
  String? _facultyType;
  bool _showAddForm = false;
  List<Map<String, dynamic>> _studentList = [];
  List<Map<String, dynamic>> _filteredStudentList = [];

  @override
  void initState() {
    super.initState();
    _fetchUserFacultyType();
    _fetchStudentList();
    _searchController.addListener(_filterStudentList);
  }

  Future<void> _fetchUserFacultyType() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc =
          await FirebaseFirestore.instance
              .collection('faculty_members')
              .doc(user.uid)
              .get();
      if (doc.exists) {
        setState(() {
          _facultyType = doc.data()?['faculty_type'] ?? '';
        });
      }
    }
  }

  Future<void> _fetchStudentList() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('users').get();
      setState(() {
        _studentList = snapshot.docs.map((doc) => doc.data()).toList();
        _filteredStudentList = _studentList;
      });
    } catch (e) {
      print('Error fetching student list: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load student list: $e')),
      );
    }
  }

  void _filterStudentList() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredStudentList = _studentList;
      } else {
        _filteredStudentList =
            _studentList.where((student) {
              final name = student['name']?.toString().toLowerCase() ?? '';
              final email = student['email']?.toString().toLowerCase() ?? '';
              final regdNumber =
                  student['regdNumber']?.toString().toLowerCase() ?? '';
              final studentClass =
                  student['class']?.toString().toLowerCase() ?? '';
              final department =
                  student['department']?.toString().toLowerCase() ?? '';
              final year = student['year']?.toString().toLowerCase() ?? '';
              return name.contains(query) ||
                  email.contains(query) ||
                  regdNumber.contains(query) ||
                  studentClass.contains(query) ||
                  department.contains(query) ||
                  year.contains(query);
            }).toList();
      }
    });
  }

  Future<void> _addStudent() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final String email = _emailController.text.trim();
      String? uid;

      try {
        final signInMethods = await FirebaseAuth.instance
            .fetchSignInMethodsForEmail(email);
        if (signInMethods.isEmpty) {
          final UserCredential userCredential = await FirebaseAuth.instance
              .createUserWithEmailAndPassword(
                email: email,
                password: 'Dummy123',
              );
          uid = userCredential.user!.uid;
          await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
          print('New user created: $uid with email: $email');
        } else {
          final querySnapshot =
              await FirebaseFirestore.instance
                  .collection('users')
                  .where('email', isEqualTo: email)
                  .get();
          if (querySnapshot.docs.isNotEmpty) {
            uid = querySnapshot.docs.first.id;
            print('User already exists with email: $email, UID: $uid');
          } else {
            final UserCredential userCredential = await FirebaseAuth.instance
                .createUserWithEmailAndPassword(
                  email: email,
                  password: 'Dummy123',
                );
            uid = userCredential.user!.uid;
            print('Existing email in Auth but not in Firestore, new UID: $uid');
          }
        }
      } on FirebaseAuthException catch (e) {
        if (e.code == 'email-already-in-use') {
          final querySnapshot =
              await FirebaseFirestore.instance
                  .collection('users')
                  .where('email', isEqualTo: email)
                  .get();
          if (querySnapshot.docs.isNotEmpty) {
            uid = querySnapshot.docs.first.id;
            print('User already exists with email: $email, UID: $uid');
          } else {
            throw Exception(
              'Email exists in Authentication but not in Firestore',
            );
          }
        } else {
          throw e;
        }
      }

      final studentData = {
        'name': _nameController.text.trim(),
        'email': email,
        'regdNumber': _regdNumberController.text.trim(),
        'class': _selectedClass,
        'department': _selectedDepartment,
        'year': _selectedYear,
      };

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set(studentData);

      print('Student added: $uid, Data: $studentData');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Student added successfully.')),
      );

      await _fetchStudentList();

      _nameController.clear();
      _emailController.clear();
      _regdNumberController.clear();
      setState(() {
        _selectedClass = null;
        _selectedDepartment = null;
        _selectedYear = null;
        _showAddForm = false;
      });
    } catch (e) {
      print('Error adding student: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to add student: $e')));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_facultyType == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_facultyType != 'Admin') {
      print('Unauthorized access attempt: $_facultyType');
      return Scaffold(
        appBar: AppBar(
          title: const Text('Student List'),
          backgroundColor: Colors.blue,
        ),
        drawer: const AppDrawer(),
        body: const Center(
          child: Text(
            'You are not authorized to access this page.',
            style: TextStyle(fontSize: 16, color: Colors.black54),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Student List'),
        backgroundColor: Colors.blue,
      ),
      drawer: const AppDrawer(),
      body: Container(
        color: Colors.white,
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Students',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0C4D83),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: 'Search Students',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  filled: true,
                  fillColor: Colors.grey[100],
                  prefixIcon: const Icon(Icons.search),
                ),
              ),
              const SizedBox(height: 16),
              _filteredStudentList.isEmpty
                  ? const Center(child: Text('No students found.'))
                  : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _filteredStudentList.length,
                    itemBuilder: (context, index) {
                      final student = _filteredStudentList[index];
                      return Card(
                        elevation: 4,
                        margin: const EdgeInsets.symmetric(vertical: 8.0),
                        child: ListTile(
                          title: Text(
                            student['name'] ?? 'Unknown',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Email: ${student['email'] ?? 'N/A'}'),
                              Text(
                                'Regd Number: ${student['regdNumber'] ?? 'N/A'}',
                              ),
                              Text('Class: ${student['class'] ?? 'N/A'}'),
                              Text(
                                'Department: ${student['department'] ?? 'N/A'}',
                              ),
                              Text('Year: ${student['year'] ?? 'N/A'}'),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
              const SizedBox(height: 16),
              Center(
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _showAddForm = !_showAddForm;
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    padding: const EdgeInsets.symmetric(
                      vertical: 14.0,
                      horizontal: 30.0,
                    ),
                    elevation: 6,
                  ),
                  child: Text(
                    _showAddForm ? 'Hide Form' : 'Add New Student',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (_showAddForm)
                Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16.0),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Student Details',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0C4D83),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _nameController,
                            decoration: InputDecoration(
                              labelText: 'Name',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.0),
                              ),
                              filled: true,
                              fillColor: Colors.grey[100],
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter a name';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _emailController,
                            decoration: InputDecoration(
                              labelText: 'Email',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.0),
                              ),
                              filled: true,
                              fillColor: Colors.grey[100],
                            ),
                            keyboardType: TextInputType.emailAddress,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter an email';
                              }
                              if (!RegExp(
                                r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                              ).hasMatch(value)) {
                                return 'Please enter a valid email';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _regdNumberController,
                            decoration: InputDecoration(
                              labelText: 'Regd Number',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.0),
                              ),
                              filled: true,
                              fillColor: Colors.grey[100],
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter a registration number';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            value: _selectedClass,
                            decoration: InputDecoration(
                              labelText: 'Class',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.0),
                              ),
                              filled: true,
                              fillColor: Colors.grey[100],
                            ),
                            items:
                                _classes.map((className) {
                                  return DropdownMenuItem(
                                    value: className,
                                    child: Text(className),
                                  );
                                }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedClass = value;
                              });
                            },
                            validator: (value) {
                              if (value == null) {
                                return 'Please select a class';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            value: _selectedDepartment,
                            decoration: InputDecoration(
                              labelText: 'Department',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.0),
                              ),
                              filled: true,
                              fillColor: Colors.grey[100],
                            ),
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
                            validator: (value) {
                              if (value == null) {
                                return 'Please select a department';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            value: _selectedYear,
                            decoration: InputDecoration(
                              labelText: 'Year',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.0),
                              ),
                              filled: true,
                              fillColor: Colors.grey[100],
                            ),
                            items:
                                _years.map((year) {
                                  return DropdownMenuItem(
                                    value: year,
                                    child: Text(year),
                                  );
                                }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedYear = value;
                              });
                            },
                            validator: (value) {
                              if (value == null) {
                                return 'Please select a year';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),
                          Center(
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _addStudent,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.teal,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12.0),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14.0,
                                  horizontal: 30.0,
                                ),
                                elevation: 6,
                              ),
                              child:
                                  _isLoading
                                      ? const CircularProgressIndicator(
                                        color: Colors.white,
                                      )
                                      : const Text(
                                        'Add Student',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _regdNumberController.dispose();
    _searchController.dispose();
    super.dispose();
  }
}
