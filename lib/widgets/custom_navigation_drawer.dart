import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

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
    final bool isWeb = MediaQuery.of(context).size.width > 800;

    // Navigation items
    final List<Map<String, dynamic>> navItems = [
      {'title': 'Home', 'icon': Icons.home, 'route': '/home'},
      {
        'title': 'My Time Table',
        'icon': Icons.schedule,
        'route': '/faculty_timetable',
      },
      {
        'title': 'My Subjects',
        'icon': Icons.book,
        'route': '/under_construction',
      },
      {
        'title': 'My Lesson Plans',
        'icon': Icons.list,
        'route': '/under_construction',
      },
      if (facultyType == 'Associate Professor')
        {
          'title': 'Student Leave Requests',
          'icon': Icons.person,
          'route': '/student_leave_requests',
        },
      if (facultyType == 'HoD')
        {
          'title': 'Student Leave Requests',
          'icon': Icons.person,
          'route': '/student_leave_requests_hod',
        },
      if (facultyType == 'Admin')
        {
          'title': 'Add Faculty',
          'icon': Icons.person_add,
          'route': '/add_faculty',
        },
      if (facultyType == 'Admin')
        {
          'title': 'Add Students',
          'icon': Icons.group,
          'route': '/add_students',
        },
      if (facultyType == 'Admin')
        {'title': 'Add Subjects', 'icon': Icons.book, 'route': '/add_subject'},
      if (facultyType == 'Admin')
        {
          'title': 'Add Timetable',
          'icon': Icons.schedule,
          'route': '/add_timetable',
        },
      {
        'title': 'Announcement',
        'icon': Icons.announcement,
        'route': '/announcement',
      },
      if (facultyType == 'Admin')
        {
          'title': 'Staff Edge',
          'icon': Icons.work,
          'route': '/under_construction',
        },
      if (['HoD', 'Admin'].contains(facultyType))
        {
          'title': 'Student Daily Attendance',
          'icon': Icons.event_available,
          'route': '/under_construction',
        },
      if (['HoD', 'Admin'].contains(facultyType))
        {
          'title': 'Day Attendance Summary',
          'icon': Icons.summarize,
          'route': '/under_construction',
        },
      if (facultyType == 'Admin')
        {
          'title': 'Student Edge',
          'icon': Icons.school,
          'route': '/under_construction',
        },
      if (facultyType == 'Admin')
        {
          'title': 'Apply Leave / OD',
          'icon': Icons.leave_bags_at_home,
          'route': '/under_construction',
        },
      if (['HoD', 'Admin'].contains(facultyType))
        {
          'title': 'Subject Attendance Report',
          'icon': Icons.report,
          'route': '/under_construction',
        },
      if (['HoD', 'Admin'].contains(facultyType))
        {
          'title': 'Alteration Requests',
          'icon': Icons.request_page,
          'route': '/under_construction',
        },
      if (['HoD', 'Admin'].contains(facultyType))
        {
          'title': 'Permission Request',
          'icon': Icons.request_page,
          'route': '/under_construction',
        },
      if (facultyType == 'Admin')
        {
          'title': 'Staff Personal Attendance',
          'icon': Icons.person,
          'route': '/under_construction',
        },
      if (facultyType == 'Admin')
        {
          'title': 'Student Leave Request',
          'icon': Icons.request_page,
          'route': '/under_construction',
        },
      if (facultyType == 'Admin')
        {
          'title': 'Subject Reg Requests',
          'icon': Icons.request_page,
          'route': '/under_construction',
        },
      if (['HoD', 'Admin'].contains(facultyType))
        {
          'title': 'Syllabus Completion Report',
          'icon': Icons.report,
          'route': '/under_construction',
        },
      if (['HoD', 'Admin'].contains(facultyType))
        {
          'title': 'Marks Entry',
          'icon': Icons.grade,
          'route': '/under_construction',
        },
      if (['HoD', 'Admin'].contains(facultyType))
        {
          'title': 'View Marks',
          'icon': Icons.visibility,
          'route': '/under_construction',
        },
      if (['HoD', 'Admin'].contains(facultyType))
        {
          'title': 'Committee',
          'icon': Icons.group,
          'route': '/under_construction',
        },
      if (facultyType == 'Admin')
        {
          'title': 'Feed Back',
          'icon': Icons.feedback,
          'route': '/under_construction',
        },
      if (facultyType == 'Admin')
        {
          'title': 'Messages',
          'icon': Icons.message,
          'route': '/under_construction',
        },
      {'title': 'Profile', 'icon': Icons.person, 'route': '/profile'},
      {'title': 'Settings', 'icon': Icons.settings, 'route': '/settings'},
    ];

    // Build navigation item widget
    Widget buildNavItem(Map<String, dynamic> item, {bool isWeb = false}) {
      return isWeb
          ? MouseRegion(
            cursor: SystemMouseCursors.click,
            child: ListTile(
              leading: Icon(item['icon'], color: Colors.grey[700]),
              title: Text(
                item['title'],
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[800],
                ),
              ),
              hoverColor: Colors.blue.withOpacity(0.1),
              onTap: () {
                Navigator.pushNamed(context, item['route']);
                if (!isWeb) Navigator.pop(context); // Close drawer on mobile
              },
            ),
          )
          : ListTile(
            leading: Icon(item['icon']),
            title: Text(item['title']),
            onTap: () {
              Navigator.pushNamed(context, item['route']);
              Navigator.pop(context); // Close drawer
            },
          );
    }

    // Web Sidebar
    if (isWeb) {
      return Container(
        width: 250,
        color: Colors.grey[100],
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16.0),
              color: Colors.blue,
              child: GestureDetector(
                onTap: () => Navigator.pushNamed(context, '/profile'),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 30,
                      backgroundImage: NetworkImage(
                        'https://via.placeholder.com/150',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _userData?['name'] ?? 'Guest',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            user?.email ?? 'guest@example.com',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Navigation items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(8.0),
                children:
                    navItems
                        .map((item) => buildNavItem(item, isWeb: true))
                        .toList(),
              ),
            ),
            // Logout and footer
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text(
                'Logout',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w500,
                ),
              ),
              hoverColor: Colors.red.withOpacity(0.1),
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

    // Mobile Drawer
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
              children: navItems.map((item) => buildNavItem(item)).toList(),
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Logout', style: TextStyle(color: Colors.red)),
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
