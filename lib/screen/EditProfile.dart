import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:marketplace_logamas/function/Utils.dart';
import 'package:marketplace_logamas/widget/FieldEdit.dart';
import 'package:marketplace_logamas/widget/PhoneNumberField.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({Key? key}) : super(key: key);

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _accessToken;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadAccessTokenAndUserData();
  }

  // Load access token and fetch profile data
  Future<void> _loadAccessTokenAndUserData() async {
    setState(() {
      _isLoading = true;
    });
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
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Fetch user profile from API
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

        // Hapus kode negara '62' saat ditampilkan di input field
        String phone = data['data']['phone'];
        if (phone.startsWith('62')) {
          phone = phone.substring(2); // Hilangkan '62' di awal
        }

        _nameController.text = data['data']['name'];
        _phoneController.text = phone;
      } else {
        print('Failed to fetch user profile: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching user profile: $e');
    }
  }

  // Update profile using API
  Future<void> _updateProfile() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });
      try {
        // Tambahkan kembali '62' ke nomor telepon sebelum dikirim ke API
        final phoneWithCountryCode = '62${_phoneController.text.trim()}';

        final response = await http.put(
          Uri.parse('http://127.0.0.1:3000/api/user/update-details'),
          headers: {
            'Authorization': 'Bearer $_accessToken',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'name': _nameController.text.trim(),
            'phone': phoneWithCountryCode,
          }),
        );

        print(jsonDecode(response.body));

        if (response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Profile updated successfully',
                style: TextStyle(
                  color: Colors.white, // Warna teks
                ),
              ),
              backgroundColor:
                  const Color(0xFF31394E), // Ganti dengan warna palet Anda
              behavior: SnackBarBehavior.floating, // Snackbar melayang
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.0),
              ),
            ),
          );
          context.go('/information');
        } else {
          final data = jsonDecode(response.body);
          print('Failed to update profile: ${data['message']}');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                data['message'] ?? 'Update failed',
                style: const TextStyle(
                  color: Colors
                      .white, // Warna teks agar kontras dengan latar belakang
                ),
              ),
              backgroundColor: const Color(
                  0xFFC58189), // Ganti dengan warna palet error Anda
              behavior: SnackBarBehavior.floating, // Snackbar melayang
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.0),
              ),
            ),
          );
        }
      } catch (e) {
        print('Error updating profile: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('An error occurred while updating')),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            )),
        leading: IconButton(
            onPressed: () => context.go('/information'),
            icon: Icon(
              Icons.arrow_back,
              color: Colors.white,
            )),
        backgroundColor: const Color(0xFF31394E),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Edit your profile details below.',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FieldSquareEdit(
                        controller: _nameController,
                        isPassword: false,
                        hintText: 'Name',
                        prefixIcon: Icons.person),
                    const SizedBox(height: 16),
                    PhoneNumberField(controller: _phoneController),
                    // FieldSquareEdit(
                    //     controller: _phoneController,
                    //     isPassword: false,
                    //     hintText: 'Phone Number',
                    //     prefixIcon: Icons.phone),
                    const SizedBox(height: 32),
                    GestureDetector(
                      onTap: () {
                        _updateProfile();
                      },
                      child: Container(
                        width: double.infinity,
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
                          "Save Changes",
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
            ),
    );
  }
}
