import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:marketplace_logamas/function/Utils.dart';
import 'package:cached_network_image/cached_network_image.dart';

class WishlistPage extends StatefulWidget {
  const WishlistPage({Key? key}) : super(key: key);

  @override
  _WishlistPageState createState() => _WishlistPageState();
}

class _WishlistPageState extends State<WishlistPage> {
  List<dynamic> wishlistProducts = [];
  bool isLoading = true;
  String? _accessToken;

  @override
  void initState() {
    super.initState();
    loadAccessToken();
    fetchWishlist();
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

  Future<void> fetchWishlist() async {
    setState(() {
      isLoading = true;
    });

    try {
      final userId = await getUserId();
      final response = await http.get(
        Uri.parse('$apiBaseUrl/wishlist'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_accessToken',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body)['data'];
        print(data);
        setState(() {
          wishlistProducts = List<Map<String, dynamic>>.from(data);
        });
      } else {
        throw Exception('Failed to fetch wishlist');
      }
    } catch (e) {
      print('Error fetching wishlist: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> toggleWishlist(String productId) async {
    final userId = await getUserId();

    try {
      final response = await http.delete(
        Uri.parse('$apiBaseUrl/wishlist/$productId'),
        headers: {'Authorization': 'Bearer $_accessToken'},
      );

      if (response.statusCode == 200) {
        setState(() {
          wishlistProducts.removeWhere(
              (product) => product['product']['product_id'] == productId);
        });

        // Show success message overlay
        showWishlistConfirmation(false);
      } else {
        final responseBody = jsonDecode(response.body);
        throw Exception(responseBody['message'] ?? 'Failed to update wishlist');
      }
    } catch (e) {
      showWishlistConfirmation(false, isError: true);
    }
  }

  void showWishlistConfirmation(bool added, {bool isError = false}) {
    OverlayState? overlayState = Overlay.of(context);
    OverlayEntry overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).size.height / 2 - 40,
        left: MediaQuery.of(context).size.width / 2 - 150,
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 300,
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: isError
                  ? Colors.red
                  : (added ? const Color(0xFFC58189) : Colors.grey[800]),
              borderRadius: BorderRadius.circular(8.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  added ? Icons.favorite : Icons.favorite_border,
                  color: Colors.white,
                  size: 24,
                ),
                const SizedBox(width: 10),
                Text(
                  isError
                      ? 'Failed to update wishlist'
                      : (added
                          ? 'Added to Wishlist 🩷'
                          : 'Removed from Wishlist 🖤'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    overlayState?.insert(overlayEntry);

    // Hapus overlay setelah 2 detik
    Future.delayed(const Duration(seconds: 2), () {
      overlayEntry.remove();
    });
  }

  // Custom ProductCard with wishlist toggle and stock flag
  Widget CustomWishlistProductCard(Map<String, dynamic> product) {
    // Extract product data with null safety
    final String productName = product['name'] ?? "Unknown Product";
    final double productPrice = (product['low_price'] ?? 0).toDouble();
    final double avgRating = (product['average_rating'] ?? 0).toDouble();
    final int totalSold = product['totalSold'] ?? 0;
    final String storeName = product['store']?['store_name'] ?? 'Unknown Store';
    final int stocks = product['stocks'] ?? 0;
    final String productId = product['product_id'] ?? '';
    final bool isOutOfStock = stocks <= 0;

    // Image handling with better fallback strategy
    String productImage = _getProductImage(product);

    return Card(
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      elevation: 2,
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product Image with loading and error handling
              Expanded(
                child: Stack(
                  children: [
                    CachedNetworkImage(
                      imageUrl: productImage,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      fadeInDuration: Duration.zero,
                      placeholderFadeInDuration: Duration.zero,
                      placeholder: (context, url) => Container(
                        width: double.infinity,
                        height: double.infinity,
                        color: Colors.grey[200],
                        child: Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2.0,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                Color(0xFFC58189)),
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        width: double.infinity,
                        height: double.infinity,
                        color: Colors.grey[200],
                        child:
                            Icon(Icons.image_not_supported, color: Colors.grey),
                      ),
                    ),
                    // Out of Stock Overlay
                    if (isOutOfStock)
                      Container(
                        width: double.infinity,
                        height: double.infinity,
                        color: Colors.black.withOpacity(0.5),
                        child: Center(
                          child: Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'SOLD OUT',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Product Details
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product Name
                    Text(
                      productName,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isOutOfStock ? Colors.grey : Colors.black,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4),

                    // Product Price
                    Text(
                      'Rp. ${formatCurrency(productPrice)}',
                      style: TextStyle(
                        color: isOutOfStock ? Colors.grey : Color(0xFFC58189),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    SizedBox(height: 4),

                    // Stock Info
                    if (!isOutOfStock)
                      Text(
                        'Stok: $stocks',
                        style: TextStyle(
                          fontSize: 12,
                          color: stocks <= 5 ? Colors.orange : Colors.green,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    SizedBox(height: 4),

                    // Rating and Sold Info
                    _buildRatingAndSoldInfo(avgRating, totalSold, isOutOfStock),
                    SizedBox(height: 4),

                    // Location Info
                    Row(
                      children: [
                        Icon(Icons.store_sharp,
                            size: 14,
                            color:
                                isOutOfStock ? Colors.grey : Colors.grey[600]),
                        SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            storeName,
                            style: TextStyle(
                                fontSize: 12,
                                color: isOutOfStock
                                    ? Colors.grey
                                    : Colors.grey[700]),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Wishlist Toggle Button
          Positioned(
            top: 8,
            right: 8,
            child: GestureDetector(
              onTap: () => toggleWishlist(productId),
              child: Container(
                padding: EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.favorite,
                  color: Color(0xFFC58189),
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to determine product image
  String _getProductImage(Map<String, dynamic> product) {
    // Check product_codes first
    if (product['product_codes'] != null &&
        product['product_codes'] is List &&
        product['product_codes'].isNotEmpty &&
        product['product_codes'][0]['image'] != null) {
      return '$apiBaseUrlImage${product['product_codes'][0]['image']}';
    }

    // Then check images array
    if (product['images'] != null &&
        product['images'] is List &&
        product['images'].isNotEmpty) {
      return '$apiBaseUrlImage${product['images'][0]}';
    }

    // Use a random placeholder as last resort
    return 'https://picsum.photos/200/200?random=${Random().nextInt(1000)}';
  }

  // Helper method to build rating and sold information
  Widget _buildRatingAndSoldInfo(
      double avgRating, int totalSold, bool isOutOfStock) {
    final String displayText = (avgRating <= 0)
        ? (totalSold > 0
            ? 'No Rating | $totalSold Terjual'
            : 'No Rating & Sales')
        : '${avgRating.toStringAsFixed(1)} | $totalSold Terjual';

    return Row(
      children: [
        Icon(Icons.star,
            size: 14, color: isOutOfStock ? Colors.grey : Colors.orange),
        SizedBox(width: 4),
        Text(
          displayText,
          style: TextStyle(
            fontSize: 12,
            color: isOutOfStock ? Colors.grey : Colors.black,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        flexibleSpace: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/appbar.png',
              fit: BoxFit.cover,
            ),
            Container(
              color: Colors.black.withOpacity(0.2),
            ),
          ],
        ),
        title: const Text(
          'Wishlist',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(
            Icons.arrow_back,
            color: Colors.white,
          ),
        ),
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFC58189)),
            )
          : wishlistProducts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.favorite_border,
                          size: 80, color: Colors.grey.shade400),
                      const SizedBox(height: 10),
                      Text(
                        'No items in wishlist',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Browse products and add them to your wishlist.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 0.7,
                  ),
                  itemCount: wishlistProducts.length,
                  itemBuilder: (context, index) {
                    final product = wishlistProducts[index]['product'];

                    return GestureDetector(
                      onTap: () {
                        context
                            .push('/product-detail/${product['product_id']}');
                      },
                      child: CustomWishlistProductCard(product),
                    );
                  },
                ),
    );
  }
}
