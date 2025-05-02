import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
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
      debugPrint("Error: $e");
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchCartData() async {
    try {
      final response = await http.get(Uri.parse('$apiBaseUrl/cart/$userId'));
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (mounted) {
          setState(() {
            cartData =
                (responseData['data'] as List).cast<Map<String, dynamic>>();
            isLoading = false;
            _initializeSelection();
          });
        }
      } else {
        throw Exception("Failed to fetch cart data: ${response.statusCode}");
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
        _showErrorSnackBar("Gagal memuat data keranjang");
      }
      debugPrint("Error fetching cart data: $e");
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

  Future<void> _deleteCartItem(String cartId, String productName) async {
    try {
      // Show loading indicator
      _showLoadingDialog("Menghapus item...");

      final response = await http.delete(Uri.parse('$baseUrl/$cartId'));

      // Dismiss loading dialog
      Navigator.of(context).pop();

      if (response.statusCode == 200) {
        _showSuccessSnackBar('$productName dihapus dari keranjang');
        await _fetchCartData();
      } else {
        throw Exception('Failed to delete cart item: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error deleting cart item: $e');
      _showErrorSnackBar("Gagal menghapus item");
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
            "quantity": 1,
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

  int _getSelectedItemCount() {
    int count = 0;
    for (var storeProducts in _selectedProducts) {
      for (var isSelected in storeProducts) {
        if (isSelected) count++;
      }
    }
    return count;
  }

  void _toggleSelectStore(int storeIndex, bool? value) {
    if (value == null) return;

    setState(() {
      // First, clear all selections
      for (int i = 0; i < _selectedStores.length; i++) {
        _selectedStores[i] = false;
        for (int j = 0; j < _selectedProducts[i].length; j++) {
          _selectedProducts[i][j] = false;
        }
      }

      // Then, select only the current store
      if (value) {
        _selectedStores[storeIndex] = true;
        for (int j = 0; j < _selectedProducts[storeIndex].length; j++) {
          _selectedProducts[storeIndex][j] = true;
        }
      }
    });
  }

  void _toggleSelectProduct(int storeIndex, int productIndex, bool? value) {
    if (value == null) return;

    setState(() {
      // First, ensure all other stores are deselected
      for (int i = 0; i < _selectedStores.length; i++) {
        if (i != storeIndex) {
          _selectedStores[i] = false;
          for (int j = 0; j < _selectedProducts[i].length; j++) {
            _selectedProducts[i][j] = false;
          }
        }
      }

      // Now handle the selection for this specific product
      _selectedProducts[storeIndex][productIndex] = value;

      // Update store checkbox based on product selections:
      // - If ALL products are selected, store should be checked
      // - If ANY product is selected (but not all), store should still show as "partially" selected
      // - If NO products are selected, store should be unchecked

      bool anySelected =
          _selectedProducts[storeIndex].any((selected) => selected);
      bool allSelected =
          _selectedProducts[storeIndex].every((selected) => selected);

      // Set store checkbox based on all products being selected
      _selectedStores[storeIndex] = allSelected;

      // If none are selected, ensure store is also not selected
      if (!anySelected) {
        _selectedStores[storeIndex] = false;
      }
    });
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF31394E),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _showLoadingDialog(String message) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFC58189)),
              ),
              const SizedBox(width: 20),
              Text(message),
            ],
          ),
        );
      },
    );
  }

  Future<bool> _confirmDelete(String productName) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.delete_outline,
                  color: Colors.red,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),

              // Title
              const Text(
                'Konfirmasi Hapus',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF31394E),
                ),
              ),
              const SizedBox(height: 12),

              // Content
              Text(
                'Apakah Anda yakin ingin menghapus "$productName" dari keranjang?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 24),

              // Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Cancel Button
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: Colors.grey[200],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Batal',
                        style: TextStyle(
                          color: Color(0xFF31394E),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Delete Button
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Hapus',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
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
    );

    return result ?? false;
  }

  void _proceedToCheckout() {
    if (!_hasSelectedProducts()) return;

    final checkoutData = _prepareCheckoutData();
    context.push('/checkout', extra: checkoutData);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F4),
      appBar: _buildAppBar(),
      body: isLoading
          ? _buildLoadingView()
          : cartData.isEmpty
              ? _buildEmptyCartView()
              : _buildCartListView(),
      bottomNavigationBar: cartData.isEmpty ? null : _buildCheckoutBar(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      centerTitle: true,
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
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => context.pop(),
      ),
      title: const Text(
        'Keranjang',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildLoadingView() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFC58189)),
          ),
          SizedBox(height: 16),
          Text(
            "Memuat keranjang...",
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCartView() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/empty_cart.png',
              width: 200,
              height: 200,
            ),
            const Text(
              "Keranjang Anda Kosong",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF31394E),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              "Mulai belanja sekarang dan tambahkan produk favorit Anda ke keranjang!",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF31394E),
                padding:
                    const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => context.push('/home'),
              child: const Text(
                "Belanja Sekarang",
                style: TextStyle(fontSize: 16, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartListView() {
    return ListView.builder(
      padding: const EdgeInsets.all(10),
      itemCount: cartData.length,
      itemBuilder: (context, storeIndex) {
        final store = cartData[storeIndex];
        return _buildStoreCard(store, storeIndex);
      },
    );
  }

  Widget _buildStoreCard(Map<String, dynamic> store, int storeIndex) {
    return Card(
      color: Colors.white,
      margin: const EdgeInsets.symmetric(vertical: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStoreHeader(store, storeIndex),
            const Divider(),
            ...List.generate(
              store["ProductList"].length,
              (productIndex) =>
                  _buildProductItem(store, storeIndex, productIndex),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoreHeader(Map<String, dynamic> store, int storeIndex) {
    return Row(
      children: [
        Checkbox(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
          activeColor: const Color(0xFFC58189),
          value: _selectedStores[storeIndex],
          onChanged: (bool? value) {
            _toggleSelectStore(storeIndex, value);
          },
        ),
        Icon(
          Icons.store,
          size: 20,
          color: Color(0xFF31394E),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            store["store"]["store_name"],
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProductItem(
      Map<String, dynamic> store, int storeIndex, int productIndex) {
    final product = store["ProductList"][productIndex];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
            activeColor: const Color(0xFFC58189),
            value: _selectedProducts[storeIndex][productIndex],
            onChanged: (bool? value) {
              _toggleSelectProduct(storeIndex, productIndex, value);
            },
          ),
          _buildProductImage(product),
          const SizedBox(width: 12),
          Expanded(
            child: _buildProductDetails(product),
          ),
          _buildDeleteButton(product),
        ],
      ),
    );
  }

  Widget _buildProductImage(Map<String, dynamic> product) {
    return Hero(
      tag: 'product_${product["cart_id"]}',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade200),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Image.network(
            "$apiBaseUrlImage${product['image']}",
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                width: 80,
                height: 80,
                color: Colors.grey[200],
                child: const Icon(
                  Icons.image_not_supported_outlined,
                  size: 40,
                  color: Colors.grey,
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildProductDetails(Map<String, dynamic> product) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          product["productName"],
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 6),
        Text(
          'Rp. ${formatCurrency(product["productPrice"].toDouble())}',
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFFC58189),
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Berat: ${product["productWeight"]} g',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildDeleteButton(Map<String, dynamic> product) {
    return IconButton(
      icon: const Icon(Icons.delete_outline, color: Colors.red),
      onPressed: () async {
        final confirm = await _confirmDelete(product["productName"]);
        if (confirm) {
          await _deleteCartItem(product["cart_id"], product["productName"]);
        }
      },
    );
  }

  Widget _buildCheckoutBar() {
    final int selectedCount = _getSelectedItemCount();
    final int total = _calculateTotal();
    final bool hasSelected = _hasSelectedProducts();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            spreadRadius: 0,
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: SafeArea(
        child: Row(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  selectedCount > 0
                      ? '$selectedCount item dipilih'
                      : 'Pilih produk',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Total: Rp. ${formatCurrency(total.toDouble())}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF31394E),
                  ),
                ),
              ],
            ),
            const Spacer(),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    hasSelected ? const Color(0xFF31394E) : Colors.grey[400],
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: hasSelected ? _proceedToCheckout : null,
              child: Text(
                'Checkout ($selectedCount)',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
