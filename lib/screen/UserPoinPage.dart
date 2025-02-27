import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:marketplace_logamas/function/Utils.dart';

class UserPointsPage extends StatefulWidget {
  @override
  _UserPointsPageState createState() => _UserPointsPageState();
}

class _UserPointsPageState extends State<UserPointsPage> {
  List<dynamic> userPoints = [];
  bool isLoading = true;
  int totalPoints = 0;
  String? _accessToken;

  Future<void> _loadAccessToken() async {
    try {
      final token = await getAccessToken();
      setState(() {
        _accessToken = token;
      });
      await fetchUserPoints();
    } catch (e) {
      print('Error loading access token or user data: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _loadAccessToken();
  }

  Future<void> fetchUserPoints() async {
    final apiUrl = '$apiBaseUrl/user-poin';
    final token = _accessToken;
    print(token);

    try {
      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          userPoints = data['data'];
          totalPoints = userPoints.fold<int>(
            0,
            (sum, item) => sum + (item['points'] as num).toInt(),
          );

          isLoading = false;
        });
      } else {
        throw Exception('Failed to load points');
      }
    } catch (e) {
      print('Error fetching points: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor:
            Colors.transparent, // Buat transparan agar gambar terlihat
        flexibleSpace: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/appbar.png', // Ganti dengan path gambar yang sesuai
              fit: BoxFit.cover, // Pastikan gambar memenuhi seluruh AppBar
            ),
            Container(
              color: Colors.black
                  .withOpacity(0.2), // Overlay agar teks tetap terbaca
            ),
          ],
        ),
        title: const Text(
          'My Points',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: GestureDetector(
          onTap: () => context.pop(),
          child: const Icon(
            Icons.arrow_back,
            color: Colors.white,
          ),
        ),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : userPoints.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(Icons.star_border, size: 80, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'No Points Available',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black54),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Start earning points by completing transactions!',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Total Points Display
                    Container(
                      width: double.infinity,
                      margin: EdgeInsets.all(16),
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Color(0xFFC58189),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Total Points',
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                          SizedBox(height: 5),
                          Text(
                            totalPoints.toString(),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // List of Stores with Points
                    Expanded(
                      child: ListView.builder(
                        itemCount: userPoints.length,
                        itemBuilder: (context, index) {
                          final item = userPoints[index];
                          final store = item['store'];
                          final storeName =
                              store?['store_name'] ?? 'Unknown Store';
                          final storeLogo = store?['logo'] != null
                              ? '$apiBaseUrlImage${store['logo']}' // Update with your image base URL
                              : null;
                          final points = item['points'] ?? 0;

                          return Card(
                            margin: EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            child: ListTile(
                              leading: storeLogo != null
                                  ? CircleAvatar(
                                      backgroundImage:
                                          CachedNetworkImageProvider(storeLogo),
                                    )
                                  : CircleAvatar(
                                      backgroundColor: Colors.grey,
                                      child: Icon(Icons.store,
                                          color: Colors.white),
                                    ),
                              title: Text(storeName),
                              trailing:
                                  Icon(Icons.chevron_right, color: Colors.grey),
                              onTap: () {
                                context.push(
                                  '/store-points/${store['store_id']}',
                                  extra: {
                                    'storeName': store['store_name'],
                                    'storeLogo': store['logo'] != null
                                        ? '$apiBaseUrlImage${store['logo']}'
                                        : null,
                                  },
                                );
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }
}
