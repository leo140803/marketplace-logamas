import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:marketplace_logamas/function/Utils.dart';
import 'package:marketplace_logamas/widget/BottomNavigationBar.dart';

import 'package:shared_preferences/shared_preferences.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({Key? key}) : super(key: key);

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  int _selectedIndex = 2;
  String? _accessToken;
  String _name = 'Loading...';
  String _email = 'Loading...';
  String _phone = 'Loading...';

  @override
  void initState() {
    super.initState();
    _loadAccessTokenAndUserData();
  }

  Future<void> _loadAccessTokenAndUserData() async {
    try {
      final token = await getAccessToken();
      setState(() {
        _accessToken = token;
      });

      if (_accessToken != null) {
        await _fetchUserProfile();
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
      print(jsonDecode(response.body));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print(data);
        setState(() {
          _name = data['data']['name'];
          _email = data['data']['email'];
          _phone = _formatPhoneNumber(data['data']['phone']);
        });
      } else {
        print('Failed to fetch user profile: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching user profile: $e');
    }
  }

  String _formatPhoneNumber(String phoneNumber) {
    if (phoneNumber.startsWith('62')) {
      return '0${phoneNumber.substring(2)}';
    }
    return phoneNumber;
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    navigate(context, index);
  }

  Future<void> _logout() async {
    // Hapus data dari SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    // Arahkan ke halaman landing
    context.go('/landing');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Menu Utama',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        automaticallyImplyLeading: false,
        centerTitle: true,
        elevation: 0,
        backgroundColor: Color(0xFF31394E),
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section
            Container(
              padding: const EdgeInsets.all(16.0),
              color: Colors.white,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Color(0xFF31394E),
                    child: Text(
                      _name.isNotEmpty ? _name[0] : 'U',
                      style: const TextStyle(
                        fontSize: 24,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _email,
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _phone,
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => context.go('/edit-profile'),
                    child: const Icon(Icons.settings, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Menu Items
            Container(
              color: Colors.white,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.receipt, color: Colors.grey),
                    title: const Text('Daftar Pembelian'),
                    trailing:
                        Icon(Icons.chevron_right, color: Colors.grey.shade400),
                    onTap: () => context.goNamed('order'),
                  ),
                  _buildMenuItem('Daftar Penjualan', Icons.sell_outlined),
                  ListTile(
                    leading: const Icon(Icons.build_circle,
                        color: Colors.grey), // Icon Service
                    title: const Text('Daftar Service'),
                    trailing:
                        Icon(Icons.chevron_right, color: Colors.grey.shade400),
                    onTap: () => context.push('/service'),
                  ),
                  ListTile(
                    leading:
                        const Icon(Icons.favorite_outline, color: Colors.grey),
                    title: const Text('Daftar Wishlist'),
                    trailing:
                        Icon(Icons.chevron_right, color: Colors.grey.shade400),
                    onTap: () => context.push('/wishlist'),
                  ),
                  ListTile(
                    leading:
                        const Icon(Icons.card_giftcard, color: Colors.grey),
                    title: const Text('My Poin'),
                    trailing:
                        Icon(Icons.chevron_right, color: Colors.grey.shade400),
                    onTap: () => context.push('/my-poin'),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // More Options
            Container(
              color: Colors.white,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.headset_mic_outlined,
                        color: Colors.grey),
                    title: const Text('Bantuan Logamas Care'),
                    trailing:
                        Icon(Icons.chevron_right, color: Colors.grey.shade400),
                    onTap: () => context.goNamed('faq'),
                  ),
                  ListTile(
                    leading:
                        const Icon(Icons.qr_code_scanner, color: Colors.grey),
                    title: const Text('Show My QR'),
                    trailing:
                        Icon(Icons.chevron_right, color: Colors.grey.shade400),
                    onTap: () => context.goNamed('myQR'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.lock_outline, color: Colors.grey),
                    title: const Text('Change Password'),
                    trailing:
                        Icon(Icons.chevron_right, color: Colors.grey.shade400),
                    onTap: () => context.push('/change-password'),
                  ),
                  const Divider(height: 1),
                  // Logout Option
                  ListTile(
                    leading: const Icon(Icons.logout, color: Colors.red),
                    title: const Text(
                      'Logout',
                      style: TextStyle(color: Colors.red),
                    ),
                    onTap: () {
                      showLogoutDialog(context, _logout);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavBar(
        selectedIndex: _selectedIndex,
        onItemTapped: _onItemTapped,
      ),
    );
  }

  Widget _buildMenuItem(String title, IconData icon) {
    return ListTile(
      leading: Icon(icon, color: Colors.grey),
      title: Text(title),
      trailing: Icon(Icons.chevron_right, color: Colors.grey.shade400),
    );
  }

  void showLogoutDialog(BuildContext context, VoidCallback onLogout) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: const Color(0xFF31394E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Title
                Text(
                  'Logout',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                // Description
                const Text(
                  'Apakah Anda yakin ingin keluar?',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                // Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Cancel Button
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop(); // Tutup dialog
                      },
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                      ),
                      child: Container(
                        width: 100,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
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
                          "Batal",
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    // Logout Button
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop(); // Tutup dialog
                        onLogout(); // Panggil fungsi logout
                      },
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                      ),
                      child: Container(
                        width: 100,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFFC58189),
                              Color(0xFFE8C4BD),
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
                          "Logout",
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
