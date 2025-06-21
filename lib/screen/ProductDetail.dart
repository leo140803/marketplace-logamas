import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:marketplace_logamas/converter/metal_type.dart';
import 'package:marketplace_logamas/function/Utils.dart';
import 'package:marketplace_logamas/screen/FullScreenImageView.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

class ProductDetailPage extends StatefulWidget {
  final String productId;

  const ProductDetailPage({Key? key, required this.productId})
      : super(key: key);

  @override
  _ProductDetailPageState createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage>
    with SingleTickerProviderStateMixin {
  bool isWishlisted = false;
  String? _accessToken;
  final PageController _pageController = PageController();
  TabController? _tabController;
  bool _isLoading = true;
  Map<String, dynamic>? _productData;
  int _currentImageIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initializeData();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _tabController?.dispose();
    super.dispose();
  }

  // Combine initialization functions into one
  Future<void> _initializeData() async {
    try {
      final token = await getAccessToken();
      final userId = await getUserId();

      setState(() {
        _accessToken = token;
        _isLoading = true;
      });

      // Parallel data fetching
      await Future.wait([
        _fetchProductData(),
        _checkWishlistStatus(userId, widget.productId),
      ]);
    } catch (e) {
      print('Error initializing data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchProductData() async {
    try {
      final data = await fetchProductDetail(widget.productId);
      setState(() {
        _productData = data;
      });
    } catch (e) {
      print('Error fetching product data: $e');
    }
  }

  Future<void> _checkWishlistStatus(String userId, String productId) async {
    if (_accessToken == null) return;

    final url =
        Uri.parse('$apiBaseUrl/wishlist/is-wishlist?product_id=$productId');
    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_accessToken',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseBody = jsonDecode(response.body);
        setState(() {
          isWishlisted = responseBody['data'] ?? false;
        });
      }
    } catch (e) {
      print('Error checking wishlist status: $e');
    }
  }

  Future<void> toggleWishlist(String userId, String productId) async {
    if (_accessToken == null) return;

    final url = Uri.parse('$apiBaseUrl/wishlist');
    final body = jsonEncode({'user_id': userId, 'product_id': productId});

    try {
      final response = await (isWishlisted
          ? http.delete(
              Uri.parse('$apiBaseUrl/wishlist/$productId'),
              headers: {
                'Authorization': 'Bearer $_accessToken',
              },
            )
          : http.post(
              url,
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $_accessToken',
              },
              body: body,
            ));

      if (response.statusCode == 200 || response.statusCode == 201) {
        setState(() {
          isWishlisted = !isWishlisted;
        });

        // Show feedback to user
        _showToast(
          isWishlisted ? 'Added to Wishlist 🩷' : 'Removed from Wishlist 🖤',
          isWishlisted ? const Color(0xFFC58189) : Colors.red,
          isWishlisted ? Icons.favorite : Icons.favorite_border,
        );
      } else {
        throw Exception('Failed to update wishlist');
      }
    } catch (e) {
      _showToast('Error updating wishlist', Colors.red, Icons.error);
    }
  }

  // Reusable toast notification
  void _showToast(String message, Color backgroundColor, IconData icon) {
    final overlay = Overlay.of(context);

    final entry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).size.height / 2 - 40,
        left: MediaQuery.of(context).size.width / 2 - 150,
        child: Material(
          color: Colors.transparent,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            width: 300,
            padding:
                const EdgeInsets.symmetric(vertical: 12.0, horizontal: 20.0),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(12.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(
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
      ),
    );

    overlay?.insert(entry);
    Future.delayed(const Duration(seconds: 2), () {
      entry.remove();
    });
  }

  Future<Map<String, dynamic>> fetchProductDetail(String productId) async {
    final url = Uri.parse('$apiBaseUrl/products/$productId');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final Map<String, dynamic> responseBody = jsonDecode(response.body);
      return responseBody['data'];
    } else {
      throw Exception('Failed to load product');
    }
  }

  Future<bool> addToCartAPI(String userId, String productCodeId) async {
    final url = Uri.parse('$apiBaseUrl/cart');
    final body = jsonEncode({
      'user_id': userId,
      'product_code_id': productCodeId,
      'quantity': 1,
    });

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      if (response.statusCode == 201) {
        return true;
      } else {
        final responseBody = jsonDecode(response.body);
        throw Exception(responseBody['message'] ?? 'Failed to add to cart');
      }
    } catch (e) {
      throw Exception('Error adding product to cart: $e');
    }
  }

  Widget _buildCachedImage(String imageUrl,
      {double? width, double? height, BoxFit fit = BoxFit.cover}) {
    return CachedNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      placeholder: (context, url) => Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: Container(
          width: width,
          height: height,
          color: Colors.white,
        ),
      ),
      errorWidget: (context, url, error) => Container(
        width: width,
        height: height,
        color: Colors.grey[200],
        child: const Icon(Icons.broken_image, size: 50, color: Colors.grey),
      ),
    );
  }

  Widget _buildStat(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, 2),
            blurRadius: 4,
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 16, color: Colors.grey),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewCard({
    required String customerName,
    required String review,
    required int rating,
    String? replyAdmin,
    List<String> images = const [],
  }) {
    return Card(
      color: Colors.white,
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Nama dan Rating
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleAvatar(
                  backgroundColor: Color(0xFFC58189),
                  child: Icon(Icons.person, color: Colors.white),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customerName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF31394E),
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: List.generate(
                          5,
                          (index) => Icon(
                            Icons.star,
                            size: 18,
                            color: index < rating
                                ? const Color(0xFFF2C94C)
                                : Colors.grey[300],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const Divider(height: 20),

            // Review pelanggan
            Text(
              review,
              style: const TextStyle(fontSize: 14, color: Colors.black87),
              maxLines: 6,
              overflow: TextOverflow.ellipsis,
            ),

            if (images.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: images.map((url) {
                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FullScreenImageView(
                            imageUrl: '$apiBaseUrlImage2$url',
                          ),
                        ),
                      );
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        '$apiBaseUrlImage2$url',
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: 80,
                          height: 80,
                          color: Colors.grey[300],
                          child: const Icon(Icons.broken_image),
                        ),
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            width: 80,
                            height: 80,
                            alignment: Alignment.center,
                            child:
                                const CircularProgressIndicator(strokeWidth: 2),
                          );
                        },
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],

            // Balasan dari admin
            if (replyAdmin != null && replyAdmin.isNotEmpty) ...[
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.admin_panel_settings_rounded,
                      color: Color(0xFFC58189), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: const LinearGradient(
                          colors: [
                            Color.fromARGB(255, 252, 239, 241),
                            Color.fromARGB(255, 255, 169, 179)
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withOpacity(0.2),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Admin",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFC58189),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            replyAdmin,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                            maxLines: 6,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Improved product codes modal
  void _showProductCodesModal(
      BuildContext context, List productCodes, String productId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (_, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  // Pull handle
                  Container(
                    width: 50,
                    height: 5,
                    margin: const EdgeInsets.only(top: 16, bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  // Header
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Text(
                      'Select Product Variant',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF31394E),
                      ),
                    ),
                  ),
                  // Content
                  Expanded(
                    child: productCodes.isEmpty
                        ? const Center(
                            child: Text(
                              'No available product variants',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                          )
                        : ListView.builder(
                            controller: scrollController,
                            padding: const EdgeInsets.all(16),
                            itemCount: productCodes.length,
                            itemBuilder: (context, index) {
                              final productCode = productCodes[index];
                              final imageUrl =
                                  '$apiBaseUrlImage${productCode['image']}';

                              return Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 10,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: IntrinsicHeight(
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      ClipRRect(
                                        borderRadius: const BorderRadius.only(
                                          topLeft: Radius.circular(16),
                                          bottomLeft: Radius.circular(16),
                                        ),
                                        child: _buildCachedImage(
                                          imageUrl,
                                          width: 100,
                                          height: 100,
                                        ),
                                      ),
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.all(12),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                'Barcode: ${productCode['barcode']}',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  const Icon(
                                                    Icons.scale,
                                                    size: 16,
                                                    color: Colors.grey,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    '${productCode['weight']} g',
                                                    style: const TextStyle(
                                                      fontSize: 14,
                                                      color: Colors.grey,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Rp ${formatCurrency(productCode['total_price'].toDouble())}',
                                                style: const TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFFC58189),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: ElevatedButton(
                                          onPressed: () async {
                                            try {
                                              final userId = await getUserId();
                                              await addToCartAPI(
                                                  userId, productCode['id']);
                                              Navigator.pop(context);
                                              _showToast(
                                                'Added to cart successfully',
                                                const Color(0xFF31394E),
                                                Icons.check_circle,
                                              );
                                            } catch (e) {
                                              _showToast(
                                                'Failed to add to cart',
                                                Colors.red,
                                                Icons.error,
                                              );
                                            }
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                const Color(0xFF31394E),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 12,
                                              horizontal: 16,
                                            ),
                                          ),
                                          child: const Text(
                                            'Add',
                                            style: TextStyle(
                                              color: Color(0xFFC58189),
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
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildProductInfo() {
    if (_productData == null) {
      return const Center(child: Text('Product information not available'));
    }

    final product = _productData!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Product Name with Price
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                product['name'] ?? 'Product Name',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF31394E),
                ),
              ),
              const SizedBox(height: 12),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Price container
                  if (product['low_price'] != null &&
                      product['high_price'] != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.payments_outlined,
                            size: 20,
                            color: Color(0xFF31394E),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            product['low_price'] == product['high_price']
                                ? 'Rp ${formatCurrency(product['low_price'].toDouble())}'
                                : 'Rp ${formatCurrency(product['low_price'].toDouble())} - ${formatCurrency(product['high_price'].toDouble())}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFC58189),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 8),

              // Stock indicator with better styling
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                    decoration: BoxDecoration(
                      color: product['stock'] > 0
                          ? Colors.green[50]
                          : Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: product['stock'] > 0 ? Colors.green : Colors.red,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      product['stock'] > 0
                          ? 'In Stock (${product['stock']})'
                          : 'Out of Stock',
                      style: TextStyle(
                        fontSize: 14,
                        color: product['stock'] > 0 ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  // Wishlist button
                  GestureDetector(
                    onTap: () async {
                      final userId = await getUserId();
                      await toggleWishlist(userId, widget.productId);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isWishlisted
                            ? Colors.red.withOpacity(0.1)
                            : Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isWishlisted
                                ? Icons.favorite
                                : Icons.favorite_border,
                            color: isWishlisted ? Colors.red : Colors.grey,
                            size: 22,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isWishlisted ? 'Saved' : 'Save',
                            style: TextStyle(
                              color: isWishlisted ? Colors.red : Colors.grey,
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
        ),

        // Stats Row (Rating, Sold, Weight)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStat(
                product['average_rating'] != null &&
                        product['average_rating'] > 0
                    ? '⭐ ${product['average_rating']}'
                    : 'No Rate',
                'Rating',
              ),
              _buildStat(
                product['totalSold'] != null
                    ? '${product['totalSold']}'
                    : 'Not Sold',
                'Sold',
              ),
              _buildStat(
                (product['min_weight'] != null && product['max_weight'] != null)
                    ? (product['min_weight'] == product['max_weight']
                        ? '${product['min_weight']} g'
                        : '${product['min_weight']} - ${product['max_weight']} g')
                    : 'N/A',
                'Weight',
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // Tab Bar for Details, Description, Reviews
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TabBar(
            controller: _tabController,
            labelColor: const Color(0xFFC58189),
            unselectedLabelColor: Colors.grey,
            indicatorColor: const Color(0xFFC58189),
            indicatorWeight: 3,
            tabs: const [
              Tab(text: 'Details'),
              Tab(text: 'Description'),
              Tab(text: 'Reviews'),
            ],
          ),
        ),

        // Tab content
        SizedBox(
          height: 500, // Fixed height for tab content
          child: TabBarView(
            controller: _tabController,
            children: [
              // Details Tab
              SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            spreadRadius: 1,
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          _buildDetailRow(
                              'Category', product['types']['category']['name']),
                          const Divider(),
                          _buildDetailRow(
                              'Karat', product['types']['category']['purity']),
                          const Divider(),
                          _buildDetailRow(
                            'Metal Type',
                            MetalTypeConverter.getMetalType(
                                product['types']['category']['metal_type']),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Store Card
                    GestureDetector(
                      onTap: () {
                        final storeId = product['store']['store_id'];
                        context.push('/store/$storeId');
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Colors.white, Color(0xFFF8F8F8)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.15),
                              spreadRadius: 1,
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            // Store logo
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.white, width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 10,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: ClipOval(
                                child: _buildCachedImage(
                                  "$apiBaseUrlImage${product['store']['logo'] ?? ''}",
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Store info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    product['store']['store_name'] ??
                                        'Store Name',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF31394E),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                ],
                              ),
                            ),
                            // Visit store button
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF31394E),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Visit',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                  SizedBox(width: 4),
                                  Icon(
                                    Icons.arrow_forward_ios,
                                    size: 12,
                                    color: Colors.white,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Description Tab
              SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        spreadRadius: 1,
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Description title
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0F0F0),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.description,
                              color: Color(0xFF31394E),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'Product Description',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF31394E),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Description content
                      Text(
                        product['description'] ?? 'No description available',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.black87,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Reviews Tab
              SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Reviews summary
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            spreadRadius: 1,
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF8E1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  product['average_rating'] != null &&
                                          product['average_rating'] > 0
                                      ? '${product['average_rating']}'
                                      : '0.0',
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFF2C94C),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: List.generate(
                                        5,
                                        (index) => Icon(
                                          Icons.star,
                                          size: 20,
                                          color: index <
                                                  (product['average_rating'] ??
                                                          0)
                                                      .floor()
                                              ? const Color(0xFFF2C94C)
                                              : Colors.grey[300],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Based on ${product['total_reviews'] ?? 0} reviews',
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 14,
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

                    const SizedBox(height: 16),

                    // Customer reviews
                    if (product['reviews'] != null &&
                        (product['reviews'] as List).isNotEmpty) ...[
                      const Text(
                        'Customer Reviews',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF31394E),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...List.generate(
                        (product['reviews'] as List).length,
                        (index) {
                          final review = (product['reviews'] as List)[index];
                          return _buildReviewCard(
                            customerName: review['customer_name'] ?? 'Customer',
                            review: review['review'] ?? '',
                            rating: review['rating'] ?? 0,
                            replyAdmin: review['reply_admin'],
                            images: List<String>.from(review['images'] ?? []),
                          );
                        },
                      ),
                    ] else
                      Container(
                        padding: const EdgeInsets.all(24),
                        alignment: Alignment.center,
                        child: Column(
                          children: [
                            Icon(
                              Icons.rate_review_outlined,
                              size: 48,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No reviews yet',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Be the first to review this product',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildImageCarousel() {
    if (_productData == null) return const SizedBox.shrink();

    final product = _productData!;
    final images = <String>[];

    // Collect images from product codes first
    if (product['product_codes']?.isNotEmpty == true) {
      for (final code in product['product_codes']) {
        if (code['image'] != null) {
          images.add('$apiBaseUrlImage${code['image']}');
        }
      }
    }

    // If no images in product codes, use product images
    if (images.isEmpty && product['images'] != null) {
      for (final image in product['images']) {
        images.add('$apiBaseUrlImage$image');
      }
    }

    if (images.isEmpty) {
      return Container(
        height: MediaQuery.of(context).size.width > 800 ? 400 : 300,
        color: Colors.grey[200],
        child: const Center(
          child: Icon(Icons.image_not_supported, size: 64, color: Colors.grey),
        ),
      );
    }

    return Stack(
      children: [
        // Image carousel
        SizedBox(
          height: MediaQuery.of(context).size.width > 800 ? 800 : 350,
          child: PageView.builder(
            controller: _pageController,
            itemCount: images.length,
            onPageChanged: (index) {
              setState(() {
                _currentImageIndex = index;
              });
            },
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          FullScreenImageView(imageUrl: images[index]),
                    ),
                  );
                },
                child: Container(
                  margin: EdgeInsets.symmetric(
                      horizontal:
                          MediaQuery.of(context).size.width > 800 ? 20 : 10),
                  child: Hero(
                    tag: images[index],
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: _buildCachedImage(
                        images[index],
                        width: double.infinity,
                        height:
                            MediaQuery.of(context).size.width > 800 ? 400 : 300,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        // Page indicator
        if (images.length > 1)
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  images.length,
                  (index) => Container(
                    width: _currentImageIndex == index ? 20 : 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: _currentImageIndex == index
                          ? const Color(0xFFC58189)
                          : Colors.grey,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => GoRouter.of(context).pop(),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.8),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.arrow_back,
              color: Color(0xFF31394E),
            ),
          ),
        ),
        actions: [
          GestureDetector(
            onTap: () {
              getAccessToken();
              context.push('/cart');
            },
            child: Container(
              margin: const EdgeInsets.all(8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.8),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.shopping_cart_outlined,
                color: Color(0xFF31394E),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFC58189)),
              ),
            )
          : RefreshIndicator(
              onRefresh: _initializeData,
              color: const Color(0xFFC58189),
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: _buildImageCarousel(),
                  ),
                  SliverToBoxAdapter(
                    child: _buildProductInfo(),
                  ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          if (_productData == null) return;

          final productCodes = _productData!['product_codes'] ?? [];
          if (productCodes.isEmpty) {
            _showToast(
              'No product variants available',
              Colors.red,
              Icons.error,
            );
          } else {
            _showProductCodesModal(context, productCodes, widget.productId);
          }
        },
        backgroundColor: const Color(0xFF31394E),
        elevation: 4,
        icon: const Icon(Icons.add_shopping_cart, color: Colors.white),
        label: const Text(
          'Add to Cart',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
