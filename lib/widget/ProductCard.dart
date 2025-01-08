import 'dart:math';
import 'package:marketplace_logamas/function/Utils.dart';
import 'package:flutter/material.dart';

Card ProductCard(Map<String, dynamic> product) {
  return Card(
    color: Colors.white,
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
    ),
    elevation: 0,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: NetworkImage(
                  product['store']?['image_url'] != null &&
                          product['store']?['image_url'].isNotEmpty
                      ? "http://localhost:3000${product['store']?['image_url']}"
                      : 'https://picsum.photos/200/200?random=${Random().nextInt(1000)}',
                ),
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                product['productName'] ?? "Unknown Product",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 4),
              Text(
                'Rp. ${formatCurrency(product['productPrice'].toDouble()).toString()}',
                style: TextStyle(
                  color: Color(0xFFC58189),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              SizedBox(height: 4),
              Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.star, size: 14, color: Colors.orange),
                          SizedBox(width: 4),
                          Text(
                            // Rating dan sold mungkin tidak ada di API, gunakan default jika null
                            '${product['rating'] ?? 4.5} | ${product['sold'] ?? 0} Terjual',
                            style: TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.location_on, size: 14, color: Colors.grey),
                          SizedBox(width: 4),
                          Text(
                            // Lokasi mungkin berasal dari `store` objek
                            product['store']?['store_name'] ??
                                'Unknown Location',
                            style: TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Spacer(),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
