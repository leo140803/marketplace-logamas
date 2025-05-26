import 'dart:math';

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
  late Future<List<String>> banners;
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
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return {
        'hargaBeli': data['data']['hargaBeli'],
        'hargaJual': data['data']['hargaJual'],
      };
    } else {
      throw Exception('Failed to fetch gold prices');
    }
  }

  Future<List<String>> fetchBannerImages() async {
    try {
      final response =
          await http.get(Uri.parse('$apiBaseUrlPlatform/api/banner/active'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List banners = data['data'];
        return banners.map<String>((banner) {
          return '$apiBaseUrlPlatform${banner['image_url']}';
        }).toList();
      } else if (response.statusCode == 404) {
        return [];
      } else {
        throw Exception('Failed to load banners');
      }
    } catch (e) {
      // Handle error silently and return empty list
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

      final maxY =
          historicalData.map((e) => e['price']).reduce((a, b) => a > b ? a : b);
      final minY =
          historicalData.map((e) => e['price']).reduce((a, b) => a < b ? a : b);

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF2E2E48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          titlePadding: EdgeInsets.zero,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          insetPadding: EdgeInsets.symmetric(horizontal: 16),
          title: Stack(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF31394E), Color(0xFF2E2E48)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.analytics, color: Color(0xFFC58189)),
                    SizedBox(width: 8),
                    Text(
                      'Gold Price Chart',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    padding: EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
          content: Container(
            height: 450,
            width: double.maxFinite,
            child: Column(
              children: [
                // Legend with improved styling
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      LegendItem(color: Colors.blue, text: 'Harga Beli'),
                      SizedBox(width: 16),
                      LegendItem(color: Colors.red, text: 'Harga Jual'),
                    ],
                  ),
                ),
                SizedBox(height: 16),
                Expanded(
                  child: LineChart(
                    LineChartData(
                      backgroundColor: const Color(0xFF2E2E48),
                      borderData: FlBorderData(
                        show: true,
                        border: Border.all(color: Colors.white24),
                      ),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: true,
                        getDrawingHorizontalLine: (value) {
                          return FlLine(
                            color: Colors.white10,
                            strokeWidth: 1,
                          );
                        },
                        getDrawingVerticalLine: (value) {
                          return FlLine(
                            color: Colors.white10,
                            strokeWidth: 1,
                          );
                        },
                      ),
                      titlesData: FlTitlesData(
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 36,
                            getTitlesWidget: (value, meta) {
                              final date = DateTime.fromMillisecondsSinceEpoch(
                                  value.toInt());
                              final formattedDate =
                                  "${date.day}-${date.month}-${date.year}";

                              if (value == hargaBeliData.first['x'] ||
                                  value == hargaBeliData.last['x'] ||
                                  value ==
                                      hargaBeliData[(hargaBeliData.length / 2)
                                          .floor()]['x']) {
                                return Padding(
                                  padding: EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    formattedDate,
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
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
                            reservedSize: 40,
                            getTitlesWidget: (value, meta) {
                              // Show more interval markers for better readability
                              if (value == minY ||
                                  value == maxY ||
                                  value == minY + (maxY - minY) / 2) {
                                return Padding(
                                  padding: EdgeInsets.only(right: 8),
                                  child: Text(
                                    formatYAxisValue(value.toInt()),
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                );
                              }
                              return Container();
                            },
                          ),
                        ),
                        topTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      lineBarsData: [
                        // Harga Beli with improved styling
                        LineChartBarData(
                          spots: hargaBeliData
                              .map((e) => FlSpot(e['x'], e['y']))
                              .toList(),
                          isCurved: true,
                          barWidth: 3,
                          color: Colors.blue,
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              colors: [
                                Colors.blue.withOpacity(0.4),
                                Colors.transparent
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                          dotData: FlDotData(
                            show: true,
                            getDotPainter: (spot, percent, barData, index) {
                              return FlDotCirclePainter(
                                radius: 3,
                                color: Colors.white,
                                strokeWidth: 2,
                                strokeColor: Colors.blue,
                              );
                            },
                            checkToShowDot: (spot, barData) {
                              // Get index by finding this spot in the data
                              int idx = hargaBeliData.indexWhere((data) =>
                                  data['x'] == spot.x && data['y'] == spot.y);
                              // Only show dots for first, last and middle points
                              return idx == 0 ||
                                  idx == hargaBeliData.length - 1 ||
                                  idx == hargaBeliData.length ~/ 2;
                            },
                          ),
                        ),
                        // Harga Jual with improved styling
                        LineChartBarData(
                          spots: hargaJualData
                              .map((e) => FlSpot(e['x'], e['y']))
                              .toList(),
                          isCurved: true,
                          barWidth: 3,
                          color: Colors.red,
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              colors: [
                                Colors.red.withOpacity(0.4),
                                Colors.transparent
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                          dotData: FlDotData(
                            show: true,
                            getDotPainter: (spot, percent, barData, index) {
                              return FlDotCirclePainter(
                                radius: 3,
                                color: Colors.white,
                                strokeWidth: 2,
                                strokeColor: Colors.red,
                              );
                            },
                            checkToShowDot: (spot, barData) {
                              // Get index by finding this spot in the data
                              int idx = hargaJualData.indexWhere((data) =>
                                  data['x'] == spot.x && data['y'] == spot.y);
                              // Only show dots for first, last and middle points
                              return idx == 0 ||
                                  idx == hargaJualData.length - 1 ||
                                  idx == hargaJualData.length ~/ 2;
                            },
                          ),
                        ),
                      ],
                      lineTouchData: LineTouchData(
                        touchTooltipData: LineTouchTooltipData(
                          tooltipRoundedRadius: 10,
                          tooltipPadding: EdgeInsets.all(8),
                          getTooltipItems: (touchedSpots) {
                            final xValue = touchedSpots.first.x.toInt();
                            final date =
                                DateTime.fromMillisecondsSinceEpoch(xValue);
                            final formattedDate =
                                "${date.day}-${date.month}-${date.year}";

                            return touchedSpots.map((touchedSpot) {
                              final yValue = touchedSpot.y.toInt();
                              final isHargaBeli = touchedSpot.barIndex == 0;

                              return LineTooltipItem(
                                '${isHargaBeli ? "Harga Beli" : "Harga Jual"}\n'
                                'Date: $formattedDate\n'
                                'Price: Rp $yValue',
                                TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              );
                            }).toList();
                          },
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
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                    child: FutureBuilder<List<String>>(
                      future: banners,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return shimmerBanner();
                        } else if (snapshot.hasError ||
                            !snapshot.hasData ||
                            snapshot.data!.isEmpty) {
                          return SizedBox.shrink();
                        } else {
                          final bannerImages = snapshot.data!;
                          return Column(
                            children: [
                              Container(
                                height: 180,
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
                                      return Container(
                                        decoration: BoxDecoration(
                                          image: DecorationImage(
                                            image: NetworkImage(
                                                bannerImages[index]),
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),

                              // Banner indicators
                              if (bannerImages.length > 1)
                                Padding(
                                  padding: const EdgeInsets.only(top: 10),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: List.generate(
                                        bannerImages.length,
                                        (index) => AnimatedContainer(
                                              duration: const Duration(
                                                  milliseconds: 300),
                                              width:
                                                  _currentBannerIndex == index
                                                      ? 20
                                                      : 8,
                                              height: 8,
                                              margin:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 4),
                                              decoration: BoxDecoration(
                                                color: _currentBannerIndex ==
                                                        index
                                                    ? const Color(0xFFC58189)
                                                    : Colors.grey[300],
                                                borderRadius:
                                                    BorderRadius.circular(5),
                                              ),
                                            )),
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
                    height: 190, // Slightly taller for better visibility
                    child: FutureBuilder<List<Map<String, dynamic>>>(
                      future: followedStores,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20.0, vertical: 10),
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: 3,
                              itemBuilder: (context, index) {
                                return shimmerStoreCard();
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
                                    // Navigate to discover stores page
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
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16.0, vertical: 10),
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
                                    width: MediaQuery.of(context).size.width *
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
                                            height: 180,
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

                                        // Gradient Overlay for text legibility
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
                            } else if (snapshot.hasError || !snapshot.hasData) {
                              return Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(
                                    'Failed to load prices',
                                    style: TextStyle(color: Colors.white70),
                                  ),
                                ),
                              );
                            } else {
                              final hargaBeli =
                                  snapshot.data!['hargaBeli'] ?? '-';
                              final hargaJual =
                                  snapshot.data!['hargaJual'] ?? '-';

                              return Row(
                                children: [
                                  Expanded(
                                    child: Container(
                                      padding: EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                            color:
                                                Colors.blue.withOpacity(0.3)),
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
                                                  color: Colors.red
                                                      .withOpacity(0.2),
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
                            }
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
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Product Grid
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                  sliver: FutureBuilder<List<Map<String, dynamic>>>(
                    future: futureProducts,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return SliverGrid(
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: 0.68,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => shimmerProductCard(),
                            childCount: 6,
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
                            crossAxisCount: 2,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 16,
                            childAspectRatio: 0.68,
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
                                // Keep ProductCard as is per your request
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
