import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:marketplace_logamas/function/Utils.dart';
import 'package:marketplace_logamas/converter/metal_type.dart';

class ProductCodeDetailPage extends StatefulWidget {
  final String barcode;

  const ProductCodeDetailPage({
    Key? key,
    required this.barcode,
  }) : super(key: key);

  @override
  State<ProductCodeDetailPage> createState() => _ProductCodeDetailPageState();
}

class _ProductCodeDetailPageState extends State<ProductCodeDetailPage> {
  Map<String, dynamic>? selectedProductCode;
  Map<String, dynamic>? product;

  @override
  void initState() {
    super.initState();
    fetchProductDetails();
  }

  Future<void> fetchProductDetails() async {
    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/products/barcode/${widget.barcode}'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        final data = result['data'];
        if (data == null || data['product'] == null) {
          throw Exception("Data produk tidak ditemukan.");
        }

        setState(() {
          selectedProductCode = data;
          product = data['product'];
        });
      } else {
        throw Exception('Gagal mengambil detail produk berdasarkan barcode');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = selectedProductCode != null
        ? '$apiBaseUrlImage${selectedProductCode!['image']}'
        : null;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset('assets/images/appbar.png', fit: BoxFit.cover),
            Container(color: Colors.black.withOpacity(0.2)),
          ],
        ),
        title: const Text(
          'Product Code Detail',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: product == null || selectedProductCode == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (imageUrl != null)
                    Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.network(
                          imageUrl,
                          height: 300,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                            height: 300,
                            color: Colors.grey[300],
                            child: const Icon(Icons.broken_image,
                                size: 60, color: Colors.grey),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),
                  Text(
                    product!['name'] ?? 'Nama Produk',
                    style: const TextStyle(
                        fontSize: 26, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  if (selectedProductCode!['fixed_price'] != null)
                    _buildDetailRow(
                      'Barcode',
                      selectedProductCode!['barcode'],
                    ),
                  _buildDetailRow(
                    'Berat',
                    '${selectedProductCode!['weight']} g',
                  ),
                  const SizedBox(height: 16),
                  if (product!['description'] != null &&
                      product!['description'].toString().trim().isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Deskripsi',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          product!['description'],
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  const Text(
                    'Detail Produk',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  _buildDetailRow(
                    'Kategori',
                    product!['type']['category']['name'],
                  ),
                  _buildDetailRow(
                    'Karat',
                    product!['type']['category']['purity'],
                  ),
                  _buildDetailRow(
                    'Metal Type',
                    MetalTypeConverter.getMetalType(
                        product!['type']['category']['metal_type']),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
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
}
