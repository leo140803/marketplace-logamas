import 'package:flutter/material.dart';
import 'package:marketplace_logamas/widget/BottomNavigationBar.dart';
import 'package:marketplace_logamas/widget/CategoryCard.dart';
import 'package:marketplace_logamas/widget/Dialog.dart';
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
  int _selectedIndex = 0;
  String _userName = '';
  bool isRingSelected = false;
  bool isNecklaceSelected = false;
  bool isEarringSelected = false;
  bool isBraceletSelected = false;
  bool is24KSelected = false;
  bool is22KSelected = false;
  bool is18KSelected = false;
  bool is14KSelected = false;
  bool isYellowGoldSelected = false;
  bool isWhiteGoldSelected = false;
  bool isRoseGoldSelected = false;

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
  }

  Future<Map<String, String>> fetchGoldPrices() async {
    final response =
        await http.get(Uri.parse('$apiBaseUrl/goldprice/now'));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return {
        'hargaBeli': data['hargaBeli'],
        'hargaJual': data['hargaJual'],
      };
    } else {
      throw Exception('Failed to fetch gold prices');
    }
  }

  Future<List<Map<String, dynamic>>> fetchCategories() async {
    try {
      final response =
          await http.get(Uri.parse('http://127.0.0.1:3000/api/categories'));
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
    final response =
        await http.get(Uri.parse('http://127.0.0.1:3001/api/banner/active'));
    print(response.statusCode);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List banners = data['data'];
      return banners.map<String>((banner) {
        return 'http://127.0.0.1:3000${banner['image_url']}';
      }).toList();
    } else if (response.statusCode == 404) {
      return [];
    } else {
      dialog(context, 'Error', 'Failed to Fetch Banner Data');
      throw Exception('Failed to load banners');
    }
  }

  String _getCategoryEmoji(String categoryName) {
  switch (categoryName) {
    case 'Cincin':
      return '💍';
    case 'Kalung':
      return '📿';
    case 'Anting':
      return '💎';
    case 'Gelang':
      return '🪄';
    default:
      return '❓';
  }
}


  Future<void> _getUserName() async {
    String? name = await getUsername();
    setState(() {
      _userName = (name ?? 'Guest').split(" ")[0];
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

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: WillPopScope(
        onWillPop: () async => false,
        child: Scaffold(
          backgroundColor: Colors.grey[100],
          body: NestedScrollView(
            floatHeaderSlivers: true,
            headerSliverBuilder: (context, _) => [
              SliverAppBar(
                pinned: true,
                floating: true,
                backgroundColor: Color(0xFF31394E),
                automaticallyImplyLeading: false,
                toolbarHeight: 80,
                title: Padding(
                  padding: const EdgeInsets.only(bottom: 10.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _textController,
                          focusNode: _textFieldFocusNode,
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: 'Cari...',
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
                            suffixIcon: IconButton(
                              icon: Icon(Icons.filter_alt),
                              color: Color(0xFFC58189),
                              onPressed: () {
                                _showFilterDrawer(context);
                              },
                            ),
                          ),
                        ),
                      ),
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
                            context.go('/cart');
                            // Navigator.pushReplacementNamed(context, '/cart');
                          },
                        ),
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: Color(0xFFC58189),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '3',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                centerTitle: false,
                elevation: 0,
              ),
            ],
            body: Padding(
              padding: const EdgeInsets.all(20),
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 0, 0),
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
                    child: SizedBox(height: 7),
                  ),
                  SliverToBoxAdapter(
                    child: FutureBuilder<List<String>>(
                      future: banners,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return SizedBox(
                            height: 200,
                            child: Center(child: CircularProgressIndicator()),
                          );
                        } else if (snapshot.hasError ||
                            !snapshot.hasData ||
                            snapshot.data!.isEmpty) {
                          // Jangan tampilkan apa pun jika data kosong atau error
                          return SizedBox.shrink();
                        } else {
                          final bannerImages = snapshot.data!;
                          return SizedBox(
                            height: 200, // Hanya muncul jika ada data
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
                          );
                        }
                      },
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 0, 8),
                      child: Text(
                        'Gold Price',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 100,
                      child: FutureBuilder<Map<String, String>>(
                        future: goldPrices,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            // Tampilan Loading (Siluet Box)
                            return Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                shimmerBox(),
                                shimmerBox(),
                              ],
                            );
                          } else if (snapshot.hasError || !snapshot.hasData) {
                            return Center(child: Text('Failed to load prices'));
                          } else {
                            final hargaBeli =
                                snapshot.data!['hargaBeli'] ?? '-';
                            final hargaJual =
                                snapshot.data!['hargaJual'] ?? '-';

                            return Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                priceBox(
                                    'Harga Jual', hargaJual, Color(0xFFC58189)),
                                priceBox(
                                    'Harga Beli', hargaBeli, Color(0xFFC58189)),
                              ],
                            );
                          }
                        },
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 0, 0),
                      child: Text(
                        'Categories',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 100,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          CategoryCard(
                            '📿',
                            'Kalung',
                          ),
                          CategoryCard('🪄', 'Gelang'),
                          CategoryCard('💍', 'Cincin'),
                          CategoryCard('💎', 'Anting'),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(height: 20),
                  ),
                  // SliverGrid(
                  //   gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  //     crossAxisCount: 2,
                  //     crossAxisSpacing: 10,
                  //     mainAxisSpacing: 10,
                  //     childAspectRatio: 0.65,
                  //   ),
                  //   delegate: SliverChildBuilderDelegate(
                  //     (context, index) {
                  //       return ProductCard(index);
                  //     },
                  //     childCount: 10,
                  //   ),
                  // ),
                ],
              ),
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

  void _showFilterDrawer(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return FractionallySizedBox(
              heightFactor: 0.65, // Adjust height for the new content
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16.0, vertical: 16.0),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Drag handle
                      Center(
                        child: Container(
                          width: 50,
                          height: 6,
                          margin: EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      // Title
                      Text(
                        'Set Price Range',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      SizedBox(height: 20),
                      // Price range inputs
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: lowPriceController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Low Price',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(
                                    color: Colors.grey,
                                    width: 1.5,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(
                                    color: Color(0xFFC58189),
                                    width: 2.0,
                                  ),
                                ),
                                prefixIcon: Icon(Icons.arrow_drop_down),
                              ),
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: TextField(
                              controller: highPriceController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'High Price',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(
                                    color: Colors.grey,
                                    width: 1.5,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(
                                    color: Color(0xFFC58189),
                                    width: 2.0,
                                  ),
                                ),
                                prefixIcon: Icon(Icons.arrow_drop_up_outlined),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 20),
                      // Category selection
                      Text(
                        'Select Categories',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      SizedBox(height: 10),
                      Wrap(
                        spacing: 12.0,
                        runSpacing: 12.0,
                        children: [
                          _buildCategoryBox(
                            label: 'Cincin',
                            isSelected: isRingSelected,
                            onTap: () {
                              setState(() {
                                isRingSelected = !isRingSelected;
                              });
                            },
                          ),
                          _buildCategoryBox(
                            label: 'Kalung',
                            isSelected: isNecklaceSelected,
                            onTap: () {
                              setState(() {
                                isNecklaceSelected = !isNecklaceSelected;
                              });
                            },
                          ),
                          _buildCategoryBox(
                            label: 'Anting',
                            isSelected: isEarringSelected,
                            onTap: () {
                              setState(() {
                                isEarringSelected = !isEarringSelected;
                              });
                            },
                          ),
                          _buildCategoryBox(
                            label: 'Gelang',
                            isSelected: isBraceletSelected,
                            onTap: () {
                              setState(() {
                                isBraceletSelected = !isBraceletSelected;
                              });
                            },
                          ),
                        ],
                      ),
                      SizedBox(height: 20),
                      // Purity selection
                      Text(
                        'Select Purity',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      SizedBox(height: 10),
                      Wrap(
                        spacing: 12.0,
                        runSpacing: 12.0,
                        children: [
                          _buildCategoryBox(
                            label: '24K',
                            isSelected: is24KSelected,
                            onTap: () {
                              setState(() {
                                is24KSelected = !is24KSelected;
                              });
                            },
                          ),
                          _buildCategoryBox(
                            label: '22K',
                            isSelected: is22KSelected,
                            onTap: () {
                              setState(() {
                                is22KSelected = !is22KSelected;
                              });
                            },
                          ),
                          _buildCategoryBox(
                            label: '18K',
                            isSelected: is18KSelected,
                            onTap: () {
                              setState(() {
                                is18KSelected = !is18KSelected;
                              });
                            },
                          ),
                          _buildCategoryBox(
                            label: '14K',
                            isSelected: is14KSelected,
                            onTap: () {
                              setState(() {
                                is14KSelected = !is14KSelected;
                              });
                            },
                          ),
                        ],
                      ),
                      SizedBox(height: 20),
                      // Gold type selection
                      Text(
                        'Select Gold Type',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      SizedBox(height: 10),
                      Wrap(
                        spacing: 12.0,
                        runSpacing: 12.0,
                        children: [
                          _buildCategoryBox(
                            label: 'Emas Kuning',
                            isSelected: isYellowGoldSelected,
                            onTap: () {
                              setState(() {
                                isYellowGoldSelected = !isYellowGoldSelected;
                              });
                            },
                          ),
                          _buildCategoryBox(
                            label: 'Emas Putih',
                            isSelected: isWhiteGoldSelected,
                            onTap: () {
                              setState(() {
                                isWhiteGoldSelected = !isWhiteGoldSelected;
                              });
                            },
                          ),
                          _buildCategoryBox(
                            label: 'Rose Gold',
                            isSelected: isRoseGoldSelected,
                            onTap: () {
                              setState(() {
                                isRoseGoldSelected = !isRoseGoldSelected;
                              });
                            },
                          ),
                        ],
                      ),
                      SizedBox(height: 24),
                      // Apply button
                      ElevatedButton(
                        onPressed: () {
                          final lowPrice =
                              double.tryParse(lowPriceController.text);
                          final highPrice =
                              double.tryParse(highPriceController.text);

                          // Jika lowPrice atau highPrice null, anggap tidak ada filter harga
                          final priceFilter =
                              (lowPrice != null || highPrice != null)
                                  ? {
                                      'lowPrice': lowPrice ?? 0,
                                      'highPrice': highPrice ?? double.infinity
                                    }
                                  : null;

                          // Kumpulkan kategori yang terpilih
                          final selectedCategories = [];
                          if (isRingSelected) selectedCategories.add('Cincin');
                          if (isNecklaceSelected)
                            selectedCategories.add('Kalung');
                          if (isEarringSelected)
                            selectedCategories.add('Anting');
                          if (isBraceletSelected)
                            selectedCategories.add('Gelang');

                          // Jika tidak ada kategori yang dipilih, anggap tidak ada filter kategori
                          final categoryFilter = selectedCategories.isNotEmpty
                              ? selectedCategories
                              : null;

                          // Kumpulkan purity yang terpilih
                          final selectedPurities = [];
                          if (is24KSelected) selectedPurities.add('24K');
                          if (is22KSelected) selectedPurities.add('22K');
                          if (is18KSelected) selectedPurities.add('18K');
                          if (is14KSelected) selectedPurities.add('14K');

                          // Jika tidak ada purity yang dipilih, anggap tidak ada filter purity
                          final purityFilter = selectedPurities.isNotEmpty
                              ? selectedPurities
                              : null;

                          // Kumpulkan jenis emas yang terpilih
                          final selectedGoldTypes = [];
                          if (isYellowGoldSelected)
                            selectedGoldTypes.add('Emas Kuning');
                          if (isWhiteGoldSelected)
                            selectedGoldTypes.add('Emas Putih');
                          if (isRoseGoldSelected)
                            selectedGoldTypes.add('Rose Gold');

                          // Jika tidak ada jenis emas yang dipilih, anggap tidak ada filter jenis emas
                          final goldTypeFilter = selectedGoldTypes.isNotEmpty
                              ? selectedGoldTypes
                              : null;

                          // Validasi tambahan: Jika lowPrice lebih besar dari highPrice, beri peringatan
                          if (lowPrice != null &&
                              highPrice != null &&
                              lowPrice > highPrice) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    'Low Price cannot be higher than High Price!'),
                              ),
                            );
                            return;
                          }

                          // Kembalikan hasil filter melalui Navigator
                          Navigator.pop(context, {
                            'priceFilter':
                                priceFilter, // null jika tidak ada filter harga
                            'categories':
                                categoryFilter, // null jika tidak ada filter kategori
                            'purities':
                                purityFilter, // null jika tidak ada filter purity
                            'goldTypes':
                                goldTypeFilter, // null jika tidak ada filter jenis emas
                          });
                          print({
                            'priceFilter': priceFilter,
                            'categories': categoryFilter,
                            'purities': purityFilter,
                            'goldTypes': goldTypeFilter,
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF31394E),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          minimumSize: Size(double.infinity, 50),
                        ),
                        child: Text(
                          'Apply',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
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
