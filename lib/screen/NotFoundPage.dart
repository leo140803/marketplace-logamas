import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class NotFoundPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Page Not Found")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 80),
            SizedBox(height: 20),
            Text(
              "Oops! Page not found",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text("The page you are looking for doesn't exist."),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => context.go('/home'), // Redirect to Home
              child: Text("Go to Home"),
            ),
          ],
        ),
      ),
    );
  }
}
