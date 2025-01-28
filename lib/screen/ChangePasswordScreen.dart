import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:marketplace_logamas/function/Utils.dart';
import 'package:marketplace_logamas/widget/Dialog.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({Key? key}) : super(key: key);

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _oldPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  bool _isLoading = false;
  String? _accessToken;
  String? _email;

  @override
  void initState() {
    super.initState();
    _loadAccessTokenAndUserData();
  }

  Future<void> _loadAccessTokenAndUserData() async {
    try {
      final token = await getAccessToken(); // Fetch the access token
      setState(() {
        _accessToken = token;
      });

      if (_accessToken != null) {
        await _fetchUserProfile(); // Fetch user profile to get the email
      }
    } catch (e) {
      print('Error loading access token or user data: $e');
    }
  }

  Future<void> _fetchUserProfile() async {
    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/user/profile'),
        headers: {
          'Authorization': 'Bearer $_accessToken',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _email = data['data']['email'];
        });
      } else {
        print('Failed to fetch user profile: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching user profile: $e');
    }
  }

  Future<void> _sendOtp() async {
    if (_email == null) {
      dialog(context, 'Failed', 'Email not found');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/user/send-otp'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'email': _email}),
      );

      final result = jsonDecode(response.body);
      if (response.statusCode == 201) {
        dialog(context, 'Success', 'OTP sent to your email');
        _showOtpDrawer();
      } else {
        dialog(context, 'Failed', result['message'] ?? 'Failed to send OTP');
      }
    } catch (e) {
      dialog(context, 'Failed', 'An error occurred: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _changePasswordWithOtp() async {
    if (_otpController.text.isEmpty) {
      dialog(context, 'Failed', 'Please enter the OTP');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/user/change-password-with-otp-and-old-password'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'email': _email,
          'oldPassword': _oldPasswordController.text.trim(),
          'otp': _otpController.text.trim(),
          'newPassword': _newPasswordController.text.trim(),
        }),
      );

      final result = jsonDecode(response.body);
      if (response.statusCode == 201) {
        dialog(context, 'Success', 'Password has been changed successfully');
        Navigator.pop(context); // Close the drawer
        context.push('/login'); // Redirect to login screen
      } else {
        dialog(context, 'Failed',
            result['message'] ?? 'Failed to change password');
      }
    } catch (e) {
      dialog(context, 'Failed', 'An error occurred: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showOtpDrawer() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(
                child: Text(
                  'Enter OTP',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _otpController,
                decoration: InputDecoration(
                  labelText: 'OTP Code',
                  filled: true,
                  fillColor: Colors.grey[200],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                keyboardType: TextInputType.number,
                maxLength: 6,
              ),
              const SizedBox(height: 16),
              Center(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        vertical: 14, horizontal: 60),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    backgroundColor: const Color(0xFFC58189),
                  ),
                  onPressed: _changePasswordWithOtp,
                  child: const Text(
                    'Submit OTP',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String hintText,
    required IconData prefixIcon,
    required bool isPassword,
    required String validationMessage,
  }) {
    return TextFormField(
      cursorColor: const Color(0xFFC58189),
      controller: controller,
      obscureText: isPassword,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(color: Color(0xFFC58189)),
        prefixIcon: Icon(prefixIcon, color: const Color(0xFFC58189)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30.0),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor: const Color.fromARGB(255, 251, 224, 221),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return validationMessage;
        }
        if (hintText == 'New Password' && value.length < 6) {
          return 'Password must be at least 6 characters';
        }
        return null;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Change Password with OTP',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: GestureDetector(
          onTap: () => context.pop(),
          child: const Icon(
            Icons.arrow_back,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF31394E),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      _buildPasswordField(
                        controller: _oldPasswordController,
                        hintText: 'Current Password',
                        prefixIcon: Icons.lock_outline,
                        isPassword: true,
                        validationMessage: 'Please enter your current password',
                      ),
                      const SizedBox(height: 16),
                      _buildPasswordField(
                        controller: _newPasswordController,
                        hintText: 'New Password',
                        prefixIcon: Icons.lock_open,
                        isPassword: true,
                        validationMessage: 'Please enter your new password',
                      ),
                      const SizedBox(height: 16),
                      _buildPasswordField(
                        controller: _confirmPasswordController,
                        hintText: 'Confirm New Password',
                        prefixIcon: Icons.lock,
                        isPassword: true,
                        validationMessage: 'Please confirm your new password',
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              vertical: 14, horizontal: 80),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          backgroundColor: const Color(0xFFC58189),
                        ),
                        onPressed: _sendOtp,
                        child: const Text(
                          'Send OTP',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
