import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ritian_faculty/widgets/custom_navigation_drawer.dart';

class ManageAcademicsScreen extends StatefulWidget {
  const ManageAcademicsScreen({super.key});

  @override
  _ManageAcademicsScreenState createState() => _ManageAcademicsScreenState();
}

class _ManageAcademicsScreenState extends State<ManageAcademicsScreen> {
  String? _facultyType;
  bool _isLoading = false;
  bool _showAddDeptForm = false;
  bool _showAddClassForm = false;
  String? _selectedDeptForClass;
  List<Map<String, dynamic>> _departments = [];
  Set<String> _selectedDepartments = {};
  bool _selectAll = false;
  final _deptFormKey = GlobalKey<FormState>();
  final _classFormKey = GlobalKey<FormState>();
  final _deptController = TextEditingController();
  final _classController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchUserFacultyType();
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

  Future<void> _fetchDepartments() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('academic').get();
      setState(() {
        _departments =
            snapshot.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return data;
            }).toList();
        _selectedDepartments.clear();
        _selectAll = false;
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching departments: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to fetch departments: $e')),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _addDepartment() async {
    if (!_deptFormKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not logged in.');

      final deptName = _deptController.text.trim().toUpperCase();
      final deptExists = _departments.any(
        (dept) => dept['department'] == deptName,
      );

      if (deptExists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Department already exists.')),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }

      await FirebaseFirestore.instance.collection('academic').add({
        'department': deptName,
        'classes': [],
        'created_at': FieldValue.serverTimestamp(),
        'created_by': user.uid,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Department added successfully.')),
      );

      _deptController.clear();
      setState(() {
        _showAddDeptForm = false;
      });
      await _fetchDepartments();
    } catch (e) {
      print('Error adding department: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to add department: $e')));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _addClass() async {
    if (!_classFormKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not logged in.');

      final className = _classController.text.trim().toUpperCase();
      final deptDoc = _departments.firstWhere(
        (dept) => dept['department'] == _selectedDeptForClass,
      );
      final classes = List<String>.from(deptDoc['classes'] ?? []);

      if (classes.contains(className)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Class already exists in this department.'),
          ),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }

      classes.add(className);

      await FirebaseFirestore.instance
          .collection('academic')
          .doc(deptDoc['id'])
          .update({
            'classes': classes,
            'created_at': FieldValue.serverTimestamp(),
            'created_by': user.uid,
          });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Class added successfully.')),
      );

      _classController.clear();
      setState(() {
        _showAddClassForm = false;
        _selectedDeptForClass = null;
      });
      await _fetchDepartments();
    } catch (e) {
      print('Error adding class: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to add class: $e')));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<bool> _checkDepartmentDependencies(String deptId) async {
    final dept = _departments.firstWhere((d) => d['id'] == deptId);
    final deptName = dept['department'];
    final classes = List<String>.from(dept['classes'] ?? []);

    // Check if department or its classes are linked to faculty in-charge
    final facultySnapshot =
        await FirebaseFirestore.instance
            .collection('faculty_members')
            .where('department', isEqualTo: deptName)
            .get();

    if (facultySnapshot.docs.isNotEmpty) {
      return true;
    }

    if (classes.isNotEmpty) {
      final inChargeSnapshot =
          await FirebaseFirestore.instance
              .collection('faculty_members')
              .where('incharge', whereIn: classes)
              .get();

      if (inChargeSnapshot.docs.isNotEmpty) {
        return true;
      }
    }

    return false;
  }

  Future<bool> _checkClassDependencies(String deptId, String className) async {
    final inChargeSnapshot =
        await FirebaseFirestore.instance
            .collection('faculty_members')
            .where('incharge', isEqualTo: className)
            .get();

    return inChargeSnapshot.docs.isNotEmpty;
  }

  Future<void> _deleteDepartment(String deptId) async {
    final hasDependencies = await _checkDepartmentDependencies(deptId);
    if (hasDependencies) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Cannot delete department: It is linked to faculty or classes in use.',
          ),
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Confirm Deletion'),
            content: const Text(
              'Are you sure you want to delete this department?',
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
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not logged in.');

      await FirebaseFirestore.instance
          .collection('academic')
          .doc(deptId)
          .update({
            'deleted_at': FieldValue.serverTimestamp(),
            'deleted_by': user.uid,
          });

      await FirebaseFirestore.instance
          .collection('academic')
          .doc(deptId)
          .delete();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Department deleted successfully.')),
      );

      await _fetchDepartments();
    } catch (e) {
      print('Error deleting department: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete department: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteClass(String deptId, String className) async {
    final hasDependencies = await _checkClassDependencies(deptId, className);
    if (hasDependencies) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Cannot delete class: It is assigned to a faculty in-charge.',
          ),
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Confirm Deletion'),
            content: const Text('Are you sure you want to delete this class?'),
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
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not logged in.');

      final deptDoc = _departments.firstWhere((dept) => dept['id'] == deptId);
      final classes = List<String>.from(deptDoc['classes'] ?? []);
      classes.remove(className);

      await FirebaseFirestore.instance
          .collection('academic')
          .doc(deptId)
          .update({
            'classes': classes,
            'created_at': FieldValue.serverTimestamp(),
            'created_by': user.uid,
            'deleted_at': FieldValue.serverTimestamp(),
            'deleted_by': user.uid,
          });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Class deleted successfully.')),
      );

      await _fetchDepartments();
    } catch (e) {
      print('Error deleting class: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to delete class: $e')));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteSelectedDepartments() async {
    if (_selectedDepartments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No departments selected for deletion.')),
      );
      return;
    }

    for (var deptId in _selectedDepartments) {
      final hasDependencies = await _checkDepartmentDependencies(deptId);
      if (hasDependencies) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Cannot delete one or more departments: They are linked to faculty or classes in use.',
            ),
          ),
        );
        return;
      }
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Confirm Deletion'),
            content: Text(
              'Are you sure you want to delete ${_selectedDepartments.length} selected department(s)?',
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
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not logged in.');

      final batch = FirebaseFirestore.instance.batch();
      for (var deptId in _selectedDepartments) {
        final docRef = FirebaseFirestore.instance
            .collection('academic')
            .doc(deptId);
        batch.update(docRef, {
          'deleted_at': FieldValue.serverTimestamp(),
          'deleted_by': user.uid,
        });
        batch.delete(docRef);
      }
      await batch.commit();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Deleted ${_selectedDepartments.length} department(s) successfully.',
          ),
        ),
      );

      await _fetchDepartments();
    } catch (e) {
      print('Error deleting departments: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete departments: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
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
            style: TextStyle(color: Colors.white),
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
          'Manage Departments & Classes',
          style: TextStyle(color: Colors.white),
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
    return SingleChildScrollView(
      padding: isWeb ? const EdgeInsets.all(24) : const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Departments & Classes',
                style: TextStyle(
                  fontSize: isWeb ? 28 : 24,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0C4D83),
                ),
              ),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed:
                        _selectedDepartments.isEmpty
                            ? null
                            : _deleteSelectedDepartments,
                    icon: const Icon(Icons.delete, color: Colors.white),
                    label: const Text(
                      'Delete Selected',
                      style: TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
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
                        _showAddDeptForm = !_showAddDeptForm;
                        _showAddClassForm = false;
                      });
                    },
                    icon: const Icon(Icons.add, color: Colors.white),
                    label: Text(
                      _showAddDeptForm ? 'Hide Add Dept' : 'Add Department',
                      style: const TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
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
                        _showAddClassForm = !_showAddClassForm;
                        _showAddDeptForm = false;
                      });
                    },
                    icon: const Icon(Icons.class_, color: Colors.white),
                    label: Text(
                      _showAddClassForm ? 'Hide Add Class' : 'Add Class',
                      style: const TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
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
          if (_showAddDeptForm) ...[
            Card(
              elevation: isWeb ? 8 : 6,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding:
                    isWeb ? const EdgeInsets.all(20) : const EdgeInsets.all(16),
                child: Form(
                  key: _deptFormKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Add New Department',
                        style: TextStyle(
                          fontSize: isWeb ? 20 : 18,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF0C4D83),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _deptController,
                        decoration: InputDecoration(
                          labelText: 'Department Name (e.g., CSE)',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: Colors.grey[100],
                        ),
                        validator:
                            (value) =>
                                value?.trim().isEmpty ?? true
                                    ? 'Please enter a department name'
                                    : null,
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _addDepartment,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding:
                                isWeb
                                    ? const EdgeInsets.symmetric(
                                      vertical: 14,
                                      horizontal: 30,
                                    )
                                    : const EdgeInsets.symmetric(
                                      vertical: 12,
                                      horizontal: 24,
                                    ),
                          ),
                          child:
                              _isLoading
                                  ? const CircularProgressIndicator(
                                    color: Colors.white,
                                  )
                                  : Text(
                                    'Add Department',
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
          if (_showAddClassForm) ...[
            Card(
              elevation: isWeb ? 8 : 6,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding:
                    isWeb ? const EdgeInsets.all(20) : const EdgeInsets.all(16),
                child: Form(
                  key: _classFormKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Add Class to Department',
                        style: TextStyle(
                          fontSize: isWeb ? 20 : 18,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF0C4D83),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _selectedDeptForClass,
                        decoration: InputDecoration(
                          labelText: 'Select Department',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: Colors.grey[100],
                        ),
                        items:
                            _departments
                                .where((dept) => dept['department'] != null)
                                .map(
                                  (dept) => DropdownMenuItem<String>(
                                    value: dept['department'] as String,
                                    child: Text(dept['department'] as String),
                                  ),
                                )
                                .toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedDeptForClass = value;
                          });
                        },
                        validator:
                            (value) =>
                                value == null
                                    ? 'Please select a department'
                                    : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _classController,
                        decoration: InputDecoration(
                          labelText: 'Class Name (e.g., CSE-A)',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: Colors.grey[100],
                        ),
                        validator:
                            (value) =>
                                value?.trim().isEmpty ?? true
                                    ? 'Please enter a class name'
                                    : null,
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _addClass,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding:
                                isWeb
                                    ? const EdgeInsets.symmetric(
                                      vertical: 14,
                                      horizontal: 30,
                                    )
                                    : const EdgeInsets.symmetric(
                                      vertical: 12,
                                      horizontal: 24,
                                    ),
                          ),
                          child:
                              _isLoading
                                  ? const CircularProgressIndicator(
                                    color: Colors.white,
                                  )
                                  : Text(
                                    'Add Class',
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
                      _selectedDepartments =
                          _departments
                              .map((dept) => dept['id'] as String)
                              .toSet();
                    } else {
                      _selectedDepartments.clear();
                    }
                  });
                },
              ),
              const Text('Select All', style: TextStyle(fontSize: 16)),
            ],
          ),
          const SizedBox(height: 16),
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _departments.isEmpty
              ? const Center(child: Text('No departments found.'))
              : isWeb
              ? _buildWebTable()
              : _buildMobileList(),
        ],
      ),
    );
  }

  Widget _buildWebTable() {
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
                        _selectedDepartments =
                            _departments
                                .map((dept) => dept['id'] as String)
                                .toSet();
                      } else {
                        _selectedDepartments.clear();
                      }
                    });
                  },
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
                flex: 4,
                child: Text(
                  'Classes',
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
          itemCount: _departments.length,
          itemBuilder: (context, index) {
            final dept = _departments[index];
            final classes = List<String>.from(dept['classes'] ?? []);
            return Card(
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 1,
                      child: Checkbox(
                        value: _selectedDepartments.contains(dept['id']),
                        onChanged: (value) {
                          setState(() {
                            if (value == true) {
                              _selectedDepartments.add(dept['id']);
                            } else {
                              _selectedDepartments.remove(dept['id']);
                            }
                            _selectAll =
                                _selectedDepartments.length ==
                                _departments.length;
                          });
                        },
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        dept['department'] ?? 'Unknown',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 4,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children:
                            classes.isEmpty
                                ? [
                                  const Text(
                                    'No classes',
                                    style: TextStyle(fontSize: 15),
                                  ),
                                ]
                                : classes.map((className) {
                                  return Chip(
                                    label: Text(
                                      className,
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                    deleteIcon: const Icon(
                                      Icons.delete,
                                      size: 18,
                                    ),
                                    onDeleted:
                                        () =>
                                            _deleteClass(dept['id'], className),
                                  );
                                }).toList(),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        tooltip: 'Delete Department',
                        onPressed: () => _deleteDepartment(dept['id']),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildMobileList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _departments.length,
      itemBuilder: (context, index) {
        final dept = _departments[index];
        final classes = List<String>.from(dept['classes'] ?? []);
        return Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: _selectedDepartments.contains(dept['id']),
                  onChanged: (value) {
                    setState(() {
                      if (value == true) {
                        _selectedDepartments.add(dept['id']);
                      } else {
                        _selectedDepartments.remove(dept['id']);
                      }
                      _selectAll =
                          _selectedDepartments.length == _departments.length;
                    });
                  },
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dept['department'] ?? 'Unknown',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children:
                            classes.isEmpty
                                ? [
                                  const Text(
                                    'No classes',
                                    style: TextStyle(fontSize: 14),
                                  ),
                                ]
                                : classes.map((className) {
                                  return Chip(
                                    label: Text(
                                      className,
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                    deleteIcon: const Icon(
                                      Icons.delete,
                                      size: 18,
                                    ),
                                    onDeleted:
                                        () =>
                                            _deleteClass(dept['id'], className),
                                  );
                                }).toList(),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  tooltip: 'Delete Department',
                  onPressed: () => _deleteDepartment(dept['id']),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
