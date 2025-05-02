import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:marketplace_logamas/function/Utils.dart';
import 'package:marketplace_logamas/widget/Timer.dart';
import 'package:http/http.dart' as http;

class TradePage extends StatefulWidget {
  const TradePage({Key? key}) : super(key: key);

  @override
  State<TradePage> createState() => _TradePageState();
}

class _TradePageState extends State<TradePage>
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
  bool isSearching = false;
  final FocusNode _searchFocusNode = FocusNode();

  // Define theme colors
  final Color primaryColor = const Color(0xFFC58189);
  final Color secondaryColor = const Color(0xFFFDE7E9);
  final Color accentColor = const Color(0xFF81C784);
  final Color bgColor = const Color(0xFFF5F5F5);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    loadAccessToken().then((_) {
      if (_accessToken != null) {
        _loadOrders();
      }
    });

    _searchFocusNode.addListener(() {
      setState(() {
        isSearching = _searchFocusNode.hasFocus;
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
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

      // Set time filters based on user selection
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

      // Filter by date if a filter is selected
      if (startDate != null) {
        allOrders = allOrders.where((order) {
          DateTime orderDate =
              DateTime.tryParse(order['created_at']) ?? DateTime(2000);
          return orderDate.isAfter(startDate!.subtract(Duration(seconds: 1))) &&
              (endDate == null ||
                  orderDate.isBefore(endDate!.add(Duration(days: 1))));
        }).toList();
      }

      // Filter by product search
      String searchQuery = _searchController.text.trim().toLowerCase();

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

  Future<List<Map<String, dynamic>>> fetchTransactionsByStatus(
      int status) async {
    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/transactions?payment_status=$status&type=3'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_accessToken',
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to fetch data: ${response.statusCode}');
      }

      final Map<String, dynamic> data = jsonDecode(response.body);

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

  Future<void> _selectDateRange(BuildContext context) async {
    DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2022, 1, 1),
      lastDate: DateTime.now(),
      initialDateRange: selectedStartDate != null && selectedEndDate != null
          ? DateTimeRange(start: selectedStartDate!, end: selectedEndDate!)
          : null,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: primaryColor,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        selectedStartDate = picked.start;
        selectedEndDate = picked.end;
        selectedFilter = 3; // Custom Date
        _loadOrders(); // Refresh data after filter selection
      });
    }
  }

  Future<void> _pickStartDate(
      BuildContext context, StateSetter setState) async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedStartDate ?? DateTime.now(),
      firstDate: DateTime(2022, 1, 1),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: primaryColor,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
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
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: primaryColor,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
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
            return Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.3),
                    spreadRadius: 1,
                    blurRadius: 5,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              // Increased height factor to prevent overflow
              child: FractionallySizedBox(
                heightFactor: selectedFilter == 3 ? 0.6 : 0.4,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20.0, vertical: 16.0),
                  // Wrap in SingleChildScrollView to handle potential overflow
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Drawer with notch
                      Center(
                        child: Container(
                          width: 50,
                          height: 5,
                          margin: const EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                      ),

                      // Title with icon
                      Row(
                        children: [
                          Icon(Icons.filter_alt, color: primaryColor, size: 24),
                          const SizedBox(width: 8),
                          Text(
                            'Filter Waktu Transaksi',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Time Filter Dropdown with improved styling
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.1),
                              spreadRadius: 0,
                              blurRadius: 3,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: selectedFilter,
                            isExpanded: true,
                            icon: Icon(Icons.keyboard_arrow_down,
                                color: primaryColor),
                            elevation: 16,
                            borderRadius: BorderRadius.circular(12),
                            items: const [
                              DropdownMenuItem(
                                value: 0,
                                child: Row(
                                  children: [
                                    Icon(Icons.calendar_month,
                                        color: Colors.grey),
                                    SizedBox(width: 8),
                                    Text("Semua Tanggal"),
                                  ],
                                ),
                              ),
                              DropdownMenuItem(
                                value: 1,
                                child: Row(
                                  children: [
                                    Icon(Icons.calendar_today,
                                        color: Colors.blue),
                                    SizedBox(width: 8),
                                    Text("30 Hari Terakhir"),
                                  ],
                                ),
                              ),
                              DropdownMenuItem(
                                value: 2,
                                child: Row(
                                  children: [
                                    Icon(Icons.date_range, color: Colors.green),
                                    SizedBox(width: 8),
                                    Text("90 Hari Terakhir"),
                                  ],
                                ),
                              ),
                              DropdownMenuItem(
                                value: 3,
                                child: Row(
                                  children: [
                                    Icon(Icons.edit_calendar,
                                        color: Colors.orange),
                                    SizedBox(width: 8),
                                    Text("Pilih Tanggal Sendiri"),
                                  ],
                                ),
                              ),
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
                              color: Colors.black87,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Expanded scrollable area for date selection
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Custom Date Range Selection
                              if (selectedFilter == 3)
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  margin: const EdgeInsets.only(bottom: 20),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border:
                                        Border.all(color: Colors.grey.shade300),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.grey.withOpacity(0.1),
                                        spreadRadius: 0,
                                        blurRadius: 3,
                                        offset: Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.date_range,
                                              color: primaryColor, size: 18),
                                          const SizedBox(width: 8),
                                          Text(
                                            "Pilih Rentang Tanggal:",
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black87,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      // Modified date selection layout to better handle overflow
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          // Start date selector
                                          Text(
                                            "Tanggal Mulai:",
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey[700],
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          GestureDetector(
                                            onTap: () => _pickStartDate(
                                                context, setState),
                                            child: Container(
                                              width: double.infinity,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 12,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.grey[50],
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                border: Border.all(
                                                    color:
                                                        Colors.grey.shade300),
                                              ),
                                              child: Row(
                                                children: [
                                                  Icon(Icons.calendar_today,
                                                      size: 16,
                                                      color: primaryColor),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      selectedStartDate != null
                                                          ? "${selectedStartDate!.day} ${_getMonthName(selectedStartDate!.month)} ${selectedStartDate!.year}"
                                                          : "Pilih Tanggal Mulai",
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                        color:
                                                            selectedStartDate !=
                                                                    null
                                                                ? Colors.black87
                                                                : Colors.grey,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),

                                          const SizedBox(height: 16),

                                          // End date selector
                                          Text(
                                            "Tanggal Akhir:",
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey[700],
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          GestureDetector(
                                            onTap: () =>
                                                _pickEndDate(context, setState),
                                            child: Container(
                                              width: double.infinity,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 12,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.grey[50],
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                border: Border.all(
                                                    color:
                                                        Colors.grey.shade300),
                                              ),
                                              child: Row(
                                                children: [
                                                  Icon(Icons.calendar_today,
                                                      size: 16,
                                                      color: primaryColor),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      selectedEndDate != null
                                                          ? "${selectedEndDate!.day} ${_getMonthName(selectedEndDate!.month)} ${selectedEndDate!.year}"
                                                          : "Pilih Tanggal Akhir",
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                        color:
                                                            selectedEndDate !=
                                                                    null
                                                                ? Colors.black87
                                                                : Colors.grey,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),

                                          // Date range visualization
                                          if (selectedStartDate != null &&
                                              selectedEndDate != null)
                                            Container(
                                              margin: const EdgeInsets.only(
                                                  top: 16),
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: primaryColor
                                                    .withOpacity(0.1),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                border: Border.all(
                                                    color: primaryColor
                                                        .withOpacity(0.3)),
                                              ),
                                              child: Row(
                                                children: [
                                                  Icon(Icons.info_outline,
                                                      size: 16,
                                                      color: primaryColor),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      selectedEndDate != null &&
                                                              selectedStartDate !=
                                                                  null
                                                          ? "Rentang waktu: ${selectedEndDate!.difference(selectedStartDate!).inDays + 1} hari"
                                                          : "Pilih kedua tanggal",
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        color: primaryColor,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),

                      // Apply Button with improved styling
                      Container(
                        width: double.infinity,
                        height: 50,
                        margin: const EdgeInsets.only(top: 16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: primaryColor.withOpacity(0.3),
                              spreadRadius: 1,
                              blurRadius: 3,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                            _loadOrders();
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_circle_outline,
                                  color: Colors.white),
                              const SizedBox(width: 8),
                              Text(
                                "Terapkan Filter",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/images/appbar.png'),
              fit: BoxFit.cover,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 5,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.2),
                  Colors.black.withOpacity(0.4),
                ],
              ),
            ),
          ),
        ),
        elevation: 0,
        title: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          height: 45,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(isSearching ? 12 : 25),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: _searchController,
            focusNode: _searchFocusNode,
            onSubmitted: (value) => _loadOrders(),
            style: TextStyle(fontSize: 14),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Cari produk...',
              hintStyle: TextStyle(
                fontSize: 14,
                color: primaryColor.withOpacity(0.7),
              ),
              prefixIcon: Icon(
                Icons.search,
                color: primaryColor,
                size: 20,
              ),
              suffixIcon: _searchController.text.isNotEmpty
                  ? GestureDetector(
                      onTap: () {
                        _searchController.clear();
                        _loadOrders();
                      },
                      child: Icon(
                        Icons.close,
                        color: Colors.grey,
                        size: 18,
                      ),
                    )
                  : null,
              border: InputBorder.none,
              contentPadding:
                  EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            ),
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: Colors.white, size: 22),
          onPressed: () => context.go('/information'),
        ),
        actions: [
          Container(
            margin: EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: Icon(
                Icons.filter_list_rounded,
                color: Colors.white,
                size: 24,
              ),
              onPressed: () => _showFilterDrawer(context),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(kToolbarHeight),
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Colors.white.withOpacity(0.3),
                  width: 1,
                ),
              ),
            ),
            child: Center(
              child: TabBar(
                controller: _tabController,
                indicatorColor: Colors.white,
                indicatorWeight: 3,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white.withOpacity(0.7),
                labelStyle:
                    TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                unselectedLabelStyle:
                    TextStyle(fontWeight: FontWeight.normal, fontSize: 13),
                tabs: [
                  Tab(
                    child: Row(
                      mainAxisAlignment:
                          MainAxisAlignment.center, // Center icon + text
                      mainAxisSize: MainAxisSize.min, // Wrap content size
                      children: [
                        Icon(Icons.payment_outlined, size: 18),
                        SizedBox(width: 6),
                        Flexible(
                          child:
                              Text('Pending', overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.store_outlined, size: 18),
                        SizedBox(width: 6),
                        Flexible(
                          child: Text('Paid', overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_outline, size: 18),
                        SizedBox(width: 6),
                        Flexible(
                          child: Text('Done', overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                    strokeWidth: 3,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Memuat transaksi...',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            )
          : Container(
              color: bgColor,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildOrderList(pendingOrders),
                  _buildOrderList(readyToPickupOrders),
                  _buildOrderList(completedOrders),
                ],
              ),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long,
            size: 100,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Belum ada Tukar Tambah',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tukar Tambah Anda akan muncul di sini',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
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
                DateFormat("dd MMM yyyy • HH:mm").format(parsedDate);
          }
        }

        // Check if this is a trade transaction (has products of different types)
        bool hasBoughtProducts =
            products.any((p) => p['transaction_type'] == 1);
        bool hasSoldProducts = products.any((p) => p['transaction_type'] == 2);
        bool isTradeTransaction = hasBoughtProducts && hasSoldProducts;

        return Container(
          margin: const EdgeInsets.only(bottom: 16.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.15),
                spreadRadius: 1,
                blurRadius: 5,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => context
                    .push('/traded/${order['id']}'), // Changed to traded path
                borderRadius: BorderRadius.circular(16),
                child: Column(
                  children: [
                    // Order Header
                    Container(
                      decoration: BoxDecoration(
                        color: order['status'] == 0
                            ? secondaryColor
                            : order['status'] == 1
                                ? Color(0xFFE8F5E9)
                                : Color(0xFFF0F4FF),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            spreadRadius: 0,
                            blurRadius: 3,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      isTradeTransaction
                                          ? Icons.swap_horiz
                                          : order['status'] == 0
                                              ? Icons.store
                                              : order['status'] == 1
                                                  ? Icons.store
                                                  : Icons.check_circle,
                                      size: 16,
                                      color: isTradeTransaction
                                          ? Colors.orange[700]
                                          : order['status'] == 0
                                              ? primaryColor
                                              : accentColor,
                                    ),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        isTradeTransaction
                                            ? "Trade-in di ${order['store']?['store_name'] ?? 'Toko Tidak Diketahui'}"
                                            : order['store']?['store_name'] ??
                                                'Toko Tidak Diketahui',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: Colors.black87,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.access_time,
                                      size: 14,
                                      color: Colors.black54,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      formattedCreatedAt ??
                                          'Tanggal tidak tersedia',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.black54,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (order['status'] == 0 && expirationTime != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.withOpacity(0.1),
                                    spreadRadius: 0,
                                    blurRadius: 2,
                                    offset: Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: CountdownTimer(expirationTime),
                            ),
                          if (order['status'] == 1)
                            _buildStatusBadge("Siap Diambil", accentColor),
                          if (order['status'] == 2)
                            _buildStatusBadge("Selesai", Colors.blue),
                        ],
                      ),
                    ),

                    // Order Details
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Products List - Now separated into Bought and Sold sections

                          // 🔻 Produk Dibeli oleh Customer (Transaction Type 1)
                          if (hasBoughtProducts) ...[
                            Container(
                              margin: const EdgeInsets.only(bottom: 12.0),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.shopping_cart_outlined,
                                    size: 16,
                                    color: Colors.blue[700],
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Produk yang dibeli',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue[700],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            ..._buildProductsList(
                                products
                                    .where((product) =>
                                        product['transaction_type'] == 1)
                                    .toList(),
                                apiBaseUrlImage),
                          ],

                          // 🔺 Produk Dijual oleh Customer (Transaction Type 2)
                          if (hasSoldProducts) ...[
                            Container(
                              margin:
                                  const EdgeInsets.only(top: 8.0, bottom: 12.0),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.sell_outlined,
                                    size: 16,
                                    color: Colors.green[700],
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Produk yang dijual',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green[700],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            ..._buildProductsList(
                                products
                                    .where((product) =>
                                        product['transaction_type'] == 2)
                                    .toList(),
                                apiBaseUrlImage),
                          ],

                          // Additional Services (Operations)
                          if (operations.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.grey.shade200,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.construction_outlined,
                                        size: 16,
                                        color: Colors.orange[800],
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        "Layanan Tambahan",
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  ...operations.map((operation) {
                                    final double adjustmentPrice =
                                        double.tryParse(
                                                operation['adjustment_price']
                                                        ?.toString() ??
                                                    '0') ??
                                            0;

                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.only(
                                              bottom: 4.0),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                "${operation['name']} (x${operation['unit']})",
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: Colors.black87,
                                                ),
                                              ),
                                              Text(
                                                "Rp ${formatCurrency(double.tryParse(operation['total_price'].toString()) ?? 0)}",
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w500,
                                                  color: Colors.black87,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Only show adjustment if it's not zero
                                        if (adjustmentPrice != 0)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                                left: 16.0, bottom: 4.0),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Text(
                                                  "Adjustment",
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontStyle: FontStyle.italic,
                                                    color: Colors.grey[600],
                                                  ),
                                                ),
                                                Text(
                                                  adjustmentPrice >= 0
                                                      ? "+ Rp ${formatCurrency(adjustmentPrice)}"
                                                      : "- Rp ${formatCurrency(adjustmentPrice.abs())}",
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontStyle: FontStyle.italic,
                                                    color: adjustmentPrice >= 0
                                                        ? Colors.green[700]
                                                        : Colors.red[700],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                      ],
                                    );
                                  }).toList(),
                                ],
                              ),
                            ),
                          ],

                          // Order Summary
                          Container(
                            margin: const EdgeInsets.only(top: 16),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.grey.shade200,
                              ),
                            ),
                            child: Column(
                              children: [
                                // Sub Total
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Subtotal',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    Text(
                                      'Rp ${formatCurrency(subTotal.abs())}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),

                                // Trade-in Fee
                                if (order.containsKey('adjustment_price')) ...[
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.swap_horiz,
                                            size: 14,
                                            color: Colors.orange[700],
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Trade-in Fee',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.orange[700],
                                            ),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        'Rp ${formatCurrency(double.tryParse(order['adjustment_price'].toString()) ?? 0)}',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.orange[700],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],

                                // Tax
                                if (taxPrice > 0) ...[
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Pajak (${taxPercentage.toStringAsFixed(1)}%)',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      Text(
                                        'Rp ${formatCurrency(taxPrice)}',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],

                                // Voucher Discount
                                if (discount > 0) ...[
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.discount_outlined,
                                            size: 14,
                                            color: Colors.green[700],
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Potongan Voucher',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.green[700],
                                            ),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        '-Rp ${formatCurrency(discount)}',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.green[700],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],

                                // Divider
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 8.0),
                                  child: Divider(
                                    color: Colors.grey.shade300,
                                    height: 1,
                                  ),
                                ),

                                // Total
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      isTradeTransaction
                                          ? (totalPrice >= 0
                                              ? 'Total Bayar'
                                              : 'Total Uang Diterima')
                                          : 'Total Bayar',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black,
                                      ),
                                    ),
                                    Text(
                                      'Rp ${formatCurrency(totalPrice.abs())}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: totalPrice >= 0
                                            ? primaryColor
                                            : Colors.green,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // Points Earned
                          if (pointsEarned > 0) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.blue.shade100,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.loyalty_outlined,
                                        size: 16,
                                        color: Colors.blue[700],
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Poin yang Didapat',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.blue[700],
                                        ),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.blue[700],
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '+$pointsEarned Poin',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

// Helper method to build products list
  List<Widget> _buildProductsList(
      List<dynamic> products, String apiBaseUrlImage) {
    return products.asMap().entries.map((entry) {
      final int idx = entry.key;
      final product = entry.value;

      double price = double.tryParse(product['price'].toString()) ?? 0;
      double adjPrice =
          double.tryParse(product['adjustment_price'].toString()) ?? 0;
      double discount = double.tryParse(product['discount'].toString()) ?? 0;
      double totalPrice =
          double.tryParse(product['total_price'].toString()) ?? 0;

      // Check if product_code is null and show "OutSide Product"
      String productName = product['product_code'] != null
          ? product['product_code']['product']['name'] ?? 'Unknown Product'
          : 'OutSide Product';

      return Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          border: idx < products.length - 1
              ? Border(
                  bottom: BorderSide(
                    color: Colors.grey.shade100,
                    width: 1,
                  ),
                )
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product image or icon
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: product['product_code'] != null &&
                            product['product_code']['image'] != null
                        ? Image.network(
                            '$apiBaseUrlImage${product['product_code']['image']}',
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              // Fallback icon if image fails to load
                              return Icon(
                                Icons.shopping_bag_outlined,
                                color: primaryColor,
                                size: 20,
                              );
                            },
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        primaryColor),
                                    value: loadingProgress.expectedTotalBytes !=
                                            null
                                        ? loadingProgress
                                                .cumulativeBytesLoaded /
                                            loadingProgress.expectedTotalBytes!
                                        : null,
                                  ),
                                ),
                              );
                            },
                          )
                        : Icon(
                            Icons.shopping_bag_outlined,
                            color: primaryColor,
                            size: 20,
                          ),
                  ),
                ),
                const SizedBox(width: 12),

                // Product Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        productName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${product['weight']}g',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),

                // Price
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Rp ${formatCurrency(totalPrice.abs())}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: product['transaction_type'] == 2
                            ? Colors.green[700]
                            : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // Additional Product Info (Adjustment & Discount)
            if (adjPrice != 0 || discount > 0)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.grey.shade200,
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    if (adjPrice != 0)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Adjustment Price",
                            style: TextStyle(
                              fontSize: 13,
                              color: adjPrice > 0
                                  ? Colors.blue[700]
                                  : Colors.green[700],
                            ),
                          ),
                          Text(
                            adjPrice > 0
                                ? "+Rp ${formatCurrency(adjPrice)}"
                                : "-Rp ${formatCurrency(adjPrice.abs())}",
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: adjPrice > 0
                                  ? Colors.blue[700]
                                  : Colors.green[700],
                            ),
                          ),
                        ],
                      ),
                    if (adjPrice != 0 && discount > 0) SizedBox(height: 4),
                    if (discount > 0)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Discount",
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.green[700],
                            ),
                          ),
                          Text(
                            "-Rp ${formatCurrency(discount)}",
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Colors.green[700],
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
    }).toList();
  }

  Widget _buildStatusBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            text == "Siap Diambil"
                ? Icons.shopping_bag_outlined
                : Icons.check_circle_outline,
            color: color,
            size: 12,
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
