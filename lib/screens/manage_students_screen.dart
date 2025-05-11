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
import 'package:flutter/services.dart';
import 'add_student_screen.dart'; // Import the AddStudentScreen

class ManageStudentsScreen extends StatefulWidget {
  const ManageStudentsScreen({super.key});

  @override
  _ManageStudentsScreenState createState() => _ManageStudentsScreenState();
}

class _ManageStudentsScreenState extends State<ManageStudentsScreen> {
  String? _selectedDepartment;
  String? _selectedYear;
  String _searchQuery = '';
  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _filteredStudents = [];
  bool _isLoading = false;
  bool _selectAll = false;
  Set<String> _selectedStudents = {};

  final List<String> _departments = ['All', 'CSE', 'ECE', 'MECH', 'AIDS'];
  final List<String> _years = [
    'All',
    'First Year',
    'Second Year',
    'Third Year',
    'Fourth Year',
  ];

  Map<String, bool> _exportFields = {
    'name': true,
    'regdNumber': true,
    'department': true,
    'year': true,
    'class': true,
    'email': false,
  };

  @override
  void initState() {
    super.initState();
    _fetchStudents();
  }

  Future<void> _fetchStudents() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final usersSnapshot =
          await FirebaseFirestore.instance.collection('users').get();
      List<Map<String, dynamic>> students = [];
      for (var userDoc in usersSnapshot.docs) {
        final studentData = userDoc.data();
        studentData['uid'] = userDoc.id;
        // Validate required fields
        if (studentData['uid'] == null || studentData['name'] == null) {
          print('Skipping invalid student data: $studentData');
          continue;
        }
        students.add(studentData);
      }
      setState(() {
        _students = students;
        _filteredStudents = students;
        _selectedStudents.clear();
        _selectAll = false;
        _isLoading = false;
      });
      _applyFilters();
    } catch (e) {
      print('Error fetching students: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to fetch students: $e')));
      }
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredStudents =
          _students.where((student) {
            final matchesDepartment =
                _selectedDepartment == null ||
                _selectedDepartment == 'All' ||
                student['department'] == _selectedDepartment;
            final matchesYear =
                _selectedYear == null ||
                _selectedYear == 'All' ||
                student['year'] == _selectedYear;
            final matchesSearch =
                _searchQuery.isEmpty ||
                (student['name']?.toLowerCase() ?? '').contains(
                  _searchQuery.toLowerCase(),
                ) ||
                (student['regdNumber']?.toLowerCase() ?? '').contains(
                  _searchQuery.toLowerCase(),
                );
            return matchesDepartment && matchesYear && matchesSearch;
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
                            field == 'regdNumber'
                                ? 'Registration Number'
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
      Sheet sheet = excel['Students'];
      List<String> headers = [];
      _exportFields.forEach((field, isSelected) {
        if (isSelected) {
          headers.add(
            field == 'regdNumber' ? 'Registration Number' : _capitalize(field),
          );
        }
      });
      sheet.appendRow(headers.map((header) => TextCellValue(header)).toList());
      for (var student in _filteredStudents) {
        List<String> row = [];
        _exportFields.forEach((field, isSelected) {
          if (isSelected) {
            row.add(student[field]?.toString() ?? 'N/A');
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
              ..setAttribute('download', 'students.xlsx')
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
        final filePath = '${directory.path}/students.xlsx';
        final file = File(filePath);
        await file.writeAsBytes(encodedBytes, flush: true);
        await Share.shareXFiles([XFile(filePath)], text: 'Student Excel File');
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

  Future<void> _deleteSelectedStudents() async {
    if (_selectedStudents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No students selected for deletion.')),
      );
      return;
    }

    // Prevent deletion of the current user's account
    final currentUserUid = FirebaseAuth.instance.currentUser?.uid;
    if (_selectedStudents.contains(currentUserUid)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot delete the current user.')),
      );
      return;
    }

    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Confirm Deletion'),
            content: Text(
              'Are you sure you want to delete ${_selectedStudents.length} selected student(s)? This action cannot be undone.',
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
      // Client-Side Workaround: Delete Firestore documents only
      final batch = FirebaseFirestore.instance.batch();
      for (var uid in _selectedStudents) {
        final studentDoc = FirebaseFirestore.instance
            .collection('users')
            .doc(uid);
        batch.delete(studentDoc);
      }
      await batch.commit();

      // Warn that Auth accounts are not deleted
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Deleted ${_selectedStudents.length} student(s) from Firestore. Firebase Auth accounts remain active. Set up Cloud Functions to delete Auth accounts.',
            ),
          ),
        );
      }

      // Server-Side Solution (Uncomment after setting up Cloud Functions):
      /*
      final callable = FirebaseFunctions.instance.httpsCallable('deleteStudents');
      final result = await callable.call({
        'uids': _selectedStudents.toList(),
      });

      if (result.data['success']) {
        // Firestore deletion is handled by the Cloud Function, but confirm locally
        final batch = FirebaseFirestore.instance.batch();
        for (var uid in _selectedStudents) {
          final studentDoc =
              FirebaseFirestore.instance.collection('users').doc(uid);
          batch.delete(studentDoc);
        }
        await batch.commit();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Deleted ${_selectedStudents.length} student(s) successfully.',
              ),
            ),
          );
        }
      } else {
        throw Exception(result.data['error'] ?? 'Failed to delete students.');
      }
      */

      // Refresh the student list
      await _fetchStudents();
    } catch (e) {
      print('Error deleting students: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete students: $e')),
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

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final bool isWeb = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Manage Students',
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
                      'Students List',
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
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) =>
                                        AddStudentScreen(onAdd: _fetchStudents),
                              ),
                            );
                          },
                          icon: const Icon(Icons.add, color: Colors.white),
                          label: const Text(
                            'Add Student',
                            style: TextStyle(color: Colors.white),
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
                              _selectedStudents.isEmpty
                                  ? null
                                  : _deleteSelectedStudents,
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
                // Select All Checkbox
                Row(
                  children: [
                    Checkbox(
                      value: _selectAll,
                      onChanged: (value) {
                        setState(() {
                          _selectAll = value!;
                          if (_selectAll) {
                            _selectedStudents =
                                _filteredStudents
                                    .map((student) => student['uid'] as String)
                                    .toSet();
                          } else {
                            _selectedStudents.clear();
                          }
                        });
                      },
                    ),
                    const Text('Select All', style: TextStyle(fontSize: 16)),
                  ],
                ),
                const SizedBox(height: 16),
                // Search Field
                TextField(
                  decoration: InputDecoration(
                    labelText: 'Search by Name or Registration Number',
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
                      // Clear selections when filtering
                      _selectedStudents.clear();
                      _selectAll = false;
                    });
                  },
                ),
                const SizedBox(height: 16),
                // Filters
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
                                // Clear selections when filtering
                                _selectedStudents.clear();
                                _selectAll = false;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedYear ?? 'All',
                            decoration: InputDecoration(
                              labelText: 'Filter by Year',
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
                                        child: Text(
                                          year,
                                          style: TextStyle(
                                            fontSize: isWeb ? 16 : 14,
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedYear = value;
                                _applyFilters();
                                // Clear selections when filtering
                                _selectedStudents.clear();
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
                              // Clear selections when filtering
                              _selectedStudents.clear();
                              _selectAll = false;
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: _selectedYear ?? 'All',
                          decoration: InputDecoration(
                            labelText: 'Filter by Year',
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
                                      child: Text(
                                        year,
                                        style: TextStyle(
                                          fontSize: isWeb ? 16 : 14,
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedYear = value;
                              _applyFilters();
                              // Clear selections when filtering
                              _selectedStudents.clear();
                              _selectAll = false;
                            });
                          },
                        ),
                      ],
                    ),
                const SizedBox(height: 16),
                // Student List
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _filteredStudents.isEmpty
                    ? const Center(child: Text('No students found.'))
                    : isWeb
                    ? _buildWebStudentTable()
                    : _buildMobileStudentList(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildWebStudentTable() {
    return Column(
      children: [
        // Header Row
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
                        _selectedStudents =
                            _filteredStudents
                                .map((student) => student['uid'] as String)
                                .toSet();
                      } else {
                        _selectedStudents.clear();
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
                  'Regd Number',
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
                  'Year',
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
                  'Class',
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
                flex: 1,
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
        // Student Rows
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemCount: _filteredStudents.length,
          itemBuilder: (context, index) {
            final student = _filteredStudents[index];
            // Log student data for debugging
            print('Student $index: $student');
            return GestureDetector(
              onTap: () {
                if (student['uid'] == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Invalid student data: Missing UID'),
                    ),
                  );
                  return;
                }
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) => EditStudentScreen(
                          student: student,
                          onUpdate: _fetchStudents,
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
                          value: _selectedStudents.contains(student['uid']),
                          onChanged: (value) {
                            setState(() {
                              if (value == true) {
                                _selectedStudents.add(student['uid']);
                              } else {
                                _selectedStudents.remove(student['uid']);
                              }
                              // Update select all state
                              _selectAll =
                                  _selectedStudents.length ==
                                  _filteredStudents.length;
                            });
                          },
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          student['name']?.toString() ?? 'Unknown',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          student['regdNumber']?.toString() ?? 'N/A',
                          style: const TextStyle(
                            fontSize: 15,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          student['department']?.toString() ?? 'N/A',
                          style: const TextStyle(
                            fontSize: 15,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          student['year']?.toString() ?? 'N/A',
                          style: const TextStyle(
                            fontSize: 15,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          student['class']?.toString() ?? 'N/A',
                          style: const TextStyle(
                            fontSize: 15,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          student['email']?.toString() ?? 'N/A',
                          style: const TextStyle(
                            fontSize: 15,
                            color: Colors.black54,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: IconButton(
                          icon: const Icon(Icons.info, color: Colors.blue),
                          tooltip: 'View Details',
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) =>
                                        StudentDetailsScreen(student: student),
                              ),
                            );
                          },
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

  Widget _buildMobileStudentList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _filteredStudents.length,
      itemBuilder: (context, index) {
        final student = _filteredStudents[index];
        // Log student data for debugging
        print('Student $index: $student');
        return GestureDetector(
          onTap: () {
            if (student['uid'] == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Invalid student data: Missing UID'),
                ),
              );
              return;
            }
            Navigator.push(
              context,
              MaterialPageRoute(
                builder:
                    (context) => EditStudentScreen(
                      student: student,
                      onUpdate: _fetchStudents,
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
                    value: _selectedStudents.contains(student['uid']),
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          _selectedStudents.add(student['uid']);
                        } else {
                          _selectedStudents.remove(student['uid']);
                        }
                        // Update select all state
                        _selectAll =
                            _selectedStudents.length ==
                            _filteredStudents.length;
                      });
                    },
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          student['name']?.toString() ?? 'Unknown',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Regd: ${student['regdNumber']?.toString() ?? 'N/A'}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Dept: ${student['department']?.toString() ?? 'N/A'}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Year: ${student['year']?.toString() ?? 'N/A'}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Class: ${student['class']?.toString() ?? 'N/A'}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Email: ${student['email']?.toString() ?? 'N/A'}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.info, color: Colors.blue),
                    tooltip: 'View Details',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) =>
                                  StudentDetailsScreen(student: student),
                        ),
                      );
                    },
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

class StudentDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> student;

  const StudentDetailsScreen({super.key, required this.student});

  @override
  Widget build(BuildContext context) {
    final bool isWeb = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${student['name']?.toString() ?? 'Student'} Details',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF0C4D83),
      ),
      body: SingleChildScrollView(
        padding:
            isWeb
                ? const EdgeInsets.symmetric(horizontal: 40, vertical: 20)
                : const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: CircleAvatar(
                radius: isWeb ? 60 : 40,
                backgroundColor: Colors.grey[300],
                child: Icon(
                  Icons.person,
                  size: isWeb ? 50 : 30,
                  color: Colors.grey[600],
                ),
              ),
            ),
            const SizedBox(height: 20),
            _buildDetailItem(
              'Name',
              student['name']?.toString() ?? 'N/A',
              isWeb,
            ),
            _buildDetailItem(
              'Registration Number',
              student['regdNumber']?.toString() ?? 'N/A',
              isWeb,
            ),
            _buildDetailItem(
              'Email',
              student['email']?.toString() ?? 'N/A',
              isWeb,
            ),
            _buildDetailItem(
              'Department',
              student['department']?.toString() ?? 'N/A',
              isWeb,
            ),
            _buildDetailItem(
              'Year',
              student['year']?.toString() ?? 'N/A',
              isWeb,
            ),
            _buildDetailItem(
              'Class',
              student['class']?.toString() ?? 'N/A',
              isWeb,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailItem(String label, String value, bool isWeb) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isWeb ? 14 : 12,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: isWeb ? 18 : 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Divider(color: Colors.grey[300], thickness: 1),
        ],
      ),
    );
  }
}

class EditStudentScreen extends StatefulWidget {
  final Map<String, dynamic> student;
  final VoidCallback onUpdate;

  const EditStudentScreen({
    super.key,
    required this.student,
    required this.onUpdate,
  });

  @override
  _EditStudentScreenState createState() => _EditStudentScreenState();
}

class _EditStudentScreenState extends State<EditStudentScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _regdNumberController;
  late TextEditingController _emailController;
  late TextEditingController _classController;
  String? _selectedDepartment;
  String? _selectedYear;
  bool _isLoading = false;

  final List<String> _departments = ['CSE', 'ECE', 'MECH', 'AIDS'];
  final List<String> _years = [
    'First Year',
    'Second Year',
    'Third Year',
    'Fourth Year',
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.student['name']?.toString() ?? '',
    );
    _regdNumberController = TextEditingController(
      text: widget.student['regdNumber']?.toString() ?? '',
    );
    _emailController = TextEditingController(
      text: widget.student['email']?.toString() ?? '',
    );
    _classController = TextEditingController(
      text: widget.student['class']?.toString() ?? '',
    );

    // Validate department
    String? dept = widget.student['department']?.toString();
    if (dept != null && _departments.contains(dept)) {
      _selectedDepartment = dept;
    } else {
      _selectedDepartment = _departments.first;
      if (dept != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Department "$dept" is invalid. Defaulting to ${_departments.first}.',
                ),
              ),
            );
          }
        });
      }
    }

    // Validate year
    String? year = widget.student['year']?.toString();
    if (year != null && _years.contains(year)) {
      _selectedYear = year;
    } else {
      _selectedYear = _years.first;
      if (year != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Year "$year" is invalid. Defaulting to ${_years.first}.',
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
    _regdNumberController.dispose();
    _emailController.dispose();
    _classController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.student['uid'])
            .update({
              'name': _nameController.text.trim(),
              'regdNumber': _regdNumberController.text.trim(),
              'email': _emailController.text.trim(),
              'department': _selectedDepartment,
              'year': _selectedYear,
              'class': _classController.text.trim(),
            });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Student updated successfully')),
          );
        }
        widget.onUpdate(); // Refresh the student list
        Navigator.pop(context);
      } catch (e) {
        print('Error updating student: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to update student: $e')),
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
          'Edit Student',
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
                      TextFormField(
                        controller: _classController,
                        decoration: InputDecoration(
                          labelText: 'Class',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          filled: true,
                          fillColor: Colors.grey[100],
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter a class';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 30),
                      Center(
                        child: Column(
                          children: [
                            ElevatedButton(
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
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
    );
  }
}
