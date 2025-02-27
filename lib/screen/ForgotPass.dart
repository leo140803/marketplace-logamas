import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:marketplace_logamas/function/Utils.dart';
import 'package:marketplace_logamas/widget/Dialog.dart';
import 'package:marketplace_logamas/widget/Field.dart';

class ForgotPasswordPage extends StatefulWidget {
  @override
  _ForgotPasswordPageState createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final TextEditingController emailController = TextEditingController();

  void _requestPasswordReset() async {
    String email = emailController.text;

    // Validasi email kosong
    if (email.isEmpty) {
      dialog(context, 'Error', 'Email cannot be empty');
      return;
    }

    // Tampilkan dialog loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text('Please wait...'),
        content: Row(
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFE0B9B2)),
            ),
            SizedBox(width: 15),
            Text('Sending reset link...'),
          ],
        ),
      ),
    );

    // API call untuk reset password
    const String apiUrl = '$apiBaseUrl/user/forgot-password';
    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'email': email,
        }),
      );

      Navigator.of(context, rootNavigator: true).pop();

      if (response.statusCode == 201) {
        dialog(context, 'Success',
            'If the email is registered, a reset link has been sent.');
      } else {
        final responseBody = jsonDecode(response.body);
        final errorMessage =
            responseBody['message'] ?? 'An unknown error occurred';
        dialog(context, 'Error', errorMessage);
      }
    } catch (error) {
      Navigator.of(context, rootNavigator: true).pop();
      dialog(context, 'Error', 'Failed to send reset link. Try again later.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor:
            Colors.transparent, // Buat transparan agar gambar terlihat
        flexibleSpace: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/appbar.png', // Ganti dengan path gambar yang sesuai
              fit: BoxFit.cover, // Pastikan gambar memenuhi seluruh AppBar
            ),
            Container(
              color: Colors.black
                  .withOpacity(0.2), // Overlay agar teks tetap terbaca
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            context.pop();
          },
        ),
        title: const Text(
          "Forgot Password",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Enter your email to reset your password',
              style: TextStyle(fontSize: 16, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20),
            Field(
              con: emailController,
              isPassword: false,
              text: 'Email',
              logo: Icons.email_rounded,
            ),
            SizedBox(height: 20),
            GestureDetector(
              onTap: () {
                _requestPasswordReset();
              },
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFFE8C4BD),
                      Color(0xFFC58189),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(30),
                ),
                padding: const EdgeInsets.symmetric(vertical: 15),
                alignment: Alignment.center,
                child: const Text(
                  "Send Reset Link",
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white,
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
