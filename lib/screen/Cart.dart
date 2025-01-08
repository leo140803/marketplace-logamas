import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';

import 'package:marketplace_logamas/function/Utils.dart';
// import 'package:marketplace_logamas/screen/CheckoutPage.dart';
import 'package:marketplace_logamas/widget/Dialog.dart';

class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  List<Map<String, dynamic>> cartData = [];
  bool isLoading = true;
  String userId ='';

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
      print(userId);
      final response =
          await http.get(Uri.parse('$apiBaseUrl/cart/$userId'));

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        setState(() {
          final previousSelectedProducts = [..._selectedProducts];
          cartData =
              (responseData['data'] as List).cast<Map<String, dynamic>>();
          isLoading = false;

          // Reinitialize selection if the structure of cartData changes
          if (previousSelectedProducts.length != cartData.length) {
            _initializeSelection();
          }
        });
      } else {
        throw Exception("Failed to fetch cart data");
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      print("Error fetching cart data: $e");
      // Show error dialog or message
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

  Future<void> _incrementCartItem(String cartId) async {
    try {
      final response =
          await http.patch(Uri.parse('$baseUrl/$cartId/increment'));
      final responseData = json.decode(response.body);
      print(responseData);
      if (response.statusCode == 200) {
        setState(() {
          _preserveSelection();
          // _fetchCartData(); // Refresh cart data after successful increment
        });
      } else {
        throw Exception('Failed to increment cart item');
      }
    } catch (e) {
      print('Error incrementing cart item: $e');
    }
  }

  Future<void> _decrementCartItem(String cartId) async {
    try {
      final response =
          await http.patch(Uri.parse('$baseUrl/$cartId/decrement'));
      final responseData = json.decode(response.body);
      print(responseData);
      if (response.statusCode == 200) {
        setState(() {
          _fetchCartData(); // Refresh cart data after successful decrement
        });
      } else {
        throw Exception('Failed to decrement cart item');
      }
    } catch (e) {
      print('Error decrementing cart item: $e');
    }
  }

  Future<void> _deleteCartItem(String cartId) async {
    try {
      final response = await http.delete(Uri.parse('$baseUrl/$cartId'));
      final responseData = json.decode(response.body);
      print(responseData);
      if (response.statusCode == 200) {
        setState(() {
          _fetchCartData(); // Refresh cart data after successful deletion
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

  void _preserveSelection() {
    for (int storeIndex = 0; storeIndex < cartData.length; storeIndex++) {
      for (int productIndex = 0;
          productIndex < cartData[storeIndex]["ProductList"].length;
          productIndex++) {
        if (storeIndex < _selectedProducts.length &&
            productIndex < _selectedProducts[storeIndex].length) {
          _selectedProducts[storeIndex][productIndex] =
              _selectedProducts[storeIndex][productIndex];
        }
      }
    }
  }

  Map<String, dynamic> _prepareCheckoutData() {
    for (int storeIndex = 0; storeIndex < cartData.length; storeIndex++) {
      final selectedProducts = [];
      for (int productIndex = 0;
          productIndex < _selectedProducts[storeIndex].length;
          productIndex++) {
        if (_selectedProducts[storeIndex][productIndex]) {
          selectedProducts
              .add(cartData[storeIndex]["ProductList"][productIndex]);
        }
      }

      if (selectedProducts.isNotEmpty) {
        final store = cartData[storeIndex]["store"];
        return {
          "store": store,
          "selectedProducts": selectedProducts,
        };
      }
    }
    return {};
  }

  int _calculateTotal() {
    int total = 0;
    for (int i = 0; i < cartData.length; i++) {
      for (int j = 0; j < cartData[i]["ProductList"].length; j++) {
        if (_selectedProducts[i][j]) {
          total += (cartData[i]["ProductList"][j]["productPrice"] as int) *
              (cartData[i]["ProductList"][j]["quantity"] as int);
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
          icon: Icon(Icons.arrow_back),
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
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : cartData.isEmpty
              ? const Center(
                  child: Text("Keranjang kosong"),
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
                                  activeColor: Color(0xFFC58189),
                                  value: _selectedStores[storeIndex],
                                  onChanged: (bool? value) {
                                    setState(() {
                                      for (int i = 0;
                                          i <
                                              _selectedProducts[storeIndex]
                                                  .length;
                                          i++) {
                                        _selectedProducts[storeIndex][i] =
                                            value ?? false;
                                      }

                                      _selectedStores[storeIndex] =
                                          value ?? false;
                                      print(_selectedStores);
                                      if (value ?? false) {
                                        for (int i = 0;
                                            i < _selectedStores.length;
                                            i++) {
                                          if (i != storeIndex) {
                                            _selectedStores[i] = false;
                                            _selectedProducts[i] =
                                                List.generate(
                                                    cartData[i]["ProductList"]
                                                        .length,
                                                    (_) => false);
                                          }
                                        }
                                      }
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Checkbox(
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        activeColor: Color(0xFFC58189),
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
                                            print(_selectedStores);
                                            if (value ?? false) {
                                              for (int i = 0;
                                                  i < _selectedStores.length;
                                                  i++) {
                                                if (i != storeIndex) {
                                                  _selectedStores[i] = false;
                                                  _selectedProducts[i] =
                                                      List.generate(
                                                          cartData[i][
                                                                  "ProductList"]
                                                              .length,
                                                          (_) => false);
                                                }
                                              }
                                            }
                                          });
                                        },
                                      ),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: Image.network(
                                          "$apiBaseUrlImage/uploads/storeLogo/store-1735984629390-441954104.png",
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
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Flexible(
                                                  // Gunakan Flexible agar teks dapat menyesuaikan ruang
                                                  child: Text(
                                                    product["productName"],
                                                    style: const TextStyle(
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    maxLines: 1,
                                                  ),
                                                ),
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                          right: 12.0),
                                                  child: Text(
                                                    'Stok: ${product["productQuantity"]}', // Menampilkan stok
                                                    style: const TextStyle(
                                                      fontSize: 10,
                                                      color: Colors.grey,
                                                    ),
                                                  ),
                                                ),
                                              ],
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
                                            Row(
                                              children: [
                                                IconButton(
                                                  icon: Icon(
                                                    product["quantity"] == 1
                                                        ? Icons.delete
                                                        : Icons.remove_circle,
                                                    color:
                                                        product["quantity"] > 1
                                                            ? const Color(
                                                                0xFF31394E)
                                                            : Colors.red[400],
                                                  ),
                                                  onPressed:
                                                      product["quantity"] > 1
                                                          ? () {
                                                              _decrementCartItem(
                                                                  product[
                                                                      "cart_id"]); // Call API
                                                              setState(() {
                                                                product[
                                                                    "quantity"]--;
                                                              });
                                                            }
                                                          : () {
                                                              _deleteCartItem(
                                                                  product[
                                                                      "cart_id"]); // Call API
                                                              setState(() {
                                                                // Hapus produk dari cartData
                                                                cartData[storeIndex]
                                                                        [
                                                                        "ProductList"]
                                                                    .removeAt(
                                                                        productIndex);

                                                                // Perbarui daftar _selectedProducts untuk toko ini
                                                                _selectedProducts[
                                                                        storeIndex]
                                                                    .removeAt(
                                                                        productIndex);

                                                                // Jika daftar produk untuk toko kosong, hapus toko
                                                                if (cartData[
                                                                            storeIndex]
                                                                        [
                                                                        "ProductList"]
                                                                    .isEmpty) {
                                                                  cartData.removeAt(
                                                                      storeIndex);
                                                                  _selectedStores
                                                                      .removeAt(
                                                                          storeIndex);
                                                                  _selectedProducts
                                                                      .removeAt(
                                                                          storeIndex);
                                                                } else {
                                                                  _selectedStores[
                                                                      storeIndex] = _selectedProducts[
                                                                          storeIndex]
                                                                      .every((selected) =>
                                                                          selected);
                                                                }
                                                              });
                                                            },
                                                ),
                                                Text(
                                                  product["quantity"]
                                                      .toString(),
                                                  style: const TextStyle(
                                                      fontSize: 16),
                                                ),
                                                IconButton(
                                                  icon: Icon(
                                                    Icons.add_circle,
                                                    color: product["quantity"] <
                                                            product[
                                                                "productQuantity"]
                                                        ? const Color(
                                                            0xFF31394E)
                                                        : Colors.grey,
                                                  ),
                                                  onPressed: product[
                                                              "quantity"] <
                                                          product[
                                                              "productQuantity"]
                                                      ? () {
                                                          _incrementCartItem(
                                                              product[
                                                                  "cart_id"]); // Call API
                                                          setState(() {
                                                            product[
                                                                "quantity"]++;
                                                          });
                                                        }
                                                      : null,
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
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
              offset: Offset(0, -5),
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
                      context.go('/checkout', extra: checkoutData);
                      // Navigator.push(
                      //   context,
                      //   MaterialPageRoute(
                      //     builder: (context) => CheckoutPage(
                      //       cartData: checkoutData,
                      //     ),
                      //   ),
                      // );
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
