import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ritian_faculty/widgets/custom_navigation_drawer.dart';
import 'package:url_launcher/url_launcher.dart';

class StudentLeaveRequestsScreen extends StatelessWidget {
  const StudentLeaveRequestsScreen({super.key});

  Future<Map<String, String>> _fetchStudentInfo(String uid) async {
    try {
      DocumentSnapshot doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists) {
        return {
          'name': doc.get('name') ?? 'Unknown',
          'class': doc.get('class') ?? 'Unknown',
        };
      }
      return {'name': 'Unknown', 'class': 'Unknown'};
    } catch (e) {
      print('Error fetching student info: $e'); // Log error
      return {'name': 'Unknown', 'class': 'Unknown'};
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
      print('Error updating request status: $e'); // Log error
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
      print('Error opening attachment: $e'); // Log error
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Cannot open attachment')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('No authenticated user found'); // Log authentication issue
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
                  .where('status', isEqualTo: 'requested')
                  .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              print(
                'Firestore query error: ${snapshot.error}',
              ); // Log query error
              return Center(
                child: Text(
                  'Error: ${snapshot.error}',
                  style: const TextStyle(fontSize: 16, color: Colors.red),
                ),
              );
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              print('No data found or empty snapshot'); // Log no data
              return const Center(
                child: Text(
                  'No pending leave requests',
                  style: TextStyle(fontSize: 16, color: Colors.black54),
                ),
              );
            }
            print(
              'Data found: ${snapshot.data!.docs.length} documents',
            ); // Log document count
            return ListView.builder(
              itemCount: snapshot.data!.docs.length,
              itemBuilder: (context, index) {
                final doc = snapshot.data!.docs[index];
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
                        {'name': 'Unknown', 'class': 'Unknown'};
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
                              'Reason: ${data['reason']}',
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.black87,
                              ),
                            ),
                            if (data['attachmentUrl'] != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: ElevatedButton(
                                  onPressed:
                                      () => _viewAttachment(
                                        context,
                                        data['attachmentUrl'],
                                      ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF0C4D83),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12.0),
                                    ),
                                  ),
                                  child: const Text(
                                    'View Attachment',
                                    style: TextStyle(color: Colors.white),
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
                                        'hod',
                                      ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12.0),
                                    ),
                                  ),
                                  child: const Text(
                                    'Accept',
                                    style: TextStyle(color: Colors.white),
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
                                      borderRadius: BorderRadius.circular(12.0),
                                    ),
                                  ),
                                  child: const Text(
                                    'Reject',
                                    style: TextStyle(color: Colors.white),
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
        ),
      ),
    );
  }
}
