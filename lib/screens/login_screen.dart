import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _resetEmailController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final String email = _emailController.text.trim();
      final String password = _passwordController.text.trim();

      final UserCredential userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);

      final userDoc =
          await FirebaseFirestore.instance
              .collection('faculty_members')
              .doc(userCredential.user!.uid)
              .get();

      if (!userDoc.exists) {
        await FirebaseAuth.instance.signOut();
        throw Exception('User not found in faculty records.');
      }

      final facultyType = userDoc.data()?['faculty_type']?.toString();
      if (!['Associate Professor', 'HoD', 'Admin'].contains(facultyType)) {
        await FirebaseAuth.instance.signOut();
        throw Exception('Not authorized. Only faculty members can log in.');
      }

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
      print('Login error: $e');
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _resetPassword() async {
    final email = _resetEmailController.text.trim();

    if (email.isEmpty ||
        !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid email address.')),
      );
      return;
    }

    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      Navigator.of(context).pop();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password reset email sent. Check your inbox.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to send reset email: $e')));
      print('Reset password error: $e');
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showResetPasswordDialog() {
    _resetEmailController.clear();
    if (!mounted) return;
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Reset Password'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _resetEmailController,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    filled: true,
                    fillColor: Colors.grey[100],
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  if (!mounted) return;
                  Navigator.of(context).pop();
                },
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: _isLoading ? null : _resetPassword,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                ),
                child:
                    _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Send Reset Email'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isWeb = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Faculty Login'),
        backgroundColor: Colors.blue,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isWeb ? 500 : double.infinity, // Limit form width on web
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Card(
              elevation: isWeb ? 8 : 0,
              shape:
                  isWeb
                      ? RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16.0),
                      )
                      : null,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Login',
                          style: TextStyle(
                            fontSize: isWeb ? 28 : 24,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0C4D83),
                          ),
                        ),
                        const SizedBox(height: 24),
                        if (_errorMessage != null) ...[
                          Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        TextFormField(
                          controller: _emailController,
                          decoration: InputDecoration(
                            labelText: 'Email',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                            filled: true,
                            fillColor: Colors.grey[100],
                          ),
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter your email';
                            }
                            if (!RegExp(
                              r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                            ).hasMatch(value)) {
                              return 'Please enter a valid email';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passwordController,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                            filled: true,
                            fillColor: Colors.grey[100],
                          ),
                          obscureText: true,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter your password';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _showResetPasswordDialog,
                            child: const Text(
                              'Forgot Password?',
                              style: TextStyle(color: Colors.blue),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Center(
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _login,
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
                                    ? const CircularProgressIndicator(
                                      color: Colors.white,
                                    )
                                    : const Text(
                                      'Login',
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
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _resetEmailController.dispose();
    super.dispose();
  }
}
