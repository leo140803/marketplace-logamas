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
  TextEditingController lowWeightController = TextEditingController();
  TextEditingController highWeightController = TextEditingController();

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
    double? lowWeight,
    double? highWeight,
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

    if (lowWeight != null && highWeight != null && lowWeight > highWeight) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Low Weight cannot be greater than High Weight.'),
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
          highPrice != null ||
          lowWeight != null ||
          highWeight != null;

      filteredProducts = products.where((product) {
        final type = product['types'] as Map<String, dynamic>? ?? {};
        final category = type['category'] as Map<String, dynamic>? ?? {};
        final price = product['price'] as int? ?? 0;
        final minWeight = (product['min_weight'] is int)
            ? (product['min_weight'] as int).toDouble()
            : (product['min_weight'] as double? ?? 0);

        final maxWeight = (product['max_weight'] is int)
            ? (product['max_weight'] as int).toDouble()
            : (product['max_weight'] as double? ?? 0);

        final nameMatches = selectedCategoryNames.isEmpty ||
            selectedCategoryNames.contains(category['name']);

        final purityMatches = selectedPurities.isEmpty ||
            selectedPurities.contains(category['purity']);

        final metalTypeMatches = selectedMetalTypes.isEmpty ||
            selectedMetalTypes.contains(
                _getMetalTypeName(category['metal_type'] as int? ?? -1));

        final priceMatches = (lowPrice == null || price >= lowPrice) &&
            (highPrice == null || price <= highPrice);

        final weightMatches = (lowWeight == null || maxWeight >= lowWeight) &&
            (highWeight == null || minWeight <= highWeight);

        return nameMatches &&
            purityMatches &&
            metalTypeMatches &&
            priceMatches &&
            weightMatches;
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
      case 1:
        return 'Gold';
      case 2:
        return 'Silver';
      case 3:
        return 'Red Gold';
      case 4:
        return 'White Gold';
      case 5:
        return 'Platinum';
      default:
        return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.search_off,
                      size: 80,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'No results found',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Try searching with different keywords.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
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

    // Count active filters for the badge
    int activeFilterCount = selectedTypes.length +
        selectedPurities.length +
        selectedMetalTypes.length +
        (lowPriceController.text.isNotEmpty ? 1 : 0) +
        (highPriceController.text.isNotEmpty ? 1 : 0) +
        (lowWeightController.text.isNotEmpty ? 1 : 0) +
        (highWeightController.text.isNotEmpty ? 1 : 0);

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
            // Function to update active filter count
            void updateFilterCount() {
              activeFilterCount = selectedTypes.length +
                  selectedPurities.length +
                  selectedMetalTypes.length +
                  (lowPriceController.text.isNotEmpty ? 1 : 0) +
                  (highPriceController.text.isNotEmpty ? 1 : 0) +
                  (lowWeightController.text.isNotEmpty ? 1 : 0) +
                  (highWeightController.text.isNotEmpty ? 1 : 0);
            }

            // Function to clear all filters
            void clearAllFilters() {
              setState(() {
                selectedTypes.clear();
                selectedPurities.clear();
                selectedMetalTypes.clear();
                lowPriceController.clear();
                highPriceController.clear();
                lowWeightController.clear();
                highWeightController.clear();
                updateFilterCount();
              });
            }

            return FractionallySizedBox(
              heightFactor: 0.85,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with drag handle and title
                    Container(
                      padding: EdgeInsets.fromLTRB(20, 16, 20, 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(20)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            spreadRadius: 1,
                            blurRadius: 4,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Drag handle
                          Center(
                            child: Container(
                              width: 50,
                              height: 5,
                              decoration: BoxDecoration(
                                color: Colors.grey[300],
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                          SizedBox(height: 16),
                          // Header with title and clear button
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Filter',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF31394E),
                                    ),
                                  ),
                                  if (activeFilterCount > 0)
                                    Container(
                                      margin: EdgeInsets.only(left: 8),
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Color(0xFFC58189),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        activeFilterCount.toString(),
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              if (activeFilterCount > 0)
                                TextButton(
                                  onPressed: clearAllFilters,
                                  child: Text(
                                    'Clear All',
                                    style: TextStyle(
                                      color: Color(0xFFC58189),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Filter options in scrollable area
                    Expanded(
                      child: SingleChildScrollView(
                        physics: BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(height: 20),

                            // Category Filter Section
                            Row(
                              children: [
                                Icon(Icons.category_outlined,
                                    color: Color(0xFF31394E), size: 20),
                                SizedBox(width: 10),
                                Text(
                                  'Category',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF31394E),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 12),
                            Wrap(
                              spacing: 10.0,
                              runSpacing: 10.0,
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
                                      updateFilterCount();
                                    });
                                  },
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 14.0, vertical: 10.0),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? Color(0xFFFBE9E7)
                                          : Colors.grey[100],
                                      borderRadius: BorderRadius.circular(8.0),
                                      border: Border.all(
                                        color: isSelected
                                            ? Color(0xFFC58189)
                                            : Colors.grey.shade300,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          name,
                                          style: TextStyle(
                                            color: isSelected
                                                ? Color(0xFFC58189)
                                                : Colors.black87,
                                            fontWeight: isSelected
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                          ),
                                        ),
                                        if (isSelected) ...[
                                          SizedBox(width: 6),
                                          Icon(
                                            Icons.check_circle,
                                            color: Color(0xFFC58189),
                                            size: 16,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),

                            SizedBox(height: 24),

                            // Purity Filter Section
                            Row(
                              children: [
                                Icon(Icons.diamond_outlined,
                                    color: Color(0xFF31394E), size: 20),
                                SizedBox(width: 10),
                                Text(
                                  'Purity',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF31394E),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 12),
                            Wrap(
                              spacing: 10.0,
                              runSpacing: 10.0,
                              children: filters
                                  .map((filter) => filter['purity'])
                                  .toSet()
                                  .map((purity) {
                                final isSelected =
                                    selectedPurities.contains(purity);

                                return GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      if (isSelected) {
                                        selectedPurities.remove(purity);
                                      } else {
                                        selectedPurities.add(purity);
                                      }
                                      updateFilterCount();
                                    });
                                  },
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 14.0, vertical: 10.0),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? Color(0xFFFBE9E7)
                                          : Colors.grey[100],
                                      borderRadius: BorderRadius.circular(8.0),
                                      border: Border.all(
                                        color: isSelected
                                            ? Color(0xFFC58189)
                                            : Colors.grey.shade300,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          purity,
                                          style: TextStyle(
                                            color: isSelected
                                                ? Color(0xFFC58189)
                                                : Colors.black87,
                                            fontWeight: isSelected
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                          ),
                                        ),
                                        if (isSelected) ...[
                                          SizedBox(width: 6),
                                          Icon(
                                            Icons.check_circle,
                                            color: Color(0xFFC58189),
                                            size: 16,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),

                            SizedBox(height: 24),

                            // Metal Type Filter Section
                            Row(
                              children: [
                                Icon(Icons.design_services_outlined,
                                    color: Color(0xFF31394E), size: 20),
                                SizedBox(width: 10),
                                Text(
                                  'Metal Type',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF31394E),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 12),
                            Wrap(
                              spacing: 10.0,
                              runSpacing: 10.0,
                              children: filters
                                  .map((filter) => _getMetalTypeName(
                                      filter['metal_type'] as int))
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
                                      updateFilterCount();
                                    });
                                  },
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 14.0, vertical: 10.0),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? Color(0xFFFBE9E7)
                                          : Colors.grey[100],
                                      borderRadius: BorderRadius.circular(8.0),
                                      border: Border.all(
                                        color: isSelected
                                            ? Color(0xFFC58189)
                                            : Colors.grey.shade300,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          metalType,
                                          style: TextStyle(
                                            color: isSelected
                                                ? Color(0xFFC58189)
                                                : Colors.black87,
                                            fontWeight: isSelected
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                          ),
                                        ),
                                        if (isSelected) ...[
                                          SizedBox(width: 6),
                                          Icon(
                                            Icons.check_circle,
                                            color: Color(0xFFC58189),
                                            size: 16,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),

                            SizedBox(height: 24),

                            // Price Range Filter Section
                            Row(
                              children: [
                                Icon(Icons.price_change_outlined,
                                    color: Color(0xFF31394E), size: 20),
                                SizedBox(width: 10),
                                Text(
                                  'Price Range',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF31394E),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      color: Colors.grey[100],
                                      border: Border.all(
                                        color: Colors.grey[300]!,
                                        width: 1,
                                      ),
                                    ),
                                    child: TextField(
                                      controller: lowPriceController,
                                      keyboardType: TextInputType.number,
                                      onChanged: (_) =>
                                          setState(() => updateFilterCount()),
                                      inputFormatters: [
                                        FilteringTextInputFormatter.allow(
                                            RegExp(r'^[1-9][0-9]*|0$')),
                                      ],
                                      decoration: InputDecoration(
                                        labelText: 'Min',
                                        labelStyle: TextStyle(
                                            color: Color(0xFF31394E),
                                            fontSize: 14),
                                        prefixIcon: Icon(Icons.remove,
                                            color: Color(0xFFC58189), size: 18),
                                        border: InputBorder.none,
                                        contentPadding: EdgeInsets.symmetric(
                                            vertical: 12, horizontal: 12),
                                      ),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8.0),
                                  child: Text('to',
                                      style:
                                          TextStyle(color: Colors.grey[600])),
                                ),
                                Expanded(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      color: Colors.grey[100],
                                      border: Border.all(
                                        color: Colors.grey[300]!,
                                        width: 1,
                                      ),
                                    ),
                                    child: TextField(
                                      controller: highPriceController,
                                      keyboardType: TextInputType.number,
                                      onChanged: (_) =>
                                          setState(() => updateFilterCount()),
                                      inputFormatters: [
                                        FilteringTextInputFormatter.allow(
                                            RegExp(r'^[1-9][0-9]*|0$')),
                                      ],
                                      decoration: InputDecoration(
                                        labelText: 'Max',
                                        labelStyle: TextStyle(
                                            color: Color(0xFF31394E),
                                            fontSize: 14),
                                        prefixIcon: Icon(Icons.add,
                                            color: Color(0xFFC58189), size: 18),
                                        border: InputBorder.none,
                                        contentPadding: EdgeInsets.symmetric(
                                            vertical: 12, horizontal: 12),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            SizedBox(height: 24),

                            // Weight Range Filter Section
                            Row(
                              children: [
                                Icon(Icons.scale_outlined,
                                    color: Color(0xFF31394E), size: 20),
                                SizedBox(width: 10),
                                Text(
                                  'Weight Range (grams)',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF31394E),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      color: Colors.grey[100],
                                      border: Border.all(
                                        color: Colors.grey[300]!,
                                        width: 1,
                                      ),
                                    ),
                                    child: TextField(
                                      controller: lowWeightController,
                                      keyboardType: TextInputType.number,
                                      onChanged: (_) =>
                                          setState(() => updateFilterCount()),
                                      inputFormatters: [
                                        FilteringTextInputFormatter.allow(
                                            RegExp(r'^\d+(\.\d{0,2})?$')),
                                      ],
                                      decoration: InputDecoration(
                                        labelText: 'Min',
                                        labelStyle: TextStyle(
                                            color: Color(0xFF31394E),
                                            fontSize: 14),
                                        prefixIcon: Icon(Icons.remove,
                                            color: Color(0xFFC58189), size: 18),
                                        border: InputBorder.none,
                                        contentPadding: EdgeInsets.symmetric(
                                            vertical: 12, horizontal: 12),
                                      ),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8.0),
                                  child: Text('to',
                                      style:
                                          TextStyle(color: Colors.grey[600])),
                                ),
                                Expanded(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      color: Colors.grey[100],
                                      border: Border.all(
                                        color: Colors.grey[300]!,
                                        width: 1,
                                      ),
                                    ),
                                    child: TextField(
                                      controller: highWeightController,
                                      keyboardType: TextInputType.number,
                                      onChanged: (_) =>
                                          setState(() => updateFilterCount()),
                                      inputFormatters: [
                                        FilteringTextInputFormatter.allow(
                                            RegExp(r'^\d+(\.\d{0,2})?$')),
                                      ],
                                      decoration: InputDecoration(
                                        labelText: 'Max',
                                        labelStyle: TextStyle(
                                            color: Color(0xFF31394E),
                                            fontSize: 14),
                                        prefixIcon: Icon(Icons.add,
                                            color: Color(0xFFC58189), size: 18),
                                        border: InputBorder.none,
                                        contentPadding: EdgeInsets.symmetric(
                                            vertical: 12, horizontal: 12),
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

                    // Apply button in fixed position at bottom
                    Container(
                      padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            spreadRadius: 1,
                            blurRadius: 4,
                            offset: Offset(0, -1),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                final double? lowPrice =
                                    double.tryParse(lowPriceController.text);
                                final double? highPrice =
                                    double.tryParse(highPriceController.text);
                                final double? lowWeight =
                                    double.tryParse(lowWeightController.text);
                                final double? highWeight =
                                    double.tryParse(highWeightController.text);

                                applyFilter(
                                  selectedTypes,
                                  selectedPurities,
                                  selectedMetalTypes,
                                  lowPrice: lowPrice,
                                  highPrice: highPrice,
                                  lowWeight: lowWeight,
                                  highWeight: highWeight,
                                );

                                Navigator.pop(context);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Color(0xFF31394E),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding: EdgeInsets.symmetric(vertical: 16),
                                elevation: 0,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Apply Filters',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (activeFilterCount > 0) ...[
                                    SizedBox(width: 8),
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        activeFilterCount.toString(),
                                        style: TextStyle(
                                          color: Color(0xFF31394E),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
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
      },
    );
  }
}
