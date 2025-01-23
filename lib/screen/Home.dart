import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:marketplace_logamas/widget/BottomNavigationBar.dart';
import 'package:marketplace_logamas/widget/CategoryCard.dart';
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

class _HomePageWidgetState extends State<HomePageWidget> {
  TextEditingController lowPriceController = TextEditingController();
  TextEditingController highPriceController = TextEditingController();
  final TextEditingController _textController = TextEditingController();
  final FocusNode _textFieldFocusNode = FocusNode();
  final PageController _pageController = PageController();
  List<dynamic> products = [];
  int _selectedIndex = 0;
  String _userName = '';

  late Future<List<Map<String, dynamic>>> followedStores;

  //variable to save banner
  late Future<List<String>> banners;

  //variable gold price
  late Future<Map<String, String>> goldPrices;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    getAccessToken();
    _getUserName();
    banners = fetchBannerImages();
    goldPrices = fetchGoldPrices();
    followedStores = fetchFollowedStores();
    fetchProducts();
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

  Future<void> fetchProducts() async {
    try {
      final response = await http.get(Uri.parse('$apiBaseUrl/products'));
      print(jsonDecode(response.body));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body)['data'];
        setState(() {
          products = data;
        });
      } else {
        throw Exception('Failed to load products');
      }
    } catch (e) {
      throw Exception('Failed to fetch Product Data');
    }
  }

  Future<Map<String, String>> fetchGoldPrices() async {
    final response = await http.get(Uri.parse('$apiBaseUrl/goldprice/now'));
    print(jsonDecode(response.body));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      print(data['data']);
      return {
        'hargaBeli': data['data']['hargaBeli'],
        'hargaJual': data['data']['hargaJual'],
      };
    } else {
      throw Exception('Failed to fetch gold prices');
    }
  }

  Future<List<Map<String, dynamic>>> fetchCategories() async {
    try {
      final response = await http.get(Uri.parse('$apiBaseUrl/categories'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body)['data'] as List;
        return data
            .map((category) => category as Map<String, dynamic>)
            .toList();
      } else {
        throw Exception('Failed to fetch categories');
      }
    } catch (e) {
      print('Error fetching categories: $e');
      return [];
    }
  }

  Future<List<String>> fetchBannerImages() async {
    print('masuk sini lah');
    final response =
        await http.get(Uri.parse('$apiBaseUrlPlatform/api/banner/active'));
    print(jsonDecode(response.body));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List banners = data['data'];
      return banners.map<String>((banner) {
        return '$apiBaseUrlPlatform${banner['image_url']}';
      }).toList();
    } else if (response.statusCode == 404) {
      return [];
    } else {
      dialog(context, 'Error', 'Failed to Fetch Banner Data');
      throw Exception('Failed to load banners');
    }
  }

  Future<List<Map<String, dynamic>>> fetchFollowedStores() async {
    try {
      // Dapatkan token dari getAccessToken()
      final token = await getAccessToken();

      // Kirim permintaan HTTP dengan Authorization Bearer Token
      final response = await http.get(
        Uri.parse('$apiBaseUrl/follow'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      print(json.decode(response.body));
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
      // Re-fetch data to reload the page
      banners = fetchBannerImages();
      goldPrices = fetchGoldPrices();
      followedStores = fetchFollowedStores();
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _textFieldFocusNode.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    navigate(context, index);
  }

  void showGoldPriceChart(BuildContext context) async {
    try {
      final historicalData = await fetchHistoricalGoldPrices();

      final hargaBeliData = historicalData
          .where((item) => item['type'] == 0)
          .map((item) => {
                'x': item['scraped_at'].millisecondsSinceEpoch.toDouble(),
                'y': item['price'].toDouble(),
                'date': item['scraped_at'], // Simpan tanggal untuk tooltip
              })
          .toList();

      final hargaJualData = historicalData
          .where((item) => item['type'] == 1)
          .map((item) => {
                'x': item['scraped_at'].millisecondsSinceEpoch.toDouble(),
                'y': item['price'].toDouble(),
                'date': item['scraped_at'], // Simpan tanggal untuk tooltip
              })
          .toList();

      // Cari nilai max dan min untuk Y axis
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
          titlePadding: EdgeInsets.zero, // Hilangkan padding default title
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          insetPadding: EdgeInsets.symmetric(horizontal: 16),
          title: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Gold Price Chart',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 24,
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
                // Tambahkan legend
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    LegendItem(color: Colors.blue, text: 'Harga Beli'),
                    SizedBox(width: 16),
                    LegendItem(color: Colors.red, text: 'Harga Jual'),
                  ],
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
                      gridData: FlGridData(show: false), // Hilangkan grid
                      titlesData: FlTitlesData(
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 36, // Ukuran ruang label
                            getTitlesWidget: (value, meta) {
                              final date = DateTime.fromMillisecondsSinceEpoch(
                                  value.toInt());
                              final formattedDate =
                                  "${date.day}-${date.month}-${date.year}";

                              if (value == hargaBeliData.first['x']) {
                                // Label pertama
                                return Padding(
                                  padding: EdgeInsets.only(top: 8.0, right: 30),
                                  child: Text(
                                    formattedDate,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                );
                              } else if (value == hargaBeliData.last['x']) {
                                // Label terakhir dengan padding kanan
                                return Padding(
                                  padding:
                                      EdgeInsets.only(top: 8.0, right: 16.0),
                                  child: Text(
                                    formattedDate,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                );
                              }
                              return Container(); // Kosongkan untuk nilai lain
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 40,
                            getTitlesWidget: (value, meta) {
                              if (value == minY || value == maxY) {
                                return Text(
                                  formatYAxisValue(
                                      value.toInt()), // Format Y-axis
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 10),
                                );
                              }
                              return Container(); // Kosongkan untuk nilai lain
                            },
                          ),
                        ),
                        topTitles: AxisTitles(
                          sideTitles: SideTitles(
                              showTitles: false), // Hilangkan label atas
                        ),
                        rightTitles: AxisTitles(
                          sideTitles: SideTitles(
                              showTitles: false), // Hilangkan label kanan
                        ),
                      ),
                      lineBarsData: [
                        // Harga Beli
                        LineChartBarData(
                          spots: hargaBeliData
                              .map((e) => FlSpot(e['x'], e['y']))
                              .toList(),
                          isCurved: true,
                          barWidth: 4,
                          color: Colors.blue,
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              colors: [
                                Colors.blue.withOpacity(0.3),
                                Colors.transparent
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                          dotData: FlDotData(show: true),
                        ),
                        // Harga Jual
                        LineChartBarData(
                          spots: hargaJualData
                              .map((e) => FlSpot(e['x'], e['y']))
                              .toList(),
                          isCurved: true,
                          barWidth: 4,
                          color: Colors.red,
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              colors: [
                                Colors.red.withOpacity(0.3),
                                Colors.transparent
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                          dotData: FlDotData(show: true),
                        ),
                      ],
                      lineTouchData: LineTouchData(
                        touchTooltipData: LineTouchTooltipData(
                          tooltipRoundedRadius: 10,
                          tooltipPadding: EdgeInsets.all(8),
                          getTooltipColor: (touchedSpot) {
                            return Color(0xFFC58189).withOpacity(0.5);
                          },
                          getTooltipItems: (touchedSpots) {
                            final xValue = touchedSpots.first.x.toInt();
                            final date =
                                DateTime.fromMillisecondsSinceEpoch(xValue);
                            final formattedDate =
                                "${date.day}-${date.month}-${date.year}";

                            return touchedSpots.map((touchedSpot) {
                              final yValue = touchedSpot.y.toInt();

                              return LineTooltipItem(
                                'Date: $formattedDate\nPrice: $yValue',
                                TextStyle(
                                  color: Colors.white, // Warna teks tooltip
                                  fontWeight: FontWeight.bold,
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
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text('Error'),
          content: Text('Failed to fetch historical gold prices'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Close'),
            ),
          ],
        ),
      );
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
                SliverAppBar(
                  pinned: true,
                  floating: true,
                  backgroundColor: Color(0xFF31394E),
                  automaticallyImplyLeading: false,
                  toolbarHeight: 80,
                  title: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                    child: Row(
                      children: [
                        Expanded(
                            child: TextFormField(
                          controller: _textController,
                          focusNode: _textFieldFocusNode,
                          autocorrect: false,
                          readOnly:
                              false, // Sekarang pengguna dapat mengetik di dalam field
                          onFieldSubmitted: (value) {
                            // Ketika pengguna menekan Enter, arahkan ke halaman pencarian
                            if (value.trim().isNotEmpty) {
                              context.push('/search-result',
                                  extra: {'query': value});
                            }
                          },
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: 'Search Product...',
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
                        )),
                      ],
                    ),
                  ),
                  actions: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(0, 0, 10, 10),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          IconButton(
                            icon: Icon(
                              Icons.shopping_cart_outlined,
                              color: Colors.white,
                            ),
                            onPressed: () {
                              getAccessToken();
                              context.push('/cart');
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                  centerTitle: false,
                  elevation: 0,
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                    child: Text(
                      'Hello, $_userName👋',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(height: 8),
                ),
                SliverToBoxAdapter(
                  child: FutureBuilder<List<String>>(
                    future: banners,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return SizedBox(
                          height: 200,
                          child: Center(child: CircularProgressIndicator()),
                        );
                      } else if (snapshot.hasError ||
                          !snapshot.hasData ||
                          snapshot.data!.isEmpty) {
                        return SizedBox.shrink();
                      } else {
                        final bannerImages = snapshot.data!;
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20.0),
                          child: SizedBox(
                            height: 200,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: bannerImages.length,
                              itemBuilder: (context, index) {
                                return Container(
                                  width:
                                      MediaQuery.of(context).size.width * 0.7,
                                  margin: EdgeInsets.only(right: 8),
                                  decoration: BoxDecoration(
                                    image: DecorationImage(
                                      image: NetworkImage(bannerImages[index]),
                                      fit: BoxFit.fill,
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                    child: Text(
                      'Followed Stores',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(height: 8),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 150,
                    child: FutureBuilder<List<Map<String, dynamic>>>(
                      future: followedStores,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return SizedBox(
                            height: 150,
                            child: Center(child: CircularProgressIndicator()),
                          );
                        } else if (snapshot.hasError ||
                            !snapshot.hasData ||
                            snapshot.data!.isEmpty) {
                          return Center(
                              child: Text('No followed stores found'));
                        } else {
                          final stores = snapshot.data!;
                          return Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 20.0),
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: stores.length,
                              itemBuilder: (context, index) {
                                final store = stores[index];
                                return GestureDetector(
                                  onTap: () {
                                    final storeId = store['store'][
                                        'store_id']; // Ambil store_id dari store
                                    context.push(
                                      '/store/$storeId', // Gunakan storeId sebagai bagian dari path
                                    );
                                  },
                                  child: Container(
                                    width:
                                        MediaQuery.of(context).size.width * 0.7,
                                    margin: EdgeInsets.only(right: 8),
                                    decoration: BoxDecoration(
                                      image: DecorationImage(
                                        image: NetworkImage(
                                          "https://picsum.photos/200/200?random=${Random().nextInt(1000)}",
                                          // "$apiBaseUrlImage${store['store']['image_url']}",
                                        ),
                                        fit: BoxFit.cover,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Stack(
                                      children: [
                                        Positioned(
                                          bottom: 0,
                                          left: 0,
                                          right: 0,
                                          child: Container(
                                            padding: EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: Colors.black
                                                  .withOpacity(0.35),
                                              borderRadius:
                                                  BorderRadius.vertical(
                                                bottom: Radius.circular(10),
                                              ),
                                            ),
                                            child: Text(
                                              store['store']['store_name'],
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                              textAlign: TextAlign.center,
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
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Gold Price',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color:
                                Color(0xFF2E2E48), // Warna background lingkaran
                          ),
                          child: IconButton(
                            icon:
                                Icon(Icons.line_axis, color: Color(0xFFC58189)),
                            onPressed: () {
                              // Panggil fungsi untuk menampilkan chart pergerakan harga emas
                              showGoldPriceChart(context);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(height: 8),
                ),
                SliverToBoxAdapter(
                  child: FutureBuilder<Map<String, String>>(
                    future: goldPrices,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              shimmerBox(),
                              shimmerBox(),
                            ],
                          ),
                        );
                      } else if (snapshot.hasError || !snapshot.hasData) {
                        return Center(child: Text('Failed to load prices'));
                      } else {
                        final hargaBeli = snapshot.data!['hargaBeli'] ?? '-';
                        final hargaJual = snapshot.data!['hargaJual'] ?? '-';
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              priceBox(
                                  'Harga Jual', hargaJual, Color(0xFFC58189)),
                              priceBox(
                                  'Harga Beli', hargaBeli, Color(0xFFC58189)),
                              // IconButton(
                              //   icon: Icon(Icons.show_chart,
                              //       color: Color(0xFFC58189)),
                              //   onPressed: () => showGoldPriceChart(context),
                              // ),
                            ],
                          ),
                        );
                      }
                    },
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
                    child: Text(
                      'For $_userName🫶',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(height: 2),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 0.65,
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

  Widget _buildCategoryBox({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        decoration: BoxDecoration(
          color: isSelected ? Color(0xFFC58189) : Colors.grey[200],
          borderRadius: BorderRadius.circular(10.0),
          border: Border.all(
            color: isSelected ? Color(0xFFC58189) : Colors.grey.shade300,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // Widget Box Placeholder Shimmer
  Widget shimmerBox() {
    return Expanded(
      flex: 1,
      child: Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: 8),
          height: 100,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterOption({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      splashColor: Colors.grey[200],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: Colors.blueGrey, size: 24),
            SizedBox(width: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
