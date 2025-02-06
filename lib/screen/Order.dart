import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:marketplace_logamas/function/Utils.dart';
import 'package:marketplace_logamas/widget/Timer.dart';
import 'package:http/http.dart' as http;

class OrdersPage extends StatefulWidget {
  const OrdersPage({Key? key}) : super(key: key);

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> pendingOrders = [];
  List<Map<String, dynamic>> readyToPickupOrders = [];
  List<Map<String, dynamic>> completedOrders = [];
  bool isLoading = true;

  Future<List<Map<String, dynamic>>> fetchTransactionsByStatus(
      int status) async {
    try {
      final response = await http.get(
        Uri.parse(
            '$apiBaseUrl/transactions?payment_status=$status'), // ✅ Memperbaiki query parameter
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to fetch data: ${response.statusCode}');
      }

      final Map<String, dynamic> data = jsonDecode(response.body);
      print(data);

      if (data.containsKey('data') && data['data'] is Map<String, dynamic>) {
        final transactions = data['data']['data'];
        if (transactions is List) {
          return transactions.cast<Map<String, dynamic>>();
        }
      }

      return [];
    } catch (e) {
      print('Error fetching transactions: $e');
      return [];
    }
  }

  Future<void> _loadOrders() async {
    setState(() => isLoading = true);

    try {
      final pending = await fetchTransactionsByStatus(0); // Belum Bayar
      final readyToPickup = await fetchTransactionsByStatus(1); // Siap Ambil
      final completed =
          await fetchTransactionsByStatus(2); // Sudah Diambil (Done)

      setState(() {
        pendingOrders = pending;
        readyToPickupOrders = readyToPickup;
        completedOrders = completed;
      });
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadOrders();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Pesanan Saya',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          onPressed: () => context.go('/information'),
          icon: const Icon(
            Icons.arrow_back,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF31394E),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFC58189),
          labelColor: const Color(0xFFC58189),
          unselectedLabelColor: Colors.white,
          tabs: const [
            Tab(text: 'Belum Bayar 💳'),
            Tab(text: 'Siap Ambil 🏬'),
            Tab(text: 'Selesai ✅'),
          ],
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOrderList(pendingOrders),
                _buildOrderList(readyToPickupOrders),
                _buildOrderList(completedOrders),
              ],
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.note_alt_outlined,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          const Text(
            'Belum ada pesanan',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderList(List<Map<String, dynamic>> orders) {
    if (orders.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final order = orders[index];
        final products = order['transaction_products'] ?? [];
        final expirationTime = order['expired_at'] != null
            ? DateTime.tryParse(order['expired_at'])
            : null;

        // Calculate subTotal, totalPrice, discount, and tax
        double subTotal =
            double.tryParse(order['sub_total_price'].toString()) ?? 0;
        double totalPrice =
            double.tryParse(order['total_price'].toString()) ?? 0;
        double taxPrice = double.tryParse(order['tax_price'].toString()) ?? 0;
        // Calculate voucher discount from (sub_total_price + tax) - total_price
        double discount = (subTotal + taxPrice) - totalPrice;
        int pointsEarned = order['poin_earned'] ?? 0;
        double tax = double.tryParse(order['tax_price']) ?? 0;
        double taxPercentage = (subTotal > 0) ? (taxPrice / subTotal) * 100 : 0;
        print(tax);

        return Card(
          margin: const EdgeInsets.only(bottom: 16.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: 3,
          child: InkWell(
            onTap: () {
              context.push('/detail/${order['id']}');
            },
            child: Column(
              children: [
                // Header
                Container(
                  decoration: BoxDecoration(
                    color: order['status'] == 0
                        ? const Color(0xFFFDE7E9) // Belum Bayar: Merah Muda
                        : const Color(0xFFE8F5E9), // Siap Ambil: Hijau Muda
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(10),
                    ),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        order['store']?['store_name'] ?? 'Toko Tidak Diketahui',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      if (order['status'] == 1)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF81C784),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Siap Diambil',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      if (order['status'] == 2)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF81C784),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Done',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      if (order['status'] == 0 && expirationTime != null)
                        CountdownTimer(expirationTime),
                    ],
                  ),
                ),

                // Body
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ...products.map((product) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${product['product_code']['product']['name']} (${product['weight']}g)',
                              ),
                              Text(
                                'Rp ${formatCurrency(double.tryParse(product['total_price'].toString()) ?? 0)}',
                                style: const TextStyle(fontSize: 14),
                              ),
                            ],
                          ),
                        );
                      }).toList(),

                      const Divider(height: 16, thickness: 1),

                      // Harga Sebelum Voucher
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Harga Sebelum Voucher',
                            style: TextStyle(fontSize: 14),
                          ),
                          Text(
                            'Rp ${formatCurrency(subTotal)}',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),

                      // Potongan Voucher (Tampil jika > 0)
                      if (discount > 0)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Potongan Voucher',
                              style:
                                  TextStyle(fontSize: 14, color: Colors.green),
                            ),
                            Text(
                              '-Rp ${formatCurrency(discount)}',
                              style: const TextStyle(
                                  fontSize: 14, color: Colors.green),
                            ),
                          ],
                        ),

                      if (tax > 0)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Tax (${taxPercentage.toStringAsFixed(1)}%)',
                              style:
                                  TextStyle(fontSize: 14, color: Colors.black),
                            ),
                            Text(
                              'Rp ${formatCurrency(tax)}',
                              style: const TextStyle(
                                  fontSize: 14, color: Colors.black),
                            ),
                          ],
                        ),

                      // Poin Earned (Tampil jika > 0)
                      if (pointsEarned > 0)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Poin Earned',
                              style:
                                  TextStyle(fontSize: 14, color: Colors.blue),
                            ),
                            Text(
                              '$pointsEarned Poin',
                              style: const TextStyle(
                                  fontSize: 14, color: Colors.blue),
                            ),
                          ],
                        ),

                      const Divider(height: 16, thickness: 1),

                      // Total Bayar
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total Bayar',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Rp ${formatCurrency(totalPrice)}',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusLabel(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
