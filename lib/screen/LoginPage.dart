import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:marketplace_logamas/function/Utils.dart';
import 'package:marketplace_logamas/widget/CustomLoader.dart';
import 'package:marketplace_logamas/widget/Dialog.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  late AnimationController _animationController;
  Animation<double>? _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // Setup animation
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // Email validation
  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email tidak boleh kosong';
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Format email tidak valid';
    }
    return null;
  }

  // Password validation
  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password tidak boleh kosong';
    }
    return null;
  }

  void _login() async {
    // Validate form first
    if (_formKey.currentState?.validate() != true) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    String email = emailController.text.trim();
    String password = passwordController.text;

    // Show loader dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.rectangle,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFC58189)),
                strokeWidth: 5,
              ),
              const SizedBox(height: 20),
              Text(
                'Memproses Login',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Mohon tunggu sebentar...',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      const String apiUrl = '$apiBaseUrl/user/login';
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      // Close loading dialog
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      setState(() {
        _isLoading = false;
      });

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final String accessToken = data['data']['access_token'];
        final String name = data['data']['name'];
        final String userId = data['data']['user_id'];

        SharedPreferences prefs = await SharedPreferences.getInstance();
        prefs.setString('access_token', accessToken);
        prefs.setString('name', name);
        prefs.setString('user_id', userId);

        if (!kIsWeb) {
          // Only run on Android/iOS
          if (Platform.isAndroid) {
            await addDeviceToken(accessToken, context);
          }
        }

        if (context.mounted) {
          context.go(
              '/home'); // Using go instead of push to replace the current screen
        }
      } else {
        final responseBody = jsonDecode(response.body);
        final errorMessage =
            responseBody['message'] ?? 'Terjadi kesalahan. Silakan coba lagi.';

        if (context.mounted) {
          _showErrorSnackBar(errorMessage);
        }
      }
    } catch (error) {
      setState(() {
        _isLoading = false;
      });

      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        _showErrorSnackBar('Periksa koneksi internet Anda dan coba lagi.');
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[700],
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  Future<String> getDeviceToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('fcm_token') ?? '';
  }

  Future<void> addDeviceToken(String accessToken, BuildContext context) async {
    const String addDeviceTokenApiUrl = '$apiBaseUrl/user/device-token';

    try {
      final String deviceToken = await getDeviceToken();
      if (deviceToken.isNotEmpty) {
        final response = await http.post(
          Uri.parse(addDeviceTokenApiUrl),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $accessToken',
          },
          body: jsonEncode({'deviceToken': deviceToken}),
        );

        if (response.statusCode != 201) {
          final responseBody = jsonDecode(response.body);
          final errorMessage =
              responseBody['message'] ?? 'Gagal menambahkan device token';
          debugPrint('Device token error: $errorMessage');
        }
      }
    } catch (error) {
      debugPrint('Error adding device token: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/images/appbar.png'),
              fit: BoxFit.cover,
            ),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: Text(
          "Login",
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
      ),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation ?? AlwaysStoppedAnimation(1.0),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24.0, vertical: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Logo
                    Hero(
                      tag: 'app_logo',
                      child: Container(
                        height: 200,
                        child: Image.asset(
                          'assets/images/logo.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Welcome message
                    Text(
                      'Selamat Datang!',
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF333333),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Silakan login untuk melanjutkan',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Email field
                    _buildCustomTextField(
                      controller: emailController,
                      hintText: 'Masukkan email',
                      prefixIcon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      validator: _validateEmail,
                    ),
                    const SizedBox(height: 16),

                    // Password field
                    _buildCustomTextField(
                      controller: passwordController,
                      hintText: 'Masukkan password',
                      prefixIcon: Icons.lock_outline,
                      obscureText: !_isPasswordVisible,
                      validator: _validatePassword,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isPasswordVisible
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: const Color(0xFFC58189),
                          size: 20,
                        ),
                        onPressed: () {
                          setState(() {
                            _isPasswordVisible = !_isPasswordVisible;
                          });
                        },
                      ),
                    ),

                    // Forgot password
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => context.push('/forgot-password'),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            vertical: 4,
                            horizontal: 8,
                          ),
                        ),
                        child: Text(
                          'Lupa Password?',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFFC58189),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Login button
                    _buildGradientButton(
                      text: 'Login',
                      onPressed: _login,
                    ),
                    const SizedBox(height: 20),

                    // Register link
                    GestureDetector(
                      onTap: () => context.push('/register'),
                      child: RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: 'Belum punya akun? ',
                              style: GoogleFonts.poppins(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                            TextSpan(
                              text: 'Daftar sekarang',
                              style: GoogleFonts.poppins(
                                color: const Color(0xFFDAA07D),
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData prefixIcon,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    Widget? suffixIcon,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      style: GoogleFonts.poppins(
        fontSize: 15,
        color: Colors.black87,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: GoogleFonts.poppins(
          color: Colors.grey[400],
          fontSize: 14,
        ),
        prefixIcon: Icon(
          prefixIcon,
          color: const Color(0xFFC58189),
          size: 20,
        ),
        suffixIcon: suffixIcon,
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Colors.grey[300]!,
            width: 1,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Colors.grey[300]!,
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: Color(0xFFE8C4BD),
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: Colors.redAccent,
            width: 1,
          ),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }

  Widget _buildGradientButton({
    required String text,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: double.infinity,
      height: 55,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFC58189).withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFFE8C4BD),
                Color(0xFFC58189),
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Container(
            alignment: Alignment.center,
            child: Text(
              text,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
