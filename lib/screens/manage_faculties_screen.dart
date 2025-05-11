import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:ritian_faculty/widgets/custom_navigation_drawer.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:convert';
import 'package:permission_handler/permission_handler.dart';
import 'package:universal_html/html.dart'
    if (dart.library.html) 'dart:html'
    as html;
import 'package:ritian_faculty/screens/faculty_details_screen.dart';

class ManageFacultiesScreen extends StatefulWidget {
  const ManageFacultiesScreen({super.key});

  @override
  _ManageFacultiesScreenState createState() => _ManageFacultiesScreenState();
}

class _ManageFacultiesScreenState extends State<ManageFacultiesScreen> {
  String? _selectedDepartment;
  String? _selectedFacultyType;
  String _searchQuery = '';
  List<Map<String, dynamic>> _faculties = [];
  List<Map<String, dynamic>> _filteredFaculties = [];
  List<String> _classes = [];
  List<String> _departments = [];
  bool _isLoading = false;
  bool _selectAll = false;
  bool _showAddForm = false;
  Set<String> _selectedFaculties = {};
  String? _facultyType;

  final List<String> _facultyTypes = [
    'All',
    'Associate Professor',
    'HoD',
    'Admin',
  ];

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _biometricIdController = TextEditingController();
  final _ageController = TextEditingController();
  final _birthdayController = TextEditingController();
  final _dateOfJoiningController = TextEditingController();
  String? _selectedFormDepartment;
  final _highestDegreeController = TextEditingController();
  final _phoneController = TextEditingController();
  final _religionController = TextEditingController();
  final _staffCodeController = TextEditingController();
  final _totalExperienceController = TextEditingController();
  String? _selectedFormFacultyType;

  Map<String, bool> _exportFields = {
    'name': true,
    'email': true,
    'staffCode': true,
    'department': true,
    'faculty_type': true,
    'incharge': false,
  };

  @override
  void initState() {
    super.initState();
    _fetchUserFacultyType();
    _fetchFaculties();
    _fetchClasses();
    _fetchDepartments();
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

  Future<void> _fetchFaculties() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('faculty_members').get();
      List<Map<String, dynamic>> faculties = [];
      for (var doc in snapshot.docs) {
        final facultyData = doc.data();
        facultyData['uid'] = doc.id;
        if (facultyData['uid'] == null || facultyData['name'] == null) {
          print('Skipping invalid faculty data: $facultyData');
          continue;
        }
        faculties.add(facultyData);
      }
      setState(() {
        _faculties = faculties;
        _filteredFaculties = faculties;
        _selectedFaculties.clear();
        _selectAll = false;
        _isLoading = false;
      });
      _applyFilters();
    } catch (e) {
      print('Error fetching faculties: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to fetch faculties: $e')),
        );
      }
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchClasses() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('academic').get();
      final classList = <String>{};
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final deptClasses = List<String>.from(data['classes'] ?? []);
        classList.addAll(deptClasses);
      }
      setState(() {
        _classes = classList.toList()..sort();
        print('Fetched classes: $_classes');
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

  Future<void> _fetchDepartments() async {
    try {
      print('Fetching departments from Firestore academic collection...');
      final snapshot =
          await FirebaseFirestore.instance.collection('academic').get();
      print(
        'Fetched ${snapshot.docs.length} documents from academic collection',
      );
      final deptList = <String>[];
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final deptName = data['department']?.toString();
        if (deptName != null && deptName.isNotEmpty) {
          deptList.add(deptName);
        } else {
          print(
            'Skipping document ${doc.id}: Missing or empty department field',
          );
        }
      }
      setState(() {
        _departments = ['All', ...deptList.toSet()]..sort();
        print('Updated departments: $_departments');
      });
      if (deptList.isEmpty) {
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
        _departments = ['All'];
      });
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredFaculties =
          _faculties.where((faculty) {
            final matchesDepartment =
                _selectedDepartment == null ||
                _selectedDepartment == 'All' ||
                faculty['department'] == _selectedDepartment;
            final matchesFacultyType =
                _selectedFacultyType == null ||
                _selectedFacultyType == 'All' ||
                faculty['faculty_type'] == _selectedFacultyType;
            final matchesSearch =
                _searchQuery.isEmpty ||
                (faculty['name']?.toLowerCase() ?? '').contains(
                  _searchQuery.toLowerCase(),
                ) ||
                (faculty['email']?.toLowerCase() ?? '').contains(
                  _searchQuery.toLowerCase(),
                ) ||
                (faculty['staffCode']?.toLowerCase() ?? '').contains(
                  _searchQuery.toLowerCase(),
                );
            return matchesDepartment && matchesFacultyType && matchesSearch;
          }).toList();
    });
  }

  Future<void> _showExportDialog() async {
    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Select Fields to Export'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children:
                      _exportFields.keys.map((field) {
                        return CheckboxListTile(
                          title: Text(
                            field == 'staffCode'
                                ? 'Staff Code'
                                : field == 'faculty_type'
                                ? 'Faculty Type'
                                : field == 'incharge'
                                ? 'Class In-Charge'
                                : _capitalize(field),
                          ),
                          value: _exportFields[field],
                          onChanged: (value) {
                            setState(() {
                              _exportFields[field] = value!;
                            });
                          },
                        );
                      }).toList(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _exportToExcel();
                  },
                  child: const Text('Export'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _exportToExcel() async {
    if (!_exportFields.values.any((value) => value)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one field to export'),
        ),
      );
      return;
    }
    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Preparing Excel file...')),
        );
      }
      var excel = Excel.createExcel();
      Sheet sheet = excel['Faculties'];
      List<String> headers = [];
      _exportFields.forEach((field, isSelected) {
        if (isSelected) {
          headers.add(
            field == 'staffCode'
                ? 'Staff Code'
                : field == 'faculty_type'
                ? 'Faculty Type'
                : field == 'incharge'
                ? 'Class In-Charge'
                : _capitalize(field),
          );
        }
      });
      sheet.appendRow(headers.map((header) => TextCellValue(header)).toList());
      for (var faculty in _filteredFaculties) {
        List<String> row = [];
        _exportFields.forEach((field, isSelected) {
          if (isSelected) {
            row.add(faculty[field]?.toString() ?? 'N/A');
          }
        });
        sheet.appendRow(row.map((cell) => TextCellValue(cell)).toList());
      }
      final List<int>? encodedBytes = excel.encode();
      if (encodedBytes == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to generate Excel file.')),
        );
        return;
      }
      if (kIsWeb) {
        final content = base64Encode(encodedBytes);
        final anchor =
            html.AnchorElement(
                href:
                    'data:application/vnd.openxmlformats-officedocument.spreadsheetml.sheet;base64,$content',
              )
              ..setAttribute('download', 'faculties.xlsx')
              ..click();
      } else if (Platform.isAndroid || Platform.isIOS) {
        if (Platform.isAndroid) {
          final status = await Permission.storage.request();
          if (!status.isGranted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Storage permission denied. Cannot share file.'),
              ),
            );
            return;
          }
        }
        final directory = await getTemporaryDirectory();
        final filePath = '${directory.path}/faculties.xlsx';
        final file = File(filePath);
        await file.writeAsBytes(encodedBytes, flush: true);
        await Share.shareXFiles([XFile(filePath)], text: 'Faculty Excel File');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Export not supported on this platform.'),
          ),
        );
      }
    } catch (e) {
      print('Error exporting to Excel: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to export: $e')));
    }
  }

  Future<void> _addFaculty() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
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

          await FirebaseAuth.instance.signOut();
          await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: adminEmail!,
            password: adminPassword,
          );
        } else {
          final querySnapshot =
              await FirebaseFirestore.instance
                  .collection('faculty_members')
                  .where('email', isEqualTo: email)
                  .get();
          if (querySnapshot.docs.isNotEmpty) {
            uid = querySnapshot.docs.first.id;
          } else {
            final UserCredential userCredential = await FirebaseAuth.instance
                .createUserWithEmailAndPassword(
                  email: email,
                  password: 'Dummy123',
                );
            uid = userCredential.user!.uid;

            await FirebaseAuth.instance.signOut();
            await FirebaseAuth.instance.signInWithEmailAndPassword(
              email: adminEmail!,
              password: adminPassword,
            );
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
        'faculty_type': _selectedFormFacultyType,
        'age': int.parse(_ageController.text.trim()),
        'birthday': _birthdayController.text.trim(),
        'date_of_joining': _dateOfJoiningController.text.trim(),
        'department': _selectedFormDepartment,
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

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Faculty added successfully.')),
      );

      await _fetchFaculties();

      _nameController.clear();
      _emailController.clear();
      _biometricIdController.clear();
      _ageController.clear();
      _birthdayController.clear();
      _dateOfJoiningController.clear();
      _highestDegreeController.clear();
      _phoneController.clear();
      _religionController.clear();
      _staffCodeController.clear();
      _totalExperienceController.clear();
      setState(() {
        _selectedFormFacultyType = null;
        _selectedFormDepartment = null;
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
                onPressed: () => Navigator.pop(context),
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

  Future<void> _deleteSelectedFaculties() async {
    if (_selectedFaculties.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No faculties selected for deletion.')),
      );
      return;
    }

    final currentUserUid = FirebaseAuth.instance.currentUser?.uid;
    if (_selectedFaculties.contains(currentUserUid)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot delete the current user.')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Confirm Deletion'),
            content: Text(
              'Are you sure you want to delete ${_selectedFaculties.length} selected faculty member(s)? This action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );

    if (confirm != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final batch = FirebaseFirestore.instance.batch();
      for (var uid in _selectedFaculties) {
        final facultyDoc = FirebaseFirestore.instance
            .collection('faculty_members')
            .doc(uid);
        batch.delete(facultyDoc);
      }
      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Deleted ${_selectedFaculties.length} faculty member(s) from Firestore. Firebase Auth accounts remain active. Set up Cloud Functions to delete Auth accounts.',
            ),
          ),
        );
      }

      await _fetchFaculties();
    } catch (e) {
      print('Error deleting faculties: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete faculties: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _assignClassInCharge(
    String facultyUid,
    String? currentClass,
  ) async {
    String? selectedClass;

    await showDialog(
      context: context,
      builder: (context) {
        String? tempSelectedClass = currentClass;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Assign Class In-Charge'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: tempSelectedClass,
                    decoration: InputDecoration(
                      labelText: 'Select Class',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('None')),
                      ..._classes.map(
                        (className) => DropdownMenuItem(
                          value: className,
                          child: Text(className),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        tempSelectedClass = value;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    selectedClass = tempSelectedClass;
                    Navigator.pop(context);
                  },
                  child: const Text('Assign'),
                ),
              ],
            );
          },
        );
      },
    );

    if (selectedClass == currentClass) return;

    try {
      setState(() {
        _isLoading = true;
      });

      if (selectedClass != null) {
        final existingAssignment =
            await FirebaseFirestore.instance
                .collection('faculty_members')
                .where('incharge', isEqualTo: selectedClass)
                .get();
        if (existingAssignment.docs.isNotEmpty) {
          final batch = FirebaseFirestore.instance.batch();
          for (var doc in existingAssignment.docs) {
            batch.update(doc.reference, {'incharge': null});
          }
          await batch.commit();
        }
      }

      await FirebaseFirestore.instance
          .collection('faculty_members')
          .doc(facultyUid)
          .update({'incharge': selectedClass});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Class in-charge ${selectedClass ?? 'unassigned'} successfully.',
          ),
        ),
      );

      await _fetchFaculties();
    } catch (e) {
      print('Error assigning class in-charge: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to assign class in-charge: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final bool isWeb = MediaQuery.of(context).size.width > 800;

    if (_facultyType == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_facultyType != 'Admin') {
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
          'Manage Faculties',
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
        return SingleChildScrollView(
          child: Padding(
            padding:
                isWeb
                    ? const EdgeInsets.fromLTRB(24, 24, 24, 16)
                    : const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Faculties List',
                      style: TextStyle(
                        fontSize: isWeb ? 28 : 24,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0C4D83),
                      ),
                    ),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: _showExportDialog,
                          icon: const Icon(Icons.download, color: Colors.white),
                          label: const Text(
                            'Export as Excel',
                            style: TextStyle(color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            padding: EdgeInsets.symmetric(
                              horizontal: isWeb ? 20 : 16,
                              vertical: isWeb ? 12 : 10,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              _showAddForm = !_showAddForm;
                            });
                          },
                          icon: const Icon(Icons.add, color: Colors.white),
                          label: Text(
                            _showAddForm ? 'Hide Add Form' : 'Add Faculty',
                            style: const TextStyle(color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            padding: EdgeInsets.symmetric(
                              horizontal: isWeb ? 20 : 16,
                              vertical: isWeb ? 12 : 10,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed:
                              _selectedFaculties.isEmpty
                                  ? null
                                  : _deleteSelectedFaculties,
                          icon: const Icon(Icons.delete, color: Colors.white),
                          label: const Text(
                            'Delete Selected',
                            style: TextStyle(color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            padding: EdgeInsets.symmetric(
                              horizontal: isWeb ? 20 : 16,
                              vertical: isWeb ? 12 : 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_showAddForm) ...[
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
                              'Add Faculty Details',
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
                              value: _selectedFormFacultyType,
                              decoration: InputDecoration(
                                labelText: 'Faculty Type',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
                                filled: true,
                                fillColor: Colors.grey[100],
                              ),
                              items:
                                  ['Associate Professor', 'HoD', 'Admin']
                                      .map(
                                        (type) => DropdownMenuItem(
                                          value: type,
                                          child: Text(type),
                                        ),
                                      )
                                      .toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedFormFacultyType = value;
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
                            DropdownButtonFormField<String>(
                              value: _selectedFormDepartment,
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
                                      .where((dept) => dept != 'All')
                                      .map(
                                        (dept) => DropdownMenuItem(
                                          value: dept,
                                          child: Text(dept),
                                        ),
                                      )
                                      .toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedFormDepartment = value;
                                  print('Selected department: $value');
                                });
                              },
                              validator:
                                  (value) =>
                                      value == null
                                          ? 'Please select a department'
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
                  const SizedBox(height: 16),
                ],
                Row(
                  children: [
                    Checkbox(
                      value: _selectAll,
                      onChanged: (value) {
                        setState(() {
                          _selectAll = value!;
                          if (_selectAll) {
                            _selectedFaculties =
                                _filteredFaculties
                                    .map((faculty) => faculty['uid'] as String)
                                    .toSet();
                          } else {
                            _selectedFaculties.clear();
                          }
                        });
                      },
                    ),
                    const Text('Select All', style: TextStyle(fontSize: 16)),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  decoration: InputDecoration(
                    labelText: 'Search by Name, Email, or Staff Code',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    filled: true,
                    fillColor: Colors.grey[100],
                    prefixIcon: const Icon(Icons.search),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                      _applyFilters();
                      _selectedFaculties.clear();
                      _selectAll = false;
                    });
                  },
                ),
                const SizedBox(height: 16),
                isWeb
                    ? Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedDepartment ?? 'All',
                            decoration: InputDecoration(
                              labelText: 'Filter by Department',
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
                                        child: Text(
                                          dept,
                                          style: TextStyle(
                                            fontSize: isWeb ? 16 : 14,
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedDepartment = value;
                                _applyFilters();
                                _selectedFaculties.clear();
                                _selectAll = false;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedFacultyType ?? 'All',
                            decoration: InputDecoration(
                              labelText: 'Filter by Faculty Type',
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
                                        child: Text(
                                          type,
                                          style: TextStyle(
                                            fontSize: isWeb ? 16 : 14,
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedFacultyType = value;
                                _applyFilters();
                                _selectedFaculties.clear();
                                _selectAll = false;
                              });
                            },
                          ),
                        ),
                      ],
                    )
                    : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DropdownButtonFormField<String>(
                          value: _selectedDepartment ?? 'All',
                          decoration: InputDecoration(
                            labelText: 'Filter by Department',
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
                                      child: Text(
                                        dept,
                                        style: TextStyle(
                                          fontSize: isWeb ? 16 : 14,
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedDepartment = value;
                              _applyFilters();
                              _selectedFaculties.clear();
                              _selectAll = false;
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: _selectedFacultyType ?? 'All',
                          decoration: InputDecoration(
                            labelText: 'Filter by Faculty Type',
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
                                      child: Text(
                                        type,
                                        style: TextStyle(
                                          fontSize: isWeb ? 16 : 14,
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedFacultyType = value;
                              _applyFilters();
                              _selectedFaculties.clear();
                              _selectAll = false;
                            });
                          },
                        ),
                      ],
                    ),
                const SizedBox(height: 16),
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _filteredFaculties.isEmpty
                    ? const Center(child: Text('No faculties found.'))
                    : isWeb
                    ? _buildWebFacultyTable()
                    : _buildMobileFacultyList(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildWebFacultyTable() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 1,
                child: Checkbox(
                  value: _selectAll,
                  onChanged: (value) {
                    setState(() {
                      _selectAll = value!;
                      if (_selectAll) {
                        _selectedFaculties =
                            _filteredFaculties
                                .map((faculty) => faculty['uid'] as String)
                                .toSet();
                      } else {
                        _selectedFaculties.clear();
                      }
                    });
                  },
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Name',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.grey[800],
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Email',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.grey[800],
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Staff Code',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.grey[800],
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Department',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.grey[800],
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Faculty Type',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.grey[800],
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Class In-Charge',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.grey[800],
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Actions',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.grey[800],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemCount: _filteredFaculties.length,
          itemBuilder: (context, index) {
            final faculty = _filteredFaculties[index];
            return GestureDetector(
              onTap: () {
                if (faculty['uid'] == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Invalid faculty data: Missing UID'),
                    ),
                  );
                  return;
                }
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) => EditFacultyScreen(
                          faculty: faculty,
                          onUpdate: _fetchFaculties,
                        ),
                  ),
                );
              },
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 16,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 1,
                        child: Checkbox(
                          value: _selectedFaculties.contains(faculty['uid']),
                          onChanged: (value) {
                            setState(() {
                              if (value == true) {
                                _selectedFaculties.add(faculty['uid']);
                              } else {
                                _selectedFaculties.remove(faculty['uid']);
                              }
                              _selectAll =
                                  _selectedFaculties.length ==
                                  _filteredFaculties.length;
                            });
                          },
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          faculty['name']?.toString() ?? 'Unknown',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          faculty['email']?.toString() ?? 'N/A',
                          style: const TextStyle(
                            fontSize: 15,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          faculty['staffCode']?.toString() ?? 'N/A',
                          style: const TextStyle(
                            fontSize: 15,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          faculty['department']?.toString() ?? 'N/A',
                          style: const TextStyle(
                            fontSize: 15,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          faculty['faculty_type']?.toString() ?? 'N/A',
                          style: const TextStyle(
                            fontSize: 15,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          faculty['incharge']?.toString() ?? 'Not assigned',
                          style: const TextStyle(
                            fontSize: 15,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.info, color: Colors.blue),
                              tooltip: 'View Details',
                              onPressed: () async {
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
                                  await _fetchFaculties();
                                }
                              },
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.class_,
                                color: Colors.green,
                              ),
                              tooltip: 'Assign Class In-Charge',
                              onPressed: () {
                                _assignClassInCharge(
                                  faculty['uid'],
                                  faculty['incharge'],
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildMobileFacultyList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _filteredFaculties.length,
      itemBuilder: (context, index) {
        final faculty = _filteredFaculties[index];
        return GestureDetector(
          onTap: () {
            if (faculty['uid'] == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Invalid faculty data: Missing UID'),
                ),
              );
              return;
            }
            Navigator.push(
              context,
              MaterialPageRoute(
                builder:
                    (context) => EditFacultyScreen(
                      faculty: faculty,
                      onUpdate: _fetchFaculties,
                    ),
              ),
            );
          },
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Checkbox(
                    value: _selectedFaculties.contains(faculty['uid']),
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          _selectedFaculties.add(faculty['uid']);
                        } else {
                          _selectedFaculties.remove(faculty['uid']);
                        }
                        _selectAll =
                            _selectedFaculties.length ==
                            _filteredFaculties.length;
                      });
                    },
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          faculty['name']?.toString() ?? 'Unknown',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Email: ${faculty['email']?.toString() ?? 'N/A'}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Staff Code: ${faculty['staffCode']?.toString() ?? 'N/A'}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Dept: ${faculty['department']?.toString() ?? 'N/A'}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Type: ${faculty['faculty_type']?.toString() ?? 'N/A'}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'In-Charge: ${faculty['incharge']?.toString() ?? 'Not assigned'}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.info, color: Colors.blue),
                        tooltip: 'View Details',
                        onPressed: () async {
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
                            await _fetchFaculties();
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.class_, color: Colors.green),
                        tooltip: 'Assign Class In-Charge',
                        onPressed: () {
                          _assignClassInCharge(
                            faculty['uid'],
                            faculty['incharge'],
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class EditFacultyScreen extends StatefulWidget {
  final Map<String, dynamic> faculty;
  final VoidCallback onUpdate;

  const EditFacultyScreen({
    super.key,
    required this.faculty,
    required this.onUpdate,
  });

  @override
  _EditFacultyScreenState createState() => _EditFacultyScreenState();
}

class _EditFacultyScreenState extends State<EditFacultyScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _biometricIdController;
  late TextEditingController _ageController;
  late TextEditingController _birthdayController;
  late TextEditingController _dateOfJoiningController;
  late TextEditingController _departmentController;
  late TextEditingController _highestDegreeController;
  late TextEditingController _phoneController;
  late TextEditingController _religionController;
  late TextEditingController _staffCodeController;
  late TextEditingController _totalExperienceController;
  String? _selectedFacultyType;
  bool _isLoading = false;

  final List<String> _facultyTypes = ['Associate Professor', 'HoD', 'Admin'];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.faculty['name']?.toString() ?? '',
    );
    _emailController = TextEditingController(
      text: widget.faculty['email']?.toString() ?? '',
    );
    _biometricIdController = TextEditingController(
      text: widget.faculty['biometric_id']?.toString() ?? '',
    );
    _ageController = TextEditingController(
      text: widget.faculty['age']?.toString() ?? '',
    );
    _birthdayController = TextEditingController(
      text: widget.faculty['birthday']?.toString() ?? '',
    );
    _dateOfJoiningController = TextEditingController(
      text: widget.faculty['date_of_joining']?.toString() ?? '',
    );
    _departmentController = TextEditingController(
      text: widget.faculty['department']?.toString() ?? '',
    );
    _highestDegreeController = TextEditingController(
      text: widget.faculty['highest_degree']?.toString() ?? '',
    );
    _phoneController = TextEditingController(
      text: widget.faculty['phone']?.toString() ?? '',
    );
    _religionController = TextEditingController(
      text: widget.faculty['religion']?.toString() ?? '',
    );
    _staffCodeController = TextEditingController(
      text: widget.faculty['staff_code']?.toString() ?? '',
    );
    _totalExperienceController = TextEditingController(
      text: widget.faculty['total_experience']?.toString() ?? '',
    );

    String? type = widget.faculty['faculty_type']?.toString();
    if (type != null && _facultyTypes.contains(type)) {
      _selectedFacultyType = type;
    } else {
      _selectedFacultyType = _facultyTypes.first;
      if (type != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Faculty type "$type" is invalid. Defaulting to ${_facultyTypes.first}.',
                ),
              ),
            );
          }
        });
      }
    }
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
    super.dispose();
  }

  Future<void> _saveChanges() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });
      try {
        await FirebaseFirestore.instance
            .collection('faculty_members')
            .doc(widget.faculty['uid'])
            .update({
              'name': _nameController.text.trim(),
              'email': _emailController.text.trim(),
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
            });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Faculty updated successfully')),
          );
        }
        widget.onUpdate();
        Navigator.pop(context);
      } catch (e) {
        print('Error updating faculty: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to update faculty: $e')),
          );
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
        title: const Text(
          'Edit Faculty',
          style: TextStyle(color: Colors.white),
        ),
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
                        validator:
                            (value) =>
                                value?.trim().isEmpty ?? true
                                    ? 'Please enter a name'
                                    : null,
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
                      const SizedBox(height: 16),
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
                      const SizedBox(height: 16),
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
                      const SizedBox(height: 16),
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
                      const SizedBox(height: 16),
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
                      const SizedBox(height: 16),
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
                      const SizedBox(height: 16),
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
                      const SizedBox(height: 16),
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
                      const SizedBox(height: 16),
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
                      const SizedBox(height: 16),
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
                      const SizedBox(height: 16),
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
                      const SizedBox(height: 16),
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
                      const SizedBox(height: 30),
                      Center(
                        child: ElevatedButton(
                          onPressed: _saveChanges,
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
                            'Save Changes',
                            style: TextStyle(fontSize: 16, color: Colors.white),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
    );
  }
}
