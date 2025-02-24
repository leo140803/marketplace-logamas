import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:marketplace_logamas/converter/metal_type.dart';
import 'package:marketplace_logamas/function/Utils.dart';
import 'package:marketplace_logamas/screen/FullScreenImageView.dart';

class ProductDetailPage extends StatefulWidget {
  final String productId;

  const ProductDetailPage({Key? key, required this.productId})
      : super(key: key);

  @override
  _ProductDetailPageState createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  bool isWishlisted = false;
  String? _accessToken;

  @override
  void initState() {
    super.initState();
    loadAccessToken();
    getUserId().then((userId) {
      checkWishlistStatus(userId, widget.productId);
    });
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

  Future<void> checkWishlistStatus(String userId, String productId) async {
    final url =
        Uri.parse('$apiBaseUrl/wishlist/is-wishlist?product_id=$productId');
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
        isWishlisted =
            responseBody['data'] ?? false; // Jika true berarti ada di wishlist
      });
    } else {
      setState(() {
        isWishlisted = false;
      });
    }
  }

  Future<void> toggleWishlist(String userId, String productId) async {
    print(productId);
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
          isWishlisted = !isWishlisted; // Toggle wishlist status
        });

        // Show success message
        showWishlistConfirmation(isWishlisted);
      } else {
        final responseBody = jsonDecode(response.body);
        throw Exception(responseBody['message'] ?? 'Failed to update wishlist');
      }
    } catch (e) {
      showWishlistConfirmation(false);
    }
  }

  void showWishlistConfirmation(bool added) {
    OverlayState? overlayState = Overlay.of(context);
    OverlayEntry overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).size.height / 2 - 40,
        left: MediaQuery.of(context).size.width / 2 - 150,
        child: Material(
          color: Colors.transparent,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            width: 300,
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: added
                  ? const Color(0xFFC58189)
                  : Colors.red, // Warna berubah jika unwishlist
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
                  added ? 'Added to Wishlist 🩷' : 'Removed from Wishlist 🖤',
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

  Future<Map<String, dynamic>> fetchProductDetail(String productId) async {
    final url = Uri.parse('$apiBaseUrl/products/$productId');
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final Map<String, dynamic> responseBody = jsonDecode(response.body);
      // Response format: { "success": true, "message": "...", "data": { ... } }
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

  Widget _buildStat(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.grey)),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16, color: Colors.grey)),
          Text(value,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildReviewCard({
  required String customerName,
  required String review,
  required int rating,
  String? replyAdmin,
}) {
  return Card(
    color: Colors.white,
    elevation: 4,
    margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 5),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    child: Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Customer Name + Rating
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                customerName,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF31394E)),
              ),
              Row(
                children: List.generate(
                  5,
                  (index) => Icon(
                    Icons.star,
                    size: 18,
                    color: index < rating ? Color(0xFFF2C94C) : Colors.grey[300],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Review Text
          Text(
            review,
            style: const TextStyle(fontSize: 14, color: Colors.black87),
          ),

          // Admin Reply (if available)
          if (replyAdmin != null && replyAdmin.isNotEmpty) ...[
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.admin_panel_settings_rounded,
                    color: Colors.blue.shade700, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: const LinearGradient(
                        colors: [Color(0xFFDBEAFE), Color(0xFF93C5FD)],
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
                            color: Color(0xFF1E3A8A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          replyAdmin,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black87,
                          ),
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


  void _showProductCodesModal(
      BuildContext context, List productCodes, String productId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                width: 50,
                height: 5,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const Text(
                'Select Product Code',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87),
              ),
              const SizedBox(height: 16),
              // Content
              if (productCodes.isEmpty)
                const Center(
                  child: Text('No available product codes.',
                      style: TextStyle(fontSize: 16, color: Colors.grey)),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  itemCount: productCodes.length,
                  itemBuilder: (context, index) {
                    final productCode = productCodes[index];
                    final imageUrl = productCode['image'] != null
                        ? 'http://127.0.0.1:3000${productCode['image']}'
                        : 'https://via.placeholder.com/150'; // Placeholder jika tidak ada gambar

                    return Card(
                      elevation: 3,
                      margin: const EdgeInsets.symmetric(vertical: 8.0),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            vertical: 8.0, horizontal: 16.0),
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            imageUrl,
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                width: 60,
                                height: 60,
                                color: Colors.grey[300],
                                child: const Icon(Icons.broken_image,
                                    size: 30, color: Colors.grey),
                              );
                            },
                          ),
                        ),
                        title: Text(
                          'Barcode: ${productCode['barcode']}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Weight: ${productCode['weight']} g',
                                style: const TextStyle(
                                    fontSize: 14, color: Colors.grey)),
                            const SizedBox(height: 4),
                            Text(
                              'Price: Rp ${formatCurrency(productCode['total_price'].toDouble())}',
                              style: const TextStyle(
                                  fontSize: 14, color: Colors.black54),
                            ),
                          ],
                        ),
                        trailing: ElevatedButton(
                          onPressed: () async {
                            try {
                              final userId = await getUserId();
                              final success =
                                  await addToCartAPI(userId, productCode['id']);
                              if (success) {
                                Navigator.pop(context); // Close modal
                                // Show success snackbar overlay
                                OverlayState? overlayState =
                                    Overlay.of(context);
                                OverlayEntry overlayEntry = OverlayEntry(
                                  builder: (context) => Positioned(
                                    top:
                                        MediaQuery.of(context).size.height / 2 -
                                            40,
                                    left:
                                        MediaQuery.of(context).size.width / 2 -
                                            150,
                                    child: Material(
                                      color: Colors.transparent,
                                      child: Container(
                                        width: 300,
                                        padding: const EdgeInsets.all(16.0),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFC58189),
                                          borderRadius:
                                              BorderRadius.circular(8.0),
                                          boxShadow: [
                                            BoxShadow(
                                                color: Colors.black26,
                                                blurRadius: 8,
                                                offset: Offset(0, 4))
                                          ],
                                        ),
                                        child: const Text(
                                          'Product added to cart!',
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                                overlayState?.insert(overlayEntry);
                                await Future.delayed(
                                    const Duration(seconds: 2));
                                overlayEntry.remove();
                              }
                            } catch (e) {
                              // Show error overlay
                              OverlayState? overlayState = Overlay.of(context);
                              OverlayEntry overlayEntry = OverlayEntry(
                                builder: (context) => Positioned(
                                  top: MediaQuery.of(context).size.height / 2 -
                                      40,
                                  left: MediaQuery.of(context).size.width / 2 -
                                      150,
                                  child: Material(
                                    color: Colors.transparent,
                                    child: Container(
                                      width: 300,
                                      padding: const EdgeInsets.all(16.0),
                                      decoration: BoxDecoration(
                                        color: Colors.red,
                                        borderRadius:
                                            BorderRadius.circular(8.0),
                                        boxShadow: [
                                          BoxShadow(
                                              color: Colors.black26,
                                              blurRadius: 8,
                                              offset: Offset(0, 4))
                                        ],
                                      ),
                                      child: const Text(
                                        'Failed to add product to cart!',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                              overlayState?.insert(overlayEntry);
                              await Future.delayed(const Duration(seconds: 2));
                              overlayEntry.remove();
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF31394E),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Add',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFC58189))),
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Product Detail',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: GestureDetector(
          onTap: () => GoRouter.of(context).pop(),
          child: const Icon(Icons.arrow_back, color: Colors.white),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 0, 10, 10),
            child: IconButton(
              icon: Icon(
                isWishlisted
                    ? Icons.favorite
                    : Icons.favorite_border, // Love icon
                color: isWishlisted ? Colors.red : Colors.white,
              ),
              onPressed: () async {
                final userId = await getUserId();
                await toggleWishlist(userId, widget.productId);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 0, 10, 10),
            child: IconButton(
              icon:
                  const Icon(Icons.shopping_cart_outlined, color: Colors.white),
              onPressed: () {
                getAccessToken();
                context.push('/cart');
              },
            ),
          ),
        ],
        backgroundColor: const Color(0xFF31394E),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: fetchProductDetail(widget.productId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}',
                  style: const TextStyle(color: Colors.red, fontSize: 18)),
            );
          } else if (!snapshot.hasData || snapshot.data == null) {
            return const Center(
                child:
                    Text('Product not found', style: TextStyle(fontSize: 18)));
          }

          final product = snapshot.data!;
          final productCodes = product['product_codes'] ?? [];
          final reviews = product['reviews'] as List? ?? [];
          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product Image Carousel (Placeholder Images)
                  SizedBox(
                    height:
                        350, // Tambahkan ruang ekstra untuk teks di atas gambar
                    child: Stack(
                      children: [
                        PageView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: product['product_codes']?.isNotEmpty ==
                                  true
                              ? product['product_codes']
                                  .length // Tampilkan semua product_codes
                              : product['images']?.length ??
                                  0, // Jika tidak ada, pakai images dari product
                          itemBuilder: (context, index) {
                            // Ambil gambar dari product_code jika tersedia, jika tidak pakai dari product
                            final productCode =
                                product['product_codes']?.isNotEmpty == true
                                    ? product['product_codes'][index]
                                    : null;

                            final imageUrl = productCode != null &&
                                    productCode['image'] != null
                                ? 'http://127.0.0.1:3000${productCode['image']}'
                                : 'http://127.0.0.1:3000/uploads/${product['images'][index]}';

                            return Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8.0),
                              child: GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => FullScreenImageView(
                                          imageUrl: imageUrl),
                                    ),
                                  );
                                },
                                child: Hero(
                                  tag: imageUrl,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: Stack(
                                      children: [
                                        Image.network(
                                          imageUrl,
                                          height: 300,
                                          width: MediaQuery.of(context)
                                                  .size
                                                  .width *
                                              0.8,
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stackTrace) {
                                            return Container(
                                              height: 300,
                                              width: MediaQuery.of(context)
                                                      .size
                                                      .width *
                                                  0.8,
                                              color: Colors.grey[200],
                                              child: const Icon(
                                                  Icons.broken_image,
                                                  size: 50,
                                                  color: Colors.grey),
                                            );
                                          },
                                        ),
                                        if (productCode != null) ...[
                                          Positioned(
                                            bottom: 10,
                                            right: 10,
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.all(8.0),
                                              decoration: BoxDecoration(
                                                color: Colors.black
                                                    .withOpacity(0.6),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.end,
                                                children: [
                                                  Text(
                                                    'Barcode: ${productCode['barcode']}',
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    'Weight: ${productCode['weight']} g',
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Product Name
                  Text(
                    product['name'] ?? 'Product Name',
                    style: const TextStyle(
                        fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),

                  // Price and Stock
                  Row(
                    children: [
                      const Text('Price:',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey)),
                      const SizedBox(width: 8),
                      if (product['low_price'] != null &&
                          product['high_price'] != null)
                        Text(
                          product['low_price'] == product['high_price']
                              ? 'Rp ${formatCurrency(product['low_price'].toDouble())}'
                              : 'Rp ${formatCurrency(product['low_price'].toDouble())} - Rp ${formatCurrency(product['high_price'].toDouble())}',
                          style: TextStyle(
                              fontSize: 16,
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.bold),
                        )
                      else
                        Text('Not available',
                            style: TextStyle(
                                fontSize: 16,
                                color: Colors.red.shade600,
                                fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text('Stock: ',
                          style: TextStyle(fontSize: 16, color: Colors.grey)),
                      Text(
                        product['stock'] > 0
                            ? '${product['stock']}'
                            : 'Out of Stock',
                        style: TextStyle(
                            fontSize: 16,
                            color: product['stock'] > 0
                                ? Colors.green
                                : Colors.red,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Stats Row (Rating, Terjual, Weight)
                  Row(
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
                        'Terjual',
                      ),
                      _buildStat(
                        (product['min_weight'] != null &&
                                product['max_weight'] != null)
                            ? (product['min_weight'] == product['max_weight']
                                ? '${product['min_weight']} g'
                                : '${product['min_weight']} - ${product['max_weight']} g')
                            : 'N/A',
                        'Weight',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Product Details
                  Text(
                    'Details',
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  _buildDetailRow(
                      'Category', product['types']['category']['name']),
                  _buildDetailRow(
                      'Karat', product['types']['category']['purity']),
                  _buildDetailRow(
                      'Metal Type',
                      MetalTypeConverter.getMetalType(
                          product['types']['category']['metal_type'])),
                  const SizedBox(height: 16),

                  // Description
                  Text(
                    'Description',
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    product['description'] ?? '',
                    style: const TextStyle(fontSize: 16, color: Colors.black87),
                  ),
                  const SizedBox(height: 16),

                  // Store Card
                  GestureDetector(
                    onTap: () {
                      final storeId = product['store']['store_id'];
                      context.push('/store/$storeId');
                    },
                    child: Card(
                      elevation: 6,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      margin: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 5),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFF4F4F4), Color(0xFFE8E8E8)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            // Store Image
                            Container(
                              height: 60,
                              width: 60,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.white, width: 2),
                                boxShadow: [
                                  BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 10,
                                      offset: const Offset(0, 5)),
                                ],
                              ),
                              child: ClipOval(
                                child: Image.network(
                                  "$apiBaseUrlImage${product['store']['logo'] ?? ''}",
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      color: Colors.grey[300],
                                      child: const Icon(Icons.store,
                                          size: 30, color: Colors.grey),
                                    );
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Store Info
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
                                        color: Color(0xFF31394E)),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text('Tap to view store',
                                      style: TextStyle(
                                          fontSize: 12, color: Colors.grey)),
                                ],
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios,
                                size: 16, color: Colors.grey),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),
                  // Reviews Section
                  Text(
                    'Reviews',
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  // Display average rating and total reviews
                  Row(
                    children: [
                      Text(
                        product['average_rating'] != null &&
                                product['average_rating'] > 0
                            ? '⭐ ${product['average_rating']}'
                            : 'No Rating',
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFC58189)),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '(${product['total_reviews']} Reviews)',
                        style:
                            const TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // List Reviews
                  if (product['reviews'] != null &&
                      (product['reviews'] as List).isNotEmpty)
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: (product['reviews'] as List).length,
                      itemBuilder: (context, index) {
                        final review = (product['reviews'] as List)[index];
                        return _buildReviewCard(
                          customerName: review['customer_name'] ?? '',
                          review: review['review'] ?? '',
                          rating: review['rating'] ?? 0,
                          replyAdmin: review['reply_admin'],
                        );
                      },
                    )
                  else
                    const Text('No reviews yet.',
                        style: TextStyle(fontSize: 16, color: Colors.grey)),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final productDetail = await fetchProductDetail(widget.productId);
          final productCodes = productDetail['product_codes'] ?? [];
          if (productCodes.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No available product codes'),
                backgroundColor: Colors.red,
              ),
            );
          } else {
            _showProductCodesModal(context, productCodes, widget.productId);
          }
        },
        child: const Icon(Icons.add_shopping_cart),
        backgroundColor: const Color(0xFFC58189),
      ),
    );
  }
}
