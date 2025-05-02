import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:marketplace_logamas/function/Utils.dart';
import 'package:marketplace_logamas/converter/metal_type.dart';
import 'package:google_fonts/google_fonts.dart';

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
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    fetchProductDetails();
  }

  Future<void> fetchProductDetails() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

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
          isLoading = false;
        });
      } else {
        throw Exception('Gagal mengambil detail produk berdasarkan barcode');
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = e.toString();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error: ${e.toString()}',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl =
        selectedProductCode != null && selectedProductCode!['image'] != null
            ? '$apiBaseUrlImage${selectedProductCode!['image']}'
            : null;

    return Scaffold(
      backgroundColor: Colors.grey[50],
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
        title: Text(
          'Detail Produk',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
      ),
      body: isLoading
          ? _buildLoadingView()
          : errorMessage != null
              ? _buildErrorView()
              : _buildProductDetailView(imageUrl),
    );
  }

  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFC58189)),
          ),
          const SizedBox(height: 16),
          Text(
            'Memuat detail produk...',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 70,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Gagal memuat data produk',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              errorMessage ?? 'Terjadi kesalahan saat memuat data produk.',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: fetchProductDetails,
              icon: const Icon(Icons.refresh),
              label: Text(
                'Coba Lagi',
                style: GoogleFonts.poppins(),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF31394E),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductDetailView(String? imageUrl) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Product Image Container
              Container(
                height: 280,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(30),
                    bottomRight: Radius.circular(30),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(30),
                    bottomRight: Radius.circular(30),
                  ),
                  child: imageUrl != null
                      ? Hero(
                          tag: 'product-${widget.barcode}',
                          child: Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Center(
                                child: CircularProgressIndicator(
                                  value: loadingProgress.expectedTotalBytes !=
                                          null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                          (loadingProgress.expectedTotalBytes ??
                                              1)
                                      : null,
                                  valueColor:
                                      const AlwaysStoppedAnimation<Color>(
                                    Color(0xFFC58189),
                                  ),
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) =>
                                Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.broken_image,
                                    size: 60,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Gambar tidak tersedia',
                                    style: GoogleFonts.poppins(
                                      color: Colors.grey[600],
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      : Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.image_not_supported_outlined,
                                size: 60,
                                color: Colors.grey,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Tidak ada gambar',
                                style: GoogleFonts.poppins(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ),
              // Barcode Tag
              Positioned(
                top: 16,
                right: 16,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.qr_code,
                        size: 16,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        widget.barcode,
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // Product Details
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // Product Name
              Text(
                product!['name'] ?? 'Nama Produk',
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF31394E),
                ),
              ),

              const SizedBox(height: 16),

              // Main Product Info Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Informasi Produk',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF31394E),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Product Info Grid
                    _buildInfoGrid(),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Product Description (if available)
              if (product!['description'] != null &&
                  product!['description'].toString().trim().isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        blurRadius: 5,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Deskripsi',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF31394E),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        product!['description'],
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.grey[700],
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 30),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoGrid() {
    final infoItems = [
      {
        'icon': Icons.qr_code,
        'label': 'Barcode',
        'value': selectedProductCode!['barcode'] ?? '-',
      },
      {
        'icon': Icons.scale,
        'label': 'Berat',
        'value': '${selectedProductCode!['weight']} g',
      },
      {
        'icon': Icons.category_outlined,
        'label': 'Kategori',
        'value': product!['type']['category']['name'] ?? '-',
      },
      {
        'icon': Icons.diamond_outlined,
        'label': 'Karat',
        'value': product!['type']['category']['purity'] ?? '-',
      },
      {
        'icon': Icons.design_services_outlined,
        'label': 'Jenis Logam',
        'value': MetalTypeConverter.getMetalType(
          product!['type']['category']['metal_type'],
        ),
      },
      if (selectedProductCode!['fixed_price'] != null)
        {
          'icon': Icons.paid_outlined,
          'label': 'Harga',
          'value': 'Rp ${formatCurrency(selectedProductCode!['fixed_price'])}',
        },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 2.2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 12,
      ),
      itemCount: infoItems.length,
      itemBuilder: (context, index) {
        final item = infoItems[index];
        return Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFFBE9E7).withOpacity(0.4),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFFC58189).withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    item['icon'] as IconData,
                    size: 16,
                    color: const Color(0xFFC58189),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    item['label'] as String,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                item['value'] as String,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF31394E),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }

  String formatCurrency(dynamic price) {
    if (price == null) return '0';
    return price.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
        );
  }
}
