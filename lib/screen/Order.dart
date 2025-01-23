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
  bool isLoading = true;

  Future<List<Map<String, dynamic>>> fetchTransactionsByStatus(
      int status) async {
    final response = await http.get(
      Uri.parse(
          'http://localhost:3000/api/transactions?payment_status=$status'),
      headers: {
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final transactions = data['data']['data'] as List<dynamic>;
      return transactions.cast<Map<String, dynamic>>();
    } else {
      throw Exception('Failed to load transactions');
    }
  }

  Future<void> _loadOrders() async {
    setState(() => isLoading = true);

    try {
      // Ambil transaksi dengan status 0 dan 1
      final pending = await fetchTransactionsByStatus(0); // Status 0
      final readyToPickup = await fetchTransactionsByStatus(1); // Status 1
      setState(() {
        pendingOrders = pending;
        readyToPickupOrders = readyToPickup;
      });
    } catch (error) {
      print('Error fetching transactions: $error');
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this); // 3 status
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
            Tab(text: 'Done ✅'),
          ],
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOrderList(pendingOrders), // Belum Bayar
                _buildOrderList(readyToPickupOrders), // Siap Ambil
                _buildEmptyState(), // Tab Done (Placeholder)
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
        final products = order['transactionItems'] as List<dynamic>;
        final expirationTime = order['expiration_time'] != null
            ? DateTime.parse(order['expiration_time'])
            : null;

        return Card(
          margin: const EdgeInsets.only(bottom: 16.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: 3,
          child: Column(
            children: [
              // Header
              Container(
                decoration: BoxDecoration(
                  color: order['payment_status'] == 0
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
                      order['store']['store_name'],
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    if (order['payment_status'] == 1)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF81C784), // Hijau muda
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
                    if (order['payment_status'] == 0 && expirationTime != null)
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
                              '${product['product']['name']} (x${product['quantity']})',
                              style: const TextStyle(fontSize: 14),
                            ),
                            Text(
                              'Rp ${formatCurrency(double.parse(product['sub_total']))}',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    const Divider(height: 16, thickness: 1),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total Bayar',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Rp ${formatCurrency(double.parse(order['total_price']))}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
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
}
