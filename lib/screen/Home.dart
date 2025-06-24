import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:marketplace_logamas/widget/BottomNavigationBar.dart';
import 'package:marketplace_logamas/widget/Dialog.dart';
import 'package:marketplace_logamas/widget/Legend.dart';
import 'package:marketplace_logamas/widget/PriceBox.dart';
import 'package:marketplace_logamas/widget/ProductCard.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:marketplace_logamas/function/Utils.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shimmer/shimmer.dart';

class HomePageWidget extends StatefulWidget {
  const HomePageWidget({Key? key}) : super(key: key);

  @override
  State<HomePageWidget> createState() => _HomePageWidgetState();
}

class _HomePageWidgetState extends State<HomePageWidget>
    with SingleTickerProviderStateMixin {
  TextEditingController lowPriceController = TextEditingController();
  TextEditingController highPriceController = TextEditingController();
  final TextEditingController _textController = TextEditingController();
  final FocusNode _textFieldFocusNode = FocusNode();
  final PageController _pageController = PageController();
  List<dynamic> products = [];
  int _selectedIndex = 0;
  String _userName = '';
  late AnimationController _animationController;
  late Animation<double> _animation;
  int _currentBannerIndex = 0;
  Timer? _bannerTimer;
  late Future<List<Map<String, dynamic>>> futureProducts;

  late Future<List<Map<String, dynamic>>> followedStores;
  late Future<List<Map<String, dynamic>>> banners;
  late Future<Map<String, String>> goldPrices;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    // Setup animation for welcome text
    _animationController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();

    getAccessToken();
    _getUserName();
    banners = fetchBannerImages();
    goldPrices = fetchGoldPrices();
    goldPrices.then((data) {
      print('Harga Beli: ${data['hargaBeli']}');
      print('Harga Jual: ${data['hargaJual']}');
    }).catchError((e) {
      print('Gagal ambil harga emas: $e');
    });
    followedStores = fetchFollowedStores();
    futureProducts = fetchProducts();

    // Delay starting banner timer to ensure PageController is ready
    Future.delayed(Duration(milliseconds: 300), () {
      _startBannerTimer();
    });
  }

  void _startBannerTimer() {
    _bannerTimer?.cancel();
    _bannerTimer = Timer.periodic(Duration(seconds: 5), (timer) {
      banners.then((bannerList) {
        if (bannerList.isNotEmpty && mounted) {
          setState(() {
            _currentBannerIndex = (_currentBannerIndex + 1) % bannerList.length;
            // Actually move the PageView to the new index
            _pageController.animateToPage(
              _currentBannerIndex,
              duration: Duration(milliseconds: 500),
              curve: Curves.easeInOut,
            );
          });
        }
      });
    });
  }

  String formatYAxisValue(int value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M'; // Jutaan
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K'; // Ribuan
    }
    return value.toString(); // Default
  }

  Future<List<Map<String, dynamic>>> fetchHistoricalGoldPrices() async {
    final response =
        await http.get(Uri.parse('$apiBaseUrl/goldprice/historical'));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return (data['data'] as List).map((item) {
        return {
          'price': item['price'],
          'type': item['type'], // 0: Harga Beli, 1: Harga Jual
          'scraped_at': DateTime.parse(item['scraped_at']),
        };
      }).toList();
    } else {
      throw Exception('Failed to fetch historical gold prices');
    }
  }

  Future<List<Map<String, dynamic>>> fetchProducts() async {
    try {
      final token = await getAccessToken();
      final response = await http.get(
        Uri.parse('$apiBaseUrl/products/recommendation'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body)['data'];
        return data.map((product) => product as Map<String, dynamic>).toList();
      } else {
        throw Exception('Failed to load products');
      }
    } catch (e) {
      print(e);
      throw Exception('Failed to fetch Product Data');
    }
  }

  Future<Map<String, String>> fetchGoldPrices() async {
    final response = await http.get(Uri.parse('$apiBaseUrl/goldprice/now'));
    print(response.statusCode);
    if (response.statusCode == 200) {
      final body = json.decode(response.body);
      final data = body['data'];

      if (data == null ||
          data['hargaBeli'] == null ||
          data['hargaJual'] == null) {
        throw Exception('Field hargaBeli atau hargaJual tidak ditemukan');
      }
      return {
        'hargaBeli': formatCurrency(data['hargaBeli'].toDouble()).toString(),
        'hargaJual': formatCurrency(data['hargaJual'].toDouble()).toString(),
      };
    } else {
      throw Exception('Failed to fetch gold prices');
    }
  }

  Future<List<Map<String, dynamic>>> fetchBannerImages() async {
    try {
      final response =
          await http.get(Uri.parse('$apiBaseUrlPlatform/api/banner/active'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List banners = data['data'];
        return banners.map<Map<String, dynamic>>((banner) {
          return {
            'image_url': '$apiBaseUrlPlatform${banner['image_url']}',
            'title': banner['title'] ?? '',
            'description': banner['description'] ?? '',
          };
        }).toList();
      } else if (response.statusCode == 404) {
        return [];
      } else {
        throw Exception('Failed to load banners');
      }
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchFollowedStores() async {
    try {
      final token = await getAccessToken();
      final response = await http.get(
        Uri.parse('$apiBaseUrl/follow'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body)['data'] as List;
        return data.map((store) => store as Map<String, dynamic>).toList();
      } else {
        throw Exception('Failed to fetch followed stores');
      }
    } catch (e) {
      print('Error fetching followed stores: $e');
      return [];
    }
  }

  Future<void> _getUserName() async {
    String? name = await getUsername();
    setState(() {
      _userName = (name ?? 'Guest').split(" ")[0];
    });
  }

  Future<void> _refreshHomePage() async {
    setState(() {
      banners = fetchBannerImages();
      goldPrices = fetchGoldPrices();
      followedStores = fetchFollowedStores();
      futureProducts = fetchProducts();

      // Reset and restart banner animation
      _currentBannerIndex = 0;
      _startBannerTimer();

      // Show welcome animation again
      _animationController.reset();
      _animationController.forward();
    });

    // Show a snackbar for better UX
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 8),
            Text('Refreshed successfully!'),
          ],
        ),
        backgroundColor: Color(0xFFC58189),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    _textFieldFocusNode.dispose();
    _bannerTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    navigate(context, index);
  }

  void showGoldPriceChart(BuildContext context) async {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Center(
          child: Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Color(0xFF2E2E48),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Color(0xFFC58189)),
                SizedBox(height: 20),
                Text(
                  'Loading chart data...',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final historicalData = await fetchHistoricalGoldPrices();

      // Dismiss loading dialog
      Navigator.of(context).pop();

      final hargaBeliData = historicalData
          .where((item) => item['type'] == 0)
          .map((item) => {
                'x': item['scraped_at'].millisecondsSinceEpoch.toDouble(),
                'y': item['price'].toDouble(),
                'date': item['scraped_at'],
              })
          .toList();

      final hargaJualData = historicalData
          .where((item) => item['type'] == 1)
          .map((item) => {
                'x': item['scraped_at'].millisecondsSinceEpoch.toDouble(),
                'y': item['price'].toDouble(),
                'date': item['scraped_at'],
              })
          .toList();

      hargaBeliData.sort((a, b) => a['x'].compareTo(b['x']));
      hargaJualData.sort((a, b) => a['x'].compareTo(b['x']));

      // =========================
      // Hitung kenaikan harga beli
      // =========================
      final latestBuy = hargaBeliData.last;
      final latestBuyDate =
          (latestBuy['date'] as DateTime).toIso8601String().substring(0, 10);

      Map<String, dynamic>? previousBuy;
      for (var i = hargaBeliData.length - 2; i >= 0; i--) {
        final d = hargaBeliData[i];
        final dDate =
            (d['date'] as DateTime).toIso8601String().substring(0, 10);
        if (dDate != latestBuyDate) {
          previousBuy = d;
          break;
        }
      }

      double increaseBuy = 0;
      if (previousBuy != null) {
        final latest = latestBuy['y'];
        final previous = previousBuy['y'];
        increaseBuy = ((latest - previous) / previous) * 100;
      }

      // =========================
      // Hitung kenaikan harga jual
      // =========================
      final latestSell = hargaJualData.last;
      final latestSellDate =
          (latestSell['date'] as DateTime).toIso8601String().substring(0, 10);

      Map<String, dynamic>? previousSell;
      for (var i = hargaJualData.length - 2; i >= 0; i--) {
        final d = hargaJualData[i];
        final dDate =
            (d['date'] as DateTime).toIso8601String().substring(0, 10);
        if (dDate != latestSellDate) {
          previousSell = d;
          break;
        }
      }

      double increaseSell = 0;
      if (previousSell != null) {
        final latest = latestSell['y'];
        final previous = previousSell['y'];
        increaseSell = ((latest - previous) / previous) * 100;
      }

      // Get current prices
      final buyPrice = latestBuy['y'].toInt();
      final sellPrice = latestSell['y'].toInt();

      final maxY =
          historicalData.map((e) => e['price']).reduce((a, b) => a > b ? a : b);
      final minY =
          historicalData.map((e) => e['price']).reduce((a, b) => a < b ? a : b);

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          titlePadding: EdgeInsets.zero,
          contentPadding: EdgeInsets.zero,
          insetPadding: EdgeInsets.all(16),
          title: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF16213E),
                  Color(0xFF0F3460),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Color(0xFFFFD700).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.analytics_outlined,
                          color: Color(0xFFFFD700),
                          size: 24,
                        ),
                      ),
                      SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Gold Price Chart',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 18,
                            ),
                          ),
                          Text(
                            'Analisis Harga Emas',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: 16,
                  right: 16,
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          content: Container(
            height: 600, // Increased height to accommodate price display
            width: double.maxFinite,
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Color(0xFF1A1A2E),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
            ),
            child: Column(
              children: [
                // Current Prices Display Section
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.08),
                        Colors.white.withOpacity(0.04),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Harga Beli Section
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Color(0xFF4FC3F7).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Icon(
                                  Icons.trending_up,
                                  color: Color(0xFF4FC3F7),
                                  size: 16,
                                ),
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Harga Beli',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8),
                          // Current Buy Price
                          Text(
                            'Rp ${buyPrice.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 6),
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 8, vertical: 6),
                            decoration: BoxDecoration(
                              color: increaseBuy >= 0
                                  ? Color(0xFF4CAF50).withOpacity(0.15)
                                  : Color(0xFFFF5252).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: increaseBuy >= 0
                                    ? Color(0xFF4CAF50).withOpacity(0.3)
                                    : Color(0xFFFF5252).withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  increaseBuy >= 0
                                      ? Icons.arrow_upward
                                      : Icons.arrow_downward,
                                  color: increaseBuy >= 0
                                      ? Color(0xFF4CAF50)
                                      : Color(0xFFFF5252),
                                  size: 14,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  '${increaseBuy.abs().toStringAsFixed(1)}%',
                                  style: TextStyle(
                                    color: increaseBuy >= 0
                                        ? Color(0xFF4CAF50)
                                        : Color(0xFFFF5252),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Perubahan terakhir',
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 10,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(width: 24),
                      Container(
                        width: 1,
                        height: 70,
                        color: Colors.white24,
                      ),
                      SizedBox(width: 24),
                      // Harga Jual Section
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Color(0xFFFF6B6B).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Icon(
                                  Icons.trending_down,
                                  color: Color(0xFFFF6B6B),
                                  size: 16,
                                ),
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Harga Jual',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8),
                          // Current Sell Price
                          Text(
                            'Rp ${sellPrice.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 6),
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 8, vertical: 6),
                            decoration: BoxDecoration(
                              color: increaseSell >= 0
                                  ? Color(0xFF4CAF50).withOpacity(0.15)
                                  : Color(0xFFFF5252).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: increaseSell >= 0
                                    ? Color(0xFF4CAF50).withOpacity(0.3)
                                    : Color(0xFFFF5252).withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  increaseSell >= 0
                                      ? Icons.arrow_upward
                                      : Icons.arrow_downward,
                                  color: increaseSell >= 0
                                      ? Color(0xFF4CAF50)
                                      : Color(0xFFFF5252),
                                  size: 14,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  '${increaseSell.abs().toStringAsFixed(1)}%',
                                  style: TextStyle(
                                    color: increaseSell >= 0
                                        ? Color(0xFF4CAF50)
                                        : Color(0xFFFF5252),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Perubahan terakhir',
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 10,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 20),
                // Chart Legend (Simplified since prices are shown above)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Chart Legend - Simplified
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 16,
                            height: 3,
                            decoration: BoxDecoration(
                              color: Color(0xFF4FC3F7),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Trend Beli',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(width: 20),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 16,
                            height: 3,
                            decoration: BoxDecoration(
                              color: Color(0xFFFF6B6B),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Trend Jual',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Color(0xFF16213E).withOpacity(0.3),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    padding: EdgeInsets.all(16),
                    child: LineChart(
                      LineChartData(
                        backgroundColor: Colors.transparent,
                        borderData: FlBorderData(show: false),
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: true,
                          getDrawingHorizontalLine: (value) {
                            return FlLine(
                              color: Colors.white.withOpacity(0.08),
                              strokeWidth: 1,
                              dashArray: [5, 3],
                            );
                          },
                          getDrawingVerticalLine: (value) {
                            return FlLine(
                              color: Colors.white.withOpacity(0.08),
                              strokeWidth: 1,
                              dashArray: [5, 3],
                            );
                          },
                        ),
                        titlesData: FlTitlesData(
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 40,
                              getTitlesWidget: (value, meta) {
                                final date =
                                    DateTime.fromMillisecondsSinceEpoch(
                                        value.toInt());
                                final formattedDate =
                                    "${date.day}/${date.month}";

                                if (value == hargaBeliData.first['x'] ||
                                    value == hargaBeliData.last['x'] ||
                                    value ==
                                        hargaBeliData[(hargaBeliData.length / 2)
                                            .floor()]['x']) {
                                  return Padding(
                                    padding: EdgeInsets.only(top: 8.0),
                                    child: Container(
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        formattedDate,
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  );
                                }
                                return Container();
                              },
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 50,
                              getTitlesWidget: (value, meta) {
                                if (value == minY ||
                                    value == maxY ||
                                    value == minY + (maxY - minY) / 2) {
                                  return Padding(
                                    padding: EdgeInsets.only(right: 8),
                                    child: Container(
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        formatYAxisValue(value.toInt()),
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  );
                                }
                                return Container();
                              },
                            ),
                          ),
                          topTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          rightTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                        ),
                        lineBarsData: [
                          // Enhanced Harga Beli Line
                          LineChartBarData(
                            spots: hargaBeliData
                                .map((e) => FlSpot(e['x'], e['y']))
                                .toList(),
                            isCurved: true,
                            curveSmoothness: 0.3,
                            barWidth: 3,
                            color: Color(0xFF4FC3F7),
                            belowBarData: BarAreaData(
                              show: true,
                              gradient: LinearGradient(
                                colors: [
                                  Color(0xFF4FC3F7).withOpacity(0.3),
                                  Color(0xFF4FC3F7).withOpacity(0.1),
                                  Colors.transparent,
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                            dotData: FlDotData(
                              show: true,
                              getDotPainter: (spot, percent, barData, index) {
                                return FlDotCirclePainter(
                                  radius: 4,
                                  color: Colors.white,
                                  strokeWidth: 2,
                                  strokeColor: Color(0xFF4FC3F7),
                                );
                              },
                              checkToShowDot: (spot, barData) {
                                int idx = hargaBeliData.indexWhere((data) =>
                                    data['x'] == spot.x && data['y'] == spot.y);
                                return idx == 0 ||
                                    idx == hargaBeliData.length - 1 ||
                                    idx == hargaBeliData.length ~/ 2;
                              },
                            ),
                          ),
                          // Enhanced Harga Jual Line
                          LineChartBarData(
                            spots: hargaJualData
                                .map((e) => FlSpot(e['x'], e['y']))
                                .toList(),
                            isCurved: true,
                            curveSmoothness: 0.3,
                            barWidth: 3,
                            color: Color(0xFFFF6B6B),
                            belowBarData: BarAreaData(
                              show: true,
                              gradient: LinearGradient(
                                colors: [
                                  Color(0xFFFF6B6B).withOpacity(0.3),
                                  Color(0xFFFF6B6B).withOpacity(0.1),
                                  Colors.transparent,
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                            dotData: FlDotData(
                              show: true,
                              getDotPainter: (spot, percent, barData, index) {
                                return FlDotCirclePainter(
                                  radius: 4,
                                  color: Colors.white,
                                  strokeWidth: 2,
                                  strokeColor: Color(0xFFFF6B6B),
                                );
                              },
                              checkToShowDot: (spot, barData) {
                                int idx = hargaJualData.indexWhere((data) =>
                                    data['x'] == spot.x && data['y'] == spot.y);
                                return idx == 0 ||
                                    idx == hargaJualData.length - 1 ||
                                    idx == hargaJualData.length ~/ 2;
                              },
                            ),
                          ),
                        ],
                        lineTouchData: LineTouchData(
                          touchTooltipData: LineTouchTooltipData(
                            tooltipRoundedRadius: 12,
                            tooltipPadding: EdgeInsets.all(12),
                            tooltipBorder: BorderSide(color: Colors.white24),
                            getTooltipItems: (touchedSpots) {
                              final xValue = touchedSpots.first.x.toInt();
                              final date =
                                  DateTime.fromMillisecondsSinceEpoch(xValue);
                              final formattedDate =
                                  "${date.day}/${date.month}/${date.year}";

                              return touchedSpots.map((touchedSpot) {
                                final yValue = touchedSpot.y.toInt();
                                final isHargaBeli = touchedSpot.barIndex == 0;

                                // Format price with comma separator
                                String formatPrice(int price) {
                                  return price.toString().replaceAllMapped(
                                        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                                        (Match m) => '${m[1]},',
                                      );
                                }

                                return LineTooltipItem(
                                  '${isHargaBeli ? "💰 Harga Beli" : "💸 Harga Jual"}\n'
                                  '📅 $formattedDate\n'
                                  '💵 Rp ${formatPrice(yValue)}',
                                  TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                    height: 1.4,
                                  ),
                                );
                              }).toList();
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      dialog(context, 'Chart Error',
          'We couldn\'t load the historical gold price data. Please try again later.');
    }
  }

  Widget _buildLegendItem({
    required Color color,
    required String text,
    required IconData icon,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            icon,
            color: color,
            size: 16,
          ),
        ),
        SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

// Helper function to format price
  String _formatPrice(int price) {
    return price.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: WillPopScope(
        onWillPop: () async => false,
        child: Scaffold(
          backgroundColor: Colors.grey[100],
          body: RefreshIndicator(
            color: Color(0xFFC58189),
            backgroundColor: Color(0xFF31394E),
            strokeWidth: 2,
            onRefresh: _refreshHomePage,
            child: CustomScrollView(
              physics: AlwaysScrollableScrollPhysics(),
              slivers: [
                // Enhanced AppBar
                SliverAppBar(
                  pinned: true,
                  floating: true,
                  backgroundColor: Colors.transparent,
                  automaticallyImplyLeading: false,
                  toolbarHeight: 80,
                  elevation: 0,
                  flexibleSpace: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Background with gradient overlay
                      Image.asset(
                        'assets/images/appbar.png',
                        fit: BoxFit.cover,
                      ),
                      // Gradient overlay for better text visibility
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withOpacity(0.3),
                              Colors.black.withOpacity(0.5),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  title: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                    child: Row(
                      children: [
                        // Enhanced search bar
                        Expanded(
                          child: Container(
                            height: 45,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 5,
                                  offset: Offset(0, 2),
                                )
                              ],
                            ),
                            child: TextFormField(
                              controller: _textController,
                              focusNode: _textFieldFocusNode,
                              autocorrect: false,
                              style: TextStyle(fontSize: 14),
                              onFieldSubmitted: (value) {
                                if (value.trim().isNotEmpty) {
                                  context.push('/search-result',
                                      extra: {'query': value});
                                }
                              },
                              decoration: InputDecoration(
                                isDense: true,
                                hintText: 'Search for gold products...',
                                hintStyle: TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFFC58189).withOpacity(0.7),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderSide:
                                      BorderSide(color: Colors.transparent),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide:
                                      BorderSide(color: Color(0xFFC58189)),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: Colors.white,
                                prefixIcon: Icon(
                                  Icons.search,
                                  color: Color(0xFFC58189),
                                ),
                                suffixIcon: _textController.text.isNotEmpty
                                    ? IconButton(
                                        icon: Icon(Icons.clear,
                                            color: Colors.grey, size: 20),
                                        onPressed: () {
                                          _textController.clear();
                                          setState(() {});
                                        },
                                      )
                                    : null,
                              ),
                              onChanged: (value) {
                                // Rebuild to show/hide clear button
                                setState(() {});
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    // Enhanced cart button
                    Padding(
                      padding: const EdgeInsets.fromLTRB(0, 0, 10, 10),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: Icon(
                                Icons.shopping_cart_outlined,
                                color: Colors.white,
                              ),
                              onPressed: () {
                                getAccessToken();
                                context.push('/cart');
                              },
                            ),
                          ),
                          // Optional: Add a badge indicator for items in cart
                          // This would require cart item count from your API
                        ],
                      ),
                    ),
                  ],
                  centerTitle: false,
                ),

                // Animated Greeting
                SliverToBoxAdapter(
                  child: FadeTransition(
                    opacity: _animation,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                      child: Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFFC58189), Color(0xFFE8C4BD)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.waving_hand_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Hello, $_userName',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Enhanced Banner
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                        MediaQuery.of(context).size.width > 800 ? 40 : 20,
                        12,
                        MediaQuery.of(context).size.width > 800 ? 40 : 20,
                        12),
                    child: FutureBuilder<List<Map<String, dynamic>>>(
                      future: banners,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return Container(
                            height: MediaQuery.of(context).size.width > 800
                                ? 350
                                : 220,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(15),
                              color: Colors.grey[300],
                            ),
                          );
                        } else if (snapshot.hasError ||
                            !snapshot.hasData ||
                            snapshot.data!.isEmpty) {
                          return SizedBox.shrink();
                        } else {
                          final bannerImages = snapshot.data!;
                          return Column(
                            children: [
                              Container(
                                height: MediaQuery.of(context).size.width > 800
                                    ? 500
                                    : 220,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(15),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 8,
                                      offset: Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(15),
                                  child: PageView.builder(
                                    controller: _pageController,
                                    onPageChanged: (index) {
                                      setState(() {
                                        _currentBannerIndex = index;
                                      });
                                    },
                                    itemCount: bannerImages.length,
                                    itemBuilder: (context, index) {
                                      final banner = bannerImages[index];
                                      return GestureDetector(
                                        onTap: () {
                                          showDialog(
                                            context: context,
                                            barrierDismissible: true,
                                            barrierColor:
                                                Colors.black.withOpacity(0.7),
                                            builder: (BuildContext context) {
                                              return Dialog(
                                                backgroundColor:
                                                    Colors.transparent,
                                                insetPadding:
                                                    EdgeInsets.all(20),
                                                child: Container(
                                                  constraints: BoxConstraints(
                                                    maxWidth:
                                                        MediaQuery.of(context)
                                                                    .size
                                                                    .width >
                                                                600
                                                            ? 500
                                                            : double.infinity,
                                                    maxHeight:
                                                        MediaQuery.of(context)
                                                                .size
                                                                .height *
                                                            0.8,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            20),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: Colors.black
                                                            .withOpacity(0.3),
                                                        blurRadius: 20,
                                                        offset: Offset(0, 10),
                                                      ),
                                                    ],
                                                  ),
                                                  child: Column(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      // Header dengan gambar banner
                                                      Container(
                                                        height: 200,
                                                        width: double.infinity,
                                                        decoration:
                                                            BoxDecoration(
                                                          borderRadius:
                                                              BorderRadius.only(
                                                            topLeft:
                                                                Radius.circular(
                                                                    20),
                                                            topRight:
                                                                Radius.circular(
                                                                    20),
                                                          ),
                                                        ),
                                                        child: Stack(
                                                          children: [
                                                            // Banner Image
                                                            ClipRRect(
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .only(
                                                                topLeft: Radius
                                                                    .circular(
                                                                        20),
                                                                topRight: Radius
                                                                    .circular(
                                                                        20),
                                                              ),
                                                              child:
                                                                  CachedNetworkImage(
                                                                imageUrl: banner[
                                                                    'image_url'],
                                                                fit: BoxFit
                                                                    .cover,
                                                                width: double
                                                                    .infinity,
                                                                height: double
                                                                    .infinity,
                                                                errorWidget: (context,
                                                                        url,
                                                                        error) =>
                                                                    Container(
                                                                  decoration:
                                                                      BoxDecoration(
                                                                    gradient:
                                                                        LinearGradient(
                                                                      begin: Alignment
                                                                          .topLeft,
                                                                      end: Alignment
                                                                          .bottomRight,
                                                                      colors: [
                                                                        Color(
                                                                            0xFFC58189),
                                                                        Color(
                                                                            0xFFE8A87C),
                                                                      ],
                                                                    ),
                                                                  ),
                                                                  child: Center(
                                                                    child: Icon(
                                                                      Icons
                                                                          .image_not_supported_outlined,
                                                                      size: 50,
                                                                      color: Colors
                                                                          .white
                                                                          .withOpacity(
                                                                              0.8),
                                                                    ),
                                                                  ),
                                                                ),
                                                              ),
                                                            ),
                                                            // Gradient overlay
                                                            Container(
                                                              decoration:
                                                                  BoxDecoration(
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .only(
                                                                  topLeft: Radius
                                                                      .circular(
                                                                          20),
                                                                  topRight: Radius
                                                                      .circular(
                                                                          20),
                                                                ),
                                                                gradient:
                                                                    LinearGradient(
                                                                  begin: Alignment
                                                                      .topCenter,
                                                                  end: Alignment
                                                                      .bottomCenter,
                                                                  colors: [
                                                                    Colors
                                                                        .transparent,
                                                                    Colors.black
                                                                        .withOpacity(
                                                                            0.3),
                                                                  ],
                                                                ),
                                                              ),
                                                            ),
                                                            // Close button
                                                            Positioned(
                                                              top: 15,
                                                              right: 15,
                                                              child: Container(
                                                                decoration:
                                                                    BoxDecoration(
                                                                  color: Colors
                                                                      .black
                                                                      .withOpacity(
                                                                          0.5),
                                                                  borderRadius:
                                                                      BorderRadius
                                                                          .circular(
                                                                              20),
                                                                ),
                                                                child:
                                                                    IconButton(
                                                                  icon: Icon(
                                                                    Icons.close,
                                                                    color: Colors
                                                                        .white,
                                                                    size: 20,
                                                                  ),
                                                                  onPressed: () =>
                                                                      Navigator.of(
                                                                              context)
                                                                          .pop(),
                                                                  padding:
                                                                      EdgeInsets
                                                                          .all(
                                                                              8),
                                                                  constraints:
                                                                      BoxConstraints(),
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                      // Content
                                                      Flexible(
                                                        child: Padding(
                                                          padding:
                                                              EdgeInsets.all(
                                                                  24),
                                                          child: Column(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            mainAxisSize:
                                                                MainAxisSize
                                                                    .min,
                                                            children: [
                                                              // Title dengan icon
                                                              Row(
                                                                children: [
                                                                  Container(
                                                                    padding:
                                                                        EdgeInsets
                                                                            .all(8),
                                                                    decoration:
                                                                        BoxDecoration(
                                                                      color: Color(
                                                                              0xFFC58189)
                                                                          .withOpacity(
                                                                              0.1),
                                                                      borderRadius:
                                                                          BorderRadius.circular(
                                                                              8),
                                                                    ),
                                                                    child: Icon(
                                                                      Icons
                                                                          .campaign_outlined,
                                                                      color: Color(
                                                                          0xFFC58189),
                                                                      size: 20,
                                                                    ),
                                                                  ),
                                                                  SizedBox(
                                                                      width:
                                                                          12),
                                                                  Expanded(
                                                                    child: Text(
                                                                      banner['title'] ??
                                                                          'Detail Banner',
                                                                      style:
                                                                          TextStyle(
                                                                        fontSize:
                                                                            20,
                                                                        fontWeight:
                                                                            FontWeight.bold,
                                                                        color: Colors
                                                                            .grey[800],
                                                                        height:
                                                                            1.2,
                                                                      ),
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                              SizedBox(
                                                                  height: 16),
                                                              // Description
                                                              if (banner['description'] !=
                                                                      null &&
                                                                  banner['description']
                                                                      .toString()
                                                                      .trim()
                                                                      .isNotEmpty)
                                                                Flexible(
                                                                  child:
                                                                      SingleChildScrollView(
                                                                    child: Text(
                                                                      banner[
                                                                          'description'],
                                                                      style:
                                                                          TextStyle(
                                                                        fontSize:
                                                                            14,
                                                                        color: Colors
                                                                            .grey[600],
                                                                        height:
                                                                            1.5,
                                                                      ),
                                                                    ),
                                                                  ),
                                                                )
                                                              else
                                                                Container(
                                                                  padding:
                                                                      EdgeInsets
                                                                          .all(
                                                                              16),
                                                                  decoration:
                                                                      BoxDecoration(
                                                                    color: Colors
                                                                        .grey[50],
                                                                    borderRadius:
                                                                        BorderRadius.circular(
                                                                            12),
                                                                    border:
                                                                        Border
                                                                            .all(
                                                                      color: Colors
                                                                              .grey[
                                                                          200]!,
                                                                      width: 1,
                                                                    ),
                                                                  ),
                                                                  child: Row(
                                                                    children: [
                                                                      Icon(
                                                                        Icons
                                                                            .info_outline,
                                                                        color: Colors
                                                                            .grey[400],
                                                                        size:
                                                                            20,
                                                                      ),
                                                                      SizedBox(
                                                                          width:
                                                                              12),
                                                                      Expanded(
                                                                        child:
                                                                            Text(
                                                                          'Tidak ada deskripsi untuk banner ini',
                                                                          style:
                                                                              TextStyle(
                                                                            color:
                                                                                Colors.grey[500],
                                                                            fontSize:
                                                                                14,
                                                                            fontStyle:
                                                                                FontStyle.italic,
                                                                          ),
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                ),
                                                              SizedBox(
                                                                  height: 24),
                                                              // Action buttons
                                                              Row(
                                                                children: [
                                                                  Expanded(
                                                                    child:
                                                                        TextButton(
                                                                      onPressed:
                                                                          () =>
                                                                              Navigator.of(context).pop(),
                                                                      style: TextButton
                                                                          .styleFrom(
                                                                        padding:
                                                                            EdgeInsets.symmetric(vertical: 12),
                                                                        shape:
                                                                            RoundedRectangleBorder(
                                                                          borderRadius:
                                                                              BorderRadius.circular(12),
                                                                          side:
                                                                              BorderSide(
                                                                            color:
                                                                                Colors.grey[300]!,
                                                                            width:
                                                                                1,
                                                                          ),
                                                                        ),
                                                                      ),
                                                                      child:
                                                                          Text(
                                                                        'Tutup',
                                                                        style:
                                                                            TextStyle(
                                                                          color:
                                                                              Colors.grey[600],
                                                                          fontSize:
                                                                              16,
                                                                          fontWeight:
                                                                              FontWeight.w500,
                                                                        ),
                                                                      ),
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              );
                                            },
                                          );
                                        },
                                        child: CachedNetworkImage(
                                          imageUrl: banner['image_url'],
                                          fit: BoxFit.cover,
                                          errorWidget: (context, url, error) =>
                                              Container(
                                            decoration: BoxDecoration(
                                              color: Colors.grey[300],
                                              borderRadius:
                                                  BorderRadius.circular(15),
                                            ),
                                            child: Center(
                                              child: Icon(
                                                Icons.image_not_supported,
                                                size: 40,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              if (bannerImages.length > 1)
                                Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: List.generate(
                                      bannerImages.length,
                                      (index) => Container(
                                        width: _currentBannerIndex == index
                                            ? 20
                                            : 8,
                                        height: 8,
                                        margin: const EdgeInsets.symmetric(
                                            horizontal: 4),
                                        decoration: BoxDecoration(
                                          color: _currentBannerIndex == index
                                              ? const Color(0xFFC58189)
                                              : Colors.grey[300],
                                          borderRadius:
                                              BorderRadius.circular(5),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          );
                        }
                      },
                    ),
                  ),
                ),

                // Enhanced Followed Stores Section
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.store,
                              color: Color(0xFFC58189),
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Followed Stores',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Store Cards
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: MediaQuery.of(context).size.width > 800 ? 220 : 190,
                    child: FutureBuilder<List<Map<String, dynamic>>>(
                      future: followedStores,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal:
                                    MediaQuery.of(context).size.width > 800
                                        ? 40.0
                                        : 20.0,
                                vertical: 10),
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: 3,
                              itemBuilder: (context, index) {
                                return Container(
                                  width: MediaQuery.of(context).size.width > 800
                                      ? 300
                                      : MediaQuery.of(context).size.width *
                                          0.65,
                                  margin: EdgeInsets.only(right: 12),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(15),
                                    color: Colors.grey[300],
                                  ),
                                );
                              },
                            ),
                          );
                        } else if (snapshot.hasError ||
                            !snapshot.hasData ||
                            snapshot.data!.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.store_outlined,
                                  color: Colors.grey,
                                  size: 40,
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'No followed stores yet',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 14,
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    context.push('/nearby');
                                  },
                                  child: Text(
                                    'Discover Stores',
                                    style: TextStyle(
                                      color: Color(0xFFC58189),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                )
                              ],
                            ),
                          );
                        } else {
                          final stores = snapshot.data!;
                          return Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal:
                                    MediaQuery.of(context).size.width > 800
                                        ? 40.0
                                        : 16.0,
                                vertical: 10),
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: stores.length,
                              itemBuilder: (context, index) {
                                final store = stores[index];
                                final storeId = store['store']['store_id'];
                                final storeName = store['store']['store_name'];
                                final storeAddress = store['store']
                                        ['address'] ??
                                    "Address not available";
                                final storeLogoUrl =
                                    "$apiBaseUrlImage${store['store']['logo']}";

                                return GestureDetector(
                                  onTap: () {
                                    context.push('/store/$storeId');
                                  },
                                  child: Container(
                                    width: MediaQuery.of(context).size.width >
                                            800
                                        ? 300
                                        : MediaQuery.of(context).size.width *
                                            0.65,
                                    margin: EdgeInsets.only(right: 12),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(15),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black26,
                                          blurRadius: 6,
                                          offset: Offset(2, 4),
                                        ),
                                      ],
                                    ),
                                    child: Stack(
                                      children: [
                                        // Store Image
                                        ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(15),
                                          child: Image.network(
                                            storeLogoUrl,
                                            width: double.infinity,
                                            height: MediaQuery.of(context)
                                                        .size
                                                        .width >
                                                    800
                                                ? 200
                                                : 180,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stackTrace) =>
                                                    Container(
                                              decoration: BoxDecoration(
                                                color: Colors.grey[300],
                                                borderRadius:
                                                    BorderRadius.circular(15),
                                              ),
                                              child: Center(
                                                child: Column(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Icon(Icons.store,
                                                        size: 40,
                                                        color: Colors.grey),
                                                    SizedBox(height: 8),
                                                    Text(
                                                      storeName,
                                                      textAlign:
                                                          TextAlign.center,
                                                      style: TextStyle(
                                                        color: Colors.grey[700],
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),

                                        // Gradient Overlay
                                        Positioned(
                                          bottom: 0,
                                          left: 0,
                                          right: 0,
                                          child: Container(
                                            padding: EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.vertical(
                                                      bottom:
                                                          Radius.circular(15)),
                                              gradient: LinearGradient(
                                                begin: Alignment.topCenter,
                                                end: Alignment.bottomCenter,
                                                colors: [
                                                  Colors.transparent,
                                                  Colors.black.withOpacity(0.7),
                                                ],
                                              ),
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  storeName,
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                    shadows: [
                                                      Shadow(
                                                        offset: Offset(1, 1),
                                                        blurRadius: 2,
                                                        color: Colors.black
                                                            .withOpacity(0.5),
                                                      ),
                                                    ],
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                SizedBox(height: 4),
                                                Row(
                                                  children: [
                                                    Icon(Icons.location_on,
                                                        size: 14,
                                                        color: Colors.white70),
                                                    SizedBox(width: 4),
                                                    Expanded(
                                                      child: Text(
                                                        storeAddress,
                                                        style: TextStyle(
                                                          color: Colors.white70,
                                                          fontSize: 12,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),

                                        // Visit store button
                                        Positioned(
                                          top: 10,
                                          right: 10,
                                          child: Container(
                                            padding: EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Color(0xFFC58189),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black26,
                                                  blurRadius: 4,
                                                  offset: Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            child: Text(
                                              'Visit',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ),

                // Enhanced Gold Price Section
                SliverToBoxAdapter(
                  child: Container(
                    margin: EdgeInsets.fromLTRB(20, 20, 20, 0),
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF31394E), Color(0xFF2E2E48)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.trending_up,
                                    color: Color(0xFFC58189)),
                                SizedBox(width: 8),
                                Text(
                                  'Gold Price',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                // Info tooltip
                                Tooltip(
                                  message: "Gold prices from anekalogam.co.id",
                                  preferBelow: false,
                                  decoration: BoxDecoration(
                                    color: Colors.black87,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  textStyle: TextStyle(
                                      color: Colors.white, fontSize: 12),
                                  padding: EdgeInsets.all(8),
                                  child: Icon(
                                    Icons.info_outline,
                                    color: Colors.white60,
                                    size: 18,
                                  ),
                                ),
                                SizedBox(width: 8),

                                // Chart button
                                GestureDetector(
                                  onTap: () => showGoldPriceChart(context),
                                  child: Container(
                                    padding: EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.white12,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.show_chart,
                                          color: Color(0xFFC58189),
                                          size: 16,
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          'Chart',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        SizedBox(height: 16),

                        // Gold Price Boxes
                        FutureBuilder<Map<String, String>>(
                          future: goldPrices,
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return Row(
                                children: [
                                  Expanded(child: shimmerBox()),
                                  SizedBox(width: 12),
                                  Expanded(child: shimmerBox()),
                                ],
                              );
                            }
                            if (snapshot.hasError) {
                              return Text(
                                'Terjadi kesalahan: ${snapshot.error}',
                                style: TextStyle(color: Colors.redAccent),
                              );
                            }
                            final data = snapshot.data;
                            if (data == null ||
                                data['hargaBeli'] == null ||
                                data['hargaJual'] == null) {
                              return Text(
                                'Data harga tidak tersedia',
                                style: TextStyle(color: Colors.orangeAccent),
                              );
                            }

                            final hargaBeli = data['hargaBeli']!;
                            final hargaJual = data['hargaJual']!;

                            return Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    padding: EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                          color: Colors.blue.withOpacity(0.3)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding: EdgeInsets.all(4),
                                              decoration: BoxDecoration(
                                                color: Colors.blue
                                                    .withOpacity(0.2),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Icon(
                                                Icons.shopping_bag,
                                                color: Colors.blue,
                                                size: 14,
                                              ),
                                            ),
                                            SizedBox(width: 6),
                                            Text(
                                              'Harga Beli',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: 8),
                                        Text(
                                          'Rp $hargaBeli',
                                          style: TextStyle(
                                            fontSize: 18,
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          'per gram',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.white70,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Container(
                                    padding: EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                          color: Colors.red.withOpacity(0.3)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding: EdgeInsets.all(4),
                                              decoration: BoxDecoration(
                                                color:
                                                    Colors.red.withOpacity(0.2),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Icon(
                                                Icons.sell_rounded,
                                                color: Colors.red,
                                                size: 14,
                                              ),
                                            ),
                                            SizedBox(width: 6),
                                            Text(
                                              'Harga Jual',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: 8),
                                        Text(
                                          'Rp $hargaJual',
                                          style: TextStyle(
                                            fontSize: 18,
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          'per gram',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.white70,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                // Enhanced Product Recommendations Section
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Color(0xFFC58189).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.diamond_outlined,
                                color: Color(0xFFC58189),
                                size: 18,
                              ),
                            ),
                            SizedBox(width: 8),
                            Text(
                              'For $_userName',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            SizedBox(width: 4),
                            Icon(
                              Icons.favorite,
                              color: Color(0xFFC58189),
                              size: 16,
                            ),
                            SizedBox(width: 6),
                            Tooltip(
                              message:
                                  'Products similar to items in your wishlist',
                              textStyle: TextStyle(
                                fontSize: 12,
                                color: Colors.white,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black87,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              child: Icon(
                                Icons.info_outline,
                                color: Colors.grey[500],
                                size: 16,
                              ),
                            ),
                          ],
                        ),
                        GestureDetector(
                          onTap: () => context.push('/wishlist'),
                          child: Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Color(0xFFC58189).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Color(0xFFC58189).withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'See Wishlist',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFFC58189),
                                  ),
                                ),
                                SizedBox(width: 4),
                                Icon(
                                  Icons.arrow_forward_ios,
                                  color: Color(0xFFC58189),
                                  size: 12,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Product Grid
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                      MediaQuery.of(context).size.width > 800 ? 40 : 16,
                      16,
                      MediaQuery.of(context).size.width > 800 ? 40 : 16,
                      20),
                  sliver: FutureBuilder<List<Map<String, dynamic>>>(
                    future: futureProducts,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return SliverGrid(
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount:
                                MediaQuery.of(context).size.width > 1200
                                    ? 4
                                    : MediaQuery.of(context).size.width > 800
                                        ? 3
                                        : 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio:
                                MediaQuery.of(context).size.width > 800
                                    ? 0.75
                                    : 0.68,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: Colors.grey[300],
                              ),
                            ),
                            childCount: MediaQuery.of(context).size.width > 1200
                                ? 8
                                : MediaQuery.of(context).size.width > 800
                                    ? 6
                                    : 6,
                          ),
                        );
                      } else if (snapshot.hasError || !snapshot.hasData) {
                        return SliverToBoxAdapter(
                          child: Center(
                            child: Column(
                              children: [
                                Icon(Icons.error_outline,
                                    color: Colors.grey, size: 40),
                                SizedBox(height: 8),
                                Text(
                                  'Failed to load products',
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                                TextButton(
                                  onPressed: _refreshHomePage,
                                  child: Text(
                                    'Retry',
                                    style: TextStyle(color: Color(0xFFC58189)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      } else {
                        final products = snapshot.data!;
                        return SliverGrid(
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount:
                                MediaQuery.of(context).size.width > 1200
                                    ? 8
                                    : MediaQuery.of(context).size.width > 800
                                        ? 5
                                        : 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 16,
                            childAspectRatio:
                                MediaQuery.of(context).size.width > 800
                                    ? 0.75
                                    : 0.68,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final product = products[index];
                              return GestureDetector(
                                onTap: () {
                                  final productId = product['product_id'];
                                  if (productId != null) {
                                    context.push('/product-detail/$productId');
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Product ID is missing'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                },
                                child: ProductCard(product),
                              );
                            },
                            childCount: products.length,
                          ),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: BottomNavBar(
            selectedIndex: _selectedIndex,
            onItemTapped: _onItemTapped,
          ),
        ),
      ),
    );
  }

  // Shimmer loading widget for banner
  Widget shimmerBanner() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        height: 180,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          color: Colors.white,
        ),
      ),
    );
  }

  // Shimmer loading widget for store card
  Widget shimmerStoreCard() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.65,
        margin: EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          color: Colors.white,
        ),
      ),
    );
  }

  // Enhanced shimmer box for price display
  Widget shimmerBox() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[800]!,
      highlightColor: Colors.grey[600]!,
      child: Container(
        height: 80,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: Colors.white12,
        ),
      ),
    );
  }

  // Enhanced shimmer product card
  Widget shimmerProductCard() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 5,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 140,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Container(
                height: 16,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Container(
                height: 16,
                width: 100,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
