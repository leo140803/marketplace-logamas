import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:marketplace_logamas/widget/Dialog.dart';
import 'package:marketplace_logamas/widget/UnauthorizedDialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String apiBaseUrl = 'https://c0fa-66-96-225-86.ngrok-free.app/api';
const String apiBaseUrlImage = 'http://127.0.0.1:3000/';
const String apiBaseUrlNota = 'http://127.0.0.1:3000';
const String apiBaseUrlPlatform = 'http://127.0.0.1:3020';

void navigate(BuildContext context, int index) {
  if (index == 0) {
    context.go('/home');
    // Navigator.pushReplacementNamed(context, '/home');
  } else if (index == 1) {
    context.go('/nearby');
    // Navigator.pushReplacementNamed(context, '/nearby');
  } else if (index == 2) {
    context.go('/scan');
    // Navigator.pushReplacementNamed(context, '/nearby');
  } else if (index == 3) {
    context.go('/conversations');
  } else if (index == 4) {
    context.go('/information');
  }
}

Future<String> getAccessToken() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  String? accessToken = prefs.getString('access_token');

  if (accessToken == null) {
    throw Exception('Access token not found');
  }

  return accessToken;
}

Future<String> getUserId() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  String? userId = prefs.getString('user_id');

  if (userId == null) {
    throw Exception('User ID not found');
  }

  return userId;
}

Future<String?> getUsername() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  String? name = prefs.getString('name');
  return name;
}

Future<String?> getEmail() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  String? email = prefs.getString('email');
  return email;
}

String formatCurrency(double amount) {
  final format = NumberFormat("#,##0", "id_ID"); // Menggunakan format Indonesia
  return format.format(amount);
}

void handleUnauthorized(BuildContext context) {
  // Tampilkan dialog atau navigasikan ke halaman login
  unauthorizedDialog(context);
}
