import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class PaymentFailedPage extends StatelessWidget {
  final String orderId;
  final String status;

  const PaymentFailedPage({
    Key? key,
    required this.orderId,
    required this.status,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Pembayaran Gagal',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF31394E),
        elevation: 2,
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Error icon with animation
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.8, end: 1.0),
                duration: const Duration(seconds: 1),
                curve: Curves.elasticOut,
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.cancel_outlined,
                        size: 80,
                        color: Colors.red.shade700,
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 32),

              // Status message
              Text(
                status,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 16),

              Text(
                'Order ID: $orderId',
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),

              const SizedBox(height: 24),

              // Information about the failed payment
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  children: [
                    _buildInfoItem(
                      Icons.info_outline,
                      'Transaksi Anda tidak dapat diproses.',
                    ),
                    const Divider(height: 24),
                    _buildInfoItem(
                      Icons.access_time,
                      'Pembayaran mungkin telah kadaluarsa atau dibatalkan.',
                    ),
                    const Divider(height: 24),
                    _buildInfoItem(
                      Icons.shopping_cart_outlined,
                      'Silakan ulangi pemesanan atau pilih metode pembayaran lain.',
                    ),
                  ],
                ),
              ),

              const Spacer(),
              // Secondary action button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton(
                  onPressed: () {
                    // Navigate back to home page
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
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 22,
          color: Colors.grey.shade700,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade800,
            ),
          ),
        ),
      ],
    );
  }
}
