import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ritian_faculty/widgets/custom_navigation_drawer.dart';

class AddTimetableScreen extends StatefulWidget {
  const AddTimetableScreen({super.key});

  @override
  State<AddTimetableScreen> createState() => _AddTimetableScreenState();
}

class _AddTimetableScreenState extends State<AddTimetableScreen> {
  int _numberOfPeriods = 0;
  List<String> days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];
  List<Map<String, dynamic>> subjects = [];
  List<Map<String, dynamic>> faculty = [];
  List<String> classes = ['AIDS E', 'CSE A', 'ECE B', 'MECH C'];
  String? selectedClass;
  bool _isLoading = false;
  String? _existingTimetableId;

  Map<String, Map<String, Map<String, String>>> timetable = {};

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
      print(
        'Fetched subjects: ${subjects.map((s) => s['subject_code']).toList()}',
      );
    });
  }

  Future<void> _fetchFaculty() async {
    final snapshot =
        await FirebaseFirestore.instance.collection('faculty_members').get();
    setState(() {
      faculty =
          snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList();
      print('Fetched faculty: ${faculty.map((f) => f['staff_code']).toList()}');
    });
  }

  Future<void> _fetchTimetable(String className) async {
    try {
      final snapshot =
          await FirebaseFirestore.instance
              .collection('timetables')
              .where('class', isEqualTo: className)
              .limit(1)
              .get();

      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        final data = doc.data();
        final loadedTimetable =
            data['timetable'] as Map<String, dynamic>? ?? {};

        setState(() {
          _existingTimetableId = doc.id;
          timetable = {};
          _numberOfPeriods = 0;

          loadedTimetable.forEach((day, periods) {
            timetable[day] = {};
            periods.forEach((period, details) {
              final detailsMap = Map<String, String>.from(details);
              final subjectCode = detailsMap['subject'];
              final facultyCode = detailsMap['faculty'];
              final isValidSubject =
                  subjectCode != null &&
                  subjects.any((s) => s['subject_code'] == subjectCode);
              final isValidFaculty =
                  facultyCode != null &&
                  faculty.any((f) => f['staff_code'] == facultyCode);

              if (!isValidSubject && subjectCode != null) {
                print(
                  'Invalid subject code in $day, period $period: $subjectCode',
                );
              }
              if (!isValidFaculty && facultyCode != null) {
                print(
                  'Invalid faculty code in $day, period $period: $facultyCode',
                );
              }

              timetable[day]![period] = {
                'subject': isValidSubject ? subjectCode : '',
                'faculty': isValidFaculty ? facultyCode : '',
              };
              final periodNum = int.tryParse(period) ?? 0;
              if (periodNum > _numberOfPeriods) {
                _numberOfPeriods = periodNum;
              }
            });
          });

          if (timetable.isEmpty) {
            print('No valid timetable data found for class: $className');
          }
        });
      } else {
        setState(() {
          _existingTimetableId = null;
          timetable.clear();
          _numberOfPeriods = 0;
        });
      }
    } catch (e) {
      print('Error fetching timetable: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load timetable: $e')));
    }
  }

  Future<void> _saveTimetable() async {
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
      final timetableData = {
        'class': selectedClass,
        'timetable': timetable,
        'created_at': Timestamp.now(),
      };

      if (_existingTimetableId != null) {
        await FirebaseFirestore.instance
            .collection('timetables')
            .doc(_existingTimetableId)
            .update(timetableData);
      } else {
        await FirebaseFirestore.instance
            .collection('timetables')
            .add(timetableData);
      }

      Navigator.pushReplacementNamed(context, '/home');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Timetable saved successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save timetable: $e')));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildTimetableGrid(bool isWeb) {
    if (_numberOfPeriods == 0) {
      return const Center(
        child: Text(
          'Enter number of periods or select a class to load timetable',
        ),
      );
    }

    Widget dataTable = DataTable(
      columnSpacing: isWeb ? 16 : 8,
      columns: [
        DataColumn(
          label: Text('Day', style: TextStyle(fontSize: isWeb ? 16 : 14)),
        ),
        ...List.generate(
          _numberOfPeriods,
          (index) => DataColumn(
            label: Text(
              'P${index + 1}',
              style: TextStyle(fontSize: isWeb ? 16 : 14),
            ),
          ),
        ),
      ],
      rows:
          days.map((day) {
            return DataRow(
              cells: [
                DataCell(
                  Text(
                    day.substring(0, 3),
                    style: TextStyle(fontSize: isWeb ? 16 : 14),
                  ),
                ),
                ...List.generate(_numberOfPeriods, (period) {
                  final periodKey = (period + 1).toString();
                  final String? currentSubject =
                      timetable[day]?[periodKey]?['subject'];
                  final String? currentFaculty =
                      timetable[day]?[periodKey]?['faculty'];

                  final validSubject =
                      currentSubject != null &&
                              currentSubject.isNotEmpty &&
                              subjects.any(
                                (s) => s['subject_code'] == currentSubject,
                              )
                          ? currentSubject
                          : null;
                  final validFaculty =
                      currentFaculty != null &&
                              currentFaculty.isNotEmpty &&
                              faculty.any(
                                (f) => f['staff_code'] == currentFaculty,
                              )
                          ? currentFaculty
                          : null;

                  return DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: isWeb ? 120 : 100,
                          child: DropdownButton<String>(
                            isExpanded: true,
                            hint: Text(
                              'Sub',
                              style: TextStyle(fontSize: isWeb ? 14 : 12),
                            ),
                            value: validSubject,
                            onChanged: (String? value) {
                              setState(() {
                                timetable[day] ??= {};
                                timetable[day]![periodKey] ??= {};
                                timetable[day]![periodKey]!['subject'] =
                                    value ?? '';
                              });
                            },
                            items:
                                subjects.map((subject) {
                                  return DropdownMenuItem<String>(
                                    value: subject['subject_code'],
                                    child: Text(
                                      subject['subject_name'],
                                      style: TextStyle(
                                        fontSize: isWeb ? 14 : 12,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  );
                                }).toList(),
                          ),
                        ),
                        const SizedBox(width: 4),
                        SizedBox(
                          width: isWeb ? 120 : 100,
                          child: DropdownButton<String>(
                            isExpanded: true,
                            hint: Text(
                              'Fac',
                              style: TextStyle(fontSize: isWeb ? 14 : 12),
                            ),
                            value: validFaculty,
                            onChanged: (String? value) {
                              setState(() {
                                timetable[day] ??= {};
                                timetable[day]![periodKey] ??= {};
                                timetable[day]![periodKey]!['faculty'] =
                                    value ?? '';
                              });
                            },
                            items:
                                faculty.map((fac) {
                                  return DropdownMenuItem<String>(
                                    value: fac['staff_code'],
                                    child: Text(
                                      fac['name'],
                                      style: TextStyle(
                                        fontSize: isWeb ? 14 : 12,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  );
                                }).toList(),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            );
          }).toList(),
    );

    return isWeb
        ? Scrollbar(
          thumbVisibility: true,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: dataTable,
          ),
        )
        : SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: dataTable,
        );
  }

  @override
  Widget build(BuildContext context) {
    final bool isWeb = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Add Timetable',
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
        final availableHeight = constraints.maxHeight - (isWeb ? 104 : 88);
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
                  'Add Timetable',
                  style: TextStyle(
                    fontSize: isWeb ? 28 : 24,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0C4D83),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  decoration: InputDecoration(
                    labelText: 'Number of Periods',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    filled: true,
                    fillColor: Colors.grey[100],
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    setState(() {
                      _numberOfPeriods = int.tryParse(value) ?? 0;
                      timetable.clear();
                      _existingTimetableId = null;
                    });
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedClass,
                  decoration: InputDecoration(
                    labelText: 'Select Class',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    filled: true,
                    fillColor: Colors.grey[100],
                  ),
                  items:
                      classes
                          .map(
                            (className) => DropdownMenuItem(
                              value: className,
                              child: Text(
                                className,
                                style: TextStyle(fontSize: isWeb ? 16 : 14),
                              ),
                            ),
                          )
                          .toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedClass = value;
                    });
                    if (value != null) {
                      _fetchTimetable(value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                if (isWeb && _numberOfPeriods > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Text(
                      'Hold Shift and scroll to see the timetable',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                SizedBox(
                  height: isWeb ? availableHeight - 100 : availableHeight - 84,
                  child: SingleChildScrollView(
                    child: _buildTimetableGrid(isWeb),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _saveTimetable,
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
                              'Save Timetable',
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
        );
      },
    );
  }
}
