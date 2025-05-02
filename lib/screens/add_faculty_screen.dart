import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ritian_faculty/widgets/custom_navigation_drawer.dart';

class AddFacultyScreen extends StatefulWidget {
  const AddFacultyScreen({super.key});

  @override
  _AddFacultyScreenState createState() => _AddFacultyScreenState();
}

class _AddFacultyScreenState extends State<AddFacultyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _biometricIdController = TextEditingController();
  final _ageController = TextEditingController();
  final _birthdayController = TextEditingController();
  final _dateOfJoiningController = TextEditingController();
  final _departmentController = TextEditingController();
  final _highestDegreeController = TextEditingController();
  final _phoneController = TextEditingController();
  final _religionController = TextEditingController();
  final _staffCodeController = TextEditingController();
  final _totalExperienceController = TextEditingController();
  final _searchController =
      TextEditingController(); // Controller for search input
  String? _selectedFacultyType;
  final List<String> _facultyTypes = ['Associate Professor', 'HoD'];
  bool _isLoading = false;
  String? _facultyType;
  bool _showAddForm = false;
  List<Map<String, dynamic>> _facultyList = [];
  List<Map<String, dynamic>> _filteredFacultyList =
      []; // Filtered list for search

  @override
  void initState() {
    super.initState();
    _fetchUserFacultyType();
    _fetchFacultyList();
    _searchController.addListener(
      _filterFacultyList,
    ); // Listen to search input changes
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

  Future<void> _fetchFacultyList() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('faculty_members').get();
      setState(() {
        _facultyList = snapshot.docs.map((doc) => doc.data()).toList();
        _filteredFacultyList =
            _facultyList; // Initially, show all faculty members
      });
    } catch (e) {
      print('Error fetching faculty list: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load faculty list: $e')),
      );
    }
  }

  void _filterFacultyList() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredFacultyList = _facultyList; // Show all if search is empty
      } else {
        _filteredFacultyList =
            _facultyList.where((faculty) {
              final name = faculty['name']?.toString().toLowerCase() ?? '';
              final email = faculty['email']?.toString().toLowerCase() ?? '';
              final facultyType =
                  faculty['faculty_type']?.toString().toLowerCase() ?? '';
              final department =
                  faculty['department']?.toString().toLowerCase() ?? '';
              return name.contains(query) ||
                  email.contains(query) ||
                  facultyType.contains(query) ||
                  department.contains(query);
            }).toList();
      }
    });
  }

  Future<void> _addFaculty() async {
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
                  .collection('faculty_members')
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
                  .collection('faculty_members')
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

      final facultyData = {
        'name': _nameController.text.trim(),
        'email': email,
        'biometric_id': _biometricIdController.text.trim(),
        'faculty_type': _selectedFacultyType,
        'age': int.parse(_ageController.text.trim()),
        'birthday': _birthdayController.text.trim(),
        'date_of_joining': _dateOfJoiningController.text.trim(),
        'department': _departmentController.text.trim(),
        'highest_degree': _highestDegreeController.text.trim(),
        'phone': _phoneController.text.trim(),
        'religion': _religionController.text.trim(),
        'staff_code': _staffCodeController.text.trim(),
        'total_experience': _totalExperienceController.text.trim(),
      };

      await FirebaseFirestore.instance
          .collection('faculty_members')
          .doc(uid)
          .set(facultyData);

      print('Faculty added: $uid, Data: $facultyData');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Faculty added successfully.')),
      );

      await _fetchFacultyList(); // Refresh the faculty list

      _nameController.clear();
      _emailController.clear();
      _biometricIdController.clear();
      _ageController.clear();
      _birthdayController.clear();
      _dateOfJoiningController.clear();
      _departmentController.clear();
      _highestDegreeController.clear();
      _phoneController.clear();
      _religionController.clear();
      _staffCodeController.clear();
      _totalExperienceController.clear();
      setState(() {
        _selectedFacultyType = null;
        _showAddForm = false;
      });
    } catch (e) {
      print('Error adding faculty: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to add faculty: $e')));
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
          title: const Text('Faculty List'),
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
        title: const Text('Faculty List'),
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
                'Faculty Members',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0C4D83),
                ),
              ),
              const SizedBox(height: 16),
              // Search bar
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: 'Search Faculty',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  filled: true,
                  fillColor: Colors.grey[100],
                  prefixIcon: const Icon(Icons.search),
                ),
              ),
              const SizedBox(height: 16),
              // Display filtered list of faculty members
              _filteredFacultyList.isEmpty
                  ? const Center(child: Text('No faculty members found.'))
                  : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _filteredFacultyList.length,
                    itemBuilder: (context, index) {
                      final faculty = _filteredFacultyList[index];
                      return Card(
                        elevation: 4,
                        margin: const EdgeInsets.symmetric(vertical: 8.0),
                        child: ListTile(
                          title: Text(
                            faculty['name'] ?? 'Unknown',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Email: ${faculty['email'] ?? 'N/A'}'),
                              Text(
                                'Faculty Type: ${faculty['faculty_type'] ?? 'N/A'}',
                              ),
                              Text(
                                'Department: ${faculty['department'] ?? 'N/A'}',
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
              const SizedBox(height: 16),
              // Button to show the add faculty form
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
                    _showAddForm ? 'Hide Form' : 'Add New Faculty',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Form to add a new faculty (visible only when _showAddForm is true)
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
                            'Faculty Details',
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
                            controller: _biometricIdController,
                            decoration: InputDecoration(
                              labelText: 'Biometric ID',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.0),
                              ),
                              filled: true,
                              fillColor: Colors.grey[100],
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter a biometric ID';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            value: _selectedFacultyType,
                            decoration: InputDecoration(
                              labelText: 'Faculty Type',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.0),
                              ),
                              filled: true,
                              fillColor: Colors.grey[100],
                            ),
                            items:
                                _facultyTypes.map((type) {
                                  return DropdownMenuItem(
                                    value: type,
                                    child: Text(type),
                                  );
                                }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedFacultyType = value;
                              });
                            },
                            validator: (value) {
                              if (value == null) {
                                return 'Please select a faculty type';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _ageController,
                            decoration: InputDecoration(
                              labelText: 'Age',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.0),
                              ),
                              filled: true,
                              fillColor: Colors.grey[100],
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter age';
                              }
                              if (int.tryParse(value) == null ||
                                  int.parse(value) <= 0) {
                                return 'Please enter a valid age';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _birthdayController,
                            decoration: InputDecoration(
                              labelText: 'Birthday (e.g., 14 May 2004)',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.0),
                              ),
                              filled: true,
                              fillColor: Colors.grey[100],
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter birthday';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _dateOfJoiningController,
                            decoration: InputDecoration(
                              labelText: 'Date of Joining',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.0),
                              ),
                              filled: true,
                              fillColor: Colors.grey[100],
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter date of joining';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _departmentController,
                            decoration: InputDecoration(
                              labelText: 'Department',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.0),
                              ),
                              filled: true,
                              fillColor: Colors.grey[100],
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter department';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _highestDegreeController,
                            decoration: InputDecoration(
                              labelText: 'Highest Degree',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.0),
                              ),
                              filled: true,
                              fillColor: Colors.grey[100],
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter highest degree';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _phoneController,
                            decoration: InputDecoration(
                              labelText: 'Phone',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.0),
                              ),
                              filled: true,
                              fillColor: Colors.grey[100],
                            ),
                            keyboardType: TextInputType.phone,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter phone number';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _religionController,
                            decoration: InputDecoration(
                              labelText: 'Religion',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.0),
                              ),
                              filled: true,
                              fillColor: Colors.grey[100],
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter religion';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _staffCodeController,
                            decoration: InputDecoration(
                              labelText: 'Staff Code',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.0),
                              ),
                              filled: true,
                              fillColor: Colors.grey[100],
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter staff code';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _totalExperienceController,
                            decoration: InputDecoration(
                              labelText: 'Total Experience (years)',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.0),
                              ),
                              filled: true,
                              fillColor: Colors.grey[100],
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter total experience';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),
                          Center(
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _addFaculty,
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
                                        'Add Faculty',
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
    _biometricIdController.dispose();
    _ageController.dispose();
    _birthdayController.dispose();
    _dateOfJoiningController.dispose();
    _departmentController.dispose();
    _highestDegreeController.dispose();
    _phoneController.dispose();
    _religionController.dispose();
    _staffCodeController.dispose();
    _totalExperienceController.dispose();
    _searchController.dispose();
    super.dispose();
  }
}
