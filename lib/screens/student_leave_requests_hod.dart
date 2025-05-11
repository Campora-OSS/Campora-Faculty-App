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
          drawer: isWeb ? null : const AppDrawer(),
          body:
              isWeb
                  ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const AppDrawer(),
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
    return Container(
      color: Colors.white,
      padding:
          isWeb
              ? const EdgeInsets.fromLTRB(24, 24, 24, 16)
              : const EdgeInsets.fromLTRB(16, 16, 16, 8),
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
                style: TextStyle(fontSize: isWeb ? 18 : 16, color: Colors.red),
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
              if (filteredSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (filteredSnapshot.hasError) {
                print('Error filtering requests: ${filteredSnapshot.error}');
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
              if (!filteredSnapshot.hasData || filteredSnapshot.data!.isEmpty) {
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
              print('Filtered data: ${filteredDocs.length} documents');

              return Column(
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
                  isWeb
                      ? _buildWebTable(context, filteredDocs)
                      : _buildMobileList(context, filteredDocs),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildWebTable(
    BuildContext context,
    List<QueryDocumentSnapshot> filteredDocs,
  ) {
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
                flex: 2,
                child: Text(
                  'Student Name',
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
                  'From Date',
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
                  'To Date',
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
                  'Leave Type',
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
                  'Reason',
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
                  'Attachment',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.grey[800],
                  ),
                ),
              ),
              Expanded(
                flex: 3,
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
                  return const Center(child: CircularProgressIndicator());
                }
                final studentInfo =
                    studentSnapshot.data ??
                    {
                      'name': 'Unknown',
                      'class': 'Unknown',
                      'department': 'Unknown',
                    };
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
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text(
                            studentInfo['name']!,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            studentInfo['class']!,
                            style: const TextStyle(
                              fontSize: 15,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            studentInfo['department']!,
                            style: const TextStyle(
                              fontSize: 15,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            '${(data['fromDate'] as Timestamp).toDate().day}/${(data['fromDate'] as Timestamp).toDate().month}/${(data['fromDate'] as Timestamp).toDate().year}',
                            style: const TextStyle(
                              fontSize: 15,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            '${(data['toDate'] as Timestamp).toDate().day}/${(data['toDate'] as Timestamp).toDate().month}/${(data['toDate'] as Timestamp).toDate().year}',
                            style: const TextStyle(
                              fontSize: 15,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            data['leaveType'] ?? 'N/A',
                            style: const TextStyle(
                              fontSize: 15,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            data['reason'] ?? 'N/A',
                            style: const TextStyle(
                              fontSize: 15,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child:
                              data['attachmentUrl'] != null
                                  ? IconButton(
                                    icon: const Icon(
                                      Icons.attachment,
                                      color: Color(0xFF0C4D83),
                                    ),
                                    tooltip: 'View Attachment',
                                    onPressed:
                                        () => _viewAttachment(
                                          context,
                                          data['attachmentUrl'],
                                        ),
                                  )
                                  : const Text(
                                    'N/A',
                                    style: TextStyle(
                                      fontSize: 15,
                                      color: Colors.black87,
                                    ),
                                  ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                ),
                                tooltip: 'Accept',
                                onPressed:
                                    () => _updateRequestStatus(
                                      context,
                                      uid,
                                      requestId,
                                      'approved',
                                    ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.cancel,
                                  color: Colors.red,
                                ),
                                tooltip: 'Reject',
                                onPressed:
                                    () => _updateRequestStatus(
                                      context,
                                      uid,
                                      requestId,
                                      'rejected',
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildMobileList(
    BuildContext context,
    List<QueryDocumentSnapshot> filteredDocs,
  ) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: filteredDocs.length,
      itemBuilder: (context, index) {
        final doc = filteredDocs[index];
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
                {
                  'name': 'Unknown',
                  'class': 'Unknown',
                  'department': 'Unknown',
                };
            return Card(
              elevation: 6,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
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
                    const SizedBox(height: 8),
                    Text(
                      'Department: ${studentInfo['department']}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      'From: ${(data['fromDate'] as Timestamp).toDate().day}/${(data['fromDate'] as Timestamp).toDate().month}/${(data['fromDate'] as Timestamp).toDate().year}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      'To: ${(data['toDate'] as Timestamp).toDate().day}/${(data['toDate'] as Timestamp).toDate().month}/${(data['toDate'] as Timestamp).toDate().year}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      'Leave Type: ${data['leaveType']}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                    if (data['leaveType'] == 'OD') ...[
                      Text(
                        'OD Type: ${data['odType']}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        'OD Hours: ${data['odHours']}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                    Text(
                      'Reason: ${data['reason']}',
                      style: const TextStyle(
                        fontSize: 14,
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
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                          ),
                          child: const Text(
                            'View Attachment',
                            style: TextStyle(fontSize: 13, color: Colors.white),
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
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
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                          ),
                          child: const Text(
                            'Accept',
                            style: TextStyle(fontSize: 13, color: Colors.white),
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
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                          ),
                          child: const Text(
                            'Reject',
                            style: TextStyle(fontSize: 13, color: Colors.white),
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
  }
}
