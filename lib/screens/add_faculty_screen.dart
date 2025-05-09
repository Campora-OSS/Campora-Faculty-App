import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ritian_faculty/screens/faculty_details_screen.dart';
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
  final _searchController = TextEditingController();
  String? _selectedFacultyType;
  final List<String> _facultyTypes = ['Associate Professor', 'HoD'];
  bool _isLoading = false;
  String? _facultyType;
  bool _showAddForm = false;
  List<Map<String, dynamic>> _facultyList = [];
  List<Map<String, dynamic>> _filteredFacultyList = [];

  @override
  void initState() {
    super.initState();
    _fetchUserFacultyType();
    _fetchFacultyList();
    _searchController.addListener(_filterFacultyList);
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
          _facultyType = doc.data()?['faculty_type']?.toString() ?? '';
        });
      }
    }
  }

  Future<void> _fetchFacultyList() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('faculty_members').get();
      setState(() {
        _facultyList =
            snapshot.docs.map((doc) {
              final data = doc.data();
              data['uid'] = doc.id;
              return data;
            }).toList();
        _filteredFacultyList = _facultyList;
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
        _filteredFacultyList = _facultyList;
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
      // Prompt admin to re-enter their password
      final adminPassword = await _promptAdminPassword(context);
      if (adminPassword == null) {
        throw Exception('Admin password required to proceed.');
      }

      final adminUser = FirebaseAuth.instance.currentUser;
      if (adminUser == null) {
        throw Exception('Admin user not logged in.');
      }
      final adminEmail = adminUser.email;

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

          // Sign out the newly created user
          await FirebaseAuth.instance.signOut();

          // Sign the admin back in
          await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: adminEmail!,
            password: adminPassword,
          );
          print('Admin signed back in: $adminEmail');
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

            // Sign out the newly created user
            await FirebaseAuth.instance.signOut();

            // Sign the admin back in
            await FirebaseAuth.instance.signInWithEmailAndPassword(
              email: adminEmail!,
              password: adminPassword,
            );
            print('Admin signed back in: $adminEmail');
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

      await _fetchFacultyList();

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

  Future<String?> _promptAdminPassword(BuildContext context) async {
    final TextEditingController passwordController = TextEditingController();
    String? password;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            title: const Text('Admin Password Required'),
            content: TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Enter Admin Password',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  password = passwordController.text.trim();
                  Navigator.pop(context);
                },
                child: const Text('Submit'),
              ),
            ],
          ),
    );

    return password;
  }

  @override
  Widget build(BuildContext context) {
    final bool isWeb = MediaQuery.of(context).size.width > 800;

    if (_facultyType == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_facultyType != 'Admin') {
      print('Unauthorized access attempt: $_facultyType');
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'Unauthorized',
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
        body: Center(
          child: Text(
            'You are not authorized to access this page.',
            style: TextStyle(fontSize: isWeb ? 18 : 16, color: Colors.black54),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Add Faculty',
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.maxHeight - (isWeb ? 48 : 32);
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
                  'Faculty Members',
                  style: TextStyle(
                    fontSize: isWeb ? 28 : 24,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0C4D83),
                  ),
                ),
                const SizedBox(height: 12),
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
                const SizedBox(height: 12),
                SizedBox(
                  height: isWeb ? null : availableHeight - 84,
                  child:
                      _filteredFacultyList.isEmpty
                          ? const Center(
                            child: Text('No faculty members found.'),
                          )
                          : isWeb
                          ? GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                const SliverGridDelegateWithMaxCrossAxisExtent(
                                  maxCrossAxisExtent: 400,
                                  childAspectRatio: 1.8,
                                  crossAxisSpacing: 16,
                                  mainAxisSpacing: 16,
                                ),
                            itemCount: _filteredFacultyList.length,
                            itemBuilder: (context, index) {
                              return _buildFacultyCard(
                                context,
                                _filteredFacultyList[index],
                                isWeb,
                              );
                            },
                          )
                          : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _filteredFacultyList.length,
                            itemBuilder: (context, index) {
                              return _buildFacultyCard(
                                context,
                                _filteredFacultyList[index],
                                isWeb,
                              );
                            },
                          ),
                ),
                const SizedBox(height: 12),
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
                    child: Text(
                      _showAddForm ? 'Hide Form' : 'Add New Faculty',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isWeb ? 16 : 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (_showAddForm)
                  Card(
                    elevation: isWeb ? 8 : 6,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    child: Padding(
                      padding:
                          isWeb
                              ? const EdgeInsets.all(20.0)
                              : const EdgeInsets.all(16.0),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Faculty Details',
                              style: TextStyle(
                                fontSize: isWeb ? 20 : 18,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF0C4D83),
                              ),
                            ),
                            const SizedBox(height: 12),
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
                              validator:
                                  (value) =>
                                      value?.trim().isEmpty ?? true
                                          ? 'Please enter a name'
                                          : null,
                            ),
                            const SizedBox(height: 8),
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
                                if (value?.trim().isEmpty ?? true) {
                                  return 'Please enter an email';
                                }
                                if (!RegExp(
                                  r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                                ).hasMatch(value!)) {
                                  return 'Please enter a valid email';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _biometricIdController,
                              decoration: InputDecoration(
                                labelText: 'Biometric ID',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
                                filled: true,
                                fillColor: Colors.grey[100],
                              ),
                              validator:
                                  (value) =>
                                      value?.trim().isEmpty ?? true
                                          ? 'Please enter a biometric ID'
                                          : null,
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              value: _selectedFacultyType,
                              decoration: InputDecoration(
                                labelText: 'Faculty Type',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
                                filled: true,
                                fillColor: Colors.grey[100],
                              ),
                              items:
                                  _facultyTypes
                                      .map(
                                        (type) => DropdownMenuItem(
                                          value: type,
                                          child: Text(type),
                                        ),
                                      )
                                      .toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedFacultyType = value;
                                });
                              },
                              validator:
                                  (value) =>
                                      value == null
                                          ? 'Please select a faculty type'
                                          : null,
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _ageController,
                              decoration: InputDecoration(
                                labelText: 'Age',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
                                filled: true,
                                fillColor: Colors.grey[100],
                              ),
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value?.trim().isEmpty ?? true) {
                                  return 'Please enter age';
                                }
                                if (int.tryParse(value!) == null ||
                                    int.parse(value) <= 0) {
                                  return 'Please enter a valid age';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _birthdayController,
                              decoration: InputDecoration(
                                labelText: 'Birthday (e.g., 14 May 2004)',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
                                filled: true,
                                fillColor: Colors.grey[100],
                              ),
                              validator:
                                  (value) =>
                                      value?.trim().isEmpty ?? true
                                          ? 'Please enter birthday'
                                          : null,
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _dateOfJoiningController,
                              decoration: InputDecoration(
                                labelText: 'Date of Joining',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
                                filled: true,
                                fillColor: Colors.grey[100],
                              ),
                              validator:
                                  (value) =>
                                      value?.trim().isEmpty ?? true
                                          ? 'Please enter date of joining'
                                          : null,
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _departmentController,
                              decoration: InputDecoration(
                                labelText: 'Department',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
                                filled: true,
                                fillColor: Colors.grey[100],
                              ),
                              validator:
                                  (value) =>
                                      value?.trim().isEmpty ?? true
                                          ? 'Please enter department'
                                          : null,
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _highestDegreeController,
                              decoration: InputDecoration(
                                labelText: 'Highest Degree',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
                                filled: true,
                                fillColor: Colors.grey[100],
                              ),
                              validator:
                                  (value) =>
                                      value?.trim().isEmpty ?? true
                                          ? 'Please enter highest degree'
                                          : null,
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _phoneController,
                              decoration: InputDecoration(
                                labelText: 'Phone',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
                                filled: true,
                                fillColor: Colors.grey[100],
                              ),
                              keyboardType: TextInputType.phone,
                              validator:
                                  (value) =>
                                      value?.trim().isEmpty ?? true
                                          ? 'Please enter phone number'
                                          : null,
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _religionController,
                              decoration: InputDecoration(
                                labelText: 'Religion',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
                                filled: true,
                                fillColor: Colors.grey[100],
                              ),
                              validator:
                                  (value) =>
                                      value?.trim().isEmpty ?? true
                                          ? 'Please enter religion'
                                          : null,
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _staffCodeController,
                              decoration: InputDecoration(
                                labelText: 'Staff Code',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
                                filled: true,
                                fillColor: Colors.grey[100],
                              ),
                              validator:
                                  (value) =>
                                      value?.trim().isEmpty ?? true
                                          ? 'Please enter staff code'
                                          : null,
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _totalExperienceController,
                              decoration: InputDecoration(
                                labelText: 'Total Experience (years)',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
                                filled: true,
                                fillColor: Colors.grey[100],
                              ),
                              keyboardType: TextInputType.number,
                              validator:
                                  (value) =>
                                      value?.trim().isEmpty ?? true
                                          ? 'Please enter total experience'
                                          : null,
                            ),
                            const SizedBox(height: 16),
                            Center(
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _addFaculty,
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
                                    _isLoading
                                        ? const CircularProgressIndicator(
                                          color: Colors.white,
                                        )
                                        : Text(
                                          'Add Faculty',
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
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFacultyCard(
    BuildContext context,
    Map<String, dynamic> faculty,
    bool isWeb,
  ) {
    return MouseRegion(
      cursor: isWeb ? SystemMouseCursors.click : MouseCursor.defer,
      child: Card(
        elevation: isWeb ? 6 : 4,
        margin:
            isWeb
                ? const EdgeInsets.symmetric(vertical: 6)
                : const EdgeInsets.symmetric(vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
        ),
        child: Container(
          decoration:
              isWeb
                  ? BoxDecoration(
                    borderRadius: BorderRadius.circular(12.0),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        spreadRadius: 1,
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  )
                  : null,
          child: ListTile(
            contentPadding:
                isWeb
                    ? const EdgeInsets.symmetric(horizontal: 16, vertical: 8)
                    : const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            title: Text(
              faculty['name'] ?? 'Unknown',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: isWeb ? 18 : 16,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Email: ${faculty['email'] ?? 'N/A'}',
                  style: TextStyle(fontSize: isWeb ? 14 : 13),
                ),
                Text(
                  'Type: ${faculty['faculty_type'] ?? 'N/A'}',
                  style: TextStyle(fontSize: isWeb ? 14 : 13),
                ),
                Text(
                  'Dept: ${faculty['department'] ?? 'N/A'}',
                  style: TextStyle(fontSize: isWeb ? 14 : 13),
                ),
                Text(
                  'In-Charge: ${faculty['incharge'] ?? 'Not assigned'}',
                  style: TextStyle(fontSize: isWeb ? 14 : 13),
                ),
              ],
            ),
            onTap: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (context) => FacultyDetailsScreen(
                        faculty: faculty,
                        uid: faculty['uid'],
                      ),
                ),
              );
              if (result == true) {
                await _fetchFacultyList();
              }
            },
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
