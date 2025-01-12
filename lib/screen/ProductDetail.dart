import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
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
    final url =
        Uri.parse('$apiBaseUrl/products/$productId'); // Sesuaikan URL API
    final response = await http.get(url);
    print(jsonDecode(response.body));
    if (response.statusCode == 200) {
      final responseBody = jsonDecode(response.body);
      return responseBody['data'];
    } else {
      throw Exception('Failed to load product');
    }
  }

  Future<bool> addToCartAPI(
      String userId, String productId, int quantity) async {
    final url = Uri.parse('$apiBaseUrl/cart'); // URL API Anda
    final body = jsonEncode({
      'user_id': userId,
      'product_id': productId,
      'quantity': quantity,
    });

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );
      final responseBody= jsonDecode(response.body);
      if (response.statusCode == 201) {
        final result = jsonDecode(response.body);
        if (result['success']) {
          return true; // Indikasi berhasil
        } else {
          throw Exception(result['message']); // Lempar pesan error dari server
        }
      } else {
        throw responseBody['message'];
      }
    } catch (e) {
      print('Error adding product to cart: $e');
      throw e; // Lempar kembali error agar bisa ditangani di tempat lain
    }
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
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10.0),
            child: Icon(
              Icons.arrow_back,
              color: Colors.white,
            ),
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
                    // Navigator.pushReplacementNamed(
                    //     context, '/cart');
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
          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product Image
                  Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(
                        product['imageUrl'] ??
                            'https://picsum.photos/200/200?random=1',
                        height: 300,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
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
                      _buildStat('${product['totalSold']}', 'Terjual'),
                      _buildStat('${product['weight']} g', 'Weight'),
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
                  _buildDetailRow('Category', product['type']['name']),
                  _buildDetailRow('Karat', product['type']['purity']),
                  _buildDetailRow('Gold Type', product['type']['metal_type']),
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
                      final storeId =
                          product['store_id']; // Ambil store_id dari store
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
                      itemCount: (product['TransactionItem'] as List).length,
                      itemBuilder: (context, index) {
                        final transactionItem =
                            product['TransactionItem'][index];
                        final customer =
                            transactionItem['transaction']['customer'];
                        return _buildReviewCard(
                          customerName: customer['name'],
                          review: transactionItem['review'] ??
                              'No comment provided.',
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
          try {
            // Ambil userId dari SharedPreferences
            String userId = await getUserId();

            // Panggil API untuk menambahkan ke keranjang
            final response = await addToCartAPI(userId, widget.productId, 1);

            // Tampilkan dialog sukses jika berhasil
            if (response) {
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (BuildContext dialogContext) {
                  return Center(
                    child: Material(
                      color: Colors.transparent,
                      child: Container(
                        padding: const EdgeInsets.all(16.0),
                        decoration: BoxDecoration(
                          color: const Color(0xFFC58189),
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                        child: const Text(
                          'Product added to cart!',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );

              // Hapus dialog setelah beberapa detik
              Future.delayed(const Duration(seconds: 2), () {
                Navigator.of(context, rootNavigator: true)
                    .pop(); // Pastikan hanya menutup dialog
              });
            }
          } catch (e) {
            // Jika gagal mendapatkan userId atau API gagal
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '$e',
                  textAlign: TextAlign.center,
                ),
                backgroundColor: const Color.fromARGB(255, 244, 110, 100),
              ),
            );
          }
        },
        child: const Icon(
          Icons.add_shopping_cart,
          color: Colors.white,
        ),
        backgroundColor: const Color(0xFFC58189),
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
}
