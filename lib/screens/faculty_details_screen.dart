import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ritian_faculty/widgets/custom_navigation_drawer.dart';

class FacultyDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> faculty;
  final String uid;

  const FacultyDetailsScreen({
    super.key,
    required this.faculty,
    required this.uid,
  });

  @override
  _FacultyDetailsScreenState createState() => _FacultyDetailsScreenState();
}

class _FacultyDetailsScreenState extends State<FacultyDetailsScreen> {
  String? _selectedClass;
  final List<String> _classes = ['AIDS E', 'CSE A', 'ECE B', 'MECH C'];
  bool _isLoading = false;
  bool _isDeleting = false;

  Future<void> _assignClassIncharge() async {
    if (_selectedClass == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a class.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await FirebaseFirestore.instance
          .collection('faculty_members')
          .doc(widget.uid)
          .update({'incharge': _selectedClass});

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Class in-charge assigned successfully.')),
      );

      Navigator.pop(context, true);
    } catch (e) {
      print('Error assigning class in-charge: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to assign class in-charge: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteFaculty() async {
    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: const Text(
          'Are you sure you want to delete this faculty member? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isDeleting = true;
    });

    try {
      // Delete from Firestore
      // This will trigger the Cloud Function to delete the user from Firebase Authentication
      await FirebaseFirestore.instance
          .collection('faculty_members')
          .doc(widget.uid)
          .delete();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Faculty member deleted successfully.')),
      );

      Navigator.pop(context, true);
    } catch (e) {
      print('Error deleting faculty: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete faculty: $e')),
      );
    } finally {
      setState(() {
        _isDeleting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isWeb = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Faculty Details',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF0C4D83),
        leading: isWeb
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              )
            : Builder(
                builder: (context) => IconButton(
                  icon: const Icon(Icons.menu, color: Colors.white),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              ),
      ),
      drawer: isWeb ? null : const AppDrawer(),
      body: isWeb
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppDrawer(),
                Expanded(child: _buildContent(context, isWeb)),
              ],
            )
          : _buildContent(context, isWeb),
    );
  }

  Widget _buildContent(BuildContext context, bool isWeb) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.maxHeight - (isWeb ? 104 : 88);
        return SingleChildScrollView(
          child: Padding(
            padding: isWeb
                ? const EdgeInsets.fromLTRB(24, 24, 24, 16)
                : const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${widget.faculty['name'] ?? 'Unknown'} Details',
                  style: TextStyle(
                    fontSize: isWeb ? 28 : 24,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0C4D83),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  elevation: isWeb ? 8 : 6,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: Padding(
                    padding: isWeb
                        ? const EdgeInsets.all(20.0)
                        : const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Name: ${widget.faculty['name'] ?? 'N/A'}',
                          style: TextStyle(
                            fontSize: isWeb ? 16 : 14,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Email: ${widget.faculty['email'] ?? 'N/A'}',
                          style: TextStyle(
                            fontSize: isWeb ? 16 : 14,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Faculty Type: ${widget.faculty['faculty_type'] ?? 'N/A'}',
                          style: TextStyle(
                            fontSize: isWeb ? 16 : 14,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Department: ${widget.faculty['department'] ?? 'N/A'}',
                          style: TextStyle(
                            fontSize: isWeb ? 16 : 14,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'In-Charge: ${widget.faculty['incharge'] ?? 'Not assigned'}',
                          style: TextStyle(
                            fontSize: isWeb ? 16 : 14,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Assign Class In-Charge',
                  style: TextStyle(
                    fontSize: isWeb ? 20 : 18,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF0C4D83),
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _selectedClass,
                  decoration: InputDecoration(
                    labelText: 'Select Class',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    filled: true,
                    fillColor: Colors.grey[100],
                  ),
                  items: _classes
                      .map(
                        (className) => DropdownMenuItem(
                          value: className,
                          child: Text(
                            className,
                            style: TextStyle(fontSize: isWeb ? 16 : 14),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedClass = value;
                    });
                  },
                ),
                const SizedBox(height: 12),
                Center(
                  child: Column(
                    children: [
                      ElevatedButton(
                        onPressed: _isLoading ? null : _assignClassIncharge,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          padding: isWeb
                              ? const EdgeInsets.symmetric(
                                  vertical: 14.0,
                                  horizontal: 30.0,
                                )
                              : const EdgeInsets.symmetric(
                                  vertical: 12.0,
                                  horizontal: 24.0,
                                ),
                          elevation: 6,
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : Text(
                                'Assign Class',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: isWeb ? 16 : 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _isDeleting ? null : _deleteFaculty,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          padding: isWeb
                              ? const EdgeInsets.symmetric(
                                  vertical: 14.0,
                                  horizontal: 30.0,
                                )
                              : const EdgeInsets.symmetric(
                                  vertical: 12.0,
                                  horizontal: 24.0,
                                ),
                          elevation: 6,
                        ),
                        child: _isDeleting
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : Text(
                                'Delete Faculty',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: isWeb ? 16 : 14,
                                  fontWeight: FontWeight.bold,
                                ),
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
  }
}