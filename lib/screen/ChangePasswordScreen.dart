import 'dart:async';
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
  bool _isSendingOtp = false;
  bool _isPasswordVisible = false;
  bool _isNewPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  String? _accessToken;
  String? _email;
  String? _passwordError;
  String? _confirmPasswordError;

  // Password strength
  double _passwordStrength = 0.0;
  String _passwordStrengthText = "Enter password";
  Color _passwordStrengthColor = Colors.grey;

  @override
  void initState() {
    super.initState();
    _loadAccessTokenAndUserData();

    // Add listener for password strength
    _newPasswordController.addListener(_calculatePasswordStrength);

    // Add listener for password matching
    _confirmPasswordController.addListener(_checkPasswordMatch);
  }

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _calculatePasswordStrength() {
    final password = _newPasswordController.text;

    if (password.isEmpty) {
      setState(() {
        _passwordStrength = 0;
        _passwordStrengthText = "Enter password";
        _passwordStrengthColor = Colors.grey;
      });
      return;
    }

    double strength = 0;

    // Length check
    if (password.length >= 8) {
      strength += 0.25;
    } else if (password.length >= 6) {
      strength += 0.15;
    }

    // Uppercase check
    if (password.contains(RegExp(r'[A-Z]'))) {
      strength += 0.25;
    }

    // Digits check
    if (password.contains(RegExp(r'[0-9]'))) {
      strength += 0.25;
    }

    // Special characters check
    if (password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      strength += 0.25;
    }

    // Set strength text and color
    setState(() {
      _passwordStrength = strength;

      if (strength < 0.3) {
        _passwordStrengthText = "Weak";
        _passwordStrengthColor = Colors.red;
      } else if (strength < 0.7) {
        _passwordStrengthText = "Medium";
        _passwordStrengthColor = Colors.orange;
      } else {
        _passwordStrengthText = "Strong";
        _passwordStrengthColor = Colors.green;
      }
    });
  }

  void _checkPasswordMatch() {
    if (_confirmPasswordController.text.isNotEmpty) {
      if (_confirmPasswordController.text != _newPasswordController.text) {
        setState(() {
          _confirmPasswordError = "Passwords don't match";
        });
      } else {
        setState(() {
          _confirmPasswordError = null;
        });
      }
    } else {
      setState(() {
        _confirmPasswordError = null;
      });
    }
  }

  Future<void> _loadAccessTokenAndUserData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final token = await getAccessToken(); // Fetch the access token
      if (mounted) {
        setState(() {
          _accessToken = token;
        });
      }

      if (_accessToken != null) {
        await _fetchUserProfile(); // Fetch user profile to get the email
      }
    } catch (e) {
      if (mounted) {
        dialog(context, 'Error', 'Failed to load user data. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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
        if (mounted) {
          setState(() {
            _email = data['data']['email'];
          });
        }
      } else if (response.statusCode == 401) {
        // Token expired
        dialog(context, 'Session Expired', 'Please log in again.');
        context.push('/login');
      } else {
        dialog(context, 'Error', 'Failed to fetch profile. Please try again.');
      }
    } catch (e) {
      if (mounted) {
        dialog(context, 'Network Error',
            'Check your internet connection and try again.');
      }
    }
  }


  Future<void> _sendOtp() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_email == null) {
      dialog(context, 'Error', 'Email not found. Please try logging in again.');
      return;
    }

    // Check if new password and confirm password match
    if (_newPasswordController.text != _confirmPasswordController.text) {
      setState(() {
        _confirmPasswordError = "Passwords don't match";
      });
      return;
    }

    setState(() {
      _isSendingOtp = true;
    });

    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/user/send-otp'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'email': _email}),
      );

      if (!mounted) return;

      final result = jsonDecode(response.body);
      if (response.statusCode == 201) {
        _showOtpDrawer();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 10),
                Expanded(child: Text('OTP sent to your email')),
              ],
            ),
            backgroundColor: Colors.green[700],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10.0),
            ),
          ),
        );
      } else {
        dialog(context, 'Failed', result['message'] ?? 'Failed to send OTP');
      }
    } catch (e) {
      if (mounted) {
        dialog(context, 'Network Error',
            'Check your internet connection and try again.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSendingOtp = false;
        });
      }
    }
  }

  Future<void> _changePasswordWithOtp() async {
    if (_otpController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter the OTP'),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
        ),
      );
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

      if (!mounted) return;

      final result = jsonDecode(response.body);
      if (response.statusCode == 201) {
        // Close the drawer first
        Navigator.pop(context);

        // Show success message
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green),
                  SizedBox(width: 10),
                  Text('Success'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Your password has been changed successfully.'),
                  SizedBox(height: 10),
                  Text(
                    'You will be redirected to the login screen.',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
              actions: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    context.push('/login');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFC58189),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                  ),
                  child: const Text(
                    'Log In',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      } else {
        dialog(context, 'Failed',
            result['message'] ?? 'Failed to change password');
      }
    } catch (e) {
      if (mounted) {
        dialog(context, 'Network Error',
            'Check your internet connection and try again.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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
        return StatefulBuilder(builder: (context, setState) {
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
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const Center(
                  child: Text(
                    'Enter OTP',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    'We sent a verification code to $_email',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 20),
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
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    letterSpacing: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    'OTP will expire soon. Please enter it to proceed.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ),

                const SizedBox(height: 20),
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
                    onPressed: _isLoading ? null : _changePasswordWithOtp,
                    child: _isLoading
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              ),
                              SizedBox(width: 10),
                              Text(
                                'Verifying...',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          )
                        : const Text(
                            'Verify OTP',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          );
        });
      },
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String hintText,
    required IconData prefixIcon,
    required bool isPassword,
    required String validationMessage,
    ValueChanged<bool>? onVisibilityToggle,
    String? errorText,
    bool forceVisible = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: const Color.fromARGB(255, 251, 224, 221),
            borderRadius: BorderRadius.circular(30.0),
          ),
          child: TextFormField(
            cursorColor: const Color(0xFFC58189),
            controller: controller,
            obscureText: isPassword && !forceVisible,
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: const TextStyle(color: Color(0xFFC58189)),
              prefixIcon: Icon(prefixIcon, color: const Color(0xFFC58189)),
              suffixIcon: isPassword
                  ? IconButton(
                      icon: Icon(
                        forceVisible ? Icons.visibility_off : Icons.visibility,
                        color: const Color(0xFFC58189),
                      ),
                      onPressed: () {
                        if (onVisibilityToggle != null) {
                          onVisibilityToggle(!forceVisible);
                        }
                      },
                    )
                  : null,
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
          ),
        ),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: 6.0, left: 12.0),
            child: Text(
              errorText,
              style: const TextStyle(
                color: Colors.red,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        flexibleSpace: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/appbar.png',
              fit: BoxFit.cover,
            ),
            Container(
              color: Colors.black.withOpacity(0.2),
            ),
          ],
        ),
        title: const Text(
          'Change Password',
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
      ),
      body: _isLoading && !_isSendingOtp
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(left: 12, bottom: 20),
                        child: Text(
                          'Enter your current password and set a new password',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ),

                      // Current password field
                      _buildPasswordField(
                        controller: _oldPasswordController,
                        hintText: 'Current Password',
                        prefixIcon: Icons.lock_outline,
                        isPassword: true,
                        validationMessage: 'Please enter your current password',
                        forceVisible: _isPasswordVisible,
                        onVisibilityToggle: (visible) {
                          setState(() {
                            _isPasswordVisible = visible;
                          });
                        },
                      ),
                      const SizedBox(height: 20),

                      // New password field
                      _buildPasswordField(
                        controller: _newPasswordController,
                        hintText: 'New Password',
                        prefixIcon: Icons.lock_open,
                        isPassword: true,
                        validationMessage: 'Please enter your new password',
                        forceVisible: _isNewPasswordVisible,
                        onVisibilityToggle: (visible) {
                          setState(() {
                            _isNewPasswordVisible = visible;
                          });
                        },
                        errorText: _passwordError,
                      ),

                      // Password strength indicator
                      if (_newPasswordController.text.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(
                              top: 8.0, left: 12.0, right: 12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Password Strength:',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  Text(
                                    _passwordStrengthText,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: _passwordStrengthColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              LinearProgressIndicator(
                                value: _passwordStrength,
                                backgroundColor: Colors.grey[300],
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    _passwordStrengthColor),
                                minHeight: 5,
                                borderRadius: BorderRadius.circular(2.5),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Use a combination of uppercase, lowercase, numbers, and symbols for a strong password.',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 20),

                      // Confirm password field
                      _buildPasswordField(
                        controller: _confirmPasswordController,
                        hintText: 'Confirm New Password',
                        prefixIcon: Icons.lock,
                        isPassword: true,
                        validationMessage: 'Please confirm your new password',
                        forceVisible: _isConfirmPasswordVisible,
                        onVisibilityToggle: (visible) {
                          setState(() {
                            _isConfirmPasswordVisible = visible;
                          });
                        },
                        errorText: _confirmPasswordError,
                      ),
                      const SizedBox(height: 32),

                      // Submit button
                      Center(
                        child: ElevatedButton(
                          onPressed: _isSendingOtp ? null : _sendOtp,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              vertical: 15,
                              horizontal: 40,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            backgroundColor: const Color(0xFFC58189),
                          ),
                          child: _isSendingOtp
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    Text(
                                      "Sending OTP...",
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                )
                              : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Icon(Icons.lock_reset, color: Colors.white),
                                    SizedBox(width: 12),
                                    Text(
                                      "Change Password",
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
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
