import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:marketplace_logamas/function/Utils.dart';
import 'package:marketplace_logamas/widget/FieldEdit.dart';
import 'package:marketplace_logamas/widget/PhoneNumberEdit.dart';
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
  bool _isLoading = true;
  bool _isSaving = false;
  String? _nameError;
  String? _phoneError;
  String? _originalName;
  String? _originalPhone;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _loadAccessTokenAndUserData();

    // Add listeners to track changes
    _nameController.addListener(_checkForChanges);
    _phoneController.addListener(_checkForChanges);
  }

  void _checkForChanges() {
    if (_originalName == null || _originalPhone == null) return;

    final hasChanges = _nameController.text != _originalName ||
        _phoneController.text != _originalPhone;

    if (hasChanges != _hasChanges) {
      setState(() {
        _hasChanges = hasChanges;
      });
    }
  }

  @override
  void dispose() {
    _nameController.removeListener(_checkForChanges);
    _phoneController.removeListener(_checkForChanges);
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
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
      }
    } catch (e) {
      _showErrorSnackBar('Error loading profile: ${e.toString()}');
    } finally {
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

        String phone = data['data']['phone'];
        if (phone.startsWith('62')) {
          phone = phone.substring(2); // Remove '62' prefix
        }

        if (mounted) {
          setState(() {
            _nameController.text = data['data']['name'];
            _phoneController.text = phone;
            _originalName = data['data']['name'];
            _originalPhone = phone;
          });
        }
      } else if (response.statusCode == 401) {
        _showErrorSnackBar('Session expired. Please login again.');
      } else {
        _showErrorSnackBar('Failed to load profile. Please try again.');
      }
    } catch (e) {
      _showErrorSnackBar('Network error. Please check your connection.');
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.0),
        ),
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: const Color(0xFF31394E),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.0),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  bool _validateInputs() {
    bool isValid = true;
    setState(() {
      _nameError = null;
      _phoneError = null;

      // Validate name
      if (_nameController.text.trim().isEmpty) {
        _nameError = 'Name cannot be empty';
        isValid = false;
      } else if (_nameController.text.trim().length < 2) {
        _nameError = 'Name is too short';
        isValid = false;
      }

      // Validate phone
      final phone = _phoneController.text.trim();
      if (phone.isEmpty) {
        _phoneError = 'Phone number cannot be empty';
        isValid = false;
      } else if (phone.length < 9 || phone.length > 12) {
        _phoneError = 'Please enter a valid phone number';
        isValid = false;
      }
    });

    return isValid;
  }

  void _confirmUpdate() {
    if (!_validateInputs()) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Profile'),
        content: const Text('Are you sure you want to update your profile?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey[700],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _updateProfile();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFC58189),
              foregroundColor: Colors.white,
            ),
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final phoneWithCountryCode = '62${_phoneController.text.trim()}';

      final response = await http.put(
        Uri.parse('$apiBaseUrl/user/update-details'),
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'name': _nameController.text.trim(),
          'phone': phoneWithCountryCode,
        }),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          _showSuccessSnackBar('Profile updated successfully');

          // Update original values to reflect the changes
          _originalName = _nameController.text;
          _originalPhone = _phoneController.text;
          setState(() {
            _hasChanges = false;
          });

          // Navigate back after a brief delay
          Future.delayed(const Duration(seconds: 1), () {
            if (mounted) {
              context.push('/information');
            }
          });
        }
      } else {
        final data = jsonDecode(response.body);
        if (mounted) {
          _showErrorSnackBar(
              data['message'] ?? 'Update failed. Please try again.');
        }
      }
    } catch (e) {
      _showErrorSnackBar('Network error. Please check your connection.');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _resetForm() {
    setState(() {
      _nameController.text = _originalName ?? '';
      _phoneController.text = _originalPhone ?? '';
      _nameError = null;
      _phoneError = null;
      _hasChanges = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_hasChanges) {
          final result = await _showDiscardChangesDialog();
          return result ?? false;
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent, // Keep transparent as requested
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
          title: const Text(
            'Edit Profile',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          leading: IconButton(
            onPressed: () {
              if (_hasChanges) {
                _showDiscardChangesDialog().then((discard) {
                  if (discard ?? false) {
                    context.go('/information');
                  }
                });
              } else {
                context.go('/information');
              }
            },
            icon: const Icon(
              Icons.arrow_back,
              color: Colors.white,
            ),
          ),
          actions: [
            if (_hasChanges)
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white),
                tooltip: 'Reset changes',
                onPressed: _resetForm,
              ),
          ],
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : SafeArea(
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
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
                              const SizedBox(height: 24),

                              // Name field
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Name',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  FieldSquareEdit(
                                    controller: _nameController,
                                    isPassword: false,
                                    hintText: 'Enter your name',
                                    prefixIcon: Icons.person,
                                    validator: (value) => _nameError,
                                  ),
                                  if (_nameError != null)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                          top: 6.0, left: 12.0),
                                      child: Text(
                                        _nameError!,
                                        style: const TextStyle(
                                          color: Colors.red,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 24),

                              // Phone number field
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Phone Number',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  PhoneNumberFieldEdit(
                                    controller: _phoneController,
                                  ),
                                  if (_phoneError != null)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                          top: 6.0, left: 12.0),
                                      child: Text(
                                        _phoneError!,
                                        style: const TextStyle(
                                          color: Colors.red,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 40),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Action buttons
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, -2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () {
                                if (_hasChanges) {
                                  _showDiscardChangesDialog().then((discard) {
                                    if (discard ?? false) {
                                      context.go('/information');
                                    }
                                  });
                                } else {
                                  context.go('/information');
                                }
                              },
                              style: TextButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 15),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                  side: BorderSide(color: Colors.grey[300]!),
                                ),
                              ),
                              child: const Text(
                                "Cancel",
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              onPressed: _hasChanges && !_isSaving
                                  ? _confirmUpdate
                                  : null,
                              style: ElevatedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 15),
                                backgroundColor: const Color(0xFFC58189),
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: Colors.grey[300],
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                              child: _isSaving
                                  ? Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: const [
                                        SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        ),
                                        SizedBox(width: 12),
                                        Text(
                                          "Saving...",
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    )
                                  : const Text(
                                      "Save Changes",
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
                  ],
                ),
              ),
      ),
    );
  }

  Future<bool?> _showDiscardChangesDialog() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard Changes'),
        content: const Text(
            'You have unsaved changes. Are you sure you want to discard them?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep Editing'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey[700],
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[400],
              foregroundColor: Colors.white,
            ),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
  }
}
