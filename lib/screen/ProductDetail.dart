import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:marketplace_logamas/converter/metal_type.dart';
import 'package:marketplace_logamas/function/Utils.dart';

class ProductDetailPage extends StatefulWidget {
  final String productId;

  const ProductDetailPage({Key? key, required this.productId})
      : super(key: key);

  @override
  _ProductDetailPageState createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  Future<Map<String, dynamic>> fetchProductDetail(String productId) async {
    final url = Uri.parse('$apiBaseUrl/products/$productId');
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final responseBody = jsonDecode(response.body);
      return responseBody['data'];
    } else {
      throw Exception('Failed to load product');
    }
  }

  Future<bool> addToCartAPI(String userId, String productCodeId) async {
    final url = Uri.parse('$apiBaseUrl/cart');
    print(productCodeId);
    final body = jsonEncode({
      'user_id': userId,
      'product_code_id': productCodeId,
      'quantity': 1,
    });

    print(body);

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
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
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
  }) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  customerName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  children: List.generate(
                    rating,
                    (index) => const Icon(
                      Icons.star,
                      size: 16,
                      color: Colors.amber,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              review,
              style: const TextStyle(fontSize: 14),
            ),
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
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 16),

              // Content
              if (productCodes.isEmpty)
                const Center(
                  child: Text(
                    'No available product codes.',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  itemCount: productCodes.length,
                  itemBuilder: (context, index) {
                    final productCode = productCodes[index];
                    return Card(
                      elevation: 3,
                      margin: const EdgeInsets.symmetric(vertical: 8.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 8.0,
                          horizontal: 16.0,
                        ),
                        title: Text(
                          'Barcode: ${productCode['barcode']}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Weight: ${productCode['weight']} g',
                              style: const TextStyle(
                                  fontSize: 14, color: Colors.grey),
                            ),
                            const SizedBox(
                                height: 4), // Jarak antara weight dan price
                            Text(
                              'Price: Rp ${formatCurrency(productCode['total_price'].toDouble())}', // Menampilkan harga total
                              style: const TextStyle(
                                  fontSize: 14, color: Colors.black54),
                            ),
                          ],
                        ),
                        trailing: ElevatedButton(
                          onPressed: () async {
                            try {
                              final userId = await getUserId();
                              final success = await addToCartAPI(
                                userId,
                                productCode['id'],
                              );
                              print(success);
                              if (success) {
                                Navigator.pop(context); // Tutup modal drawer

                                // Tampilkan snackbar di tengah layar
                                OverlayState? overlayState =
                                    Overlay.of(context);
                                OverlayEntry overlayEntry = OverlayEntry(
                                  builder: (context) => Positioned(
                                    top:
                                        MediaQuery.of(context).size.height / 2 -
                                            40, // Vertikal tengah
                                    left:
                                        MediaQuery.of(context).size.width / 2 -
                                            150, // Horizontal tengah
                                    child: Material(
                                      color: Colors.transparent,
                                      child: Container(
                                        width: 300,
                                        padding: const EdgeInsets.all(16.0),
                                        decoration: BoxDecoration(
                                          color: const Color(
                                              0xFFC58189), // Warna background
                                          borderRadius:
                                              BorderRadius.circular(8.0),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black26,
                                              blurRadius: 8,
                                              offset: Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: const Text(
                                          'Product added to cart!',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),
                                  ),
                                );

                                // Masukkan ke dalam overlay
                                overlayState?.insert(overlayEntry);

                                // Hapus setelah 2 detik
                                await Future.delayed(
                                    const Duration(seconds: 2));
                                overlayEntry.remove();
                              }
                            } catch (e) {
                              // Tampilkan snackbar error di tengah layar
                              OverlayState? overlayState = Overlay.of(context);
                              OverlayEntry overlayEntry = OverlayEntry(
                                builder: (context) => Positioned(
                                  top: MediaQuery.of(context).size.height / 2 -
                                      40, // Vertikal tengah
                                  left: MediaQuery.of(context).size.width / 2 -
                                      150, // Horizontal tengah
                                  child: Material(
                                    color: Colors.transparent,
                                    child: Container(
                                      width: 300,
                                      padding: const EdgeInsets.all(16.0),
                                      decoration: BoxDecoration(
                                        color: Colors
                                            .red, // Warna background untuk error
                                        borderRadius:
                                            BorderRadius.circular(8.0),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black26,
                                            blurRadius: 8,
                                            offset: Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: Text(
                                        'Have Added to Cart!',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                                ),
                              );

                              // Masukkan ke dalam overlay
                              overlayState?.insert(overlayEntry);

                              // Hapus setelah 2 detik
                              await Future.delayed(const Duration(seconds: 2));
                              overlayEntry.remove();
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF31394E),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Add',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFC58189),
                            ),
                          ),
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
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: GestureDetector(
          onTap: () => GoRouter.of(context).pop(),
          child: const Icon(
            Icons.arrow_back,
            color: Colors.white,
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
        backgroundColor: const Color(0xFF31394E),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: fetchProductDetail(widget.productId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: const TextStyle(color: Colors.red, fontSize: 18),
              ),
            );
          } else if (!snapshot.hasData || snapshot.data == null) {
            return const Center(
              child: Text('Product not found', style: TextStyle(fontSize: 18)),
            );
          }

          final product = snapshot.data!;
          final productCodes = product['product_codes'] ?? [];
          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product Image
                  SizedBox(
                    height: 300,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount:
                          5, // Jumlah gambar random yang ingin ditampilkan
                      itemBuilder: (context, index) {
                        final imageUrl =
                            'https://picsum.photos/seed/$index/600/400'; // URL gambar random
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.network(
                              imageUrl,
                              height: 300,
                              width: MediaQuery.of(context).size.width * 0.8,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  height: 300,
                                  width:
                                      MediaQuery.of(context).size.width * 0.8,
                                  color: Colors.grey[200],
                                  child: const Icon(
                                    Icons.broken_image,
                                    size: 50,
                                    color: Colors.grey,
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Product Name and Stock
                  Text(
                    product['name'] ?? 'Product Name',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text(
                        'Price:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (product['low_price'] != null &&
                          product['high_price'] != null)
                        Text(
                          (product['low_price'] != null &&
                                  product['high_price'] != null)
                              ? (product['low_price'] == product['high_price']
                                  ? 'Rp ${formatCurrency(product['low_price'].toDouble())}' // Jika sama, tampilkan satu nilai
                                  : 'Rp ${formatCurrency(product['low_price'].toDouble())} - Rp ${formatCurrency(product['high_price'].toDouble())}') // Jika berbeda, tampilkan rentang
                              : 'Not available', // Jika salah satu null, tampilkan teks default
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      else
                        Text(
                          'Not available',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.red.shade600,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text(
                        'Stock: ',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                      Text(
                        product['stock'] > 0
                            ? '${product['stock']}'
                            : 'Out of Stock',
                        style: TextStyle(
                          fontSize: 16,
                          color:
                              product['stock'] > 0 ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Product Stats
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildStat(
                        product['rating'] != null
                            ? '⭐ ${product['rating']}'
                            : 'No Rate',
                        'Rating',
                      ),
                      _buildStat(
                          product['totalSold'] != null
                              ? '${product['totalSold']}'
                              : 'Not Sold',
                          'Terjual'),
                      _buildStat(
                        (product['min_weight'] != null &&
                                product['max_weight'] != null)
                            ? (product['min_weight'] == product['max_weight']
                                ? '${product['min_weight']} g' // Jika sama, tampilkan salah satu
                                : '${product['min_weight']} - ${product['max_weight']} g') // Jika berbeda, tampilkan rentang
                            : 'N/A', // Jika salah satu null, tampilkan N/A
                        'Weight',
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Product Details
                  Text(
                    'Details',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
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

                  Text(
                    'Description',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
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
                      final storeId = product['store']
                          ['store_id']; // Ambil store_id dari store
                      context.push(
                        '/store/$storeId', // Gunakan storeId sebagai bagian dari path
                      );
                    },
                    // onTap: () {
                    //   context.go('/store',
                    //       extra: {'storeId': product['store_id']});
                    // },
                    child: Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(
                                  8), // Optional: Rounded corners
                              child: Image.network(
                                "$apiBaseUrlImage${product['store']['image_url'] ?? ''}", // Full URL for the image
                                height: 40,
                                width: 40,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Icon(
                                    Icons.store,
                                    size: 40,
                                    color: Color(0xFF31394E),
                                  ); // Fallback icon if image fails to load
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  product['store']['store_name'] ??
                                      'Store Name',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Text(
                                  'Tap to view store',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // List of Reviews
                  if (product['TransactionItem'] != null &&
                      product['TransactionItem'] is List)
                    Text(
                      'Reviews',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  const SizedBox(height: 6),
                  if (product['TransactionItem'] != null &&
                      (product['TransactionItem'] as List).isNotEmpty)
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: (product['TransactionItem'] as List)
                          .where((item) =>
                              item['review'] != null || item['rating'] != null)
                          .length, // Hitung hanya yang punya review/rating
                      itemBuilder: (context, index) {
                        final filteredReviews = (product['TransactionItem']
                                as List)
                            .where((item) =>
                                item['review'] != null ||
                                item['rating'] != null)
                            .toList(); // Filter hanya yang punya review/rating
                        final transactionItem = filteredReviews[index];
                        final customer =
                            transactionItem['transaction']['customer'];
                        return _buildReviewCard(
                          customerName: customer['name'],
                          review: transactionItem['review'] ?? '',
                          rating: transactionItem['rating'] ?? 0,
                        );
                      },
                    )
                  else
                    const Text(
                      'No reviews yet.',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
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
