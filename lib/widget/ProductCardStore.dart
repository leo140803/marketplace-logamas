import 'dart:math';
import 'package:marketplace_logamas/function/Utils.dart';
import 'package:flutter/material.dart';

Card ProductCardStore(Map<String, dynamic> product) {
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
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
              image: DecorationImage(
                image: NetworkImage(
                  (product['product_code_images'] != null && product['product_code_images'].isNotEmpty)
                      ? "$apiBaseUrlImage${product['product_code_images'][0]}"
                      : "$apiBaseUrlImage/default_image.jpg", // Gambar default jika kosong
                ),
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
                  Text(
                    '${product['average_rating']?.toStringAsFixed(1) ?? 'No Rate'} | ${product['totalSold'] ?? 0} Terjual',
                    style: TextStyle(fontSize: 12),
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
