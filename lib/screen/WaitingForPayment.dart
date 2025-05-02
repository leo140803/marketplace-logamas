import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async'; // Import untuk Timer

class WaitingForPaymentPage extends StatefulWidget {
  final String orderId;
  final String referenceId;

  const WaitingForPaymentPage({
    Key? key,
    required this.orderId,
    required this.referenceId,
  }) : super(key: key);

  @override
  State<WaitingForPaymentPage> createState() => _WaitingForPaymentPageState();
}

class _WaitingForPaymentPageState extends State<WaitingForPaymentPage>
    with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  String _statusMessage = 'Waiting for Payment';
  bool _hasError = false;
  Timer? _pollingTimer;
  int _remainingTime = 3600; // Default 1 jam dalam detik
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    // Tambahkan controller untuk animasi
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    // Timer countdown untuk batas waktu pembayaran
    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingTime > 0) {
        setState(() {
          _remainingTime--;
        });
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  String _formatRemainingTime() {
    int hours = _remainingTime ~/ 3600;
    int minutes = (_remainingTime % 3600) ~/ 60;
    int seconds = _remainingTime % 60;

    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> checkPaymentStatus() async {
    if (_isLoading) return; // Hindari multiple requests bersamaan

    setState(() {
      _isLoading = true;
    });

    try {
      final apiKey =
          "DEV-V0nm0v3uNsKpz9JNQH42QR59dzmnrRzuYHY5y3vG"; // Ganti dengan API key Anda
      final response = await http.get(
        Uri.parse(
            'https://tripay.co.id/api-sandbox/transaction/check-status?reference=${widget.referenceId}'),
        headers: {
          'Authorization': 'Bearer $apiKey',
        },
      );

      final data = jsonDecode(response.body);
      print(data); // Debug print untuk melihat struktur respons API

      // Menampilkan data lebih detail
      String status = 'Unknown status';
      bool isExpiredOrFailed = false;

      if (data['success'] == true) {
        // Periksa jika pesan mengandung status pembayaran
        String message = data['message'] ?? '';

        if (message.contains('DIBAYAR')) {
          status = 'Pembayaran Berhasil';
          _pollingTimer?.cancel(); // Hentikan polling jika sudah bayar
        } else if (message.contains('UNPAID')) {
          status = 'Menunggu Pembayaran';
        } else if (message.contains('EXPIRED')) {
          status = 'Pembayaran Kadaluarsa';
          _pollingTimer?.cancel(); // Hentikan polling jika expired
          isExpiredOrFailed = true;
        } else if (message.contains('FAILED')) {
          status = 'Pembayaran Gagal';
          _pollingTimer?.cancel(); // Hentikan polling jika gagal
          isExpiredOrFailed = true;
        } else {
          status = message; // Gunakan pesan asli jika tidak ada yang cocok
        }
      } else {
        status = data['message'] ?? 'Terjadi kesalahan';
      }

      setState(() {
        _isLoading = false;
        _statusMessage = status;
        _hasError = data['success'] != true || isExpiredOrFailed;
      });

      // Cek apakah pembayaran berhasil berdasarkan pesan yang mengandung "DIBAYAR"
      if (data['success'] == true && data['message'] != null) {
        String message = data['message'].toString();
        // message= 'EXPIRED';

        // Jika pembayaran berhasil
        if (message.contains('DIBAYAR')) {
          // Navigasi ke halaman sukses
          _showSuccessDialog(context);

          // Tunggu sebentar, lalu arahkan ke halaman sukses
          Future.delayed(const Duration(seconds: 2), () {
            context.go('/payment_success?order_id=${widget.orderId}');
          });
        }
        // Jika pembayaran expired atau gagal
        else if (message.contains('EXPIRED') || message.contains('FAILED')) {
          // Menampilkan dialog kegagalan
          _showFailureDialog(context, status);

          // Tunggu sebentar, lalu arahkan ke halaman gagal
          Future.delayed(const Duration(seconds: 2), () {
            context.go(
                '/payment_failed?order_id=${widget.orderId}&status=$status');
          });
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _statusMessage = 'Error memeriksa status pembayaran: ${e.toString()}';
      });
    }
  }

  void _showFailureDialog(BuildContext context, String status) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 80,
              ),
              const SizedBox(height: 16),
              Text(
                status,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Transaksi untuk Order ID: ${widget.orderId} tidak berhasil.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSuccessDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 80,
              ),
              const SizedBox(height: 16),
              const Text(
                'Pembayaran Berhasil!',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Pembayaran untuk Order ID: ${widget.orderId} telah diterima.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Menunggu Pembayaran',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF31394E),
        elevation: 2,
        centerTitle: true,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            onPressed: () {
              // Show help/info dialog
              _showInfoDialog(context);
            },
            icon: const Icon(Icons.info_outline, color: Colors.white),
          ),
        ],
      ),
      body: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header - Payment Info Card
                Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        AnimatedBuilder(
                            animation: _pulseController,
                            builder: (context, child) {
                              return Transform.scale(
                                scale: 0.9 + (_pulseController.value * 0.2),
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Color(0xFFE3F2FD),
                                  ),
                                  child: const Icon(
                                    Icons.payments_outlined,
                                    size: 60,
                                    color: Color(0xFF1565C0),
                                  ),
                                ),
                              );
                            }),
                        const SizedBox(height: 24),
                        const Text(
                          'Menunggu Konfirmasi Pembayaran',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        // Order details
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: [
                              _buildInfoRow('Reference ID', widget.referenceId),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Countdown timer card
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        const Text(
                          'Batas Waktu Pembayaran',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _formatRemainingTime(),
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1565C0),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Segera selesaikan pembayaran Anda sebelum batas waktu berakhir',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Status message
                if (_statusMessage.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color:
                          _hasError ? Colors.red.shade50 : Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _hasError
                            ? Colors.red.shade200
                            : Colors.green.shade200,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _hasError ? Icons.error_outline : Icons.info_outline,
                          color: _hasError
                              ? Colors.red.shade700
                              : Colors.green.shade700,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _statusMessage,
                            style: TextStyle(
                              color: _hasError
                                  ? Colors.red.shade700
                                  : Colors.green.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                const Spacer(),

                // Check status button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : checkPaymentStatus,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1565C0),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 3,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.refresh, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Periksa Status Pembayaran',
                                style: TextStyle(fontSize: 16),
                              ),
                            ],
                          ),
                  ),
                ),

                const SizedBox(height: 16),

                // Return button
                OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF31394E),
                    side: const BorderSide(color: Color(0xFF31394E)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    minimumSize: const Size(double.infinity, 48),
                  ),
                  child: const Text(
                    'Kembali ke Detail Pesanan',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: Colors.grey,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  void _showInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Informasi Pembayaran'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                  '1. Pastikan Anda melakukan pembayaran sebelum batas waktu berakhir'),
              SizedBox(height: 8),
              Text('2. Cek email Anda untuk detail instruksi pembayaran'),
              SizedBox(height: 8),
              Text(
                  '3. Setelah pembayaran selesai, status akan diperbarui secara otomatis'),
              SizedBox(height: 8),
              Text(
                  '4. Jika ada kendala, silakan hubungi customer service kami'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Tutup'),
            ),
          ],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        );
      },
    );
  }
}
