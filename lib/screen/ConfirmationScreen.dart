import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
// import 'package:register/screen/LoginPage.dart';

class ConfirmationScreen extends StatefulWidget {
  final String email;

  ConfirmationScreen({required this.email});

  @override
  _ConfirmationScreenState createState() => _ConfirmationScreenState();
}

class _ConfirmationScreenState extends State<ConfirmationScreen> {
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _sub?.cancel(); // Jangan lupa untuk membatalkan subscription
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Email Sent',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        automaticallyImplyLeading: false,
        backgroundColor: Color(0xFF31394E),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.email_outlined, size: 100, color: Color(0xFF31394E)),
              SizedBox(height: 20),
              Text(
                'Verification Email Sent',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFC58189)),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 10),
              Text(
                'Please check your email at ${widget.email} and click the verification link.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class EmailVerifiedPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.verified,
              color: Colors.green,
              size: 100,
            ),
            Text(
              'Your email has been successfully verified!',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(
              height: 20,
            ),
            GestureDetector(
              onTap: () {
                context.go('/login');
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
                padding:
                    const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
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
          ],
        ),
      ),
    );
  }
}
