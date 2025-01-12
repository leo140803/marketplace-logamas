import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:marketplace_logamas/function/Utils.dart';
import 'package:marketplace_logamas/widget/Dialog.dart';
import 'package:marketplace_logamas/widget/Field.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  void _login() async {
    String email = emailController.text;
    String password = passwordController.text;
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
    const String apiUrl = '$apiBaseUrl/user/login';
    try {
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
      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        print(data['data']);
        final String accessToken = data['data']['access_token'];
        print(accessToken);
        final String name = data['data']['name'];
        final String userId = data['data']['user_id'];
        SharedPreferences prefs = await SharedPreferences.getInstance();
        prefs.setString('access_token', accessToken);
        prefs.setString('name', name);
        prefs.setString('user_id', userId);
        if (Platform.isAndroid) {
          await addDeviceToken(accessToken, context);
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          context
              .go('/home'); // Pindah ke halaman setelah frame saat ini selesai
        });
      } else {
        final responseBody = jsonDecode(response.body);
        final errorMessage =
            responseBody['message'] ?? 'An unknown error occurred';
        dialog(context, 'Error', errorMessage);
      }
    } catch (error) {
      Navigator.of(context, rootNavigator: true).pop();

      print('Error: $error');
    }
  }

  Future<String> getDeviceToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.get('fcm_token').toString();
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

        if (response.statusCode == 201) {
          print('Device token added successfully');
        } else {
          final responseBody = jsonDecode(response.body);
          final errorMessage =
              responseBody['message'] ?? 'Failed to add device token';
          dialog(context, 'Error', errorMessage);
        }
      }
    } catch (error) {
      print('Error adding device token: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
            icon: Icon(Icons.arrow_back),
            color: Colors.white,
            onPressed: () {
              Navigator.pushReplacementNamed(context, '/landing');
            }),
        backgroundColor: const Color(0xFF31394E),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Field(
                  con: emailController,
                  isPassword: false,
                  text: 'Email',
                  logo: Icons.email_rounded,
                ),
                SizedBox(height: 20),
                Field(
                  con: passwordController,
                  isPassword: true,
                  text: 'Password',
                  logo: Icons.lock,
                ),
                SizedBox(height: 30),
                GestureDetector(
                  onTap: () {
                    _login();
                  },
                  child: Container(
                    width: 250,
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
                      "Login",
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 20),
                TextButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/register');
                  },
                  child: RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: 'Belum punya akun? ',
                          style: TextStyle(color: Colors.grey),
                        ),
                        TextSpan(
                          text: 'Register here',
                          style: TextStyle(color: Color(0xFFDAA07D)),
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
