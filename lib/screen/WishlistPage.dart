import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:marketplace_logamas/function/Utils.dart';
import 'package:marketplace_logamas/widget/ProductCard.dart';

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
        setState(() {
          wishlistProducts = List<Map<String, dynamic>>.from(data);
        });
      } else {
        throw Exception('Failed to fetch wishlist');
      }
    } catch (e) {
      print('Error fetching wishlist: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to fetch wishlist'),
          backgroundColor: Colors.red,
        ),
      );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'Wishlist',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          onPressed: () => context.go('/information'),
          icon: const Icon(
            Icons.arrow_back,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF31394E),
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
                      child: Stack(
                        children: [
                          ProductCard(product),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
