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

  // Timetable data: {day: {period: {subject, faculty}}}, using String for period keys
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
    });
  }

  Future<void> _fetchFaculty() async {
    final snapshot =
        await FirebaseFirestore.instance.collection('faculty_members').get();
    setState(() {
      faculty =
          snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList();
    });
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
      await FirebaseFirestore.instance.collection('timetables').add({
        'class': selectedClass,
        'timetable': timetable,
        'created_at': Timestamp.now(),
      });
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

  Widget _buildTimetableGrid() {
    if (_numberOfPeriods == 0) return const SizedBox.shrink();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: [
          const DataColumn(label: Text('Day')),
          ...List.generate(
            _numberOfPeriods,
            (index) => DataColumn(label: Text('Period ${index + 1}')),
          ),
        ],
        rows:
            days.map((day) {
              return DataRow(
                cells: [
                  DataCell(Text(day)),
                  ...List.generate(_numberOfPeriods, (period) {
                    final periodKey = (period + 1).toString();
                    final String? currentSubject =
                        timetable[day]?[periodKey]?['subject'];
                    final String? currentFaculty =
                        timetable[day]?[periodKey]?['faculty'];

                    return DataCell(
                      Row(
                        children: [
                          // Subject Dropdown
                          DropdownButton<String>(
                            hint: const Text('Subject'),
                            value: currentSubject,
                            onChanged: (String? value) {
                              setState(() {
                                timetable[day] ??= {};
                                timetable[day]![periodKey] ??= {};
                                timetable[day]![periodKey]!['subject'] = value!;
                              });
                            },
                            items:
                                subjects.map((subject) {
                                  return DropdownMenuItem<String>(
                                    value: subject['subject_code'],
                                    child: Text(subject['subject_name']),
                                  );
                                }).toList(),
                          ),
                          const SizedBox(width: 8),
                          // Faculty Dropdown
                          DropdownButton<String>(
                            hint: const Text('Faculty'),
                            value: currentFaculty,
                            onChanged: (String? value) {
                              setState(() {
                                timetable[day] ??= {};
                                timetable[day]![periodKey] ??= {};
                                timetable[day]![periodKey]!['faculty'] = value!;
                              });
                            },
                            items:
                                faculty.map((fac) {
                                  return DropdownMenuItem<String>(
                                    value: fac['staff_code'],
                                    child: Text(fac['name']),
                                  );
                                }).toList(),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              );
            }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Timetable')),
      drawer: const AppDrawer(),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(labelText: 'Number of Periods'),
              keyboardType: TextInputType.number,
              onChanged: (value) {
                setState(() {
                  _numberOfPeriods = int.tryParse(value) ?? 0;
                  timetable.clear();
                });
              },
            ),
            const SizedBox(height: 16),
            DropdownButton<String>(
              hint: const Text('Select Class'),
              value: selectedClass,
              onChanged: (value) {
                setState(() {
                  selectedClass = value;
                });
              },
              items:
                  classes.map((className) {
                    return DropdownMenuItem<String>(
                      value: className,
                      child: Text(className),
                    );
                  }).toList(),
            ),
            const SizedBox(height: 16),
            Expanded(child: _buildTimetableGrid()),
            const SizedBox(height: 16),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                  onPressed: _saveTimetable,
                  child: const Text('Save Timetable'),
                ),
          ],
        ),
      ),
    );
  }
}
