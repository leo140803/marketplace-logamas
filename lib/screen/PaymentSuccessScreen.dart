import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:confetti/confetti.dart'; // Tambahkan package confetti: ^0.7.0 di pubspec.yaml

class PaymentSuccessScreen extends StatefulWidget {
  final String orderId;

  const PaymentSuccessScreen({
    Key? key,
    required this.orderId,
  }) : super(key: key);

  @override
  State<PaymentSuccessScreen> createState() => _PaymentSuccessScreenState();
}

class _PaymentSuccessScreenState extends State<PaymentSuccessScreen>
    with SingleTickerProviderStateMixin {
  late ConfettiController _confettiController;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    // Setup konfeti
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 3));

    // Setup animasi
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.elasticOut,
      ),
    );

    // Jalankan animasi ketika halaman dimuat
    _animationController.forward();
    Future.delayed(const Duration(milliseconds: 500), () {
      _confettiController.play();
    });
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.close, color: Color(0xFF31394E)),
            onPressed: () => context.go('/home'),
          ),
        ],
      ),
      body: Stack(
        alignment: Alignment.topCenter,
        children: [
          // Konfeti
          ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            particleDrag: 0.05,
            emissionFrequency: 0.05,
            numberOfParticles: 20,
            gravity: 0.1,
            colors: const [
              Colors.green,
              Colors.blue,
              Colors.pink,
              Colors.orange,
              Colors.purple,
              Colors.lightBlue,
            ],
          ),

          // Konten
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Ikon check dengan animasi
                  ScaleTransition(
                    scale: _scaleAnimation,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check_circle_outline,
                        color: Colors.green.shade600,
                        size: 80,
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Judul dengan animasi fade-in
                  FadeTransition(
                    opacity: _animationController,
                    child: const Text(
                      'Pembayaran Berhasil!',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF31394E),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Subtitel
                  Text(
                    'Pesanan Anda telah dikonfirmasi dan sedang diproses',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 32),

                  // Kartu informasi
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.shade200,
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        _buildInfoRow('Status', 'Pembayaran Berhasil'),
                        const Divider(height: 20),
                        _buildInfoRow('Tanggal', _getCurrentDate()),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Tombol lihat rincian pesanan
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: () {
                        // Navigasi ke halaman detail pesanan
                        context.push('/detail/${widget.orderId}');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF31394E),
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Lihat Rincian Pesanan',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Tombol kembali ke beranda
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: OutlinedButton(
                      onPressed: () {
                        context.go('/home');
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF31394E),
                        side: const BorderSide(color: Color(0xFF31394E)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Kembali ke Beranda',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
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

  // Fungsi helper untuk baris informasi
  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF31394E),
          ),
        ),
      ],
    );
  }

  // Fungsi untuk mendapatkan tanggal saat ini
  String _getCurrentDate() {
    final now = DateTime.now();
    return '${now.day}-${now.month}-${now.year}';
  }
}
