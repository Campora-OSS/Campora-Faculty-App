import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/custom_navigation_drawer.dart';
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
    final bool isWeb = MediaQuery.of(context).size.width > 800;

    if (user == null) {
      print('No authenticated user found');
      return Scaffold(
        drawer: isWeb ? null : const AppDrawer(),
        body: Center(
          child: Text(
            'Please log in to view requests',
            style: TextStyle(fontSize: isWeb ? 18 : 16, color: Colors.black54),
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
            drawer: isWeb ? null : const AppDrawer(),
            body: Center(
              child: Text(
                'Error: ${hodSnapshot.error}',
                style: TextStyle(
                  fontSize: isWeb ? 18 : 16,
                  color: Colors.black54,
                ),
              ),
            ),
          );
        }
        if (!hodSnapshot.hasData || hodSnapshot.data!.isEmpty) {
          return Scaffold(
            drawer: isWeb ? null : const AppDrawer(),
            body: Center(
              child: Text(
                'Department not assigned to HoD',
                style: TextStyle(
                  fontSize: isWeb ? 18 : 16,
                  color: Colors.black54,
                ),
              ),
            ),
          );
        }

        final hoddepartment = hodSnapshot.data!;

        return Scaffold(
          drawer: isWeb ? null : const AppDrawer(), // Drawer only for mobile
          body:
              isWeb
                  ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const AppDrawer(), // Persistent sidebar for web
                      Expanded(
                        child: _buildContent(context, hoddepartment, isWeb),
                      ),
                    ],
                  )
                  : _buildContent(context, hoddepartment, isWeb),
        );
      },
    );
  }

  Widget _buildContent(BuildContext context, String hoddepartment, bool isWeb) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Padding(
              padding:
                  isWeb
                      ? const EdgeInsets.fromLTRB(24, 24, 24, 16)
                      : const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Student Leave Requests',
                    style: TextStyle(
                      fontSize: isWeb ? 28 : 24,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0C4D83),
                    ),
                  ),
                  const SizedBox(height: 16),
                  StreamBuilder<QuerySnapshot>(
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
                            style: TextStyle(
                              fontSize: isWeb ? 18 : 16,
                              color: Colors.red,
                            ),
                          ),
                        );
                      }
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        print('No data found or empty snapshot');
                        return Center(
                          child: Text(
                            'No pending leave requests',
                            style: TextStyle(
                              fontSize: isWeb ? 18 : 16,
                              color: Colors.black54,
                            ),
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
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          if (filteredSnapshot.hasError) {
                            print(
                              'Error filtering requests: ${filteredSnapshot.error}',
                            );
                            return Center(
                              child: Text(
                                'Error filtering requests',
                                style: TextStyle(
                                  fontSize: isWeb ? 18 : 16,
                                  color: Colors.red,
                                ),
                              ),
                            );
                          }
                          if (!filteredSnapshot.hasData ||
                              filteredSnapshot.data!.isEmpty) {
                            return Center(
                              child: Text(
                                'No pending leave requests from your department',
                                style: TextStyle(
                                  fontSize: isWeb ? 18 : 16,
                                  color: Colors.black54,
                                ),
                              ),
                            );
                          }

                          final filteredDocs = filteredSnapshot.data!;
                          print(
                            'Filtered data: ${filteredDocs.length} documents',
                          );

                          return isWeb
                              ? GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate:
                                    const SliverGridDelegateWithMaxCrossAxisExtent(
                                      maxCrossAxisExtent: 600,
                                      childAspectRatio: 1.5,
                                      crossAxisSpacing: 16,
                                      mainAxisSpacing: 16,
                                    ),
                                itemCount: filteredDocs.length,
                                itemBuilder: (context, index) {
                                  return _buildRequestCard(
                                    context,
                                    filteredDocs[index],
                                    isWeb,
                                  );
                                },
                              )
                              : ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: filteredDocs.length,
                                itemBuilder: (context, index) {
                                  return _buildRequestCard(
                                    context,
                                    filteredDocs[index],
                                    isWeb,
                                  );
                                },
                              );
                        },
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

  Widget _buildRequestCard(
    BuildContext context,
    QueryDocumentSnapshot doc,
    bool isWeb,
  ) {
    final data = doc.data() as Map<String, dynamic>;
    final requestId = doc.id;
    final uid = doc.reference.parent.parent!.id;

    return FutureBuilder<Map<String, String>>(
      future: _fetchStudentInfo(uid),
      builder: (context, studentSnapshot) {
        if (studentSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final studentInfo =
            studentSnapshot.data ??
            {'name': 'Unknown', 'class': 'Unknown', 'department': 'Unknown'};
        return MouseRegion(
          cursor: isWeb ? SystemMouseCursors.click : MouseCursor.defer,
          child: Card(
            elevation: isWeb ? 8 : 6,
            margin:
                isWeb
                    ? const EdgeInsets.symmetric(vertical: 8)
                    : const EdgeInsets.only(
                      bottom: 12,
                    ), // Reduced bottom margin
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            color: Colors.white,
            child: Container(
              decoration:
                  isWeb
                      ? BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            spreadRadius: 2,
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      )
                      : null,
              child: Padding(
                padding:
                    isWeb
                        ? const EdgeInsets.all(20) // Reduced padding
                        : const EdgeInsets.all(12), // Reduced padding
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Request from ${studentInfo['name']} (${studentInfo['class']})',
                      style: TextStyle(
                        fontSize: isWeb ? 20 : 18,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0C4D83),
                      ),
                    ),
                    const SizedBox(height: 8), // Reduced spacing
                    Text(
                      'Department: ${studentInfo['department']}',
                      style: TextStyle(
                        fontSize: isWeb ? 15 : 14, // Slightly smaller font
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      'From: ${(data['fromDate'] as Timestamp).toDate().day}/${(data['fromDate'] as Timestamp).toDate().month}/${(data['fromDate'] as Timestamp).toDate().year}',
                      style: TextStyle(
                        fontSize: isWeb ? 15 : 14,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      'To: ${(data['toDate'] as Timestamp).toDate().day}/${(data['toDate'] as Timestamp).toDate().month}/${(data['toDate'] as Timestamp).toDate().year}',
                      style: TextStyle(
                        fontSize: isWeb ? 15 : 14,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      'Leave Type: ${data['leaveType']}',
                      style: TextStyle(
                        fontSize: isWeb ? 15 : 14,
                        color: Colors.black87,
                      ),
                    ),
                    if (data['leaveType'] == 'OD') ...[
                      Text(
                        'OD Type: ${data['odType']}',
                        style: TextStyle(
                          fontSize: isWeb ? 15 : 14,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        'OD Hours: ${data['odHours']}',
                        style: TextStyle(
                          fontSize: isWeb ? 15 : 14,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                    Text(
                      'Reason: ${data['reason']}',
                      style: TextStyle(
                        fontSize: isWeb ? 15 : 14,
                        color: Colors.black87,
                      ),
                    ),
                    if (data['attachmentUrl'] != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: ElevatedButton(
                          onPressed:
                              () => _viewAttachment(
                                context,
                                data['attachmentUrl'],
                              ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0C4D83),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding:
                                isWeb
                                    ? const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 10,
                                    )
                                    : const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                          ),
                          child: Text(
                            'View Attachment',
                            style: TextStyle(
                              fontSize: isWeb ? 15 : 13,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 12), // Reduced spacing
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
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding:
                                isWeb
                                    ? const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 10,
                                    )
                                    : const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                          ),
                          child: Text(
                            'Accept',
                            style: TextStyle(
                              fontSize: isWeb ? 15 : 13,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8), // Reduced spacing
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
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding:
                                isWeb
                                    ? const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 10,
                                    )
                                    : const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                          ),
                          child: Text(
                            'Reject',
                            style: TextStyle(
                              fontSize: isWeb ? 15 : 13,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
