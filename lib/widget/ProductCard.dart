import 'dart:math';
import 'package:flutter/material.dart';
import 'package:marketplace_logamas/function/Utils.dart';
import 'package:cached_network_image/cached_network_image.dart'; // Add this package dependency

Widget ProductCard(Map<String, dynamic> product) {
  // Extract product data with null safety
  final String productName = product['name'] ?? "Unknown Product";
  final double productPrice = (product['low_price'] ?? 0).toDouble();
  final double avgRating = (product['average_rating'] ?? 0).toDouble();
  final int totalSold = product['totalSold'] ?? 0;
  final String storeName = product['store']?['store_name'] ?? 'Unknown Store';

  // Image handling with better fallback strategy
  String productImage = _getProductImage(product);

  return Card(
    color: Colors.white,
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
    ),
    elevation: 2,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Product Image with loading and error handling
        Expanded(
          child: CachedNetworkImage(
            imageUrl: productImage,
            fit: BoxFit.cover,
            width: double.infinity, // Tetapkan lebar yang konsisten
            height: double.infinity, // Tetapkan tinggi yang konsisten
            fadeInDuration: Duration.zero, // Hapus animasi fade in
            placeholderFadeInDuration:
                Duration.zero, // Hapus animasi placeholder
            placeholder: (context, url) => Container(
              width: double.infinity, // Pastikan placeholder punya ukuran sama
              height: double.infinity,
              color: Colors.grey[200],
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2.0,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFC58189)),
                ),
              ),
            ),
            errorWidget: (context, url, error) => Container(
              width: double.infinity, // Pastikan error widget punya ukuran sama
              height: double.infinity,
              color: Colors.grey[200],
              child: Icon(Icons.image_not_supported, color: Colors.grey),
            ),
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
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 4),

              // Product Price
              Text(
                'Rp. ${formatCurrency(productPrice)}',
                style: TextStyle(
                  color: Color(0xFFC58189),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              SizedBox(height: 4),

              // Rating and Sold Info
              _buildRatingAndSoldInfo(avgRating, totalSold),
              SizedBox(height: 4),

              // Location Info
              Row(
                children: [
                  Icon(Icons.store_sharp, size: 14, color: Colors.grey),
                  SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      storeName,
                      style: TextStyle(fontSize: 12, color: Colors.grey[700]),
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
Widget _buildRatingAndSoldInfo(double avgRating, int totalSold) {
  final String displayText = (avgRating <= 0)
      ? (totalSold > 0 ? 'No Rating | $totalSold Terjual' : 'No Rating & Sales')
      : '${avgRating.toStringAsFixed(1)} | $totalSold Terjual';

  return Row(
    children: [
      Icon(Icons.star, size: 14, color: Colors.orange),
      SizedBox(width: 4),
      Text(
        displayText,
        style: TextStyle(fontSize: 12),
      ),
    ],
  );
}
