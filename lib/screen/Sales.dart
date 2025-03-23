import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:marketplace_logamas/function/Utils.dart';
import 'package:marketplace_logamas/widget/Timer.dart';
import 'package:http/http.dart' as http;

class SalesPage extends StatefulWidget {
  const SalesPage({Key? key}) : super(key: key);

  @override
  State<SalesPage> createState() => _SalesPageState();
}

class _SalesPageState extends State<SalesPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> pendingOrders = [];
  List<Map<String, dynamic>> readyToPickupOrders = [];
  List<Map<String, dynamic>> completedOrders = [];
  String? _accessToken;
  bool isLoading = true;
  TextEditingController _searchController = TextEditingController();
  DateTime? selectedStartDate;
  DateTime? selectedEndDate;
  int selectedFilter = 0; // 0: Semua, 1: 30 Hari, 2: 90 Hari, 3: Custom

  Future<void> _selectDateRange(BuildContext context) async {
    DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2022, 1, 1),
      lastDate: DateTime.now(),
      initialDateRange: selectedStartDate != null && selectedEndDate != null
          ? DateTimeRange(start: selectedStartDate!, end: selectedEndDate!)
          : null,
    );

    if (picked != null) {
      setState(() {
        selectedStartDate = picked.start;
        selectedEndDate = picked.end;
        selectedFilter = 3; // Custom Date
        _loadOrders(); // Refresh data setelah memilih filter
      });
    }
  }

  Future<List<Map<String, dynamic>>> fetchTransactionsByStatus(
      int status) async {
    try {
      print(_accessToken);
      final response = await http.get(
        Uri.parse(
            '$apiBaseUrl/transactions?payment_status=$status&type=2'), // ✅ Memperbaiki query parameter
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_accessToken',
        },
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

  Future<void> loadAccessToken() async {
    try {
      final token = await getAccessToken();
      setState(() {
        _accessToken = token;
      });
    } catch (e) {
      print('Error loading access token or user data: $e');
    }
  }

  Future<void> _loadOrders() async {
    setState(() => isLoading = true);

    try {
      DateTime now = DateTime.now();
      DateTime? startDate;
      DateTime? endDate;

      // Tentukan filter waktu berdasarkan pilihan pengguna
      if (selectedFilter == 1) {
        startDate = now.subtract(const Duration(days: 30));
      } else if (selectedFilter == 2) {
        startDate = now.subtract(const Duration(days: 90));
      } else if (selectedFilter == 3) {
        startDate = selectedStartDate;
        endDate = selectedEndDate;
      }

      List<Map<String, dynamic>> allOrders = [];
      for (int status = 0; status <= 2; status++) {
        final orders = await fetchTransactionsByStatus(status);
        allOrders.addAll(orders);
      }

      // Filter berdasarkan tanggal jika ada filter yang dipilih
      if (startDate != null) {
        allOrders = allOrders.where((order) {
          DateTime orderDate =
              DateTime.tryParse(order['created_at']) ?? DateTime(2000);
          return orderDate.isAfter(startDate!.subtract(Duration(seconds: 1))) &&
              (endDate == null ||
                  orderDate.isBefore(endDate!.add(Duration(days: 1))));
        }).toList();
      }

      // Filter berdasarkan pencarian produk
      String searchQuery = _searchController.text.trim().toLowerCase();
      print("Search Query: $searchQuery");

      if (searchQuery.isNotEmpty) {
        allOrders = allOrders.where((order) {
          final products = order['transaction_products'];

          if (products is List) {
            return products.any((product) {
              if (product is Map<String, dynamic>) {
                final productCode = product['product_code'];
                final productData = productCode is Map<String, dynamic>
                    ? productCode['product']
                    : null;
                final productName = productData is Map<String, dynamic>
                    ? productData['name']
                    : null;

                if (productName is String) {
                  return productName.toLowerCase().contains(searchQuery);
                }
              }
              return false;
            });
          }
          return false;
        }).toList();
      }

      setState(() {
        pendingOrders = allOrders.where((o) => o['status'] == 0).toList();
        readyToPickupOrders = allOrders.where((o) => o['status'] == 1).toList();
        completedOrders = allOrders.where((o) => o['status'] == 2).toList();
      });
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _pickStartDate(
      BuildContext context, StateSetter setState) async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedStartDate ?? DateTime.now(),
      firstDate: DateTime(2022, 1, 1),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        selectedStartDate = picked;
      });
    }
  }

  Future<void> _pickEndDate(BuildContext context, StateSetter setState) async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedEndDate ?? DateTime.now(),
      firstDate: selectedStartDate ?? DateTime(2022, 1, 1),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        selectedEndDate = picked;
      });
    }
  }

  void _selectCustomDate(BuildContext context, StateSetter setState) async {
    await _pickStartDate(context, setState);
    if (selectedStartDate != null) {
      await _pickEndDate(context, setState);
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    loadAccessToken().then((_) {
      if (_accessToken != null) {
        _loadOrders();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showFilterDrawer(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return FractionallySizedBox(
              heightFactor: 0.4, // Setengah layar
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16.0, vertical: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 🔹 Header Drawer
                    Center(
                      child: Container(
                        width: 50,
                        height: 6,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const Text(
                      'Filter Waktu Transaksi',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),

                    // 🔹 Dropdown Filter Waktu
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[100], // Latar belakang dropdown
                        borderRadius:
                            BorderRadius.circular(10), // Membulatkan sudut
                        border:
                            Border.all(color: Colors.grey.shade300, width: 1.5),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12), // Padding dalam container
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: selectedFilter,
                          isExpanded: true,
                          icon: const Icon(Icons.arrow_drop_down,
                              color: Color(0xFFC58189),
                              size: 30), // Icon dropdown modern
                          dropdownColor: Colors.white, // Warna latar dropdown
                          borderRadius: BorderRadius.circular(
                              10), // Membulatkan sudut dropdown
                          items: const [
                            DropdownMenuItem(
                                value: 0, child: Text("📅 Semua Tanggal")),
                            DropdownMenuItem(
                                value: 1, child: Text("🗓 30 Hari Terakhir")),
                            DropdownMenuItem(
                                value: 2, child: Text("📆 90 Hari Terakhir")),
                            DropdownMenuItem(
                                value: 3,
                                child: Text("📍 Pilih Tanggal Sendiri")),
                          ],
                          onChanged: (value) {
                            setState(() {
                              selectedFilter = value!;
                              if (selectedFilter == 3) {
                                _selectCustomDate(context, setState);
                              }
                            });
                          },
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors
                                .black87, // Warna teks lebih gelap untuk kontras
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // 🔹 Jika Custom Date Dipilih, Tampilkan Rentang Tanggal
                    if (selectedFilter == 3)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: Colors.grey.shade300, width: 1.5),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Pilih Rentang Tanggal:",
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // 🔹 Tanggal Mulai
                                GestureDetector(
                                  onTap: () =>
                                      _pickStartDate(context, setState),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[100],
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                          color: Colors.grey.shade300,
                                          width: 1.5),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.calendar_today,
                                            size: 18, color: Color(0xFFC58189)),
                                        const SizedBox(width: 8),
                                        Text(
                                          selectedStartDate != null
                                              ? "${selectedStartDate!.day} ${_getMonthName(selectedStartDate!.month)} ${selectedStartDate!.year}"
                                              : "Pilih Tanggal",
                                          style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const Text(" - "),
                                // 🔹 Tanggal Akhir
                                GestureDetector(
                                  onTap: () => _pickEndDate(context, setState),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[100],
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                          color: Colors.grey.shade300,
                                          width: 1.5),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.calendar_today,
                                            size: 18, color: Color(0xFFC58189)),
                                        const SizedBox(width: 8),
                                        Text(
                                          selectedEndDate != null
                                              ? "${selectedEndDate!.day} ${_getMonthName(selectedEndDate!.month)} ${selectedEndDate!.year}"
                                              : "Pilih Tanggal",
                                          style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                    const Spacer(),

                    // 🔹 Tombol Terapkan
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFC58189),
                        ),
                        onPressed: () {
                          Navigator.pop(context); // Tutup drawer
                          _loadOrders(); // Terapkan filter
                        },
                        child: const Text("Terapkan Filter",
                            style: TextStyle(color: Colors.white)),
                      ),
                    ),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _getMonthName(int month) {
    const months = [
      "",
      "Januari",
      "Februari",
      "Maret",
      "April",
      "Mei",
      "Juni",
      "Juli",
      "Agustus",
      "September",
      "Oktober",
      "November",
      "Desember"
    ];
    return months[month];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor:
            Colors.transparent, // Buat transparan agar gambar terlihat
        flexibleSpace: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/appbar.png', // Ganti dengan path gambar yang sesuai
              fit: BoxFit.cover, // Pastikan gambar memenuhi seluruh AppBar
            ),
            Container(
              color: Colors.black
                  .withOpacity(0.2), // Overlay agar teks tetap terbaca
            ),
          ],
        ),
        title: Padding(
          padding: const EdgeInsets.only(bottom: 10.0),
          child: Row(
            children: [
              Expanded(
                child: TextFormField(
                  autocorrect: false,
                  controller: _searchController,
                  onFieldSubmitted: (value) {
                    _loadOrders(); // Load ulang data berdasarkan pencarian saat Enter ditekan
                  },
                  // focusNode: _textFieldFocusNode,
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Cari Produk...',
                    hintStyle: TextStyle(
                      fontSize: 14,
                      color: Color(0xFFC58189),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.transparent),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.transparent),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    prefixIcon: Icon(
                      Icons.search,
                      color: Color(0xFFC58189),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        leading: IconButton(
          onPressed: () => context.go('/information'),
          icon: const Icon(Icons.arrow_back, color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range, color: Colors.white),
            onPressed: () {
              _showFilterDrawer(context);
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFC58189),
          labelColor: const Color(0xFFC58189),
          unselectedLabelColor: Colors.white,
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'Paid'),
            Tab(text: 'Done ✅'),
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
        final operations = order['TransactionOperation'] ?? [];
        final expirationTime = order['expired_at'] != null
            ? DateTime.tryParse(order['expired_at'])
            : null;

        // Calculate prices
        double subTotal =
            double.tryParse(order['sub_total_price'].toString()) ?? 0;
        double totalPrice =
            double.tryParse(order['total_price'].toString()) ?? 0;
        double taxPrice = double.tryParse(order['tax_price'].toString()) ?? 0;
        double discount = (subTotal + taxPrice) - totalPrice;
        int pointsEarned = order['poin_earned'] ?? 0;
        double taxPercentage = (subTotal > 0) ? (taxPrice / subTotal) * 100 : 0;

        String? formattedCreatedAt;
        if (order['created_at'] != null) {
          DateTime? parsedDate = DateTime.tryParse(order['created_at'])
              ?.toUtc()
              .add(const Duration(hours: 7));
          if (parsedDate != null) {
            formattedCreatedAt =
                DateFormat("dd-MM-yyyy HH:mm").format(parsedDate);
          }
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 16.0),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          elevation: 3,
          child: InkWell(
            onTap: () {
              context.push('/salesd/${order['id']}');
            },
            child: Column(
              children: [
                // 🔹 HEADER PESANAN
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
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order['store']?['store_name'] ??
                                'Toko Tidak Diketahui',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tanggal: $formattedCreatedAt',
                            style: const TextStyle(
                                fontSize: 14, color: Colors.black54),
                          ),
                        ],
                      ),
                      if (order['status'] == 1)
                        _buildStatusLabel(
                            "Siap Diambil", const Color(0xFF81C784)),
                      if (order['status'] == 2)
                        _buildStatusLabel("Selesai", const Color(0xFF81C784)),
                      if (order['status'] == 0 && expirationTime != null)
                        CountdownTimer(expirationTime),
                    ],
                  ),
                ),

                // 🔹 DETAIL PESANAN
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ...products.map((product) {
                        double price =
                            double.tryParse(product['price'].toString()) ?? 0;
                        double adjPrice = double.tryParse(
                                product['adjustment_price'].toString()) ??
                            0;
                        double discount =
                            double.tryParse(product['discount'].toString()) ??
                                0;
                        double totalPrice = double.tryParse(
                                product['total_price'].toString()) ??
                            0;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${product['product_code']['product']['name']} (${product['weight']}g)',
                                      style: const TextStyle(fontSize: 14),
                                      overflow: TextOverflow
                                          .ellipsis, // Handles overflow with ellipsis
                                      maxLines:
                                          1, // Ensures text doesn't wrap to a new line
                                    ),
                                  ),
                                  Text(
                                    'Rp ${formatCurrency(totalPrice)}',
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ],
                              ),
                              // 🔹 Tampilkan Adjustment Price Jika > 0
                              if (adjPrice > 0)
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text("Adjustment Price",
                                        style: TextStyle(
                                            fontSize: 14, color: Colors.blue)),
                                    Text(
                                      "+Rp ${formatCurrency(adjPrice)}",
                                      style: const TextStyle(
                                          fontSize: 14, color: Colors.blue),
                                    ),
                                  ],
                                ),
                              // 🔹 Tampilkan Discount Jika > 0
                              if (discount > 0)
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text("Discount",
                                        style: TextStyle(
                                            fontSize: 14, color: Colors.green)),
                                    Text(
                                      "-Rp ${formatCurrency(discount)}",
                                      style: const TextStyle(
                                          fontSize: 14, color: Colors.green),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        );
                      }).toList(),

                      // 🔹 TAMPILKAN TRANSACTION OPERATIONS (Jika Ada)
                      if (operations.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        const Text(
                          "Additional Service",
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        ...operations.map((operation) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                    "${operation['name']} (x${operation['unit']})"),
                                Text(
                                  "Rp ${formatCurrency(double.tryParse(operation['total_price'].toString()) ?? 0)}",
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ],

                      // 🔹 Tax (Jika Ada)
                      if (taxPrice > 0)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Pajak (${taxPercentage.toStringAsFixed(1)}%)',
                                style: const TextStyle(fontSize: 14)),
                            Text('Rp ${formatCurrency(taxPrice)}',
                                style: const TextStyle(fontSize: 14)),
                          ],
                        ),

                      // 🔹 Poin Earned (Jika Ada)
                      if (pointsEarned > 0)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Poin Earned',
                                style: TextStyle(
                                    fontSize: 14, color: Colors.blue)),
                            Text('$pointsEarned Poin',
                                style: const TextStyle(
                                    fontSize: 14, color: Colors.blue)),
                          ],
                        ),

                      const Divider(height: 16, thickness: 1),

                      // 🔹 Total Bayar
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total Bayar',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
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

// 🔹 Widget Label Status
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
            color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }
}
