import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'dart:math';

import 'package:marketplace_logamas/function/Utils.dart';

class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  List<Map<String, dynamic>> cartData = [];
  bool isLoading = true;
  String userId = '';

  final List<bool> _selectedStores = [];
  final List<List<bool>> _selectedProducts = [];
  final String baseUrl = "$apiBaseUrl/cart";

  @override
  void initState() {
    super.initState();
    _initializeAndFetchData();
  }

  Future<void> _initializeAndFetchData() async {
    try {
      userId = await getUserId();
      await _fetchCartData();
    } catch (e) {
      print("Error: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _fetchCartData() async {
    try {
      final response = await http.get(Uri.parse('$apiBaseUrl/cart/$userId'));
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        setState(() {
          cartData =
              (responseData['data'] as List).cast<Map<String, dynamic>>();
          isLoading = false;
          _initializeSelection();
        });
      } else {
        throw Exception("Failed to fetch cart data");
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      print("Error fetching cart data: $e");
    }
  }

  void _initializeSelection() {
    _selectedStores.clear();
    _selectedProducts.clear();
    for (var store in cartData) {
      _selectedStores.add(false);
      _selectedProducts
          .add(List.generate(store["ProductList"].length, (_) => false));
    }
  }

  Future<void> _deleteCartItem(String cartId) async {
    try {
      final response = await http.delete(Uri.parse('$baseUrl/$cartId'));
      if (response.statusCode == 200) {
        setState(() {
          _fetchCartData();
        });
      } else {
        throw Exception('Failed to delete cart item');
      }
    } catch (e) {
      print('Error deleting cart item: $e');
    }
  }

  bool _hasSelectedProducts() {
    for (int i = 0; i < _selectedProducts.length; i++) {
      if (_selectedProducts[i].contains(true)) {
        return true;
      }
    }
    return false;
  }

  Map<String, dynamic> _prepareCheckoutData() {
    final selectedData = [];
    for (int storeIndex = 0; storeIndex < cartData.length; storeIndex++) {
      final selectedProducts = [];
      for (int productIndex = 0;
          productIndex < _selectedProducts[storeIndex].length;
          productIndex++) {
        if (_selectedProducts[storeIndex][productIndex]) {
          final product = cartData[storeIndex]["ProductList"][productIndex];
          selectedProducts.add({
            ...product,
            "quantity": 1, // Tambahkan field quantity dengan nilai 1
          });
        }
      }
      if (selectedProducts.isNotEmpty) {
        selectedData.add({
          "store": cartData[storeIndex]["store"],
          "ProductList": selectedProducts,
        });
      }
    }
    return {"data": selectedData};
  }

  int _calculateTotal() {
    int total = 0;
    for (int i = 0; i < cartData.length; i++) {
      for (int j = 0; j < cartData[i]["ProductList"].length; j++) {
        if (_selectedProducts[i][j]) {
          total += (cartData[i]["ProductList"][j]["productPrice"] as int);
        }
      }
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F4),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          color: Colors.white,
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Keranjang',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF31394E),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : cartData.isEmpty
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Ilustrasi
                        Image.asset(
                          'assets/images/empty_cart.png', // Pastikan Anda memiliki gambar ini di folder assets
                          width: 200,
                          height: 200,
                        ),
                        // Teks utama
                        const Text(
                          "Keranjang Anda Kosong",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF31394E),
                          ),
                        ),
                        const SizedBox(height: 10),
                        // Teks ajakan
                        const Text(
                          "Mulai belanja sekarang dan tambahkan produk favorit Anda ke keranjang!",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Tombol ajakan
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF31394E),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 30, vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () {
                            context.push('/home'); // Arahkan ke halaman utama
                          },
                          child: const Text(
                            "Belanja Sekarang",
                            style: TextStyle(fontSize: 16, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(10),
                  itemCount: cartData.length,
                  itemBuilder: (context, storeIndex) {
                    final store = cartData[storeIndex];
                    return Card(
                      color: Colors.white,
                      margin: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Checkbox(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  activeColor: const Color(0xFFC58189),
                                  value: _selectedStores[storeIndex],
                                  onChanged: (bool? value) {
                                    setState(() {
                                      _selectedStores[storeIndex] =
                                          value ?? false;
                                      _selectedProducts[storeIndex] =
                                          List.generate(
                                              store["ProductList"].length,
                                              (_) => value ?? false);
                                    });
                                  },
                                ),
                                Text(
                                  store["store"]["store_name"],
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            ...List.generate(
                              store["ProductList"].length,
                              (productIndex) {
                                final product =
                                    store["ProductList"][productIndex];
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Row(
                                    children: [
                                      Checkbox(
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        activeColor: const Color(0xFFC58189),
                                        value: _selectedProducts[storeIndex]
                                            [productIndex],
                                        onChanged: (bool? value) {
                                          setState(() {
                                            _selectedProducts[storeIndex]
                                                [productIndex] = value ?? false;
                                            _selectedStores[storeIndex] =
                                                _selectedProducts[storeIndex]
                                                    .every(
                                                        (selected) => selected);
                                          });
                                        },
                                      ),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: Image.network(
                                          product["productImage"] ??
                                              "https://picsum.photos/200/200?random=${Random().nextInt(1000)}",
                                          width: 80,
                                          height: 80,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              product["productName"],
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 5),
                                            Text(
                                              'Rp. ${formatCurrency(product["productPrice"].toDouble())}',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Color(0xFFC58189),
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 5),
                                            Text(
                                              'Weight: ${product["productWeight"]} g',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete,
                                            color: Colors.red),
                                        onPressed: () =>
                                            _deleteCartItem(product["cart_id"]),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      bottomNavigationBar: Container(
        height: 80,
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.5),
              spreadRadius: 0,
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Total: Rp. ${formatCurrency(_calculateTotal().toDouble())}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _hasSelectedProducts()
                    ? const Color(0xFF31394E)
                    : Colors.grey,
              ),
              onPressed: _hasSelectedProducts()
                  ? () {
                      final checkoutData = _prepareCheckoutData();
                      print(checkoutData);
                      context.push('/checkout', extra: checkoutData);
                    }
                  : null,
              child: const Text(
                'Checkout',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
