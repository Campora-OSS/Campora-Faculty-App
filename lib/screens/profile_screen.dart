import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ritian_faculty/widgets/custom_navigation_drawer.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _biometricIdController = TextEditingController();
  final _ageController = TextEditingController();
  final _birthdayController = TextEditingController();
  final _dateOfJoiningController = TextEditingController();
  final _departmentController = TextEditingController();
  final _highestDegreeController = TextEditingController();
  final _phoneController = TextEditingController();
  final _religionController = TextEditingController();
  final _staffCodeController = TextEditingController();
  final _totalExperienceController = TextEditingController();
  String? _facultyType;
  Map<String, dynamic>? _profileData;
  bool _isLoading = false;
  bool _isEditing = false;
  bool _isDataLoaded = false;

  @override
  void initState() {
    super.initState();
    _fetchProfileData();
  }

  Future<void> _fetchProfileData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('User not logged in')));
      return;
    }

    try {
      final doc =
          await FirebaseFirestore.instance
              .collection('faculty_members')
              .doc(user.uid)
              .get();
      if (doc.exists) {
        setState(() {
          _profileData = doc.data();
          _facultyType = _profileData?['faculty_type']?.toString();
          _nameController.text = _profileData?['name'] ?? '';
          _emailController.text = _profileData?['email'] ?? '';
          _biometricIdController.text = _profileData?['biometric_id'] ?? '';
          _ageController.text = _profileData?['age']?.toString() ?? '';
          _birthdayController.text = _profileData?['birthday'] ?? '';
          _dateOfJoiningController.text =
              _profileData?['date_of_joining'] ?? '';
          _departmentController.text = _profileData?['department'] ?? '';
          _highestDegreeController.text = _profileData?['highest_degree'] ?? '';
          _phoneController.text = _profileData?['phone'] ?? '';
          _religionController.text = _profileData?['religion'] ?? '';
          _staffCodeController.text = _profileData?['staff_code'] ?? '';
          _totalExperienceController.text =
              _profileData?['total_experience'] ?? '';
          _isDataLoaded = true;
        });
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Profile not found')));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load profile: $e')));
    }
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }

      final updatedData = {
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'biometric_id': _biometricIdController.text.trim(),
        'faculty_type': _facultyType,
        'age': int.parse(_ageController.text.trim()),
        'birthday': _birthdayController.text.trim(),
        'date_of_joining': _dateOfJoiningController.text.trim(),
        'department': _departmentController.text.trim(),
        'highest_degree': _highestDegreeController.text.trim(),
        'phone': _phoneController.text.trim(),
        'religion': _religionController.text.trim(),
        'staff_code': _staffCodeController.text.trim(),
        'total_experience': _totalExperienceController.text.trim(),
      };

      await FirebaseFirestore.instance
          .collection('faculty_members')
          .doc(user.uid)
          .update(updatedData);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully')),
      );

      setState(() {
        _profileData = updatedData;
        _isEditing = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to update profile: $e')));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isWeb = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Profile',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF0C4D83),
        leading:
            isWeb
                ? null
                : Builder(
                  builder:
                      (context) => IconButton(
                        icon: const Icon(Icons.menu, color: Colors.white),
                        onPressed: () => Scaffold.of(context).openDrawer(),
                      ),
                ),
      ),
      drawer: isWeb ? null : const AppDrawer(),
      body:
          isWeb
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
    if (!_isDataLoaded) {
      return const Center(child: CircularProgressIndicator());
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: Padding(
            padding:
                isWeb
                    ? const EdgeInsets.fromLTRB(24, 24, 24, 16)
                    : const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'My Profile',
                  style: TextStyle(
                    fontSize: isWeb ? 28 : 24,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0C4D83),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _isEditing = !_isEditing;
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      padding:
                          isWeb
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
                    child: Text(
                      _isEditing ? 'Cancel Edit' : 'Edit Profile',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isWeb ? 16 : 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  elevation: isWeb ? 8 : 6,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: Padding(
                    padding:
                        isWeb
                            ? const EdgeInsets.all(20.0)
                            : const EdgeInsets.all(16.0),
                    child:
                        _isEditing
                            ? _buildEditForm(isWeb)
                            : _buildProfileView(isWeb),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfileView(bool isWeb) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Profile Details',
          style: TextStyle(
            fontSize: isWeb ? 20 : 18,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF0C4D83),
          ),
        ),
        const SizedBox(height: 12),
        _buildProfileField('Name', _profileData?['name'] ?? 'N/A', isWeb),
        _buildProfileField('Email', _profileData?['email'] ?? 'N/A', isWeb),
        _buildProfileField(
          'Biometric ID',
          _profileData?['biometric_id'] ?? 'N/A',
          isWeb,
        ),
        _buildProfileField(
          'Faculty Type',
          _profileData?['faculty_type'] ?? 'N/A',
          isWeb,
        ),
        _buildProfileField(
          'Age',
          _profileData?['age']?.toString() ?? 'N/A',
          isWeb,
        ),
        _buildProfileField(
          'Birthday',
          _profileData?['birthday'] ?? 'N/A',
          isWeb,
        ),
        _buildProfileField(
          'Date of Joining',
          _profileData?['date_of_joining'] ?? 'N/A',
          isWeb,
        ),
        _buildProfileField(
          'Department',
          _profileData?['department'] ?? 'N/A',
          isWeb,
        ),
        _buildProfileField(
          'Highest Degree',
          _profileData?['highest_degree'] ?? 'N/A',
          isWeb,
        ),
        _buildProfileField('Phone', _profileData?['phone'] ?? 'N/A', isWeb),
        _buildProfileField(
          'Religion',
          _profileData?['religion'] ?? 'N/A',
          isWeb,
        ),
        _buildProfileField(
          'Staff Code',
          _profileData?['staff_code'] ?? 'N/A',
          isWeb,
        ),
        _buildProfileField(
          'Total Experience',
          _profileData?['total_experience'] ?? 'N/A',
          isWeb,
        ),
      ],
    );
  }

  Widget _buildProfileField(String label, String value, bool isWeb) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: isWeb ? 150 : 120,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: isWeb ? 16 : 14,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: isWeb ? 16 : 14,
                color: Colors.black54,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditForm(bool isWeb) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Edit Profile',
            style: TextStyle(
              fontSize: isWeb ? 20 : 18,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF0C4D83),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: 'Name',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
              ),
              filled: true,
              fillColor: Colors.grey[100],
            ),
            style: TextStyle(fontSize: isWeb ? 16 : 14),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter a name';
              }
              return null;
            },
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _emailController,
            decoration: InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
              ),
              filled: true,
              fillColor: Colors.grey[100],
            ),
            keyboardType: TextInputType.emailAddress,
            style: TextStyle(fontSize: isWeb ? 16 : 14),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter an email';
              }
              if (!RegExp(
                r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
              ).hasMatch(value)) {
                return 'Please enter a valid email';
              }
              return null;
            },
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _biometricIdController,
            decoration: InputDecoration(
              labelText: 'Biometric ID',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
              ),
              filled: true,
              fillColor: Colors.grey[100],
            ),
            style: TextStyle(fontSize: isWeb ? 16 : 14),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter a biometric ID';
              }
              return null;
            },
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _ageController,
            decoration: InputDecoration(
              labelText: 'Age',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
              ),
              filled: true,
              fillColor: Colors.grey[100],
            ),
            keyboardType: TextInputType.number,
            style: TextStyle(fontSize: isWeb ? 16 : 14),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter age';
              }
              if (int.tryParse(value) == null || int.parse(value) <= 0) {
                return 'Please enter a valid age';
              }
              return null;
            },
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _birthdayController,
            decoration: InputDecoration(
              labelText: 'Birthday (e.g., 14 May 2004)',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
              ),
              filled: true,
              fillColor: Colors.grey[100],
            ),
            style: TextStyle(fontSize: isWeb ? 16 : 14),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter birthday';
              }
              return null;
            },
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _dateOfJoiningController,
            decoration: InputDecoration(
              labelText: 'Date of Joining',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
              ),
              filled: true,
              fillColor: Colors.grey[100],
            ),
            style: TextStyle(fontSize: isWeb ? 16 : 14),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter date of joining';
              }
              return null;
            },
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _departmentController,
            decoration: InputDecoration(
              labelText: 'Department',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
              ),
              filled: true,
              fillColor: Colors.grey[100],
            ),
            style: TextStyle(fontSize: isWeb ? 16 : 14),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter department';
              }
              return null;
            },
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _highestDegreeController,
            decoration: InputDecoration(
              labelText: 'Highest Degree',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
              ),
              filled: true,
              fillColor: Colors.grey[100],
            ),
            style: TextStyle(fontSize: isWeb ? 16 : 14),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter highest degree';
              }
              return null;
            },
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _phoneController,
            decoration: InputDecoration(
              labelText: 'Phone',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
              ),
              filled: true,
              fillColor: Colors.grey[100],
            ),
            keyboardType: TextInputType.phone,
            style: TextStyle(fontSize: isWeb ? 16 : 14),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter phone number';
              }
              return null;
            },
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _religionController,
            decoration: InputDecoration(
              labelText: 'Religion',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
              ),
              filled: true,
              fillColor: Colors.grey[100],
            ),
            style: TextStyle(fontSize: isWeb ? 16 : 14),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter religion';
              }
              return null;
            },
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _staffCodeController,
            decoration: InputDecoration(
              labelText: 'Staff Code',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
              ),
              filled: true,
              fillColor: Colors.grey[100],
            ),
            style: TextStyle(fontSize: isWeb ? 16 : 14),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter staff code';
              }
              return null;
            },
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _totalExperienceController,
            decoration: InputDecoration(
              labelText: 'Total Experience (years)',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
              ),
              filled: true,
              fillColor: Colors.grey[100],
            ),
            keyboardType: TextInputType.number,
            style: TextStyle(fontSize: isWeb ? 16 : 14),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter total experience';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          Center(
            child: ElevatedButton(
              onPressed: _isLoading ? null : _updateProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
                padding:
                    isWeb
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
              child:
                  _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                        'Save Changes',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isWeb ? 16 : 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _biometricIdController.dispose();
    _ageController.dispose();
    _birthdayController.dispose();
    _dateOfJoiningController.dispose();
    _departmentController.dispose();
    _highestDegreeController.dispose();
    _phoneController.dispose();
    _religionController.dispose();
    _staffCodeController.dispose();
    _totalExperienceController.dispose();
    super.dispose();
  }
}
