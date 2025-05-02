import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:marketplace_logamas/screen/ConfirmationScreen.dart';
import 'package:marketplace_logamas/function/Utils.dart';
import 'package:marketplace_logamas/widget/Dialog.dart';
import 'package:marketplace_logamas/widget/Field2.dart';
import 'package:marketplace_logamas/widget/PhoneNumberField.dart';
import 'package:google_fonts/google_fonts.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({Key? key}) : super(key: key);

  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController passwordConfirmController =
      TextEditingController();
  final TextEditingController phoneController = TextEditingController();

  final _formKey = GlobalKey<FormState>();
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool isLoading = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // Animation setup
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
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    passwordConfirmController.dispose();
    phoneController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // Improved validation
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

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password tidak boleh kosong';
    }
    if (value.length < 6) {
      return 'Password minimal 6 karakter';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Konfirmasi password tidak boleh kosong';
    }
    if (value != passwordController.text) {
      return 'Password tidak sama';
    }
    return null;
  }

  String? _validateName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Nama lengkap tidak boleh kosong';
    }
    return null;
  }

  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Nomor telepon tidak boleh kosong';
    }
    if (value.length < 9) {
      return 'Nomor telepon tidak valid';
    }
    return null;
  }

  void register(BuildContext context) async {
    // Validate all fields first
    if (_formKey.currentState?.validate() != true) {
      return;
    }

    setState(() {
      isLoading = true;
    });

    // Modern loading dialog with animation
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
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: 1),
                duration: const Duration(milliseconds: 1000),
                builder: (context, value, child) {
                  return CircularProgressIndicator(
                    value: null,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFFE0B9B2),
                    ),
                    strokeWidth: 5,
                  );
                },
              ),
              const SizedBox(height: 20),
              Text(
                'Mohon tunggu sebentar',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Sedang memproses pendaftaran...',
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
      final response = await http.post(
        Uri.parse('$apiBaseUrl/user/register'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'name': nameController.text.trim(),
          'email': emailController.text.trim(),
          'password': passwordController.text,
          'phone': "62${phoneController.text.trim()}",
        }),
      );

      // Close loading dialog
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      setState(() {
        isLoading = false;
      });

      if (response.statusCode == 201) {
        final email = emailController.text;
        if (context.mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ConfirmationScreen(email: email),
            ),
          );
        }
      } else {
        final responseBody = jsonDecode(response.body);
        final errorMessage =
            responseBody['message'] ?? 'Terjadi kesalahan. Silakan coba lagi.';

        if (context.mounted) {
          dialog(context, 'Pendaftaran Gagal', errorMessage);
        }
      }
    } catch (e) {
      // Handle network or other exceptions
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        dialog(context, 'Koneksi Error',
            'Periksa koneksi internet Anda dan coba lagi.');
      }

      setState(() {
        isLoading = false;
      });
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
          "Register",
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
      ),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24.0, vertical: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Text(
                      'Daftar Akun',
                      style: GoogleFonts.poppins(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF333333),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Silakan lengkapi data diri Anda',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Name Field
                    _buildFieldLabel('Nama Lengkap'),
                    const SizedBox(height: 8),
                    _buildCustomTextField(
                      controller: nameController,
                      hintText: 'Masukkan nama lengkap',
                      prefixIcon: Icons.person_outline,
                      validator: _validateName,
                    ),
                    const SizedBox(height: 16),

                    // Email Field
                    _buildFieldLabel('Email'),
                    const SizedBox(height: 8),
                    _buildCustomTextField(
                      controller: emailController,
                      hintText: 'Masukkan email',
                      prefixIcon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      validator: _validateEmail,
                    ),
                    const SizedBox(height: 16),

                    // Password Field
                    _buildFieldLabel('Password'),
                    const SizedBox(height: 8),
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
                        ),
                        onPressed: () {
                          setState(() {
                            _isPasswordVisible = !_isPasswordVisible;
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Confirm Password Field
                    _buildFieldLabel('Konfirmasi Password'),
                    const SizedBox(height: 8),
                    _buildCustomTextField(
                      controller: passwordConfirmController,
                      hintText: 'Konfirmasi password Anda',
                      prefixIcon: Icons.lock_person_outlined,
                      obscureText: !_isConfirmPasswordVisible,
                      validator: _validateConfirmPassword,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isConfirmPasswordVisible
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: const Color(0xFFC58189),
                        ),
                        onPressed: () {
                          setState(() {
                            _isConfirmPasswordVisible =
                                !_isConfirmPasswordVisible;
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Phone Number Field
                    _buildFieldLabel('Nomor Telepon'),
                    const SizedBox(height: 8),
                    PhoneNumberField(
                      controller: phoneController,
                    ),
                    const SizedBox(height: 32),

                    // Register Button
                    _buildGradientButton(
                      text: 'Daftar',
                      onPressed: () => register(context),
                    ),
                    const SizedBox(height: 16),

                    // Login Redirect
                    Center(
                      child: GestureDetector(
                        onTap: () => context.push('/login'),
                        child: RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: 'Sudah punya akun? ',
                                style: GoogleFonts.poppins(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                              TextSpan(
                                text: 'Login',
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
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: GoogleFonts.poppins(
        color: const Color(0xFF333333),
        fontWeight: FontWeight.w500,
        fontSize: 14,
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
        onPressed: isLoading ? null : onPressed,
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
