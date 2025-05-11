import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:math';

class AddStudentScreen extends StatefulWidget {
  final VoidCallback onAdd;

  const AddStudentScreen({super.key, required this.onAdd});

  @override
  _AddStudentScreenState createState() => _AddStudentScreenState();
}

class _AddStudentScreenState extends State<AddStudentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _regdNumberController = TextEditingController();
  final _emailController = TextEditingController();
  final _classController = TextEditingController();
  String? _selectedDepartment;
  String? _selectedYear;
  String? _selectedClass;
  bool _isLoading = false;

  List<String> _departments = [];
  Map<String, List<String>> _departmentClassesMap = {};
  List<String> _filteredClasses = [];
  final List<String> _years = [
    'First Year',
    'Second Year',
    'Third Year',
    'Fourth Year',
  ];

  @override
  void initState() {
    super.initState();
    _fetchDepartmentsAndClasses();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _regdNumberController.dispose();
    _emailController.dispose();
    _classController.dispose();
    super.dispose();
  }

  Future<void> _fetchDepartmentsAndClasses() async {
    try {
      print(
        'Fetching departments and classes from Firestore academic collection...',
      );
      final snapshot =
          await FirebaseFirestore.instance.collection('academic').get();
      print(
        'Fetched ${snapshot.docs.length} documents from academic collection',
      );
      final deptList = <String>{};
      final deptClassesMap = <String, List<String>>{};
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final deptName = data['department']?.toString();
        final deptClasses = List<String>.from(data['classes'] ?? []);
        if (deptName != null && deptName.isNotEmpty) {
          deptList.add(deptName);
          deptClassesMap[deptName] = deptClasses..sort();
        } else {
          print(
            'Skipping document ${doc.id}: Missing or empty department field',
          );
        }
      }
      setState(() {
        _departments = deptList.toList()..sort();
        _departmentClassesMap = deptClassesMap;
        print('Updated departments: $_departments');
        print('Updated department-classes map: $_departmentClassesMap');
      });
      if (deptList.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No departments found in academic collection'),
          ),
        );
      }
      if (deptClassesMap.isEmpty ||
          deptClassesMap.values.every((classes) => classes.isEmpty)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No classes found in academic collection'),
          ),
        );
      }
    } catch (e) {
      print('Error fetching departments and classes: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to fetch departments and classes: $e')),
      );
      setState(() {
        _departments = [];
        _departmentClassesMap = {};
      });
    }
  }

  void _updateFilteredClasses() {
    setState(() {
      _filteredClasses =
          _selectedDepartment != null
              ? _departmentClassesMap[_selectedDepartment] ?? []
              : [];
      _selectedClass = null; // Reset selected class when department changes
      _classController.text = '';
    });
  }

  // Generate a secure random password
  String _generateRandomPassword() {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#\$%';
    final random = Random.secure();
    return List.generate(12, (_) => chars[random.nextInt(chars.length)]).join();
  }

  // Prompt user to re-authenticate
  Future<String?> _promptReAuthentication(String email) async {
    final passwordController = TextEditingController();
    bool obscureText = true;

    final password = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setState) => AlertDialog(
                  title: const Text('Re-authenticate'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Please enter your password to continue.'),
                      const SizedBox(height: 16),
                      TextField(
                        controller: passwordController,
                        obscureText: obscureText,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscureText
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                            onPressed: () {
                              setState(() {
                                obscureText = !obscureText;
                              });
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed:
                          () => Navigator.pop(
                            context,
                            passwordController.text.trim(),
                          ),
                      child: const Text('Submit'),
                    ),
                  ],
                ),
          ),
    );

    passwordController.dispose();
    return password;
  }

  Future<void> _addStudent() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      // Store the current user's information
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No user is currently signed in.')),
          );
        }
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final originalEmail = currentUser.email;
      if (originalEmail == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Current user has no email.')),
          );
        }
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Prompt for re-authentication
      final password = await _promptReAuthentication(originalEmail);
      if (password == null || password.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Re-authentication cancelled.')),
          );
        }
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Re-authenticate the current user
      try {
        final credential = EmailAuthProvider.credential(
          email: originalEmail,
          password: password,
        );
        await currentUser.reauthenticateWithCredential(credential);
      } catch (e) {
        print('Re-authentication failed: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Re-authentication failed: $e')),
          );
        }
        setState(() {
          _isLoading = false;
        });
        return;
      }

      try {
        // Generate a random password for the new student
        final tempPassword = _generateRandomPassword();

        // Create the new student account (this signs in the new user)
        final userCredential = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(
              email: _emailController.text.trim(),
              password: tempPassword,
            );

        final user = userCredential.user;

        if (user != null) {
          // Store student data in Firestore
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set({
                'name': _nameController.text.trim(),
                'regdNumber': _regdNumberController.text.trim(),
                'email': _emailController.text.trim(),
                'department': _selectedDepartment,
                'year': _selectedYear,
                'class': _selectedClass,
              });

          // Send password reset email to the student
          await user.sendEmailVerification();

          // Sign out the new user
          await FirebaseAuth.instance.signOut();

          // Sign back in as the original user
          await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: originalEmail,
            password: password,
          );

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Student added successfully')),
            );
          }

          // Call the onAdd callback to refresh the student list
          widget.onAdd();

          // Navigate back
          if (mounted) {
            Navigator.pop(context);
          }
        } else {
          throw Exception('Failed to create user account.');
        }
      } catch (e) {
        print('Error adding student: $e');
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Failed to add student: $e')));
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isWeb = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Student', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF0C4D83),
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding:
                    isWeb
                        ? const EdgeInsets.symmetric(
                          horizontal: 40,
                          vertical: 20,
                        )
                        : const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: 'Name',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.0),
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
                        controller: _regdNumberController,
                        decoration: InputDecoration(
                          labelText: 'Registration Number',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.0),
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
                      TextFormField(
                        controller: _emailController,
                        decoration: InputDecoration(
                          labelText: 'Email',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          filled: true,
                          fillColor: Colors.grey[100],
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter an email';
                          }
                          if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                            return 'Please enter a valid email';
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
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          filled: true,
                          fillColor: Colors.grey[100],
                        ),
                        items:
                            _departments
                                .map(
                                  (dept) => DropdownMenuItem(
                                    value: dept,
                                    child: Text(dept),
                                  ),
                                )
                                .toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedDepartment = value;
                            _updateFilteredClasses();
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
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          filled: true,
                          fillColor: Colors.grey[100],
                        ),
                        items:
                            _years
                                .map(
                                  (year) => DropdownMenuItem(
                                    value: year,
                                    child: Text(year),
                                  ),
                                )
                                .toList(),
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
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _selectedClass,
                        decoration: InputDecoration(
                          labelText: 'Class',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          filled: true,
                          fillColor: Colors.grey[100],
                        ),
                        items:
                            _filteredClasses
                                .map(
                                  (cls) => DropdownMenuItem(
                                    value: cls,
                                    child: Text(cls),
                                  ),
                                )
                                .toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedClass = value;
                            _classController.text = value ?? '';
                          });
                        },
                        validator: (value) {
                          if (value == null) {
                            return 'Please select a class';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 30),
                      Center(
                        child: ElevatedButton(
                          onPressed: _addStudent,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            padding:
                                isWeb
                                    ? const EdgeInsets.symmetric(
                                      horizontal: 40,
                                      vertical: 16,
                                    )
                                    : const EdgeInsets.symmetric(
                                      horizontal: 32,
                                      vertical: 12,
                                    ),
                          ),
                          child: const Text(
                            'Add Student',
                            style: TextStyle(fontSize: 16, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
    );
  }
}
