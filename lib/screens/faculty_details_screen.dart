import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  final List<String> _classes = [
    'AIDS E',
    'CSE A',
    'ECE B',
    'MECH C',
  ]; // Example classes
  bool _isLoading = false;

  Future<void> _assignClassIncharge() async {
    if (_selectedClass == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a class.')));
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

      Navigator.pop(context, true); // Return true to indicate a change was made
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.faculty['name'] ?? 'Unknown'} Details'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Faculty Details',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0C4D83),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Name: ${widget.faculty['name'] ?? 'N/A'}'),
                    Text('Email: ${widget.faculty['email'] ?? 'N/A'}'),
                    Text(
                      'Faculty Type: ${widget.faculty['faculty_type'] ?? 'N/A'}',
                    ),
                    Text(
                      'Department: ${widget.faculty['department'] ?? 'N/A'}',
                    ),
                    Text(
                      'In-Charge: ${widget.faculty['incharge'] ?? 'Not assigned'}',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Assign Class In-Charge',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0C4D83),
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedClass,
              decoration: InputDecoration(
                labelText: 'Select Class',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
              items:
                  _classes.map((className) {
                    return DropdownMenuItem(
                      value: className,
                      child: Text(className),
                    );
                  }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedClass = value;
                });
              },
            ),
            const SizedBox(height: 16),
            Center(
              child: ElevatedButton(
                onPressed: _isLoading ? null : _assignClassIncharge,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  padding: const EdgeInsets.symmetric(
                    vertical: 14.0,
                    horizontal: 30.0,
                  ),
                  elevation: 6,
                ),
                child:
                    _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                          'Assign Class',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
