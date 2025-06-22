import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:marketplace_logamas/function/Utils.dart';
import 'package:marketplace_logamas/widget/BottomNavigationBar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({Key? key}) : super(key: key);

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  int _selectedIndex = 4;
  String? _accessToken;
  bool _isLoading = true;

  // User data
  String _name = '';
  String _email = '';
  String _phone = '';

  // Menu items data
  final List<MenuItemData> _accountMenuItems = [
    MenuItemData(
      icon: Icons.receipt,
      title: 'Daftar Pembelian',
      route: '/order',
      isNamed: false,
    ),
    MenuItemData(
      icon: Icons.sell_outlined,
      title: 'Daftar Penjualan',
      route: '/sell',
    ),
    MenuItemData(
      icon: Icons.sync,
      title: 'Daftar Tukar Tambah',
      route: '/trade',
    ),
    MenuItemData(
      icon: Icons.favorite_outline,
      title: 'Daftar Wishlist',
      route: '/wishlist',
    ),
    MenuItemData(
      icon: Icons.card_giftcard,
      title: 'My Poin',
      route: '/my-poin',
    ),
  ];

  final List<MenuItemData> _settingsMenuItems = [
     MenuItemData(
      icon: Icons.description,
      title: 'Terms and Conditions',
      route: '/tnc',
      isNamed: false,
    ),
    MenuItemData(
      icon: Icons.question_mark_rounded,
      title: 'FAQ',
      route: '/faq',
      isNamed: false,
    ),
    MenuItemData(
      icon: Icons.qr_code_scanner,
      title: 'Show My QR',
      route: '/myQR',
      isNamed: false,
    ),
    MenuItemData(
      icon: Icons.lock_outline,
      title: 'Change Password',
      route: '/change-password',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadAccessTokenAndUserData();
  }

  Future<void> _loadAccessTokenAndUserData() async {
    try {
      final token = await getAccessToken();

      if (mounted) {
        setState(() {
          _accessToken = token;
        });
      }

      if (_accessToken != null) {
        await _fetchUserProfile();
      } else {
        // Handle case when token is null
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading access token or user data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (mounted) {
          setState(() {
            _name = data['data']['name'] ?? '';
            _email = data['data']['email'] ?? '';
            _phone = _formatPhoneNumber(data['data']['phone'] ?? '');
            _isLoading = false;
          });
        }
      } else {
        debugPrint('Failed to fetch user profile: ${response.statusCode}');
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching user profile: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _formatPhoneNumber(String phoneNumber) {
    if (phoneNumber.isEmpty) return '';
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
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFC58189)),
            ),
          );
        },
      );

      // Hapus data dari SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      // Close loading indicator
      Navigator.of(context).pop();

      // Arahkan ke halaman landing
      context.go('/landing');
    } catch (e) {
      // Close loading indicator if error
      Navigator.of(context).pop();
      debugPrint('Error during logout: $e');

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Terjadi kesalahan saat logout.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: _buildAppBar(),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProfileSection(),
            const SizedBox(height: 8),
            _buildMenuSection(
              title: 'Akun Saya',
              menuItems: _accountMenuItems,
            ),
            const SizedBox(height: 8),
            _buildMenuSection(
              title: 'Pengaturan',
              menuItems: _settingsMenuItems,
              includeLogout: true,
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

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      flexibleSpace: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/appbar.png',
            fit: BoxFit.cover,
          ),
          Container(
            color: Colors.black.withOpacity(0.2),
          ),
        ],
      ),
      automaticallyImplyLeading: false,
      centerTitle: true,
      elevation: 0,
      title: const Text(
        'Menu Utama',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildProfileSection() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      margin: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: const Color(0xFF31394E),
            child: _isLoading
                ? const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    strokeWidth: 2.0,
                  )
                : Text(
                    _name.isNotEmpty ? _name[0].toUpperCase() : 'U',
                    style: const TextStyle(
                      fontSize: 24,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _isLoading
                    ? _shimmerEffect()
                    : Text(
                        _name.isNotEmpty ? _name : 'User',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                const SizedBox(height: 4),
                _isLoading
                    ? _shimmerEffect()
                    : Text(
                        _email.isNotEmpty ? _email : 'Email tidak tersedia',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 14,
                        ),
                      ),
                const SizedBox(height: 4),
                _isLoading
                    ? _shimmerEffect()
                    : Text(
                        _phone.isNotEmpty
                            ? _phone
                            : 'No telepon tidak tersedia',
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
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(50),
              ),
              child: const Icon(Icons.settings, color: Color(0xFF31394E)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuSection({
    required String title,
    required List<MenuItemData> menuItems,
    bool includeLogout = false,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF31394E),
              ),
            ),
          ),
          const Divider(),
          ...menuItems.map((item) => _buildMenuItem(item)).toList(),
          if (includeLogout) ...[
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text(
                'Logout',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () => _showLogoutDialog(context),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMenuItem(MenuItemData item) {
    return ListTile(
      leading: Icon(item.icon, color: const Color(0xFF31394E)),
      title: Text(
        item.title,
        style: const TextStyle(
          fontSize: 14,
          color: Color(0xFF31394E),
        ),
      ),
      trailing: const Icon(Icons.chevron_right, color: Color(0xFFC58189)),
      onTap: () {
        try {
          if (item.isNamed) {
            context.goNamed(item.route);
          } else {
            context.push(item.route);
          }
        } catch (e) {
          debugPrint('Navigation error: $e');
          // Fallback navigation in case of error
          if (item.title == 'Daftar Pembelian') {
            context.go('/order');
          }
        }
      },
    );
  }

  Widget _shimmerEffect() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Container(
        height: 14,
        width: 150,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: const Color(0xFF31394E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Icon
                const Icon(
                  Icons.logout,
                  color: Colors.white,
                  size: 40,
                ),
                const SizedBox(height: 16),
                // Title
                const Text(
                  'Logout',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                // Description
                const Text(
                  'Apakah Anda yakin ingin keluar?',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
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
                          color: Colors.grey[600],
                          borderRadius: BorderRadius.circular(30),
                        ),
                        padding: const EdgeInsets.symmetric(
                            vertical: 12, horizontal: 16),
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
                        _logout(); // Panggil fungsi logout
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
                            vertical: 12, horizontal: 16),
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

// Model for menu items
class MenuItemData {
  final IconData icon;
  final String title;
  final String route;
  final bool isNamed;

  MenuItemData({
    required this.icon,
    required this.title,
    required this.route,
    this.isNamed = false,
  });
}
