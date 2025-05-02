import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AnnouncementPage extends StatefulWidget {
  @override
  _AnnouncementPageState createState() => _AnnouncementPageState();
}

class _AnnouncementPageState extends State<AnnouncementPage> {
  final TextEditingController _announcementController = TextEditingController();
  String? _selectedViewer;
  final List<String> viewerOptions = ['Students', 'Teachers', 'All'];

  Future<void> _submitAnnouncement() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null ||
        _selectedViewer == null ||
        _announcementController.text.isEmpty)
      return;

    // Fetch announcer name from faculty_members
    final facultySnapshot =
        await FirebaseFirestore.instance
            .collection('faculty_members')
            .doc(currentUser.uid)
            .get();

    final announcerName = facultySnapshot.data()?['name'] ?? 'Unknown';

    // Create announcement document
    await FirebaseFirestore.instance.collection('announcements').add({
      'announcement': _announcementController.text,
      'announcer': announcerName,
      'timestamp': Timestamp.now(),
      'viewers': _selectedViewer,
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Announcement posted.')));
    _announcementController.clear();
    setState(() {
      _selectedViewer = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Post Announcement')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _announcementController,
              decoration: InputDecoration(labelText: 'Announcement'),
            ),
            SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedViewer,
              items:
                  viewerOptions.map((viewer) {
                    return DropdownMenuItem(value: viewer, child: Text(viewer));
                  }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedViewer = value;
                });
              },
              decoration: InputDecoration(labelText: 'Select Viewers'),
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: _submitAnnouncement,
              child: Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }
}
