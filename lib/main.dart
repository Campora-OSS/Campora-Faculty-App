import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ritian_faculty/screens/add_faculty_screen.dart';
import 'package:ritian_faculty/screens/add_student_screen.dart';
import 'package:ritian_faculty/screens/add_subject_screen.dart';
import 'package:ritian_faculty/screens/add_timetable_screen.dart';
import 'package:ritian_faculty/screens/announcement_screen.dart';
import 'package:ritian_faculty/screens/faculty_timetable_screen.dart';
import 'package:ritian_faculty/screens/student_leave_requests_hod.dart';
import 'package:ritian_faculty/screens/student_leave_requests_screen.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/first_time_sign_in_screen.dart';
import 'screens/under_construction_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Firebase Auth App',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      initialRoute: '/',
      routes: {
        '/':
            (context) => StreamBuilder<User?>(
              stream: FirebaseAuth.instance.authStateChanges(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasData) {
                  return const HomeScreen();
                }
                return LoginScreen();
              },
            ),
        '/home': (context) => const HomeScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/first_time_sign_in': (context) => const FirstTimeSignInScreen(),
        '/student_leave_requests': (context) => const StudentLeaveRequestsScreen(),
        '/student_leave_requests_hod': (context) => const StudentLeaveRequestsHodScreen(),
        '/add_students': (context) => AddStudentScreen(),
        '/add_faculty': (context) => AddFacultyScreen(),
        '/announcement': (context) => AnnouncementScreen(),
        '/add_subject': (context) => const AddSubjectScreen(),
        '/add_timetable': (context) => const AddTimetableScreen(),
        '/faculty_timetable': (context) => const FacultyTimetableScreen(),
        '/under_construction': (context) => const UnderConstructionScreen(),
      },
    );
  }
}
