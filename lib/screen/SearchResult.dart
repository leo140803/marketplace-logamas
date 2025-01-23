import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:marketplace_logamas/function/Utils.dart';
import 'package:marketplace_logamas/widget/ProductCard.dart';
import 'package:go_router/go_router.dart';

class SearchResultPage extends StatefulWidget {
  final String query;
  const SearchResultPage({required this.query, Key? key}) : super(key: key);

  @override
  _SearchResultPageState createState() => _SearchResultPageState();
}

class _SearchResultPageState extends State<SearchResultPage> {
  TextEditingController _searchController = TextEditingController();
  String tempQuery = ""; // Temporary query for onChanged
  String finalQuery = ""; // Final query for full search
  Set<String> selectedTypes = {};
  Set<String> selectedPurities = {};
  Set<String> selectedMetalTypes = {};
  List<dynamic> products = [];
  List<dynamic> filteredProducts = [];
  TextEditingController lowPriceController = TextEditingController();
  TextEditingController highPriceController = TextEditingController();
  bool isFilterApplied = false;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.query;
    tempQuery = widget.query;
    finalQuery = widget.query;
    search(finalQuery); // Initial search
  }

  Future<void> search(String query) async {
    setState(() {
      isLoading = true;
    });

    try {
      final response =
          await http.get(Uri.parse('$apiBaseUrl/products/search?q=$query'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body)['data'];
        setState(() {
          products = List<Map<String, dynamic>>.from(data);
          filteredProducts = List.from(products); // Default filtered products
        });
      } else {
        throw Exception('Failed to fetch search results');
      }
    } catch (e) {
      print('Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to fetch search results'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void applyFilter(
    Set<String> selectedCategoryNames,
    Set<String> selectedPurities,
    Set<String> selectedMetalTypes, {
    double? lowPrice,
    double? highPrice,
  }) {
    if (lowPrice != null && highPrice != null && lowPrice > highPrice) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Low Price cannot be greater than High Price.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      isFilterApplied = selectedCategoryNames.isNotEmpty ||
          selectedPurities.isNotEmpty ||
          selectedMetalTypes.isNotEmpty ||
          lowPrice != null ||
          highPrice != null;

      filteredProducts = products.where((product) {
        final type = product['types'] as Map<String, dynamic>? ?? {};
        final category = type['category'] as Map<String, dynamic>? ?? {};
        final price = product['price'] as int? ?? 0;

        final nameMatches = selectedCategoryNames.isEmpty ||
            selectedCategoryNames.contains(category['name']);

        final purityMatches = selectedPurities.isEmpty ||
            selectedPurities.contains(category['purity']);

        final metalTypeMatches = selectedMetalTypes.isEmpty ||
            selectedMetalTypes.contains(
                _getMetalTypeName(category['metal_type'] as int? ?? -1));

        final priceMatches = (lowPrice == null || price >= lowPrice) &&
            (highPrice == null || price <= highPrice);

        return nameMatches && purityMatches && metalTypeMatches && priceMatches;
      }).toList();
    });
  }

  List<Map<String, dynamic>> extractFiltersFromProducts(
      List<dynamic> products) {
    final categories = products
        .map(
            (product) => product['types']?['category'] as Map<String, dynamic>?)
        .where((category) => category != null)
        .toList();
    final uniqueCategories = categories.fold<Map<String, Map<String, dynamic>>>(
      {},
      (acc, category) {
        final key = category!['id'];
        acc[key] = category;
        return acc;
      },
    );
    return uniqueCategories.values.toList();
  }

  String _getMetalTypeName(int metalType) {
    switch (metalType) {
      case 0:
        return 'Gold';
      case 1:
        return 'Silver';
      case 2:
        return 'Red Gold';
      case 3:
        return 'White Gold';
      case 4:
        return 'Platinum';
      default:
        return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: GestureDetector(
          onTap: () => context.push('/home'),
          child: Icon(
            Icons.arrow_back,
            color: Colors.white,
          ),
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
                    // Ketika pengguna menekan Enter, arahkan ke halaman pencarian
                    if (value.trim().isNotEmpty) {
                      context.push('/search-result', extra: {'query': value});
                    }
                  },
                  // focusNode: _textFieldFocusNode,
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
                      icon: Icon(isFilterApplied
                          ? Icons.filter_alt
                          : Icons.filter_alt_outlined),
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
        backgroundColor: Color(0xFF31394E),
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
                    // Navigator.pushReplacementNamed(
                    //     context, '/cart');
                  },
                ),
              ],
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
        child: filteredProducts.isEmpty && !isLoading
            ? Center(
                child: Text(
                  'No results found.',
                  style: TextStyle(fontSize: 16),
                ),
              )
            : isLoading
                ? Center(
                    child: CircularProgressIndicator(color: Color(0xFFC58189)),
                  )
                : GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 0.65,
                    ),
                    itemCount: filteredProducts.length,
                    itemBuilder: (context, index) {
                      final product = filteredProducts[index];
                      return GestureDetector(
                        onTap: () {
                          context.push(
                            '/product-detail/${product['product_id']}',
                          );
                        },
                        child: ProductCard(product),
                      );
                    },
                  ),
      ),
    );
  }

  void _showFilterDrawer(BuildContext context) {
    final filters = extractFiltersFromProducts(products);

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
              heightFactor: 0.8,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16.0, vertical: 16.0),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Drawer
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

                      // Filter by Category Name
                      Text(
                        'Select Category Name',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 10),
                      Wrap(
                        spacing: 12.0,
                        runSpacing: 12.0,
                        children: filters
                            .map((filter) => filter['name'])
                            .toSet()
                            .map((name) {
                          final isSelected = selectedTypes.contains(name);

                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                if (isSelected) {
                                  selectedTypes.remove(name);
                                } else {
                                  selectedTypes.add(name);
                                }
                              });
                            },
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 16.0, vertical: 12.0),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Color(0xFFC58189)
                                    : Colors.grey[200],
                                borderRadius: BorderRadius.circular(10.0),
                                border: Border.all(
                                  color: isSelected
                                      ? Color(0xFFC58189)
                                      : Colors.grey.shade300,
                                  width: 1.5,
                                ),
                              ),
                              child: Text(
                                name,
                                style: TextStyle(
                                  color:
                                      isSelected ? Colors.white : Colors.black,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          );
                        }).toList(),
                      ),

                      SizedBox(height: 20),

                      // Filter by Purity
                      Text(
                        'Select Purity',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 10),
                      Wrap(
                        spacing: 12.0,
                        runSpacing: 12.0,
                        children: filters
                            .map((filter) => filter['purity'])
                            .toSet()
                            .map((purity) {
                          final isSelected = selectedPurities.contains(purity);

                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                if (isSelected) {
                                  selectedPurities.remove(purity);
                                } else {
                                  selectedPurities.add(purity);
                                }
                              });
                            },
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 16.0, vertical: 12.0),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Color(0xFFC58189)
                                    : Colors.grey[200],
                                borderRadius: BorderRadius.circular(10.0),
                                border: Border.all(
                                  color: isSelected
                                      ? Color(0xFFC58189)
                                      : Colors.grey.shade300,
                                  width: 1.5,
                                ),
                              ),
                              child: Text(
                                purity,
                                style: TextStyle(
                                  color:
                                      isSelected ? Colors.white : Colors.black,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          );
                        }).toList(),
                      ),

                      SizedBox(height: 20),

                      // Filter by Metal Type
                      Text(
                        'Select Metal Type',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 10),
                      Wrap(
                        spacing: 12.0,
                        runSpacing: 12.0,
                        children: filters
                            .map((filter) =>
                                _getMetalTypeName(filter['metal_type'] as int))
                            .toSet()
                            .map((metalType) {
                          final isSelected =
                              selectedMetalTypes.contains(metalType);

                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                if (isSelected) {
                                  selectedMetalTypes.remove(metalType);
                                } else {
                                  selectedMetalTypes.add(metalType);
                                }
                              });
                            },
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 16.0, vertical: 12.0),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Color(0xFFC58189)
                                    : Colors.grey[200],
                                borderRadius: BorderRadius.circular(10.0),
                                border: Border.all(
                                  color: isSelected
                                      ? Color(0xFFC58189)
                                      : Colors.grey.shade300,
                                  width: 1.5,
                                ),
                              ),
                              child: Text(
                                metalType,
                                style: TextStyle(
                                  color:
                                      isSelected ? Colors.white : Colors.black,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          );
                        }).toList(),
                      ),

                      SizedBox(height: 20),

                      // Filter by Price Range
                      Text(
                        'Set Price Range',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: lowPriceController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                    RegExp(r'^[1-9][0-9]*|0$')),
                              ],
                              decoration: InputDecoration(
                                labelText: 'Low Price',
                                labelStyle: TextStyle(
                                    color: Color(0xFF31394E),
                                    fontWeight: FontWeight.bold),
                                prefixIcon: Icon(Icons.price_change_outlined,
                                    color: Color(0xFFC58189)),
                                filled: true,
                                fillColor: Colors.grey[100],
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(
                                      color: Colors.grey.shade300, width: 1.5),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(
                                      color: Color(0xFFC58189), width: 2),
                                ),
                                contentPadding: EdgeInsets.symmetric(
                                    vertical: 16, horizontal: 16),
                              ),
                            ),
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: highPriceController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                    RegExp(r'^[1-9][0-9]*|0$')),
                              ],
                              decoration: InputDecoration(
                                labelText: 'High Price',
                                labelStyle: TextStyle(
                                    color: Color(0xFF31394E),
                                    fontWeight: FontWeight.bold),
                                prefixIcon: Icon(Icons.price_check_outlined,
                                    color: Color(0xFFC58189)),
                                filled: true,
                                fillColor: Colors.grey[100],
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(
                                      color: Colors.grey.shade300, width: 1.5),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(
                                      color: Color(0xFFC58189), width: 2),
                                ),
                                contentPadding: EdgeInsets.symmetric(
                                    vertical: 16, horizontal: 16),
                              ),
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 24),

                      // Apply Button
                      ElevatedButton(
                        onPressed: () {
                          final double? lowPrice =
                              double.tryParse(lowPriceController.text);
                          final double? highPrice =
                              double.tryParse(highPriceController.text);

                          applyFilter(
                            selectedTypes,
                            selectedPurities,
                            selectedMetalTypes,
                            lowPrice: lowPrice,
                            highPrice: highPrice,
                          );

                          Navigator.pop(context);
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
}
