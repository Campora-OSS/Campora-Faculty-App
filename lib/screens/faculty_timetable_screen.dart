import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import '../widgets/custom_navigation_drawer.dart';

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

  Future<void> _fetchFacultyTimetable({bool forceRefresh = false}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('User not logged in')));
      print('No user logged in');
      return;
    }

    try {
      // Fetch staff_code
      print('Fetching faculty data for UID: ${user.uid}');
      final facultyDoc =
          await FirebaseFirestore.instance
              .collection('faculty_members')
              .doc(user.uid)
              .get();
      if (!facultyDoc.exists || facultyDoc.data() == null) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Faculty data not found')));
        print('Faculty data not found for UID: ${user.uid}');
        return;
      }
      final facultyData = facultyDoc.data()!;
      final staffCode =
          facultyData['staff_code'] is String
              ? facultyData['staff_code'] as String
              : '';
      print('Staff code: $staffCode');
      if (staffCode.isEmpty) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Invalid staff code')));
        return;
      }

      // Check cache
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = 'timetable_${user.uid}';
      if (!forceRefresh && prefs.containsKey(cacheKey)) {
        final cached = prefs.getString(cacheKey);
        if (cached != null) {
          try {
            final cachedData = jsonDecode(cached) as Map<String, dynamic>;
            setState(() {
              facultyTimetable =
                  (cachedData['timetable'] as Map<String, dynamic>).map(
                    (day, periods) => MapEntry(
                      day,
                      (periods as Map<String, dynamic>).map(
                        (period, details) =>
                            MapEntry(period, Map<String, String>.from(details)),
                      ),
                    ),
                  );
              _numberOfPeriods = cachedData['maxPeriods'] as int;
              _isLoading = false;
            });
            print(
              'Loaded timetable from cache: periods=$_numberOfPeriods, days=${facultyTimetable.keys}',
            );
            return;
          } catch (e) {
            print('Error parsing cached timetable: $e');
          }
        }
      }

      // Fetch timetables
      print('Fetching timetables, limit: 10, for staff_code: $staffCode');
      final timetablesSnapshot = await FirebaseFirestore.instance
          .collection('timetables')
          .limit(10)
          .get()
          .timeout(const Duration(seconds: 8));

      print('Fetched ${timetablesSnapshot.docs.length} timetable documents');

      // Parse in isolate
      final result = await compute(_parseTimetables, {
        'docs': timetablesSnapshot.docs,
        'staffCode': staffCode,
        'days': days,
      });

      // Cache results
      await prefs.setString(
        cacheKey,
        jsonEncode({
          'timetable': result['timetable'],
          'maxPeriods': result['maxPeriods'],
        }),
      );

      setState(() {
        facultyTimetable = result['timetable'];
        _numberOfPeriods = result['maxPeriods'];
        _isLoading = false;
      });
      print(
        'Parsed timetable, periods: $_numberOfPeriods, days: ${facultyTimetable.keys}',
      );

      if (facultyTimetable.isEmpty) {
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
      print('Error fetching timetable: $e');
    }
  }

  static Map<String, dynamic> _parseTimetables(Map<String, dynamic> input) {
    final docs = input['docs'] as List<QueryDocumentSnapshot>;
    final staffCode = input['staffCode'] as String;
    final days = input['days'] as List<String>;
    Map<String, Map<String, Map<String, String>>> tempTimetable = {};
    int maxPeriods = 0;

    for (var timetableDoc in docs) {
      final data = timetableDoc.data() as Map<String, dynamic>;
      final className =
          data.containsKey('class') && data['class'] is String
              ? data['class'] as String
              : 'Unknown';
      final timetableData =
          data.containsKey('timetable') && data['timetable'] is Map
              ? data['timetable'] as Map
              : null;

      print(
        'Processing doc ID: ${timetableDoc.id}, class: $className, timetable type: ${timetableData?.runtimeType}',
      );

      if (timetableData == null) {
        print('Skipping doc ID: ${timetableDoc.id}, no timetable data');
        continue;
      }

      for (var day in days) {
        final periods =
            timetableData.containsKey(day) && timetableData[day] is Map
                ? timetableData[day] as Map
                : null;
        if (periods == null) {
          print('No periods for day: $day in doc ID: ${timetableDoc.id}');
          continue;
        }
        tempTimetable[day] ??= {};
        periods.forEach((period, details) {
          if (details is Map) {
            final faculty =
                details.containsKey('faculty')
                    ? details['faculty'].toString()
                    : '';
            final subject =
                details.containsKey('subject') && details['subject'] is String
                    ? details['subject'] as String
                    : 'Unknown';
            print(
              'Period: $period, faculty: $faculty, subject: $subject, matches staffCode: ${faculty == staffCode}',
            );
            if (faculty == staffCode) {
              tempTimetable[day]![period] = {
                'subject': subject,
                'class': className,
              };
              final periodNum = int.tryParse(period) ?? 0;
              if (periodNum > maxPeriods) maxPeriods = periodNum;
            }
          }
        });
      }
    }

    print(
      'Final timetable: days=${tempTimetable.keys}, maxPeriods=$maxPeriods',
    );
    return {'timetable': tempTimetable, 'maxPeriods': maxPeriods};
  }

  Widget _buildTimetableGrid(bool isWeb) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Color(0xFF0C4D83)),
            SizedBox(height: 16),
            Text(
              'Loading your timetable...',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    if (_numberOfPeriods == 0 || facultyTimetable.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_busy, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No timetable assignments found',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    if (isWeb) {
      // Web: Use ListView with ExpansionTile and Wrap for periods
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: days.length,
          itemBuilder: (context, index) {
            final day = days[index];
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ExpansionTile(
                title: Text(
                  day,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0C4D83),
                  ),
                ),
                initiallyExpanded: index == 0, // Expand Monday by default
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: List.generate(_numberOfPeriods, (period) {
                        final periodKey = (period + 1).toString();
                        final subject =
                            facultyTimetable[day]?[periodKey]?['subject'] ??
                            '-';
                        final className =
                            facultyTimetable[day]?[periodKey]?['class'] ?? '-';
                        return MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: Tooltip(
                            message:
                                subject == '-'
                                    ? 'Free'
                                    : '$subject\nClass: $className',
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width:
                                  _numberOfPeriods > 6
                                      ? 180
                                      : MediaQuery.of(context).size.width > 1200
                                      ? 250
                                      : 200,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color:
                                    subject == '-'
                                        ? Colors.grey[100]
                                        : Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey[300]!),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.withOpacity(0.2),
                                    spreadRadius: 1,
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Period ${period + 1}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color:
                                          subject == '-'
                                              ? Colors.grey
                                              : const Color(0xFF0C4D83),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    subject == '-' ? 'Free' : subject,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color:
                                          subject == '-'
                                              ? Colors.grey
                                              : Colors.black,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (subject != '-')
                                    Text(
                                      'Class: $className',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );
    }

    // Mobile: Use ListView with ExpansionTile
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: days.length,
      itemBuilder: (context, index) {
        final day = days[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ExpansionTile(
            title: Text(
              day,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0C4D83),
              ),
            ),
            initiallyExpanded: index == 0, // Expand Monday by default
            children: List.generate(_numberOfPeriods, (period) {
              final periodKey = (period + 1).toString();
              final subject =
                  facultyTimetable[day]?[periodKey]?['subject'] ?? '-';
              final className =
                  facultyTimetable[day]?[periodKey]?['class'] ?? '-';
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: subject == '-' ? Colors.grey[100] : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      alignment: Alignment.center,
                      child: Text(
                        'P${period + 1}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color:
                              subject == '-'
                                  ? Colors.grey
                                  : const Color(0xFF0C4D83),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            subject == '-' ? 'Free' : subject,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color:
                                  subject == '-' ? Colors.grey : Colors.black,
                            ),
                          ),
                          if (subject != '-')
                            Text(
                              'Class: $className',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isWeb = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Timetable',
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
                  Expanded(child: _buildTimetableGrid(true)),
                ],
              )
              : _buildTimetableGrid(false),
    );
  }
}
