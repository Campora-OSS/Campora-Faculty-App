import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ritian_faculty/widgets/custom_navigation_drawer.dart';
import 'package:url_launcher/url_launcher.dart';

class StudentLeaveRequestsHodScreen extends StatelessWidget {
  const StudentLeaveRequestsHodScreen({super.key});

  // Fetch the logged-in HoD's department
  Future<String?> _fetchHodDepartment(String uid) async {
    try {
      DocumentSnapshot doc =
          await FirebaseFirestore.instance
              .collection('faculty_members')
              .doc(uid)
              .get();
      if (doc.exists) {
        String? department = doc.get('department');
        if (department == null || department.isEmpty) {
          throw Exception('HoD department field is missing or empty');
        }
        return department;
      } else {
        throw Exception('HoD user document does not exist');
      }
    } catch (e) {
      print('Error fetching HoD department: $e');
      rethrow;
    }
  }

  // Fetch student info (name, class, and department)
  Future<Map<String, String>> _fetchStudentInfo(String uid) async {
    try {
      DocumentSnapshot doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists) {
        return {
          'name': doc.get('name') ?? 'Unknown',
          'class': doc.get('class') ?? 'Unknown',
          'department': doc.get('department') ?? 'Unknown',
        };
      }
      return {'name': 'Unknown', 'class': 'Unknown', 'department': 'Unknown'};
    } catch (e) {
      print('Error fetching student info: $e');
      return {'name': 'Unknown', 'class': 'Unknown', 'department': 'Unknown'};
    }
  }

  Future<void> _updateRequestStatus(
    BuildContext context,
    String uid,
    String requestId,
    String newStatus,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('leave_requests')
          .doc(uid)
          .collection('requests')
          .doc(requestId)
          .update({'status': newStatus});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Request $newStatus successfully')),
      );
    } catch (e) {
      print('Error updating request status: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to update request: $e')));
    }
  }

  Future<void> _viewAttachment(BuildContext context, String? url) async {
    try {
      if (url != null && await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url));
      } else {
        throw Exception('Invalid or null URL');
      }
    } catch (e) {
      print('Error opening attachment: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Cannot open attachment')));
    }
  }

  // Helper method to filter requests by matching student's department with HoD's department
  Future<List<QueryDocumentSnapshot>> _filterRequestsByDepartment(
    List<QueryDocumentSnapshot> docs,
    String hoddepartment,
  ) async {
    List<QueryDocumentSnapshot> filteredDocs = [];
    for (var doc in docs) {
      final uid = doc.reference.parent.parent!.id;
      final studentInfo = await _fetchStudentInfo(uid);
      if (studentInfo['department'] == hoddepartment) {
        filteredDocs.add(doc);
      }
    }
    return filteredDocs;
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('No authenticated user found');
      return Scaffold(
        appBar: AppBar(
          title: const Text('Student Leave Requests'),
          backgroundColor: const Color(0xFF0C4D83),
        ),
        drawer: const AppDrawer(),
        body: const Center(
          child: Text(
            'Please log in to view requests',
            style: TextStyle(fontSize: 16, color: Colors.black54),
          ),
        ),
      );
    }

    return FutureBuilder<String?>(
      future: _fetchHodDepartment(user.uid),
      builder: (context, hodSnapshot) {
        if (hodSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (hodSnapshot.hasError) {
          print('Error in FutureBuilder: ${hodSnapshot.error}');
          return Scaffold(
            appBar: AppBar(
              title: const Text('Student Leave Requests'),
              backgroundColor: const Color(0xFF0C4D83),
            ),
            drawer: const AppDrawer(),
            body: Center(
              child: Text(
                'Error: ${hodSnapshot.error}',
                style: const TextStyle(fontSize: 16, color: Colors.black54),
              ),
            ),
          );
        }
        if (!hodSnapshot.hasData || hodSnapshot.data!.isEmpty) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Student Leave Requests'),
              backgroundColor: const Color(0xFF0C4D83),
            ),
            drawer: const AppDrawer(),
            body: const Center(
              child: Text(
                'Department not assigned to HoD',
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),
            ),
          );
        }

        final hoddepartment = hodSnapshot.data!;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Student Leave Requests'),
            backgroundColor: const Color(0xFF0C4D83),
          ),
          drawer: const AppDrawer(),
          body: Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16.0),
            child: StreamBuilder<QuerySnapshot>(
              stream:
                  FirebaseFirestore.instance
                      .collectionGroup('requests')
                      .where('status', isEqualTo: 'hod')
                      .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  print('Firestore query error: ${snapshot.error}');
                  return Center(
                    child: Text(
                      'Error: ${snapshot.error}',
                      style: const TextStyle(fontSize: 16, color: Colors.red),
                    ),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  print('No data found or empty snapshot');
                  return const Center(
                    child: Text(
                      'No pending leave requests',
                      style: TextStyle(fontSize: 16, color: Colors.black54),
                    ),
                  );
                }

                return FutureBuilder<List<QueryDocumentSnapshot>>(
                  future: _filterRequestsByDepartment(
                    snapshot.data!.docs,
                    hoddepartment,
                  ),
                  builder: (context, filteredSnapshot) {
                    if (filteredSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (filteredSnapshot.hasError) {
                      print(
                        'Error filtering requests: ${filteredSnapshot.error}',
                      );
                      return const Center(
                        child: Text(
                          'Error filtering requests',
                          style: TextStyle(fontSize: 16, color: Colors.red),
                        ),
                      );
                    }
                    if (!filteredSnapshot.hasData ||
                        filteredSnapshot.data!.isEmpty) {
                      return const Center(
                        child: Text(
                          'No pending leave requests from your department',
                          style: TextStyle(fontSize: 16, color: Colors.black54),
                        ),
                      );
                    }

                    final filteredDocs = filteredSnapshot.data!;
                    print('Filtered data: ${filteredDocs.length} documents');

                    return ListView.builder(
                      itemCount: filteredDocs.length,
                      itemBuilder: (context, index) {
                        final doc = filteredDocs[index];
                        final data = doc.data() as Map<String, dynamic>;
                        final requestId = doc.id;
                        final uid = doc.reference.parent.parent!.id;

                        return FutureBuilder<Map<String, String>>(
                          future: _fetchStudentInfo(uid),
                          builder: (context, studentSnapshot) {
                            if (studentSnapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }
                            final studentInfo =
                                studentSnapshot.data ??
                                {
                                  'name': 'Unknown',
                                  'class': 'Unknown',
                                  'department': 'Unknown',
                                };
                            return Card(
                              elevation: 6,
                              margin: const EdgeInsets.only(bottom: 16.0),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16.0),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Request from ${studentInfo['name']} (${studentInfo['class']})',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF0C4D83),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Department: ${studentInfo['department']}',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    Text(
                                      'From: ${(data['fromDate'] as Timestamp).toDate().day}/${(data['fromDate'] as Timestamp).toDate().month}/${(data['fromDate'] as Timestamp).toDate().year}',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    Text(
                                      'To: ${(data['toDate'] as Timestamp).toDate().day}/${(data['toDate'] as Timestamp).toDate().month}/${(data['toDate'] as Timestamp).toDate().year}',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    Text(
                                      'Leave Type: ${data['leaveType']}',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    if (data['leaveType'] == 'OD') ...[
                                      Text(
                                        'OD Type: ${data['odType']}',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      Text(
                                        'OD Hours: ${data['odHours']}',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ],
                                    Text(
                                      'Reason: ${data['reason']}',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    if (data['attachmentUrl'] != null)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          top: 8.0,
                                        ),
                                        child: ElevatedButton(
                                          onPressed:
                                              () => _viewAttachment(
                                                context,
                                                data['attachmentUrl'],
                                              ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(
                                              0xFF0C4D83,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12.0),
                                            ),
                                          ),
                                          child: const Text(
                                            'View Attachment',
                                            style: TextStyle(
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    const SizedBox(height: 16),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        ElevatedButton(
                                          onPressed:
                                              () => _updateRequestStatus(
                                                context,
                                                uid,
                                                requestId,
                                                'approved',
                                              ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.green,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12.0),
                                            ),
                                          ),
                                          child: const Text(
                                            'Accept',
                                            style: TextStyle(
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        ElevatedButton(
                                          onPressed:
                                              () => _updateRequestStatus(
                                                context,
                                                uid,
                                                requestId,
                                                'rejected',
                                              ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12.0),
                                            ),
                                          ),
                                          child: const Text(
                                            'Reject',
                                            style: TextStyle(
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }
}
