import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class FirstTimeSignInScreen extends StatefulWidget {
  const FirstTimeSignInScreen({super.key});

  @override
  State<FirstTimeSignInScreen> createState() => _FirstTimeSignInScreenState();
}

class _FirstTimeSignInScreenState extends State<FirstTimeSignInScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _nameController = TextEditingController();
  final _birthdayController = TextEditingController();
  final _ageController = TextEditingController();
  final _staffCodeController = TextEditingController();
  final _departmentController = TextEditingController();
  final _dateOfJoiningController = TextEditingController();
  final _totalExperienceController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _religionController = TextEditingController();
  final _highestDegreeController = TextEditingController();
  final _biometricIdController = TextEditingController();
  final _newPasswordController = TextEditingController();
  String? _errorMessage;
  bool _isVerifying = false;
  String? _selectedFacultyType;
  DateTime? _selectedBirthday;

  final List<String> _facultyTypes = ['Associate Professor', 'HoD', 'Admin'];

  Future<bool> _verifyEmailAndPassword(String email) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: 'Dummy123',
      );
      return true;
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = e.message;
      });
      return false;
    }
  }

  Future<void> _selectBirthday(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedBirthday) {
      setState(() {
        _selectedBirthday = picked;
        _birthdayController.text = DateFormat('d MMMM yyyy').format(picked);
        // Calculate age based on selected birthday
        final now = DateTime.now();
        int age = now.year - picked.year;
        if (now.month < picked.month ||
            (now.month == picked.month && now.day < picked.day)) {
          age--;
        }
        _ageController.text = age.toString();
      });
    }
  }

  Future<void> _submitDetails() async {
    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    try {
      final email = _emailController.text.trim();
      bool isVerified = await _verifyEmailAndPassword(email);

      if (!isVerified) {
        setState(() {
          _errorMessage = 'Email not found or incorrect default password.';
        });
        return;
      }

      final user = _auth.currentUser;
      if (user == null) {
        setState(() {
          _errorMessage = 'Failed to authenticate user.';
        });
        return;
      }

      await user.updatePassword(_newPasswordController.text.trim());

      await _firestore.collection('faculty_members').doc(user.uid).set({
        'name': _nameController.text.trim(),
        'birthday': _birthdayController.text.trim(),
        'age': int.parse(_ageController.text.trim()),
        'staff_code': _staffCodeController.text.trim(),
        'department': _departmentController.text.trim(),
        'date_of_joining': _dateOfJoiningController.text.trim(),
        'total_experience': _totalExperienceController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'religion': _religionController.text.trim(),
        'highest_degree': _highestDegreeController.text.trim(),
        'biometric_id': _biometricIdController.text.trim(),
        'faculty_type': _selectedFacultyType,
      });

      Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      setState(() {
        _isVerifying = false;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _birthdayController.dispose();
    _ageController.dispose();
    _staffCodeController.dispose();
    _departmentController.dispose();
    _dateOfJoiningController.dispose();
    _totalExperienceController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _religionController.dispose();
    _highestDegreeController.dispose();
    _biometricIdController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('First Time Sign In')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _birthdayController,
              readOnly: true,
              decoration: InputDecoration(
                labelText: 'Birthday',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.calendar_today),
                  onPressed: () => _selectBirthday(context),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _ageController,
              decoration: const InputDecoration(
                labelText: 'Age',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              readOnly: true, // Age is auto-calculated
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _staffCodeController,
              decoration: const InputDecoration(
                labelText: 'Staff Code',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _departmentController,
              decoration: const InputDecoration(
                labelText: 'Department',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _dateOfJoiningController,
              decoration: const InputDecoration(
                labelText: 'Date of Joining (e.g., 2023-03-28)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _totalExperienceController,
              decoration: const InputDecoration(
                labelText: 'Total Experience',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Phone',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _religionController,
              decoration: const InputDecoration(
                labelText: 'Religion',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _highestDegreeController,
              decoration: const InputDecoration(
                labelText: 'Highest Degree',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _biometricIdController,
              decoration: const InputDecoration(
                labelText: 'Biometric ID',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Faculty Type',
                border: OutlineInputBorder(),
              ),
              value: _selectedFacultyType,
              items:
                  _facultyTypes.map((String type) {
                    return DropdownMenuItem<String>(
                      value: type,
                      child: Text(type),
                    );
                  }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedFacultyType = newValue;
                });
              },
              validator: (value) {
                if (value == null) {
                  return 'Please select a faculty type';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _newPasswordController,
              decoration: const InputDecoration(
                labelText: 'New Password',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            if (_errorMessage != null)
              Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isVerifying ? null : _submitDetails,
              child:
                  _isVerifying
                      ? const CircularProgressIndicator()
                      : const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }
}
