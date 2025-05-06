import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:carousel_slider/carousel_slider.dart' as carousel_slider;
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../widgets/custom_navigation_drawer.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> _announcements = [];
  bool _isLoadingAnnouncements = true;
  Map<String, dynamic>? _userData;

  @override
  void initState() {
    super.initState();
    _fetchUserDataAndAnnouncements();
  }

  Future<void> _fetchUserDataAndAnnouncements() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _isLoadingAnnouncements = false;
      });
      return;
    }

    try {
      final userDoc =
          await FirebaseFirestore.instance
              .collection('faculty_members')
              .doc(user.uid)
              .get();

      if (!userDoc.exists) {
        setState(() {
          _isLoadingAnnouncements = false;
        });
        return;
      }

      _userData = userDoc.data();

      final snapshot =
          await FirebaseFirestore.instance
              .collection('announcements')
              .orderBy('timestamp', descending: true)
              .get();

      final filteredAnnouncements = <Map<String, dynamic>>[];
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final viewers = data['viewers'] as String?;
        final facultyType = _userData?['faculty_type'] as String?;
        final userDept = _userData?['department'] as String?;
        final userName = _userData?['name'] as String?;

        if (viewers == 'All Faculties' ||
            viewers == userDept ||
            viewers == userName ||
            viewers == 'Everyone') {
          filteredAnnouncements.add({
            'announcement': data['announcement'] as String,
            'announcer': data['announcer'] as String,
            'timestamp': (data['timestamp'] as Timestamp).toDate(),
            'viewers': viewers,
            'faculty_type': data['faculty_type'] as String?,
          });
        }
      }

      setState(() {
        _announcements = filteredAnnouncements;
        _isLoadingAnnouncements = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingAnnouncements = false;
      });
    }
  }

  void _showAnnouncementDialog(Map<String, dynamic> announcement) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Announcement Details'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  announcement['announcement'],
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 12),
                Text(
                  'By: ${announcement['announcer']}',
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 4),
                Text(
                  'For: ${announcement['viewers']}',
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 4),
                Text(
                  'Posted: ${announcement['timestamp'].toString().substring(0, 16)}',
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF0C4D83);
    final bool isWeb = MediaQuery.of(context).size.width > 800;

    final List<Map<String, dynamic>> quickLinks = [
      {
        'text': 'Time Table',
        'color': Colors.orange,
        'route': '/faculty_timetable',
        'icon': FontAwesomeIcons.calendar,
      },
      {
        'text': 'My Subjects',
        'color': Colors.deepPurpleAccent,
        'route': '/under_construction',
        'icon': FontAwesomeIcons.book,
      },
      {
        'text': 'Lesson Plans',
        'color': Colors.blue,
        'route': '/under_construction',
        'icon': FontAwesomeIcons.list,
      },
      {
        'text': 'Announcement',
        'color': Colors.green,
        'route': '/announcement',
        'icon': FontAwesomeIcons.bullhorn,
      },
      {
        'text': 'Profile',
        'color': Colors.red,
        'route': '/profile',
        'icon': FontAwesomeIcons.user,
      },
    ];

    final List<Map<String, dynamic>> adminLinks = [
      if (_userData?['faculty_type'] == 'Admin')
        {
          'text': 'Add Faculty',
          'color': Colors.teal,
          'route': '/add_faculty',
          'icon': FontAwesomeIcons.userPlus,
        },
      if (_userData?['faculty_type'] == 'Admin')
        {
          'text': 'Add Students',
          'color': Colors.deepPurple,
          'route': '/add_students',
          'icon': FontAwesomeIcons.users,
        },
      if (_userData?['faculty_type'] == 'Admin')
        {
          'text': 'Add Subjects',
          'color': Colors.lightGreen,
          'route': '/add_subject',
          'icon': FontAwesomeIcons.book,
        },
      if (_userData?['faculty_type'] == 'Admin')
        {
          'text': 'Add Timetable',
          'color': Colors.amber,
          'route': '/add_timetable',
          'icon': FontAwesomeIcons.calendarAlt,
        },
    ];

    final List<Map<String, dynamic>> hodAdminLinks = [
      if (['HoD', 'Admin'].contains(_userData?['faculty_type']))
        {
          'text': 'Student Attendance',
          'color': Colors.teal,
          'route': '/under_construction',
          'icon': FontAwesomeIcons.checkSquare,
        },
      if (['HoD', 'Admin'].contains(_userData?['faculty_type']))
        {
          'text': 'Attendance Summary',
          'color': Colors.deepPurple,
          'route': '/under_construction',
          'icon': FontAwesomeIcons.chartBar,
        },
      if (['HoD', 'Admin'].contains(_userData?['faculty_type']))
        {
          'text': 'Syllabus Report',
          'color': Colors.lightGreen,
          'route': '/under_construction',
          'icon': FontAwesomeIcons.fileAlt,
        },
      if (['HoD', 'Admin'].contains(_userData?['faculty_type']))
        {
          'text': 'Marks Entry',
          'color': Colors.amber,
          'route': '/under_construction',
          'icon': FontAwesomeIcons.pen,
        },
    ];

    final List<String> carouselItems = [
      'https://ritchennai.org/img/rit-about.jpg',
      'https://ritchennai.org/image/rit_imgs/CoursesOffered/1.jpg',
      'https://content.jdmagicbox.com/v2/comp/chennai/u5/044pxx44.xx44.100223165126.x1u5/catalogue/rajalakshmi-institute-of-technology-thirumazhisai-chennai-engineering-colleges-6ddqz7.jpg',
    ];

    return Scaffold(
      drawer: isWeb ? null : const AppDrawer(), // Drawer only for mobile
      body:
          isWeb
              ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AppDrawer(), // Persistent sidebar for web
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Carousel
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(15.0),
                            ),
                            child: carousel_slider.CarouselSlider(
                              options: carousel_slider.CarouselOptions(
                                height: 400.0,
                                enlargeCenterPage: true,
                                autoPlay: true,
                                aspectRatio: 16 / 9,
                                autoPlayInterval: const Duration(seconds: 3),
                                viewportFraction: 0.7,
                                autoPlayAnimationDuration: const Duration(
                                  milliseconds: 800,
                                ),
                              ),
                              items:
                                  carouselItems.map((item) {
                                    return Container(
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 5.0,
                                      ),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(
                                          15.0,
                                        ),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(
                                          15.0,
                                        ),
                                        child: Image.network(
                                          item,
                                          fit: BoxFit.cover,
                                          loadingBuilder: (
                                            context,
                                            child,
                                            loadingProgress,
                                          ) {
                                            if (loadingProgress == null)
                                              return child;
                                            return Center(
                                              child: CircularProgressIndicator(
                                                value:
                                                    loadingProgress
                                                                .expectedTotalBytes !=
                                                            null
                                                        ? loadingProgress
                                                                .cumulativeBytesLoaded /
                                                            loadingProgress
                                                                .expectedTotalBytes!
                                                        : null,
                                                color: primaryColor,
                                              ),
                                            );
                                          },
                                          errorBuilder:
                                              (context, error, stackTrace) =>
                                                  Container(
                                                    color: Colors.grey[200],
                                                    child: const Center(
                                                      child: Text(
                                                        'Image failed to load',
                                                      ),
                                                    ),
                                                  ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                            ),
                          ),
                          const SizedBox(height: 24),
                          // Announcements Section
                          Text(
                            'Announcements',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                          Container(
                            height: 3,
                            width: 80,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [primaryColor, Colors.blue[300]!],
                              ),
                            ),
                            margin: const EdgeInsets.only(top: 4),
                          ),
                          const SizedBox(height: 16),
                          _isLoadingAnnouncements
                              ? const Center(child: CircularProgressIndicator())
                              : _announcements.isEmpty
                              ? const Text(
                                'No announcements available',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey,
                                ),
                              )
                              : GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate:
                                    const SliverGridDelegateWithMaxCrossAxisExtent(
                                      maxCrossAxisExtent: 400,
                                      childAspectRatio: 3 / 2,
                                      crossAxisSpacing: 16,
                                      mainAxisSpacing: 16,
                                    ),
                                itemCount: _announcements.length,
                                itemBuilder: (context, index) {
                                  final announcement = _announcements[index];
                                  return Card(
                                    elevation: 4,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(15.0),
                                    ),
                                    child: InkWell(
                                      onTap:
                                          () => _showAnnouncementDialog(
                                            announcement,
                                          ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                announcement['announcement'],
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              'By: ${announcement['announcer']}',
                                              style: const TextStyle(
                                                fontSize: 14,
                                                color: Colors.grey,
                                              ),
                                            ),
                                            Text(
                                              'For: ${announcement['viewers']}',
                                              style: const TextStyle(
                                                fontSize: 14,
                                                color: Colors.grey,
                                              ),
                                            ),
                                            Text(
                                              'Posted: ${announcement['timestamp'].toString().substring(0, 16)}',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                          const SizedBox(height: 24),
                          // Quick Links Section
                          Text(
                            'Quick Links',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                          Container(
                            height: 3,
                            width: 80,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [primaryColor, Colors.blue[300]!],
                              ),
                            ),
                            margin: const EdgeInsets.only(top: 4),
                          ),
                          const SizedBox(height: 16),
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                const SliverGridDelegateWithMaxCrossAxisExtent(
                                  maxCrossAxisExtent: 200,
                                  childAspectRatio: 1,
                                  crossAxisSpacing: 16,
                                  mainAxisSpacing: 16,
                                ),
                            itemCount: quickLinks.length,
                            itemBuilder: (context, index) {
                              return Card(
                                elevation: 4,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20.0),
                                ),
                                child: InkWell(
                                  onTap:
                                      () => Navigator.pushNamed(
                                        context,
                                        quickLinks[index]['route'],
                                      ),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          quickLinks[index]['color']
                                              .withOpacity(0.9),
                                          quickLinks[index]['color']
                                              .withOpacity(0.7),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(20.0),
                                    ),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        FaIcon(
                                          quickLinks[index]['icon'],
                                          color: Colors.white,
                                          size: 48,
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          quickLinks[index]['text'],
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                          ),
                                          textAlign: TextAlign.center,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                          if (adminLinks.isNotEmpty) ...[
                            const SizedBox(height: 24),
                            Text(
                              'Admin Actions',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
                              ),
                            ),
                            Container(
                              height: 3,
                              width: 80,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [primaryColor, Colors.blue[300]!],
                                ),
                              ),
                              margin: const EdgeInsets.only(top: 4),
                            ),
                            const SizedBox(height: 16),
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate:
                                  const SliverGridDelegateWithMaxCrossAxisExtent(
                                    maxCrossAxisExtent: 200,
                                    childAspectRatio: 1,
                                    crossAxisSpacing: 16,
                                    mainAxisSpacing: 16,
                                  ),
                              itemCount: adminLinks.length,
                              itemBuilder: (context, index) {
                                return Card(
                                  elevation: 4,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20.0),
                                  ),
                                  child: InkWell(
                                    onTap:
                                        () => Navigator.pushNamed(
                                          context,
                                          adminLinks[index]['route'],
                                        ),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            adminLinks[index]['color']
                                                .withOpacity(0.9),
                                            adminLinks[index]['color']
                                                .withOpacity(0.7),
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          20.0,
                                        ),
                                      ),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          FaIcon(
                                            adminLinks[index]['icon'],
                                            color: Colors.white,
                                            size: 48,
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            adminLinks[index]['text'],
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                            ),
                                            textAlign: TextAlign.center,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                          if (hodAdminLinks.isNotEmpty) ...[
                            const SizedBox(height: 24),
                            Text(
                              'Reports & Actions',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
                              ),
                            ),
                            Container(
                              height: 3,
                              width: 80,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [primaryColor, Colors.blue[300]!],
                                ),
                              ),
                              margin: const EdgeInsets.only(top: 4),
                            ),
                            const SizedBox(height: 16),
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate:
                                  const SliverGridDelegateWithMaxCrossAxisExtent(
                                    maxCrossAxisExtent: 200,
                                    childAspectRatio: 1,
                                    crossAxisSpacing: 16,
                                    mainAxisSpacing: 16,
                                  ),
                              itemCount: hodAdminLinks.length,
                              itemBuilder: (context, index) {
                                return Card(
                                  elevation: 4,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20.0),
                                  ),
                                  child: InkWell(
                                    onTap:
                                        () => Navigator.pushNamed(
                                          context,
                                          hodAdminLinks[index]['route'],
                                        ),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            hodAdminLinks[index]['color']
                                                .withOpacity(0.9),
                                            hodAdminLinks[index]['color']
                                                .withOpacity(0.7),
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          20.0,
                                        ),
                                      ),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          FaIcon(
                                            hodAdminLinks[index]['icon'],
                                            color: Colors.white,
                                            size: 48,
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            hodAdminLinks[index]['text'],
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                            ),
                                            textAlign: TextAlign.center,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              )
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(15.0),
                      ),
                      child: carousel_slider.CarouselSlider(
                        options: carousel_slider.CarouselOptions(
                          height: 200.0,
                          enlargeCenterPage: true,
                          autoPlay: true,
                          aspectRatio: 16 / 9,
                          autoPlayInterval: const Duration(seconds: 3),
                          viewportFraction: 0.85,
                          autoPlayAnimationDuration: const Duration(
                            milliseconds: 800,
                          ),
                        ),
                        items:
                            carouselItems.map((item) {
                              return Builder(
                                builder: (BuildContext context) {
                                  return Container(
                                    width: MediaQuery.of(context).size.width,
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 5.0,
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(15.0),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(15.0),
                                      child: Image.network(
                                        item,
                                        fit: BoxFit.cover,
                                        loadingBuilder: (
                                          context,
                                          child,
                                          loadingProgress,
                                        ) {
                                          if (loadingProgress == null)
                                            return child;
                                          return Center(
                                            child: CircularProgressIndicator(
                                              value:
                                                  loadingProgress
                                                              .expectedTotalBytes !=
                                                          null
                                                      ? loadingProgress
                                                              .cumulativeBytesLoaded /
                                                          loadingProgress
                                                              .expectedTotalBytes!
                                                      : null,
                                              color: primaryColor,
                                            ),
                                          );
                                        },
                                        errorBuilder:
                                            (context, error, stackTrace) =>
                                                Container(
                                                  color: Colors.grey[200],
                                                  child: const Center(
                                                    child: Text(
                                                      'Image failed to load',
                                                    ),
                                                  ),
                                                ),
                                      ),
                                    ),
                                  );
                                },
                              );
                            }).toList(),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Announcements',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                          Container(
                            height: 3,
                            width: 60,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [primaryColor, Colors.blue[300]!],
                              ),
                            ),
                            margin: const EdgeInsets.only(top: 4),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _isLoadingAnnouncements
                        ? const Center(child: CircularProgressIndicator())
                        : _announcements.isEmpty
                        ? const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16.0),
                          child: Text(
                            'No announcements available',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        )
                        : Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(15.0),
                          ),
                          child: carousel_slider.CarouselSlider(
                            options: carousel_slider.CarouselOptions(
                              height: 150.0,
                              enlargeCenterPage: true,
                              autoPlay: true,
                              aspectRatio: 16 / 9,
                              autoPlayInterval: const Duration(seconds: 5),
                              viewportFraction: 0.85,
                              autoPlayAnimationDuration: const Duration(
                                milliseconds: 800,
                              ),
                            ),
                            items:
                                _announcements.map((announcement) {
                                  return Builder(
                                    builder: (BuildContext context) {
                                      return GestureDetector(
                                        onTap:
                                            () => _showAnnouncementDialog(
                                              announcement,
                                            ),
                                        child: Container(
                                          width:
                                              MediaQuery.of(context).size.width,
                                          margin: const EdgeInsets.symmetric(
                                            horizontal: 5.0,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(
                                              15.0,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.grey.withOpacity(
                                                  0.3,
                                                ),
                                                spreadRadius: 1,
                                                blurRadius: 6,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: Padding(
                                            padding: const EdgeInsets.all(16.0),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    announcement['announcement'],
                                                    style: const TextStyle(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                                Text(
                                                  'By: ${announcement['announcer']}',
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    color: Colors.grey,
                                                  ),
                                                ),
                                                Text(
                                                  'For: ${announcement['viewers']}',
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    color: Colors.grey,
                                                  ),
                                                ),
                                                Text(
                                                  'Posted: ${announcement['timestamp'].toString().substring(0, 16)}',
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                }).toList(),
                          ),
                        ),
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Quick Links',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                          Container(
                            height: 3,
                            width: 60,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [primaryColor, Colors.blue[300]!],
                              ),
                            ),
                            margin: const EdgeInsets.only(top: 4),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 150,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: quickLinks.length,
                        itemBuilder: (context, index) {
                          return AnimatedOpacity(
                            opacity: 1.0,
                            duration: Duration(
                              milliseconds: 300 + (index * 100),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8.0,
                                vertical: 4.0,
                              ),
                              child: GestureDetector(
                                onTap:
                                    () => Navigator.pushNamed(
                                      context,
                                      quickLinks[index]['route'],
                                    ),
                                child: TweenAnimationBuilder(
                                  tween: Tween<double>(begin: 1.0, end: 1.0),
                                  duration: const Duration(milliseconds: 200),
                                  builder: (context, scale, child) {
                                    return Transform.scale(
                                      scale: scale,
                                      child: child,
                                    );
                                  },
                                  child: Container(
                                    width: 120,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          quickLinks[index]['color']
                                              .withOpacity(0.9),
                                          quickLinks[index]['color']
                                              .withOpacity(0.7),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(20.0),
                                      boxShadow: [
                                        BoxShadow(
                                          color: quickLinks[index]['color']
                                              .withOpacity(0.3),
                                          spreadRadius: 1,
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        FaIcon(
                                          quickLinks[index]['icon'],
                                          color: Colors.white,
                                          size: 40,
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          quickLinks[index]['text'],
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                          ),
                                          textAlign: TextAlign.center,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    if (adminLinks.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Admin Actions',
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
                              ),
                            ),
                            Container(
                              height: 3,
                              width: 60,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [primaryColor, Colors.blue[300]!],
                                ),
                              ),
                              margin: const EdgeInsets.only(top: 4),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 150,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: adminLinks.length,
                          itemBuilder: (context, index) {
                            return AnimatedOpacity(
                              opacity: 1.0,
                              duration: Duration(
                                milliseconds: 300 + (index * 100),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8.0,
                                  vertical: 4.0,
                                ),
                                child: GestureDetector(
                                  onTap:
                                      () => Navigator.pushNamed(
                                        context,
                                        adminLinks[index]['route'],
                                      ),
                                  child: TweenAnimationBuilder(
                                    tween: Tween<double>(begin: 1.0, end: 1.0),
                                    duration: const Duration(milliseconds: 200),
                                    builder: (context, scale, child) {
                                      return Transform.scale(
                                        scale: scale,
                                        child: child,
                                      );
                                    },
                                    child: Container(
                                      width: 120,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            adminLinks[index]['color']
                                                .withOpacity(0.9),
                                            adminLinks[index]['color']
                                                .withOpacity(0.7),
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          20.0,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: adminLinks[index]['color']
                                                .withOpacity(0.3),
                                            spreadRadius: 1,
                                            blurRadius: 6,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          FaIcon(
                                            adminLinks[index]['icon'],
                                            color: Colors.white,
                                            size: 40,
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            adminLinks[index]['text'],
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                            ),
                                            textAlign: TextAlign.center,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                    if (hodAdminLinks.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Reports & Actions',
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
                              ),
                            ),
                            Container(
                              height: 3,
                              width: 60,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [primaryColor, Colors.blue[300]!],
                                ),
                              ),
                              margin: const EdgeInsets.only(top: 4),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 150,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: hodAdminLinks.length,
                          itemBuilder: (context, index) {
                            return AnimatedOpacity(
                              opacity: 1.0,
                              duration: Duration(
                                milliseconds: 300 + (index * 100),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8.0,
                                  vertical: 4.0,
                                ),
                                child: GestureDetector(
                                  onTap:
                                      () => Navigator.pushNamed(
                                        context,
                                        hodAdminLinks[index]['route'],
                                      ),
                                  child: TweenAnimationBuilder(
                                    tween: Tween<double>(begin: 1.0, end: 1.0),
                                    duration: const Duration(milliseconds: 200),
                                    builder: (context, scale, child) {
                                      return Transform.scale(
                                        scale: scale,
                                        child: child,
                                      );
                                    },
                                    child: Container(
                                      width: 120,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            hodAdminLinks[index]['color']
                                                .withOpacity(0.9),
                                            hodAdminLinks[index]['color']
                                                .withOpacity(0.7),
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          20.0,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: hodAdminLinks[index]['color']
                                                .withOpacity(0.3),
                                            spreadRadius: 1,
                                            blurRadius: 6,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          FaIcon(
                                            hodAdminLinks[index]['icon'],
                                            color: Colors.white,
                                            size: 40,
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            hodAdminLinks[index]['text'],
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                            ),
                                            textAlign: TextAlign.center,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
    );
  }
}
