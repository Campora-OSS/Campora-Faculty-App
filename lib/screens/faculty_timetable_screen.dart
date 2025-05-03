import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ritian_faculty/widgets/custom_navigation_drawer.dart';

class FacultyTimetableScreen extends StatefulWidget {
  const FacultyTimetableScreen({super.key});

  @override
  State<FacultyTimetableScreen> createState() => _FacultyTimetableScreenState();
}

class _FacultyTimetableScreenState extends State<FacultyTimetableScreen> {
  List<String> days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];
  Map<String, Map<String, Map<String, String>>> facultyTimetable = {};
  int _numberOfPeriods = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchFacultyTimetable();
  }

  Future<void> _fetchFacultyTimetable() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('User not logged in')));
      return;
    }

    try {
      // Fetch the faculty's staff_code
      final facultyDoc =
          await FirebaseFirestore.instance
              .collection('faculty_members')
              .doc(user.uid)
              .get();
      if (!facultyDoc.exists) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Faculty data not found')));
        return;
      }
      final staffCode = facultyDoc.data()!['staff_code'] as String;

      // Fetch all timetables
      final timetablesSnapshot =
          await FirebaseFirestore.instance.collection('timetables').get();

      // Build faculty timetable
      Map<String, Map<String, Map<String, String>>> tempTimetable = {};
      int maxPeriods = 0;

      for (var timetableDoc in timetablesSnapshot.docs) {
        final className = timetableDoc.data()['class'] as String;
        final timetableData =
            timetableDoc.data()['timetable'] as Map<String, dynamic>;

        // Convert Firestore data to the expected type
        final timetable = <String, Map<String, Map<String, String>>>{};
        timetableData.forEach((day, periods) {
          if (periods is Map) {
            final periodMap = <String, Map<String, String>>{};
            (periods as Map<String, dynamic>).forEach((period, details) {
              if (details is Map) {
                periodMap[period] = Map<String, String>.from(details);
              }
            });
            timetable[day] = periodMap;
          }
        });

        for (var day in days) {
          if (timetable.containsKey(day)) {
            timetable[day]!.forEach((period, details) {
              final faculty = details['faculty'];
              if (faculty == staffCode) {
                tempTimetable[day] ??= {};
                tempTimetable[day]![period] = {
                  'subject': details['subject'] as String,
                  'class': className,
                };
                // Update max periods
                final periodNum = int.parse(period);
                if (periodNum > maxPeriods) maxPeriods = periodNum;
              }
            });
          }
        }
      }

      setState(() {
        facultyTimetable = tempTimetable;
        _numberOfPeriods = maxPeriods;
        _isLoading = false;
      });

      if (tempTimetable.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No timetable assignments found')),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to fetch timetable: $e')));
    }
  }

  Widget _buildTimetableGrid() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_numberOfPeriods == 0 || facultyTimetable.isEmpty) {
      return const Center(child: Text('No timetable available'));
    }

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
                    final subject =
                        facultyTimetable[day]?[periodKey]?['subject'] ?? '-';
                    final className =
                        facultyTimetable[day]?[periodKey]?['class'] ?? '-';
                    return DataCell(
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(subject),
                          Text(
                            'Class: $className',
                            style: const TextStyle(color: Colors.grey),
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
      appBar: AppBar(title: const Text('My Timetable')),
      drawer: const AppDrawer(),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _buildTimetableGrid(),
      ),
    );
  }
}
