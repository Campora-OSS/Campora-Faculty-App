import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AppDrawer extends StatefulWidget {
  const AppDrawer({super.key});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  bool _isSigningOut = false;
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
    bool? confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Confirm Sign Out'),
            content: const Text('Are you sure you want to sign out?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Sign Out'),
              ),
            ],
          ),
    );

    if (confirm == true) {
      setState(() {
        _isSigningOut = true;
      });
      try {
        await FirebaseAuth.instance.signOut();
        Navigator.pushReplacementNamed(context, '/');
      } finally {
        if (mounted) {
          setState(() {
            _isSigningOut = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final facultyType = _userData?['faculty_type'] ?? '';

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: Colors.blue),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _userData?['staff_code'] ?? 'Staff Code',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  user?.email ?? 'Email',
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Text(
                  'Biometric ID: ${_userData?['biometric_id'] ?? 'N/A'}',
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.dashboard),
            title: const Text('Dashboard'),
            onTap: () {
              Navigator.pushReplacementNamed(context, '/home');
            },
          ),
          ListTile(
            leading: const Icon(Icons.schedule),
            title: const Text('My Time Table'),
            onTap: () {
              Navigator.pushReplacementNamed(context, '/under_construction');
            },
          ),
          ListTile(
            leading: const Icon(Icons.book),
            title: const Text('My Subjects'),
            onTap: () {
              Navigator.pushReplacementNamed(context, '/under_construction');
            },
          ),
          ListTile(
            leading: const Icon(Icons.list),
            title: const Text('My Lesson Plans'),
            onTap: () {
              Navigator.pushReplacementNamed(context, '/under_construction');
            },
          ),
          //Student Leave Requests for Incharge
          if (facultyType == 'Associate Professor')
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Student Leave Requests'),
              onTap: () {
                Navigator.pushReplacementNamed(context, '/student_leave_requests');
              },
            ),
          if (facultyType == 'HoD')
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Student Leave Requests'),
              onTap: () {
                Navigator.pushReplacementNamed(
                  context,
                  '/student_leave_requests_hod',
                );
              },
            ),
          if (facultyType == 'Admin')
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Add Faculty'),
              onTap: () {
                Navigator.pushReplacementNamed(context, '/add_faculty');
              },
            ),
            if (facultyType == 'Admin')
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Add Students'),
              onTap: () {
                Navigator.pushReplacementNamed(context, '/add_students');
              },
            ),
          if (facultyType == 'Admin')
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Staff Edge'),
              onTap: () {
                Navigator.pushReplacementNamed(context, '/under_construction');
              },
            ),
          if (['HoD', 'Admin'].contains(facultyType))
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Student Daily Attendance'),
              onTap: () {
                Navigator.pushReplacementNamed(context, '/under_construction');
              },
            ),
          if (['HoD', 'Admin'].contains(facultyType))
            ListTile(
              leading: const Icon(Icons.summarize),
              title: const Text('Day Attendance Summary'),
              onTap: () {
                Navigator.pushReplacementNamed(context, '/under_construction');
              },
            ),
          if (facultyType == 'Admin')
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Student Edge'),
              onTap: () {
                Navigator.pushReplacementNamed(context, '/under_construction');
              },
            ),
          if (facultyType == 'Admin')
            ListTile(
              leading: const Icon(Icons.leave_bags_at_home),
              title: const Text('Apply Leave / OD'),
              onTap: () {
                Navigator.pushReplacementNamed(context, '/under_construction');
              },
            ),
          if (['HoD', 'Admin'].contains(facultyType))
            ListTile(
              leading: const Icon(Icons.report),
              title: const Text('Subject Attendance Report'),
              onTap: () {
                Navigator.pushReplacementNamed(context, '/under_construction');
              },
            ),
          if (['HoD', 'Admin'].contains(facultyType))
            ListTile(
              leading: const Icon(Icons.request_page),
              title: const Text('Alteration Requests'),
              onTap: () {
                Navigator.pushReplacementNamed(context, '/under_construction');
              },
            ),
          if (['HoD', 'Admin'].contains(facultyType))
            ListTile(
              leading: const Icon(Icons.request_page),
              title: const Text('Permission Request'),
              onTap: () {
                Navigator.pushReplacementNamed(context, '/under_construction');
              },
            ),
          if (facultyType == 'Admin')
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Staff Personal Attendance'),
              onTap: () {
                Navigator.pushReplacementNamed(context, '/under_construction');
              },
            ),
          if (facultyType == 'Admin')
            ListTile(
              leading: const Icon(Icons.request_page),
              title: const Text('Student Leave Request'),
              onTap: () {
                Navigator.pushReplacementNamed(context, '/under_construction');
              },
            ),
          if (facultyType == 'Admin')
            ListTile(
              leading: const Icon(Icons.request_page),
              title: const Text('Subject Reg Requests'),
              onTap: () {
                Navigator.pushReplacementNamed(context, '/under_construction');
              },
            ),
          if (['HoD', 'Admin'].contains(facultyType))
            ListTile(
              leading: const Icon(Icons.report),
              title: const Text('Syllabus Completion Report'),
              onTap: () {
                Navigator.pushReplacementNamed(context, '/under_construction');
              },
            ),
          if (['HoD', 'Admin'].contains(facultyType))
            ListTile(
              leading: const Icon(Icons.grade),
              title: const Text('Marks Entry'),
              onTap: () {
                Navigator.pushReplacementNamed(context, '/under_construction');
              },
            ),
          if (['HoD', 'Admin'].contains(facultyType))
            ListTile(
              leading: const Icon(Icons.visibility),
              title: const Text('View Marks'),
              onTap: () {
                Navigator.pushReplacementNamed(context, '/under_construction');
              },
            ),
          if (['HoD', 'Admin'].contains(facultyType))
            ListTile(
              leading: const Icon(Icons.group),
              title: const Text('Committee'),
              onTap: () {
                Navigator.pushReplacementNamed(context, '/under_construction');
              },
            ),
          if (facultyType == 'Admin')
            ListTile(
              leading: const Icon(Icons.feedback),
              title: const Text('Feed Back'),
              onTap: () {
                Navigator.pushReplacementNamed(context, '/under_construction');
              },
            ),
          if (facultyType == 'Admin')
            ListTile(
              leading: const Icon(Icons.message),
              title: const Text('Messages'),
              onTap: () {
                Navigator.pushReplacementNamed(context, '/under_construction');
              },
            ),
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('Profile'),
            onTap: () {
              Navigator.pushReplacementNamed(context, '/profile');
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Settings'),
            onTap: () {
              Navigator.pushReplacementNamed(context, '/settings');
            },
          ),
          ListTile(
            leading:
                _isSigningOut
                    ? const CircularProgressIndicator()
                    : const Icon(Icons.logout),
            title: const Text('Sign Out'),
            onTap: _isSigningOut ? null : () => _signOut(context),
          ),
        ],
      ),
    );
  }
}
