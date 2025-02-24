import 'dart:math';
import 'package:marketplace_logamas/function/Utils.dart';
import 'package:flutter/material.dart';

Card ProductCard(Map<String, dynamic> product) {
  // Ambil gambar dari product_codes index 0 jika tersedia
  String productImage = product['product_codes'] != null &&
          product['product_codes'].isNotEmpty &&
          product['product_codes'][0]['image'] != null
      ? 'http://127.0.0.1:3000${product['product_codes'][0]['image']}'
      : (product['images'] != null && product['images'].isNotEmpty
          ? 'http://127.0.0.1:3000/uploads/${product['images'][0]}'
          : 'https://picsum.photos/200/200?random=${Random().nextInt(1000)}');

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
        // Product Image
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
              image: DecorationImage(
                image: NetworkImage(productImage),
                fit: BoxFit.cover,
              ),
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
                product['name'] ?? "Unknown Product",
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
                'Rp. ${formatCurrency(product['low_price'].toDouble())}',
                style: TextStyle(
                  color: Color(0xFFC58189),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              SizedBox(height: 4),

              // Rating and Sold Info
              Row(
                children: [
                  Icon(Icons.star, size: 14, color: Colors.orange),
                  SizedBox(width: 4),
                  Builder(builder: (context) {
                    final avgRating = product['average_rating'] ?? 0;
                    final totalSold = product['totalSold'] ?? 0;
                    final displayText = (avgRating == 0 && totalSold == 0)
                        ? 'No Rate | $totalSold Terjual'
                        : '${avgRating.toStringAsFixed(1)} | $totalSold Terjual';
                    return Text(
                      displayText,
                      style: TextStyle(fontSize: 12),
                    );
                  }),
                ],
              ),
              SizedBox(height: 4),

              // Location Info
              Row(
                children: [
                  Icon(Icons.store_sharp, size: 14, color: Colors.grey),
                  SizedBox(width: 4),
                  Text(
                    product['store']['store_name'] ?? 'Unknown Store',
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
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
