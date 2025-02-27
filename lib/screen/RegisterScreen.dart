import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:marketplace_logamas/screen/ConfirmationScreen.dart';
import 'package:marketplace_logamas/function/Utils.dart';
import 'package:marketplace_logamas/widget/Dialog.dart';
import 'package:marketplace_logamas/widget/Field2.dart';
import 'package:marketplace_logamas/widget/PhoneNumberField.dart';

class RegisterScreen extends StatefulWidget {
  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController passwordConfirmController =
      TextEditingController();
  final TextEditingController phoneController = TextEditingController();

  bool isLoading = false;

  void register(BuildContext context) async {
    setState(() {
      isLoading = true;
    });

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
            Text('Mohon tunggu sebentar'),
          ],
        ),
      ),
    );
    if (passwordController.text != passwordConfirmController.text) {
      Navigator.of(context, rootNavigator: true).pop();
      dialog(context, 'Invalid', 'Your Password doesn\'t match');
      setState(() {
        isLoading = false;
      });
      return;
    }

    final response = await http.post(
      Uri.parse('$apiBaseUrl/user/register'),
      body: {
        'name': nameController.text,
        'email': emailController.text,
        'password': passwordController.text,
        'phone': "62${phoneController.text}",
      },
    );

    setState(() {
      isLoading = false;
    });

    Navigator.of(context, rootNavigator: true).pop();

    if (response.statusCode == 201) {
      final email = emailController.text;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ConfirmationScreen(email: email),
        ),
      );
    } else {
      final responseBody = jsonDecode(response.body);
      final errorMessage =
          responseBody['message'] ?? 'An unknown error occurred';
      print(errorMessage);
      dialog(context, 'Error', errorMessage);
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
          onPressed: () => context.pop(),
        ),
        title: const Text(
          "Register",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      // resizeToAvoidBottomInset: true,
      body: SingleChildScrollView(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 20),
                  Text(
                    'Daftar Akun',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 20),
                  Text(
                    'Full Name',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(
                    height: 5,
                  ),
                  FieldSquare(
                    con: nameController,
                    isPassword: false,
                    text: 'Full Name',
                    logo: Icons.perm_identity_sharp,
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Email',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(
                    height: 5,
                  ),
                  FieldSquare(
                    con: emailController,
                    isPassword: false,
                    text: 'Email',
                    logo: Icons.email_outlined,
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Password',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(
                    height: 5,
                  ),
                  FieldSquare(
                    con: passwordController,
                    isPassword: true,
                    text: 'Password',
                    logo: Icons.lock,
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Confirm Password',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(
                    height: 5,
                  ),
                  FieldSquare(
                    con: passwordConfirmController,
                    isPassword: true,
                    text: 'Confirm your Password',
                    logo: Icons.lock_person,
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Phone Number',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(
                    height: 5,
                  ),
                  PhoneNumberField(
                    controller: phoneController,
                  ),
                  SizedBox(height: 30),
                  GestureDetector(
                    onTap: () {
                      register(context);
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
                      padding: const EdgeInsets.symmetric(
                          vertical: 15, horizontal: 20),
                      alignment: Alignment.center,
                      child: const Text(
                        "Daftar",
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 10,
                  ),
                  Center(
                    child: TextButton(
                      onPressed: () {
                        Navigator.pushReplacementNamed(context, '/login');
                      },
                      child: RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: 'Sudah punya akun? ',
                              style: TextStyle(color: Colors.grey),
                            ),
                            TextSpan(
                              text: 'Login here',
                              style: TextStyle(color: Color(0xFFDAA07D)),
                            ),
                          ],
                        ),
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
  }
}
