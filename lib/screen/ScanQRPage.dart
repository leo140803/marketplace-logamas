import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:marketplace_logamas/function/Utils.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:marketplace_logamas/widget/BottomNavigationBar.dart';
import 'package:google_fonts/google_fonts.dart';

class ScanQRPage extends StatefulWidget {
  const ScanQRPage({Key? key}) : super(key: key);

  @override
  State<ScanQRPage> createState() => _ScanQRPageState();
}

class _ScanQRPageState extends State<ScanQRPage>
    with SingleTickerProviderStateMixin {
  MobileScannerController? cameraController;
  bool _isControllerInitialized = false;
  String? scannedResult;
  int _selectedIndex = 2;
  bool _isLoading = false;
  bool _isTorchOn = false;
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();

    // Setup animation for the scanning overlay
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.linear,
      ),
    );

    _animationController.repeat(reverse: true);

    // Initialize camera with a slight delay to ensure widget is mounted
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeCamera();
      // context.push('/product-code-detail?barcode=CA0010100010001');
    });
  }

  Future<void> _initializeCamera() async {
    if (!mounted) return;

    try {
      // Create a new controller instance
      cameraController = MobileScannerController(
        detectionSpeed: DetectionSpeed.normal,
        facing: CameraFacing.back,
        torchEnabled: false,
      );

      // Start the camera
      await cameraController?.start();

      if (mounted) {
        setState(() {
          _isControllerInitialized = true;
        });
      }
    } catch (e) {
      print('Error initializing camera: $e');
      // Show an error message to the user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Failed to initialize camera. Please restart the app.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    navigate(context, index);
  }

  Future<void> _handleScannedCode(String rawCode) async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Attempt to parse the QR code in different formats
      if (rawCode.contains(';')) {
        final parts = rawCode.split(';');
        if (parts.length != 2) {
          _showResultDialog("Format QR Code tidak valid.", isError: true);
          return;
        }

        final barcode = parts[0];
        final productId =
            parts[1]; // This isn't used in the current implementation

        await _fetchProductByBarcode(barcode);
      } else {
        // Try to use the code directly as a barcode
        await _fetchProductByBarcode(rawCode);
      }
    } catch (e) {
      _showResultDialog("Gagal terhubung ke server. Periksa koneksi Anda.",
          isError: true);
    } finally {
      setState(() {
        _isLoading = false;
        scannedResult = null;
        // Restart camera safely
        if (_isControllerInitialized && cameraController != null) {
          cameraController!.start();
        }
      });
    }
  }

  Future<void> _fetchProductByBarcode(String barcode) async {
    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/products/barcode/$barcode'),
        headers: {'Content-Type': 'application/json'},
      );

      final result = jsonDecode(response.body);

      if (response.statusCode == 200 && result['data'] != null) {
        if (!mounted) return;
        _showSuccessDialog(barcode);
      } else {
        _showResultDialog("Produk tidak ditemukan untuk barcode:\n$barcode",
            isError: true);
      }
    } catch (e) {
      _showResultDialog("Gagal memuat data produk: ${e.toString()}",
          isError: true);
    }
  }

  void _showSuccessDialog(String barcode) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(
              Icons.check_circle,
              color: Color(0xFF4CAF50),
              size: 24,
            ),
            const SizedBox(width: 10),
            Text(
              'QR Code Terdeteksi',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF31394E),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Barcode produk berhasil dipindai:',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFBE9E7),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFFC58189),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.qr_code_2,
                    color: Color(0xFFC58189),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      barcode,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF31394E),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Apakah Anda ingin melihat detail produk ini?',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                scannedResult = null;
                if (_isControllerInitialized && cameraController != null) {
                  cameraController!.start();
                }
              });
            },
            child: Text(
              "Batal",
              style: GoogleFonts.poppins(
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.push('/product-code-detail?barcode=$barcode');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF31394E),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: Text(
              "Lihat Detail",
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showResultDialog(String message, {bool isError = false}) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              isError ? Icons.error : Icons.info_outline,
              color: isError ? Colors.red : const Color(0xFF31394E),
              size: 24,
            ),
            const SizedBox(width: 10),
            Text(
              isError ? 'Terjadi Kesalahan' : 'Informasi',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF31394E),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: Colors.grey[700],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                scannedResult = null;
                if (_isControllerInitialized && cameraController != null) {
                  cameraController!.start();
                }
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF31394E),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: Text(
              "Tutup",
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _toggleTorch() {
    if (!_isControllerInitialized || cameraController == null) {
      // Show a message that the camera is not ready
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Kamera sedang diinisialisasi. Mohon tunggu sebentar.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    try {
      cameraController!.toggleTorch();
      setState(() {
        _isTorchOn = !_isTorchOn;
      });
    } catch (e) {
      print('Error toggling torch: $e');
      // Try to reinitialize the controller
      _initializeCamera();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Flash tidak dapat digunakan saat ini'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    // Safely dispose the camera controller
    cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF31394E),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        flexibleSpace: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/appbar.png',
              fit: BoxFit.cover,
            ),
            Container(color: Colors.black.withOpacity(0.2)),
          ],
        ),
        centerTitle: true,
        title: Text(
          'Scan QR Code',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
      ),
      body: Stack(
        children: [
          // Scanner view - only show when initialized
          if (_isControllerInitialized && cameraController != null)
            MobileScanner(
              controller: cameraController!,
              onDetect: (capture) {
                final barcode = capture.barcodes.first;
                final String? code = barcode.rawValue;

                if (code != null && scannedResult == null && !_isLoading) {
                  cameraController?.stop();
                  setState(() {
                    scannedResult = code;
                  });
                  _handleScannedCode(code);
                }
              },
            )
          else
            // Show a loading indicator while camera initializes
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Color(0xFFC58189)),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Memulai kamera...',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),

          // Overlay for scanner area
          Container(
            width: double.infinity,
            height: double.infinity,
            color: Colors.black.withOpacity(0.5),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Transparent scanner area
                Container(
                  width: screenSize.width * 0.7,
                  height: screenSize.width * 0.7,
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    border: Border.all(
                      color: const Color(0xFFC58189),
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),

                // Animated scanner line
                AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    return Positioned(
                      // Posisi awal dari atas area pemindaian
                      top: (screenSize.width * 0.45) +
                          (screenSize.width * 0.7 * _animation.value),
                      left: screenSize.width * 0.15,
                      child: Container(
                        width: screenSize.width * 0.7,
                        height: 2,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              const Color(0xFFC58189).withOpacity(0.8),
                              Colors.transparent,
                            ],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                        ),
                      ),
                    );
                  },
                ),

                // Corner decorations
                Positioned(
                  top: screenSize.width * 0.15 - 5,
                  left: screenSize.width * 0.15 - 5,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: const BoxDecoration(
                      border: Border(
                        top: BorderSide(color: Color(0xFFC58189), width: 5),
                        left: BorderSide(color: Color(0xFFC58189), width: 5),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: screenSize.width * 0.15 - 5,
                  right: screenSize.width * 0.15 - 5,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: const BoxDecoration(
                      border: Border(
                        top: BorderSide(color: Color(0xFFC58189), width: 5),
                        right: BorderSide(color: Color(0xFFC58189), width: 5),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: screenSize.width * 0.15 - 5,
                  left: screenSize.width * 0.15 - 5,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Color(0xFFC58189), width: 5),
                        left: BorderSide(color: Color(0xFFC58189), width: 5),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: screenSize.width * 0.15 - 5,
                  right: screenSize.width * 0.15 - 5,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Color(0xFFC58189), width: 5),
                        right: BorderSide(color: Color(0xFFC58189), width: 5),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Loading indicator
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.7),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Color(0xFFC58189)),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Memproses QR Code...',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Bottom guide text
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 120.0),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  scannedResult == null
                      ? 'Arahkan kamera ke QR Code produk'
                      : 'Memproses QR Code...',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      // Floating action button for torch
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFFC58189),
        elevation: 4,
        onPressed: _toggleTorch,
        child: Icon(
          _isTorchOn ? Icons.flash_on : Icons.flash_off,
          color: Colors.white,
        ),
      ),
      bottomNavigationBar: BottomNavBar(
        selectedIndex: _selectedIndex,
        onItemTapped: _onItemTapped,
      ),
    );
  }
}
