import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:marketplace_logamas/function/Utils.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:marketplace_logamas/widget/BottomNavigationBar.dart';

class ScanQRPage extends StatefulWidget {
  const ScanQRPage({Key? key}) : super(key: key);

  @override
  State<ScanQRPage> createState() => _ScanQRPageState();
}

class _ScanQRPageState extends State<ScanQRPage> {
  final MobileScannerController cameraController = MobileScannerController();
  String? scannedResult;
  int _selectedIndex = 2;
  bool _isLoading = false;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    switch (index) {
      case 0:
        context.go('/home');
        break;
      case 1:
        context.go('/nearby');
        break;
      case 2:
        context.go('/scan');
        break;
      case 3:
        context.go('/information');
        break;
    }
  }

  Future<void> _handleScannedCode(String rawCode) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final parts = rawCode.split(';');
      if (parts.length != 2) {
        _showResultDialog("Format QR Code tidak valid.");
        return;
      }

      final barcode = parts[0];
      final productId = parts[1];

      final response = await http.get(
        Uri.parse('$apiBaseUrl/products/barcode/$barcode'),
        headers: {'Content-Type': 'application/json'},
      );

      final result = jsonDecode(response.body);

      if (response.statusCode == 200 && result['data'] != null) {
        if (!mounted) return;
        context.push('/product-code-detail?barcode=$barcode');
      } else {
        _showResultDialog("Produk tidak ditemukan untuk barcode:\n$barcode");
      }
    } catch (e) {
      _showResultDialog("Gagal terhubung ke server. Periksa koneksi Anda.");
    } finally {
      setState(() {
        _isLoading = false;
        scannedResult = null;
        cameraController.start();
      });
    }
  }

  void _showResultDialog(String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF31394E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('QR Code Terdeteksi',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(message, style: const TextStyle(color: Colors.white)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                scannedResult = null;
                cameraController.start();
              });
            },
            child:
                const Text("Tutup", style: TextStyle(color: Color(0xFFC58189))),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
        title: const Text(
          'Scan QR Code',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: cameraController,
            onDetect: (capture) {
              final barcode = capture.barcodes.first;
              final String? code = barcode.rawValue;

              if (code != null && scannedResult == null && !_isLoading) {
                cameraController.stop();
                setState(() {
                  scannedResult = code;
                });
                _handleScannedCode(code);
              }
            },
          ),
          if (_isLoading)
            const Center(child: CircularProgressIndicator(color: Colors.white)),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 120.0),
              child: scannedResult == null
                  ? const Text(
                      'Arahkan kamera ke QR Code',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavBar(
        selectedIndex: _selectedIndex,
        onItemTapped: _onItemTapped,
      ),
    );
  }
}
