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
  List<Map<String, dynamic>> orders = [];
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
      final transactions = await fetchTransactionsByStatus(0); // Status 0
      setState(() {
        orders = transactions;
      });
    } catch (error) {
      print('Error fetching transactions: $error');
    } finally {
      setState(() => isLoading = false);
    }
  }

  final List<Map<String, dynamic>> orders2 = [
    {
      'store_name': 'Toko Emas Indah',
      'status': 0,
      'products': [
        {'name': 'Cincin Emas', 'quantity': 1, 'price': 1500000},
        {'name': 'Kalung Emas', 'quantity': 2, 'price': 2500000},
      ],
      'voucher_discount': 50000,
      'total_payment': 6450000,
      'expiration_time':
          DateTime.now().add(Duration(hours: 1)), // 1 jam dari sekarang
    },
    {
      'store_name': 'Toko Perhiasan Cantik',
      'status': 1,
      'products': [
        {'name': 'Anting Emas', 'quantity': 1, 'price': 750000},
      ],
      'voucher_discount': 0,
      'total_payment': 750000,
    },
    {
      'store_name': 'Toko Berlian Mewah',
      'status': 2,
      'products': [
        {'name': 'Gelang Berlian', 'quantity': 1, 'price': 5000000},
      ],
      'voucher_discount': 100000,
      'total_payment': 4900000,
    },
  ];

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
                _buildOrderList(0),
                _buildOrderList(1),
                _buildOrderList(2),
              ],
            ),
    );
  }

  Widget _buildOrderList(int status) {
    final filteredOrders =
        orders.where((order) => order['payment_status'] == status).toList();

    if (filteredOrders.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: filteredOrders.length,
      itemBuilder: (context, index) {
        final order = filteredOrders[index];
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
                  color: status == 0
                      ? const Color(0xFFFDE7E9) // Belum Bayar: Merah Muda
                      : status == 1
                          ? const Color(0xFFE8F5E9) // Siap Ambil: Hijau Muda
                          : const Color(0xFFE3F2FD), // Done: Biru Muda
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
                    if (status == 0 && expirationTime != null)
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
