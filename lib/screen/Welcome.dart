import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  _WelcomeScreenState createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();

    // Setup animations
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Interval(0.2, 0.7, curve: Curves.easeOut),
      ),
    );

    // Start animation after checking token
    _checkAccessToken().then((_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _animationController.forward();
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // Check if access_token exists in SharedPreferences
  Future<void> _checkAccessToken() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? accessToken = prefs.getString('access_token');

      if (accessToken != null && mounted) {
        // Add a small delay for better UX
        await Future.delayed(const Duration(milliseconds: 800));
        context.go('/home'); // Navigate if token is available
      }
    } catch (e) {
      // Handle errors gracefully
      debugPrint('Error checking access token: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get screen dimensions for responsive sizing
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          // Background with overlay gradient
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/background.png'),
                fit: BoxFit.cover,
              ),
            ),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.3),
                    Colors.black.withOpacity(0.5),
                  ],
                ),
              ),
            ),
          ),

          // Main content
          _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Color(0xFFE8C4BD)),
                  ),
                )
              : SafeArea(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: screenSize.width * 0.1,
                    ),
                    child: Column(
                      children: [
                        // Logo section (can be added if available)
                        SizedBox(height: screenSize.height * 0.06),

                        // Welcome text section with animation
                        Expanded(
                          flex: 3,
                          child: Center(
                            child: FadeTransition(
                              opacity: _fadeAnimation,
                              child: SlideTransition(
                                position: _slideAnimation,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      "Selamat datang di",
                                      style: GoogleFonts.openSans(
                                        fontSize: screenSize.width * 0.055,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w400,
                                        letterSpacing: 1.2,
                                        shadows: const [
                                          Shadow(
                                            blurRadius: 5,
                                            color: Colors.black45,
                                            offset: Offset(2, 2),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    ShaderMask(
                                      shaderCallback: (bounds) =>
                                          LinearGradient(
                                        colors: const [
                                          Color(0xFFFFEEE7),
                                          Color(0xFFF0C3BA),
                                          Color(0xFFD7919A),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ).createShader(bounds),
                                      child: Text(
                                        "Logamas",
                                        style: GoogleFonts.playfairDisplay(
                                          fontSize: screenSize.width * 0.12,
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontStyle: FontStyle.italic,
                                          letterSpacing: 1.5,
                                          shadows: const [
                                            Shadow(
                                              blurRadius: 2,
                                              color: Colors.black26,
                                              offset: Offset(1, 1),
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
                        ),

                        // Buttons section
                        Expanded(
                          flex: 2,
                          child: FadeTransition(
                            opacity: _fadeAnimation,
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: screenSize.width * 0.05,
                                vertical: 20,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // Register button
                                  ElevatedButton(
                                    onPressed: () {
                                      context.push('/register');
                                    },
                                    style: ElevatedButton.styleFrom(
                                      foregroundColor: Colors.white,
                                      backgroundColor: Colors.transparent,
                                      elevation: 5,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      minimumSize: Size(
                                        double.infinity,
                                        56,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(30),
                                      ),
                                    ).copyWith(
                                      backgroundColor:
                                          MaterialStateProperty.all(
                                        const Color(0xFFD7919A),
                                      ),
                                      overlayColor: MaterialStateProperty.all(
                                        Colors.white.withOpacity(0.1),
                                      ),
                                    ),
                                    child: Text(
                                      "Daftar",
                                      style: GoogleFonts.openSans(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 16),

                                  // Login button with shimmer effect
                                  OutlinedButton(
                                    onPressed: () {
                                      context.push('/login');
                                    },
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFFE8C4BD),
                                      side: const BorderSide(
                                        color: Color(0xFFE8C4BD),
                                        width: 2,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(30),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      minimumSize: Size(
                                        double.infinity,
                                        56,
                                      ),
                                    ),
                                    child: Text(
                                      "Login",
                                      style: GoogleFonts.openSans(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.5,
                                        color: const Color(0xFFE8C4BD),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // Bottom decorative element or version info
                        FadeTransition(
                          opacity: _fadeAnimation,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Text(
                              "v1.0.0",
                              style: GoogleFonts.openSans(
                                fontSize: 12,
                                color: Colors.white.withOpacity(0.7),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}
