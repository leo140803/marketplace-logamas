import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:marketplace_logamas/function/Utils.dart';
import 'package:marketplace_logamas/widget/BottomNavigationBar.dart';

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

  // Load token and fetch user data
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
        Uri.parse('http://127.0.0.1:3000/api/user/profile'),
        headers: {
          'Authorization': 'Bearer $_accessToken',
        },
      );

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
                    title: const Text('Daftar Transaksi'),
                    trailing:
                        Icon(Icons.chevron_right, color: Colors.grey.shade400),
                    onTap: () => context.goNamed('order'),
                  ),
                  _buildMenuItem(
                      'Toko yang Di-follow', Icons.storefront_outlined),
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
}
