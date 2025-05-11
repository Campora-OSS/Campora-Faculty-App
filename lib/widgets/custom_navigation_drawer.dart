import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AppDrawer extends StatefulWidget {
  const AppDrawer({super.key});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  Map<String, dynamic>? _userData;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc =
          await FirebaseFirestore.instance
              .collection('faculty_members')
              .doc(user.uid)
              .get();
      if (doc.exists) {
        setState(() {
          _userData = doc.data();
        });
      }
    }
  }

  Future<void> _signOut(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushReplacementNamed(context, '/');
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final facultyType = _userData?['faculty_type'] ?? '';

    return Drawer(
      child: Column(
        children: [
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/profile'),
            child: UserAccountsDrawerHeader(
              accountName: Text(_userData?['name'] ?? 'Guest'),
              accountEmail: Text(user?.email ?? 'guest@example.com'),
              currentAccountPicture: const CircleAvatar(
                backgroundImage: NetworkImage(
                  'https://via.placeholder.com/150',
                ),
              ),
              decoration: const BoxDecoration(color: Colors.blue),
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                ListTile(
                  leading: const Icon(Icons.home),
                  title: const Text('Home'),
                  onTap: () => Navigator.pushNamed(context, '/home'),
                ),
                ListTile(
                  leading: const Icon(Icons.schedule),
                  title: const Text('My Time Table'),
                  onTap:
                      () => Navigator.pushNamed(context, '/faculty_timetable'),
                ),
                ListTile(
                  leading: const Icon(Icons.assignment_ind_sharp),
                  title: const Text('Manage Students'),
                  onTap:
                      () => Navigator.pushNamed(context, '/manage_students'),
                ),
                ListTile(
                  leading: const Icon(Icons.book),
                  title: const Text('My Subjects'),
                  onTap:
                      () => Navigator.pushNamed(context, '/under_construction'),
                ),
                ListTile(
                  leading: const Icon(Icons.list),
                  title: const Text('My Lesson Plans'),
                  onTap:
                      () => Navigator.pushNamed(context, '/under_construction'),
                ),
                if (facultyType == 'Associate Professor')
                  ListTile(
                    leading: const Icon(Icons.person),
                    title: const Text('Student Leave Requests'),
                    onTap:
                        () => Navigator.pushNamed(
                          context,
                          '/student_leave_requests',
                        ),
                  ),
                if (facultyType == 'HoD')
                  ListTile(
                    leading: const Icon(Icons.person),
                    title: const Text('Student Leave Requests'),
                    onTap:
                        () => Navigator.pushNamed(
                          context,
                          '/student_leave_requests_hod',
                        ),
                  ),
                if (facultyType == 'Admin')
                  ListTile(
                    leading: const Icon(Icons.person),
                    title: const Text('Manage Faculty'),
                    onTap: () => Navigator.pushNamed(context, '/manage_faculty'),
                  ),
                if (facultyType == 'Admin')
                  ListTile(
                    leading: const Icon(Icons.person),
                    title: const Text('Add Students'),
                    onTap: () => Navigator.pushNamed(context, '/add_students'),
                  ),
                if (facultyType == 'Admin')
                ListTile(
                  leading: const Icon(Icons.book),
                  title: const Text('Manage Academics'),
                  onTap: () => Navigator.pushNamed(context, '/manage_academics'),
                ),
                if (facultyType == 'Admin')
                  ListTile(
                    leading: const Icon(Icons.book),
                    title: const Text('Add Subjects'),
                    onTap: () => Navigator.pushNamed(context, '/add_subject'),
                  ),
                if (facultyType == 'Admin')
                  ListTile(
                    leading: const Icon(Icons.schedule),
                    title: const Text('Add Timetable'),
                    onTap: () => Navigator.pushNamed(context, '/add_timetable'),
                  ),
                ListTile(
                  leading: const Icon(Icons.person),
                  title: const Text('Announcement'),
                  onTap: () => Navigator.pushNamed(context, '/announcement'),
                ),
                if (facultyType == 'Admin')
                  ListTile(
                    leading: const Icon(Icons.person),
                    title: const Text('Staff Edge'),
                    onTap:
                        () =>
                            Navigator.pushNamed(context, '/under_construction'),
                  ),
                if (['HoD', 'Admin'].contains(facultyType))
                  ListTile(
                    leading: const Icon(Icons.person),
                    title: const Text('Student Daily Attendance'),
                    onTap:
                        () =>
                            Navigator.pushNamed(context, '/under_construction'),
                  ),
                if (['HoD', 'Admin'].contains(facultyType))
                  ListTile(
                    leading: const Icon(Icons.summarize),
                    title: const Text('Day Attendance Summary'),
                    onTap:
                        () =>
                            Navigator.pushNamed(context, '/under_construction'),
                  ),
                if (facultyType == 'Admin')
                  ListTile(
                    leading: const Icon(Icons.person),
                    title: const Text('Student Edge'),
                    onTap:
                        () =>
                            Navigator.pushNamed(context, '/under_construction'),
                  ),
                if (facultyType == 'Admin')
                  ListTile(
                    leading: const Icon(Icons.leave_bags_at_home),
                    title: const Text('Apply Leave / OD'),
                    onTap:
                        () =>
                            Navigator.pushNamed(context, '/under_construction'),
                  ),
                if (['HoD', 'Admin'].contains(facultyType))
                  ListTile(
                    leading: const Icon(Icons.report),
                    title: const Text('Subject Attendance Report'),
                    onTap:
                        () =>
                            Navigator.pushNamed(context, '/under_construction'),
                  ),
                if (['HoD', 'Admin'].contains(facultyType))
                  ListTile(
                    leading: const Icon(Icons.request_page),
                    title: const Text('Alteration Requests'),
                    onTap:
                        () =>
                            Navigator.pushNamed(context, '/under_construction'),
                  ),
                if (['HoD', 'Admin'].contains(facultyType))
                  ListTile(
                    leading: const Icon(Icons.request_page),
                    title: const Text('Permission Request'),
                    onTap:
                        () =>
                            Navigator.pushNamed(context, '/under_construction'),
                  ),
                if (facultyType == 'Admin')
                  ListTile(
                    leading: const Icon(Icons.person),
                    title: const Text('Staff Personal Attendance'),
                    onTap:
                        () =>
                            Navigator.pushNamed(context, '/under_construction'),
                  ),
                if (facultyType == 'Admin')
                  ListTile(
                    leading: const Icon(Icons.request_page),
                    title: const Text('Student Leave Request'),
                    onTap:
                        () =>
                            Navigator.pushNamed(context, '/under_construction'),
                  ),
                if (facultyType == 'Admin')
                  ListTile(
                    leading: const Icon(Icons.request_page),
                    title: const Text('Subject Reg Requests'),
                    onTap:
                        () =>
                            Navigator.pushNamed(context, '/under_construction'),
                  ),
                if (['HoD', 'Admin'].contains(facultyType))
                  ListTile(
                    leading: const Icon(Icons.report),
                    title: const Text('Syllabus Completion Report'),
                    onTap:
                        () =>
                            Navigator.pushNamed(context, '/under_construction'),
                  ),
                if (['HoD', 'Admin'].contains(facultyType))
                  ListTile(
                    leading: const Icon(Icons.grade),
                    title: const Text('Marks Entry'),
                    onTap:
                        () =>
                            Navigator.pushNamed(context, '/under_construction'),
                  ),
                if (['HoD', 'Admin'].contains(facultyType))
                  ListTile(
                    leading: const Icon(Icons.visibility),
                    title: const Text('View Marks'),
                    onTap:
                        () =>
                            Navigator.pushNamed(context, '/under_construction'),
                  ),
                if (['HoD', 'Admin'].contains(facultyType))
                  ListTile(
                    leading: const Icon(Icons.group),
                    title: const Text('Committee'),
                    onTap:
                        () =>
                            Navigator.pushNamed(context, '/under_construction'),
                  ),
                if (facultyType == 'Admin')
                  ListTile(
                    leading: const Icon(Icons.feedback),
                    title: const Text('Feed Back'),
                    onTap:
                        () =>
                            Navigator.pushNamed(context, '/under_construction'),
                  ),
                if (facultyType == 'Admin')
                  ListTile(
                    leading: const Icon(Icons.message),
                    title: const Text('Messages'),
                    onTap:
                        () =>
                            Navigator.pushNamed(context, '/under_construction'),
                  ),
                ListTile(
                  leading: const Icon(Icons.person),
                  title: const Text('Profile'),
                  onTap: () => Navigator.pushNamed(context, '/profile'),
                ),
                ListTile(
                  leading: const Icon(Icons.settings),
                  title: const Text('Settings'),
                  onTap: () => Navigator.pushNamed(context, '/settings'),
                ),
                const Divider(),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Logout'),
            onTap: () => _signOut(context),
          ),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Developed by: Null Pointers',
              style: TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
