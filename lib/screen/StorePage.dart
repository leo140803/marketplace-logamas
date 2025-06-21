import 'package:flutter/material.dart';
import 'package:marketplace_logamas/model/UserPoint.dart';
import 'package:marketplace_logamas/widget/BottomNavigationBar.dart';
import 'package:marketplace_logamas/widget/BuyVoucherConfirmDialog.dart';
import 'package:marketplace_logamas/widget/CategoryCard.dart';
import 'package:marketplace_logamas/widget/Dialog.dart';
import 'package:marketplace_logamas/widget/PriceBox.dart';
import 'package:marketplace_logamas/widget/ProductCard.dart';
import 'package:marketplace_logamas/widget/ProductCardStore.dart';
import 'package:marketplace_logamas/widget/UnauthorizedDialog.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:marketplace_logamas/function/Utils.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';

class StorePage extends StatefulWidget {
  final String storeId;

  const StorePage({Key? key, required this.storeId}) : super(key: key);

  @override
  State<StorePage> createState() => _StorePageState();
}

class _StorePageState extends State<StorePage> {
  TextEditingController lowPriceController = TextEditingController();
  TextEditingController highPriceController = TextEditingController();
  TextEditingController lowWeightController = TextEditingController();
  TextEditingController highWeightController = TextEditingController();
  final TextEditingController _textController = TextEditingController();
  final FocusNode _textFieldFocusNode = FocusNode();
  Set<String> selectedTypes = {};
  Set<String> selectedPurities = {};
  Set<String> selectedMetalTypes = {};
  String _userName = '';
  bool isFollow = false;
  bool isFilterApplied = false;
  Map<String, dynamic>? storeData;
  int points = 0;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    Future.delayed(Duration.zero, () async {
      String token = await getAccessToken();
      await fetchStoreData();
      await checkFollowStatus();
    });
    fetchStoreData();
  }

  List<Map<String, dynamic>> filteredProducts = [];

  List<Map<String, dynamic>> extractFiltersFromStoreData(
      Map<String, dynamic> storeData) {
    final products = storeData['products'] as List<dynamic>;

    // Ambil semua kategori dari produk
    final categories = products
        .map((product) => product['types']['category'] as Map<String, dynamic>)
        .toList();

    // Hilangkan duplikasi berdasarkan kombinasi `name`, `metal_type`, dan `purity`
    final uniqueCategories = categories.fold<Map<String, Map<String, dynamic>>>(
      {},
      (acc, category) {
        final metalTypeName = _getMetalTypeName(category['metal_type']);
        final key =
            '${category['name']}-${metalTypeName}-${category['purity']}';
        acc[key] = {
          ...category,
          'metal_type_name': metalTypeName, // Tambahkan nama deskriptif
        };
        return acc;
      },
    );

    return uniqueCategories.values.toList();
  }

// Fungsi untuk mengubah metal_type menjadi string deskriptif
// 1: Gold, 2: Silver, 3: Red Gold, 4: White Gold, 5: Platinum
  String _getMetalTypeName(int metalType) {
    switch (metalType) {
      case 1:
        return 'Gold';
      case 2:
        return 'Silver';
      case 3:
        return 'Red Gold';
      case 4:
        return 'White Gold';
      case 5:
        return 'Platinum';
      default:
        return 'Unknown';
    }
  }

  void _openChat() {
    if (storeData != null) {
      // Navigate ke chat screen
      context.push(
        '/chat/${widget.storeId}',
        extra: {
          'storeName': storeData!['store_name'],
          'storeLogo': storeData!['logo'],
        },
      );
    }
  }

  void applyFilter(
    Set<String> selectedCategoryNames,
    Set<String> selectedPurities,
    Set<String> selectedMetalTypes, {
    double? lowPrice,
    double? highPrice,
    double? lowWeight,
    double? highWeight,
  }) {
    setState(() {
      isFilterApplied = selectedCategoryNames.isNotEmpty ||
          selectedPurities.isNotEmpty ||
          selectedMetalTypes.isNotEmpty ||
          lowPrice != null ||
          highPrice != null ||
          lowWeight != null ||
          highWeight != null;

      final products = List<Map<String, dynamic>>.from(storeData!['products']);

      filteredProducts = products.where((product) {
        final category = product['types']['category'] as Map<String, dynamic>;
        final price = product['low_price'] as int;
        final minWeight = (product['min_weight'] is int)
            ? (product['min_weight'] as int).toDouble()
            : (product['min_weight'] as double? ?? 0);

        final maxWeight = (product['max_weight'] is int)
            ? (product['max_weight'] as int).toDouble()
            : (product['max_weight'] as double? ?? 0);

        // Filter kategori
        final nameMatches = selectedCategoryNames.isEmpty ||
            selectedCategoryNames.contains(category['name']);

        // Filter kemurnian emas
        final purityMatches = selectedPurities.isEmpty ||
            selectedPurities.contains(category['purity']);

        // Filter jenis logam
        final metalTypeMatches = selectedMetalTypes.isEmpty ||
            selectedMetalTypes
                .contains(_getMetalTypeName(category['metal_type'] as int));

        // Filter rentang harga
        final priceMatches = (lowPrice == null || price >= lowPrice) &&
            (highPrice == null || price <= highPrice);

        // Filter rentang berat
        final weightMatches = (lowWeight == null || maxWeight >= lowWeight) &&
            (highWeight == null || minWeight <= highWeight);

        return nameMatches &&
            purityMatches &&
            metalTypeMatches &&
            priceMatches &&
            weightMatches;
      }).toList();
    });
  }

  Future<void> fetchStoreData() async {
    try {
      print('Store ID ' + widget.storeId);
      final response = await http.get(
        Uri.parse("$apiBaseUrl/store/${widget.storeId}"),
      );
      print("Fetch Store Data --> ${jsonDecode(response.body)}");
      if (response.statusCode == 200) {
        final data = json.decode(response.body)['data']; // Ambil data dari root
        setState(() {
          storeData = data; // Simpan data toko
          filteredProducts = List<Map<String, dynamic>>.from(data['products']);
        });
      } else {
        throw Exception("Failed to load store data");
      }

      // Ambil poin pengguna di toko ini
      String token = await getAccessToken();
      final pointsResponse = await http.get(
        Uri.parse("$apiBaseUrl/user-poin/${widget.storeId}"),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );
      print("Point User Response --> ${jsonDecode(pointsResponse.body)}");
      if (pointsResponse.statusCode == 200) {
        setState(() {
          points = json.decode(pointsResponse.body)['data']['points'];
        });
      } else if (pointsResponse.statusCode == 404 ||
          pointsResponse.statusCode == 401) {
        setState(() {
          points = 0;
        });
      } else {
        throw Exception("Failed to load points data");
      }
    } catch (e) {
      print("Error fetching store data: $e");
    }
  }

  Future<void> checkFollowStatus() async {
    try {
      String token = await getAccessToken();
      final response = await http.get(
        Uri.parse("$apiBaseUrl/follow/is-following?store_id=${widget.storeId}"),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        print(responseData);
        setState(() {
          isFollow = responseData['data'];
        });
      } else {
        throw Exception("Failed to check follow status");
      }
    } catch (e) {
      print("Error checking follow status: $e");
    }
  }

  Future<void> followStore() async {
    try {
      String token = await getAccessToken();
      print(token);
      final response = await http.post(
        Uri.parse("$apiBaseUrl/follow"),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'store_id': widget.storeId}),
      );

      print("Folow Store Response --> ${jsonDecode(response.body)}");

      if (response.statusCode == 201) {
        final responseData = json.decode(response.body);
        setState(() {
          isFollow = true;
        });
        dialog(context, 'Success', responseData['message']);
      } else if (response.statusCode == 401) {
        handleUnauthorized(context);
      } else {
        throw Exception("Failed to follow the store");
      }
    } catch (e) {
      print("Error following store: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to follow the store'),
          backgroundColor: Color(0xFF31394E),
        ),
      );
    }
  }

  Future<List<dynamic>> fetchPoinHistory(String storeId) async {
    try {
      String token = await getAccessToken();
      final response = await http.get(
        Uri.parse("$apiBaseUrl/poin-history/$storeId"),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return responseData['data'];
      } else {
        throw Exception('Failed to fetch poin history');
      }
    } catch (e) {
      print("Error fetching poin history: $e");
      return [];
    }
  }

  Future<void> unfollowStore() async {
    try {
      String token = await getAccessToken();
      final response = await http.delete(
        Uri.parse("$apiBaseUrl/follow/${widget.storeId}"),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );
      print(response.statusCode);
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        print(responseData);
        setState(() {
          isFollow = false;
        });
        dialog(context, 'Success', responseData['message']);
      } else {
        throw Exception("Failed to unfollow the store");
      }
    } catch (e) {
      print("Error unfollowing store: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to unfollow the store'),
          backgroundColor: Color(0xFF31394E),
        ),
      );
    }
  }

  Future<UserStorePoints> fetchUserStorePoints(String storeId) async {
    String accessToken = await getAccessToken();
    final response = await http.get(
      Uri.parse('$apiBaseUrl/user-poin/$storeId'),
      headers: {
        'Authorization': 'Bearer $accessToken',
      },
    );
    if (response.statusCode == 200) {
      return UserStorePoints.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to load points');
    }
  }

  Future<void> _openWhatsApp() async {
    if (storeData != null && storeData!.containsKey("wa_number")) {
      String phoneNumber = storeData!["wa_number"].toString();
      print(phoneNumber);

      // **Pastikan nomor dimulai dengan '62'**
      if (!phoneNumber.startsWith("62")) {
        phoneNumber = "62$phoneNumber";
      }

      final whatsappUrl = Uri.parse("https://wa.me/$phoneNumber");

      if (await canLaunchUrl(whatsappUrl)) {
        await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
      } else {
        throw "Unable to open WhatsApp";
      }
    } else {
      print("WhatsApp number is not available");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("WhatsApp number is not available"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<List<dynamic>> fetchActiveVouchers(String storeId) async {
    try {
      String token = await getAccessToken();
      print(token);
      final response = await http.get(
        Uri.parse("$apiBaseUrl/vouchers/active-not-purchased?storeId=$storeId"),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );
      print(json.decode(response.body));

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return responseData['data'];
      } else {
        throw Exception('Failed to load vouchers');
      }
    } catch (e) {
      print("Error fetching vouchers: $e");
      return [];
    }
  }

  Future<List<dynamic>> fetchOwnedVouchers(String storeId) async {
    try {
      String token = await getAccessToken();
      final response = await http.get(
        Uri.parse("$apiBaseUrl/vouchers/purchased-not-used?storeId=$storeId"),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        print("Owned Voucher --> ${responseData['data']}");
        return responseData['data'];
      } else if (response.statusCode == 404) {
        return []; // Jika 404, kembalikan daftar kosong
      } else {
        throw Exception('Failed to load owned vouchers');
      }
    } catch (e) {
      print("Error fetching owned vouchers: $e");
      return [];
    }
  }

  Future<void> buyVoucher(BuildContext context, String accessToken,
      String voucherId, String storeId) async {
    final url = Uri.parse('$apiBaseUrl/vouchers/$voucherId/purchase');

    final headers = {
      'Authorization': 'Bearer $accessToken',
      'Content-Type': 'application/json',
    };

    final body = {
      "storeId": storeId,
    };

    try {
      final response = await http.post(
        url,
        headers: headers,
        body: json.encode(body),
      );

      if (response.statusCode == 201) {
        // Pembelian berhasil
        Navigator.of(context).pop(); // Tutup drawer
        dialog(context, 'Success', 'Success Buy Voucher');
      } else if (response.statusCode == 401) {
        unauthorizedDialog(context);
      } else {
        final responseBody = jsonDecode(response.body);
        final errorMessage =
            responseBody['message'] ?? 'An unknown error occurred';
        dialog(context, 'Error', errorMessage);
      }
    } catch (e) {
      // Kesalahan jaringan atau lainnya
      dialog(context, 'Error', 'Failed to connect to server.');
    }
  }

  void _showPoinHistoryDrawer(BuildContext context, String storeId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return FutureBuilder(
          future: fetchPoinHistory(storeId),
          builder: (context, AsyncSnapshot<List<dynamic>> snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Container(
                height: MediaQuery.of(context).size.height * 0.65,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 40,
                        height: 40,
                        child: CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Color(0xFFC58189)),
                          strokeWidth: 3,
                        ),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Loading point history...',
                        style: TextStyle(
                          fontSize: 16,
                          color: Color(0xFF31394E),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            if (snapshot.hasError || snapshot.data == null) {
              return FractionallySizedBox(
                heightFactor: 0.65,
                child: Column(
                  children: [
                    _buildDrawerHeader(context, 'Point History'),
                    Expanded(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.error_outline,
                                size: 48,
                                color: Colors.red.shade300,
                              ),
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Failed to load point history',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF31394E),
                              ),
                            ),
                            SizedBox(height: 8),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 40),
                              child: Text(
                                'Please check your connection and try again',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ),
                            SizedBox(height: 24),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.pop(context);
                                _showPoinHistoryDrawer(context, storeId);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Color(0xFF31394E),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 12),
                              ),
                              child: Text('Try Again'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            final pointHistory = snapshot.data ?? [];
            int totalPoints = 0;

            // Calculate total points
            if (pointHistory.isNotEmpty) {
              for (var history in pointHistory) {
                totalPoints += history['poin_used'] as int;
              }
            }

            return FractionallySizedBox(
              heightFactor: 0.65,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDrawerHeader(context, 'Point History'),

                  // Points summary section
                  if (pointHistory.isNotEmpty)
                    Container(
                      margin: EdgeInsets.fromLTRB(16, 0, 16, 16),
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF31394E), Color(0xFF474F67)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.equalizer,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          SizedBox(width: 16),
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Color(0xFFC58189),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              'Current: ${points} pts',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // History list
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Text(
                          'Transaction History',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF31394E),
                          ),
                        ),
                        SizedBox(width: 8),
                        Container(
                          padding:
                              EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${pointHistory.length}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF31394E),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 8),

                  Expanded(
                    child: pointHistory.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                            itemCount: pointHistory.length,
                            itemBuilder: (context, index) {
                              final history = pointHistory[index];
                              return _buildPoinHistoryCard(history);
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.history_toggle_off,
              size: 64,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No Point History Yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF31394E),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Start shopping and earn points with every purchase!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 32),
          OutlinedButton.icon(
            onPressed: () {
              // Navigate to products or close the drawer
            },
            icon: Icon(
              Icons.shopping_bag_outlined,
              size: 18,
            ),
            label: Text('Start Shopping'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Color(0xFFC58189),
              side: BorderSide(color: Color(0xFFC58189)),
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPoinHistoryCard(Map<String, dynamic> history) {
    final createdAt =
        DateTime.parse(history['created_at']).add(Duration(hours: 7));
    final formattedDate =
        "${createdAt.day.toString().padLeft(2, '0')}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.year}";
    final formattedTime =
        "${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}";

    // Get point value and determine if it's positive or negative
    final pointValue = history['poin_used'] as int;
    final isPositive = pointValue >= 0;
    final pointText = isPositive ? "+$pointValue" : "$pointValue";

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          // Optional: Show more details if needed
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Point transaction icon
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isPositive ? Color(0xFFE8F5E9) : Color(0xFFFBE9E7),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isPositive
                      ? Icons.add_circle_outline
                      : Icons.remove_circle_outline,
                  color: isPositive ? Colors.green.shade700 : Color(0xFFC58189),
                  size: 20,
                ),
              ),
              SizedBox(width: 16),

              // Transaction details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      history['purpose'] ?? 'Transaction',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF31394E),
                      ),
                    ),
                    SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today_outlined,
                          size: 12,
                          color: Colors.grey.shade600,
                        ),
                        SizedBox(width: 4),
                        Text(
                          '$formattedDate at $formattedTime',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Points value
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isPositive ? Colors.green.shade50 : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$pointText pts',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color:
                        isPositive ? Colors.green.shade700 : Color(0xFFC58189),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showVoucherDrawer(BuildContext context, String storeId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return FutureBuilder(
          future: Future.wait([
            fetchOwnedVouchers(storeId),
            fetchActiveVouchers(storeId),
          ]),
          builder: (context, AsyncSnapshot<List<dynamic>> snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Container(
                height: MediaQuery.of(context).size.height * 0.65,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 40,
                        height: 40,
                        child: CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Color(0xFFC58189)),
                          strokeWidth: 3,
                        ),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Loading vouchers...',
                        style: TextStyle(
                          fontSize: 16,
                          color: Color(0xFF31394E),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            if (snapshot.hasError) {
              return Container(
                height: MediaQuery.of(context).size.height * 0.65,
                child: Column(
                  children: [
                    _buildDrawerHeader(context, 'Store Vouchers'),
                    Expanded(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.error_outline,
                                size: 56,
                                color: Colors.red.shade300,
                              ),
                            ),
                            SizedBox(height: 24),
                            Text(
                              'Failed to load vouchers',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF31394E),
                              ),
                            ),
                            SizedBox(height: 12),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 40),
                              child: Text(
                                'Please check your connection and try again',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ),
                            SizedBox(height: 24),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.pop(context);
                                _showVoucherDrawer(context, storeId);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Color(0xFF31394E),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding: EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 12),
                              ),
                              child: Text('Try Again'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            final ownedVouchers = snapshot.data![0];
            final availableVouchers = snapshot.data![1];

            return FractionallySizedBox(
              heightFactor: 0.75,
              child: Column(
                children: [
                  _buildDrawerHeader(context, 'Store Vouchers'),

                  // Current points display
                  Container(
                    margin: EdgeInsets.fromLTRB(16, 4, 16, 20),
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Color(0xFFFBE9E7),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Color(0xFFC58189).withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Color(0xFFC58189).withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.card_giftcard,
                            color: Color(0xFFC58189),
                            size: 20,
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Your Point Balance',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF31394E),
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                '$points Points',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFC58189),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Voucher content
                  Expanded(
                    child: SingleChildScrollView(
                      physics: BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (ownedVouchers.isNotEmpty) ...[
                            _buildSectionHeader(
                                'Your Vouchers', ownedVouchers.length),
                            SizedBox(height: 12),
                            ListView.builder(
                              shrinkWrap: true,
                              physics: NeverScrollableScrollPhysics(),
                              itemCount: ownedVouchers.length,
                              itemBuilder: (context, index) {
                                final voucher = ownedVouchers[index];
                                return _buildVoucherCard(
                                  name: voucher['voucher_name'],
                                  discount: '${voucher['discount_amount']}%',
                                  points: voucher['poin_price'],
                                  startDate:
                                      voucher['start_date'].split('T')[0],
                                  endDate: voucher['end_date'].split('T')[0],
                                  minimumPurchase:
                                      double.parse(voucher['minimum_purchase']),
                                  maxDiscount:
                                      double.parse(voucher['max_discount']),
                                  isOwned: true,
                                );
                              },
                            ),
                            SizedBox(height: 24),
                          ],
                          _buildSectionHeader(
                              'Available Vouchers', availableVouchers.length),
                          SizedBox(height: 12),
                          availableVouchers.isEmpty
                              ? _buildEmptyVoucherState()
                              : ListView.builder(
                                  shrinkWrap: true,
                                  physics: NeverScrollableScrollPhysics(),
                                  itemCount: availableVouchers.length,
                                  itemBuilder: (context, index) {
                                    final voucher = availableVouchers[index];
                                    return _buildVoucherCard(
                                      name: voucher['voucher_name'],
                                      discount:
                                          '${voucher['discount_amount']}%',
                                      points: voucher['poin_price'],
                                      startDate:
                                          voucher['start_date'].split('T')[0],
                                      endDate:
                                          voucher['end_date'].split('T')[0],
                                      minimumPurchase: double.parse(
                                          voucher['minimum_purchase']),
                                      maxDiscount:
                                          double.parse(voucher['max_discount']),
                                      isOwned: false,
                                      onTap: () async {
                                        String accessToken =
                                            await getAccessToken();
                                        String storeId = widget.storeId;

                                        showPurchaseConfirmationDialog(
                                          context,
                                          voucher['voucher_name'],
                                          voucher['poin_price'],
                                          () async {
                                            await buyVoucher(
                                                context,
                                                accessToken,
                                                voucher['voucher_id'],
                                                storeId);
                                          },
                                        );
                                      },
                                    );
                                  },
                                ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDrawerHeader(BuildContext context, String title) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            offset: Offset(0, 1),
            blurRadius: 3,
          ),
        ],
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          SizedBox(height: 16),

          // Header with title and close button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF31394E),
                ),
              ),
              InkWell(
                onTap: () => Navigator.of(context).pop(),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.close,
                    size: 18,
                    color: Color(0xFF31394E),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, int count) {
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF31394E),
          ),
        ),
        SizedBox(width: 8),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            count.toString(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Color(0xFF31394E),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyVoucherState() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.local_offer_outlined,
                size: 56,
                color: Colors.grey.shade400,
              ),
            ),
            SizedBox(height: 24),
            Text(
              'No Vouchers Available',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF31394E),
              ),
            ),
            SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Check back later or try another store',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoucherCard({
    required String name,
    required String discount,
    required int points,
    required String startDate,
    required String endDate,
    required double minimumPurchase,
    required double maxDiscount,
    required bool isOwned,
    VoidCallback? onTap,
  }) {
    // Format dates for better readability
    final formattedStartDate = _formatDate(startDate);
    final formattedEndDate = _formatDate(endDate);

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Ink(
            decoration: BoxDecoration(
              color: isOwned ? Color(0xFFFBE9E7) : Color(0xFF31394E),
              borderRadius: BorderRadius.circular(12),
              border: isOwned
                  ? Border.all(color: Color(0xFFC58189), width: 1.5)
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Voucher header with discount badge
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: isOwned
                            ? Color(0xFFC58189).withOpacity(0.2)
                            : Colors.white.withOpacity(0.1),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isOwned
                                    ? Color(0xFFC58189).withOpacity(0.2)
                                    : Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                isOwned
                                    ? Icons.confirmation_number_outlined
                                    : Icons.local_offer_outlined,
                                color:
                                    isOwned ? Color(0xFFC58189) : Colors.white,
                                size: 20,
                              ),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: isOwned
                                          ? Color(0xFF31394E)
                                          : Colors.white,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    isOwned
                                        ? 'Ready to use'
                                        : '${points} points required',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: isOwned
                                          ? Color(0xFFC58189)
                                          : Colors.white.withOpacity(0.7),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isOwned
                              ? Color(0xFFC58189)
                              : Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          '$discount OFF',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isOwned ? Colors.white : Color(0xFFC58189),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Voucher details
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Validity period
                      Row(
                        children: [
                          Icon(
                            Icons.date_range_outlined,
                            size: 16,
                            color: isOwned
                                ? Colors.grey.shade600
                                : Colors.white.withOpacity(0.7),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Valid: $formattedStartDate - $formattedEndDate',
                            style: TextStyle(
                              fontSize: 13,
                              color: isOwned
                                  ? Colors.grey.shade700
                                  : Colors.white.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),

                      // Minimum purchase
                      Row(
                        children: [
                          Icon(
                            Icons.shopping_bag_outlined,
                            size: 16,
                            color: isOwned
                                ? Colors.grey.shade600
                                : Colors.white.withOpacity(0.7),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Min. Transaction: ${formatCurrency(minimumPurchase)}',
                            style: TextStyle(
                              fontSize: 13,
                              color: isOwned
                                  ? Colors.grey.shade700
                                  : Colors.white.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 8),

                      // Maximum discount
                      Row(
                        children: [
                          Icon(
                            Icons.price_check,
                            size: 16,
                            color: isOwned
                                ? Colors.grey.shade600
                                : Colors.white.withOpacity(0.7),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Max. Discount: ${formatCurrency(maxDiscount)}',
                            style: TextStyle(
                              fontSize: 13,
                              color: isOwned
                                  ? Colors.grey.shade700
                                  : Colors.white.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),

                      // Button for action (if not owned)
                      if (!isOwned) ...[
                        SizedBox(height: 16),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Color(0xFFC58189),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Get Voucher',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final parts = dateStr.split('-');
      if (parts.length == 3) {
        final year = parts[0];
        final month = parts[1];
        final day = parts[2];

        // Map month number to abbreviated month name
        final months = [
          'Jan',
          'Feb',
          'Mar',
          'Apr',
          'May',
          'Jun',
          'Jul',
          'Aug',
          'Sep',
          'Oct',
          'Nov',
          'Dec'
        ];

        final monthName = months[int.parse(month) - 1];
        return '$day $monthName $year';
      }
      return dateStr;
    } catch (e) {
      return dateStr; // Return original if parsing fails
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _textFieldFocusNode.dispose();
    super.dispose();
  }

  Future<void> _refreshPage() async {
    // Perbarui data halaman
    await fetchStoreData();
    await checkFollowStatus();
    setState(() {});
  }

  void _openGoogleMaps(double lat, double lon) async {
    final url = 'http://maps.google.com/maps?z=12&t=m&q=loc:$lat+$lon';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open Google Maps')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        floatingActionButton: (storeData != null &&
                storeData!.containsKey("latitude") &&
                storeData!.containsKey("longitude") &&
                storeData!["latitude"] != null &&
                storeData!["longitude"] != null)
            ? FloatingActionButton(
                onPressed: () {
                  _openGoogleMaps(
                    double.parse(storeData!["latitude"].toString()),
                    double.parse(storeData!["longitude"].toString()),
                  );
                },
                child: Icon(Icons.map, color: Colors.white),
                backgroundColor: Color(0xFF31394E),
              )
            : null,
        backgroundColor: Colors.grey[100],
        body: storeData == null
            ? Center(child: CircularProgressIndicator()) // Loading indicator
            : RefreshIndicator(
                color: Color(0xFFC58189),
                backgroundColor: Color(0xFF31394E),
                strokeWidth: 2,
                onRefresh: _refreshPage,
                child: CustomScrollView(
                  physics: AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverAppBar(
                      pinned: true,
                      floating: true,
                      backgroundColor: Colors
                          .transparent, // Buat transparan agar gambar terlihat
                      automaticallyImplyLeading: false,
                      toolbarHeight: 80,
                      flexibleSpace: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.asset(
                            'assets/images/appbar.png', // Ganti dengan path gambar yang sesuai
                            fit: BoxFit
                                .cover, // Pastikan gambar memenuhi seluruh AppBar
                          ),
                          Container(
                            color: Colors.black.withOpacity(
                                0.2), // Overlay agar teks tetap terbaca
                          ),
                        ],
                      ),
                      leading: GestureDetector(
                        onTap: () => GoRouter.of(context).pop(),
                        child: const Padding(
                          padding: EdgeInsets.only(bottom: 10.0),
                          child: Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      title: Padding(
                        padding: const EdgeInsets.only(bottom: 10.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                autocorrect: false,
                                controller: _textController,
                                focusNode: _textFieldFocusNode,
                                onFieldSubmitted: (value) {
                                  setState(() {
                                    if (value.isEmpty) {
                                      // Jika kosong, kembalikan semua produk
                                      filteredProducts =
                                          List<Map<String, dynamic>>.from(
                                              storeData!['products']);
                                    } else {
                                      // Pastikan konversi dilakukan dengan benar
                                      filteredProducts =
                                          List<Map<String, dynamic>>.from(
                                        storeData!['products'].where((product) {
                                          final productName =
                                              (product['name'] ?? '')
                                                  .toString()
                                                  .toLowerCase();
                                          return productName
                                              .contains(value.toLowerCase());
                                        }),
                                      );
                                    }
                                  });
                                },
                                decoration: InputDecoration(
                                  isDense: true,
                                  hintText: 'Cari Produk di Toko...',
                                  hintStyle: const TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFFC58189),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderSide: const BorderSide(
                                        color: Colors.transparent),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderSide: const BorderSide(
                                        color: Colors.transparent),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                  prefixIcon: const Icon(
                                    Icons.search,
                                    color: Color(0xFFC58189),
                                  ),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      isFilterApplied
                                          ? Icons.filter_alt
                                          : Icons.filter_alt_outlined,
                                      color: const Color(0xFFC58189),
                                    ),
                                    onPressed: () {
                                      _showFilterDrawer(context);
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      actions: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(0, 0, 10, 10),
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.shopping_cart_outlined,
                                  color: Colors.white,
                                ),
                                onPressed: () {
                                  getAccessToken();
                                  context.push('/cart');
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                      centerTitle: false,
                      elevation: 0,
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 5),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 8,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              // Store profile section
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Store logo with elevation
                                    Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color:
                                                Colors.black.withOpacity(0.1),
                                            blurRadius: 6,
                                            offset: Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: CircleAvatar(
                                        radius: 32,
                                        backgroundColor: Colors.white,
                                        child: ClipOval(
                                          child: Image.network(
                                            '$apiBaseUrlImage${storeData!["logo"]}',
                                            fit: BoxFit.cover,
                                            width: 64,
                                            height: 64,
                                            errorBuilder:
                                                (context, error, stackTrace) {
                                              return Container(
                                                width: 64,
                                                height: 64,
                                                alignment: Alignment.center,
                                                decoration: BoxDecoration(
                                                  color: Color(0xFF31394E),
                                                  gradient: LinearGradient(
                                                    colors: [
                                                      Color(0xFF31394E),
                                                      Color(0xFF474F67)
                                                    ],
                                                    begin: Alignment.topLeft,
                                                    end: Alignment.bottomRight,
                                                  ),
                                                ),
                                                child: Text(
                                                  storeData!["store_name"]
                                                      .substring(0, 1)
                                                      .toUpperCase(),
                                                  style: const TextStyle(
                                                    fontSize: 22,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),

                                    // Store details
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          // Store name and info button
                                          Row(
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  storeData!["store_name"],
                                                  style: TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                    color: Color(0xFF31394E),
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                              SizedBox(width: 6),
                                              Tooltip(
                                                message: storeData![
                                                        "information"] ??
                                                    "No additional information",
                                                child: Container(
                                                  padding: EdgeInsets.all(4),
                                                  decoration: BoxDecoration(
                                                    color: Color(0xFFF5F5F5),
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: Icon(
                                                    Icons.info_outline,
                                                    color: Color(0xFF31394E),
                                                    size: 16,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),

                                          // Store address
                                          Padding(
                                            padding: const EdgeInsets.only(
                                                top: 6, bottom: 8),
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.location_on_outlined,
                                                  color: Colors.grey[600],
                                                  size: 14,
                                                ),
                                                SizedBox(width: 4),
                                                Expanded(
                                                  child: Text(
                                                    storeData!["address"] ??
                                                        "No address available",
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      color: Colors.grey[600],
                                                    ),
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),

                                          // Store statistics - rating and transactions
                                          Container(
                                            padding: EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: Colors.grey[100],
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                // Rating
                                                Icon(
                                                  Icons.star,
                                                  color: Colors.amber,
                                                  size: 16,
                                                ),
                                                SizedBox(width: 4),
                                                Text(
                                                  storeData!['overall_rating'] !=
                                                          null
                                                      ? '${storeData!['overall_rating'].toString()} (${storeData!['total_reviews']})'
                                                      : 'No reviews',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w500,
                                                    color: Colors.grey[800],
                                                  ),
                                                ),

                                                // Divider
                                                Padding(
                                                  padding: const EdgeInsets
                                                      .symmetric(horizontal: 8),
                                                  child: Container(
                                                    height: 12,
                                                    width: 1,
                                                    color: Colors.grey[300],
                                                  ),
                                                ),

                                                // Transactions
                                                Icon(
                                                  Icons.shopping_bag_outlined,
                                                  color: Color(0xFFC58189),
                                                  size: 14,
                                                ),
                                                SizedBox(width: 4),
                                                Text(
                                                  "${storeData!['transaction_count'] ?? 0} transaksi",
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w500,
                                                    color: Colors.grey[800],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Divider
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                child:
                                    Divider(height: 1, color: Colors.grey[200]),
                              ),

                              // Points and voucher section
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 12, 16, 16),
                                child: Row(
                                  children: [
                                    // Points button with animated background
                                    Expanded(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          gradient: LinearGradient(
                                            colors: [
                                              Color(0xFFFBE9E7),
                                              Color(0xFFFFF3F1),
                                            ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                        ),
                                        child: Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            onTap: () {
                                              _showPoinHistoryDrawer(
                                                  context, widget.storeId);
                                            },
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 10,
                                                      horizontal: 12),
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Container(
                                                    padding: EdgeInsets.all(6),
                                                    decoration: BoxDecoration(
                                                      color: Color(0xFFC58189)
                                                          .withOpacity(0.2),
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: Icon(
                                                      Icons.card_giftcard,
                                                      color: Color(0xFFC58189),
                                                      size: 16,
                                                    ),
                                                  ),
                                                  SizedBox(width: 8),
                                                  Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        '${points} Points',
                                                        style: TextStyle(
                                                          color:
                                                              Color(0xFFC58189),
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 14,
                                                        ),
                                                      ),
                                                      Text(
                                                        'View History',
                                                        style: TextStyle(
                                                          color: Color(
                                                                  0xFFC58189)
                                                              .withOpacity(0.7),
                                                          fontSize: 10,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),

                                    SizedBox(width: 10),

                                    // Buy voucher button
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: () => _showVoucherDrawer(
                                            context, widget.storeId),
                                        style: ElevatedButton.styleFrom(
                                          elevation: 0,
                                          backgroundColor: Color(0xFFC58189),
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                          padding: EdgeInsets.symmetric(
                                              vertical: 13),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.local_offer_outlined,
                                              size: 16,
                                            ),
                                            SizedBox(width: 8),
                                            Text(
                                              'Buy Voucher',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Action buttons (Chat, WhatsApp, and Follow)
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                child: Row(
                                  children: [
                                    // Chat button
                                    Expanded(
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          onTap: _openChat,
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 12),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              border: Border.all(
                                                width: 1.5,
                                                color: const Color(0xFFC58189),
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            alignment: Alignment.center,
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons.chat_bubble_outline,
                                                  color: Color(0xFFC58189),
                                                  size: 18,
                                                ),
                                                SizedBox(width: 8),
                                                Text(
                                                  'Live Chat',
                                                  style: TextStyle(
                                                    color: Color(0xFFC58189),
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),

                                    SizedBox(width: 10),

                                    // WhatsApp button
                                    Expanded(
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          onTap: _openWhatsApp,
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 12),
                                            decoration: BoxDecoration(
                                              color: Color(0xFF25D366),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            alignment: Alignment.center,
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons.chat,
                                                  color: Colors.white,
                                                  size: 18,
                                                ),
                                                SizedBox(width: 8),
                                                Text(
                                                  'WA',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),

                                    SizedBox(width: 10),

                                    // Follow/Unfollow button
                                    Expanded(
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          onTap: () async {
                                            if (isFollow) {
                                              await unfollowStore();
                                            } else {
                                              await followStore();
                                            }
                                          },
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 12),
                                            decoration: BoxDecoration(
                                              color: isFollow
                                                  ? Colors.white
                                                  : null,
                                              border: Border.all(
                                                width: 1.5,
                                                color: isFollow
                                                    ? const Color(0xFFC58189)
                                                    : Colors.transparent,
                                              ),
                                              gradient: isFollow
                                                  ? null
                                                  : const LinearGradient(
                                                      colors: [
                                                        Color(0xFFE8C4BD),
                                                        Color(0xFFC58189),
                                                      ],
                                                      begin: Alignment.topLeft,
                                                      end:
                                                          Alignment.bottomRight,
                                                    ),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            alignment: Alignment.center,
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  isFollow
                                                      ? Icons
                                                          .person_remove_outlined
                                                      : Icons
                                                          .person_add_outlined,
                                                  color: isFollow
                                                      ? const Color(0xFFC58189)
                                                      : Colors.white,
                                                  size: 18,
                                                ),
                                                SizedBox(width: 8),
                                                Text(
                                                  isFollow
                                                      ? 'Unfollow'
                                                      : 'Follow',
                                                  style: TextStyle(
                                                    color: isFollow
                                                        ? const Color(
                                                            0xFFC58189)
                                                        : Colors.white,
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: SizedBox(height: 2),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      sliver: filteredProducts.isEmpty
                          ? SliverToBoxAdapter(
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons
                                          .shopping_bag_outlined, // Ikon produk kosong
                                      size: 80,
                                      color: Colors.grey.shade400,
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      'Produk tidak ditemukan',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : SliverGrid(
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: MediaQuery.of(context)
                                            .size
                                            .width >
                                        1200
                                    ? 8
                                    : MediaQuery.of(context).size.width > 800
                                        ? 5
                                        : 2,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio:
                                    MediaQuery.of(context).size.width > 800
                                        ? 0.75
                                        : 0.65,
                              ),
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final product = filteredProducts[index];
                                  return GestureDetector(
                                    onTap: () {
                                      final productId = product['product_id'];
                                      if (productId != null) {
                                        context
                                            .push('/product-detail/$productId');
                                      } else {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content:
                                                Text('Product ID is missing'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    },
                                    child: ProductCardStore(product),
                                  );
                                },
                                childCount: filteredProducts.length,
                              ),
                            ),
                    )
                  ],
                ),
              ),
      ),
    );
  }

  void _showFilterDrawer(BuildContext context) {
    final filters = extractFiltersFromStoreData(storeData!);

    // Count active filters for the badge
    int activeFilterCount = selectedTypes.length +
        selectedPurities.length +
        selectedMetalTypes.length +
        (lowPriceController.text.isNotEmpty ? 1 : 0) +
        (highPriceController.text.isNotEmpty ? 1 : 0) +
        (lowWeightController.text.isNotEmpty ? 1 : 0) +
        (highWeightController.text.isNotEmpty ? 1 : 0);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            // Function to update active filter count
            void updateFilterCount() {
              activeFilterCount = selectedTypes.length +
                  selectedPurities.length +
                  selectedMetalTypes.length +
                  (lowPriceController.text.isNotEmpty ? 1 : 0) +
                  (highPriceController.text.isNotEmpty ? 1 : 0) +
                  (lowWeightController.text.isNotEmpty ? 1 : 0) +
                  (highWeightController.text.isNotEmpty ? 1 : 0);
            }

            // Function to clear all filters
            void clearAllFilters() {
              setState(() {
                selectedTypes.clear();
                selectedPurities.clear();
                selectedMetalTypes.clear();
                lowPriceController.clear();
                highPriceController.clear();
                lowWeightController.clear();
                highWeightController.clear();
                updateFilterCount();
              });
            }

            return FractionallySizedBox(
              heightFactor: 0.85,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with drag handle and title
                    Container(
                      padding: EdgeInsets.fromLTRB(20, 16, 20, 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(20)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            spreadRadius: 1,
                            blurRadius: 4,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Drag handle
                          Center(
                            child: Container(
                              width: 50,
                              height: 5,
                              decoration: BoxDecoration(
                                color: Colors.grey[300],
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                          SizedBox(height: 16),
                          // Header with title and clear button
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Filter',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF31394E),
                                    ),
                                  ),
                                  if (activeFilterCount > 0)
                                    Container(
                                      margin: EdgeInsets.only(left: 8),
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Color(0xFFC58189),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        activeFilterCount.toString(),
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              if (activeFilterCount > 0)
                                TextButton(
                                  onPressed: clearAllFilters,
                                  child: Text(
                                    'Clear All',
                                    style: TextStyle(
                                      color: Color(0xFFC58189),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Filter options in scrollable area
                    Expanded(
                      child: SingleChildScrollView(
                        physics: BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(height: 20),

                            // Category Filter Section
                            Row(
                              children: [
                                Icon(Icons.category_outlined,
                                    color: Color(0xFF31394E), size: 20),
                                SizedBox(width: 10),
                                Text(
                                  'Category',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF31394E),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 12),
                            Wrap(
                              spacing: 10.0,
                              runSpacing: 10.0,
                              children: filters
                                  .map((filter) => filter['name'])
                                  .toSet()
                                  .map((name) {
                                final isSelected = selectedTypes.contains(name);

                                return GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      if (isSelected) {
                                        selectedTypes.remove(name);
                                      } else {
                                        selectedTypes.add(name);
                                      }
                                      updateFilterCount();
                                    });
                                  },
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 14.0, vertical: 10.0),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? Color(0xFFFBE9E7)
                                          : Colors.grey[100],
                                      borderRadius: BorderRadius.circular(8.0),
                                      border: Border.all(
                                        color: isSelected
                                            ? Color(0xFFC58189)
                                            : Colors.grey.shade300,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          name,
                                          style: TextStyle(
                                            color: isSelected
                                                ? Color(0xFFC58189)
                                                : Colors.black87,
                                            fontWeight: isSelected
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                          ),
                                        ),
                                        if (isSelected) ...[
                                          SizedBox(width: 6),
                                          Icon(
                                            Icons.check_circle,
                                            color: Color(0xFFC58189),
                                            size: 16,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),

                            SizedBox(height: 24),

                            // Purity Filter Section
                            Row(
                              children: [
                                Icon(Icons.diamond_outlined,
                                    color: Color(0xFF31394E), size: 20),
                                SizedBox(width: 10),
                                Text(
                                  'Purity',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF31394E),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 12),
                            Wrap(
                              spacing: 10.0,
                              runSpacing: 10.0,
                              children: filters
                                  .map((filter) => filter['purity'])
                                  .toSet()
                                  .map((purity) {
                                final isSelected =
                                    selectedPurities.contains(purity);

                                return GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      if (isSelected) {
                                        selectedPurities.remove(purity);
                                      } else {
                                        selectedPurities.add(purity);
                                      }
                                      updateFilterCount();
                                    });
                                  },
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 14.0, vertical: 10.0),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? Color(0xFFFBE9E7)
                                          : Colors.grey[100],
                                      borderRadius: BorderRadius.circular(8.0),
                                      border: Border.all(
                                        color: isSelected
                                            ? Color(0xFFC58189)
                                            : Colors.grey.shade300,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          purity,
                                          style: TextStyle(
                                            color: isSelected
                                                ? Color(0xFFC58189)
                                                : Colors.black87,
                                            fontWeight: isSelected
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                          ),
                                        ),
                                        if (isSelected) ...[
                                          SizedBox(width: 6),
                                          Icon(
                                            Icons.check_circle,
                                            color: Color(0xFFC58189),
                                            size: 16,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),

                            SizedBox(height: 24),

                            // Metal Type Filter Section
                            Row(
                              children: [
                                Icon(Icons.design_services_outlined,
                                    color: Color(0xFF31394E), size: 20),
                                SizedBox(width: 10),
                                Text(
                                  'Metal Type',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF31394E),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 12),
                            Wrap(
                              spacing: 10.0,
                              runSpacing: 10.0,
                              children: filters
                                  .map((filter) => _getMetalTypeName(
                                      filter['metal_type'] as int))
                                  .toSet()
                                  .map((metalType) {
                                final isSelected =
                                    selectedMetalTypes.contains(metalType);

                                return GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      if (isSelected) {
                                        selectedMetalTypes.remove(metalType);
                                      } else {
                                        selectedMetalTypes.add(metalType);
                                      }
                                      updateFilterCount();
                                    });
                                  },
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 14.0, vertical: 10.0),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? Color(0xFFFBE9E7)
                                          : Colors.grey[100],
                                      borderRadius: BorderRadius.circular(8.0),
                                      border: Border.all(
                                        color: isSelected
                                            ? Color(0xFFC58189)
                                            : Colors.grey.shade300,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          metalType,
                                          style: TextStyle(
                                            color: isSelected
                                                ? Color(0xFFC58189)
                                                : Colors.black87,
                                            fontWeight: isSelected
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                          ),
                                        ),
                                        if (isSelected) ...[
                                          SizedBox(width: 6),
                                          Icon(
                                            Icons.check_circle,
                                            color: Color(0xFFC58189),
                                            size: 16,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),

                            SizedBox(height: 24),

                            // Price Range Filter Section
                            Row(
                              children: [
                                Icon(Icons.price_change_outlined,
                                    color: Color(0xFF31394E), size: 20),
                                SizedBox(width: 10),
                                Text(
                                  'Price Range',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF31394E),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      color: Colors.grey[100],
                                      border: Border.all(
                                        color: Colors.grey[300]!,
                                        width: 1,
                                      ),
                                    ),
                                    child: TextField(
                                      controller: lowPriceController,
                                      keyboardType: TextInputType.number,
                                      onChanged: (_) =>
                                          setState(() => updateFilterCount()),
                                      inputFormatters: [
                                        FilteringTextInputFormatter.allow(
                                            RegExp(r'^[1-9][0-9]*|0$')),
                                      ],
                                      decoration: InputDecoration(
                                        labelText: 'Min',
                                        labelStyle: TextStyle(
                                            color: Color(0xFF31394E),
                                            fontSize: 14),
                                        prefixIcon: Icon(Icons.remove,
                                            color: Color(0xFFC58189), size: 18),
                                        border: InputBorder.none,
                                        contentPadding: EdgeInsets.symmetric(
                                            vertical: 12, horizontal: 12),
                                      ),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8.0),
                                  child: Text('to',
                                      style:
                                          TextStyle(color: Colors.grey[600])),
                                ),
                                Expanded(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      color: Colors.grey[100],
                                      border: Border.all(
                                        color: Colors.grey[300]!,
                                        width: 1,
                                      ),
                                    ),
                                    child: TextField(
                                      controller: highPriceController,
                                      keyboardType: TextInputType.number,
                                      onChanged: (_) =>
                                          setState(() => updateFilterCount()),
                                      inputFormatters: [
                                        FilteringTextInputFormatter.allow(
                                            RegExp(r'^[1-9][0-9]*|0$')),
                                      ],
                                      decoration: InputDecoration(
                                        labelText: 'Max',
                                        labelStyle: TextStyle(
                                            color: Color(0xFF31394E),
                                            fontSize: 14),
                                        prefixIcon: Icon(Icons.add,
                                            color: Color(0xFFC58189), size: 18),
                                        border: InputBorder.none,
                                        contentPadding: EdgeInsets.symmetric(
                                            vertical: 12, horizontal: 12),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            SizedBox(height: 24),

                            // Weight Range Filter Section
                            Row(
                              children: [
                                Icon(Icons.scale_outlined,
                                    color: Color(0xFF31394E), size: 20),
                                SizedBox(width: 10),
                                Text(
                                  'Weight Range (grams)',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF31394E),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      color: Colors.grey[100],
                                      border: Border.all(
                                        color: Colors.grey[300]!,
                                        width: 1,
                                      ),
                                    ),
                                    child: TextField(
                                      controller: lowWeightController,
                                      keyboardType: TextInputType.number,
                                      onChanged: (_) =>
                                          setState(() => updateFilterCount()),
                                      inputFormatters: [
                                        FilteringTextInputFormatter.allow(
                                            RegExp(r'^\d+(\.\d{0,2})?$')),
                                      ],
                                      decoration: InputDecoration(
                                        labelText: 'Min',
                                        labelStyle: TextStyle(
                                            color: Color(0xFF31394E),
                                            fontSize: 14),
                                        prefixIcon: Icon(Icons.remove,
                                            color: Color(0xFFC58189), size: 18),
                                        border: InputBorder.none,
                                        contentPadding: EdgeInsets.symmetric(
                                            vertical: 12, horizontal: 12),
                                      ),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8.0),
                                  child: Text('to',
                                      style:
                                          TextStyle(color: Colors.grey[600])),
                                ),
                                Expanded(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      color: Colors.grey[100],
                                      border: Border.all(
                                        color: Colors.grey[300]!,
                                        width: 1,
                                      ),
                                    ),
                                    child: TextField(
                                      controller: highWeightController,
                                      keyboardType: TextInputType.number,
                                      onChanged: (_) =>
                                          setState(() => updateFilterCount()),
                                      inputFormatters: [
                                        FilteringTextInputFormatter.allow(
                                            RegExp(r'^\d+(\.\d{0,2})?$')),
                                      ],
                                      decoration: InputDecoration(
                                        labelText: 'Max',
                                        labelStyle: TextStyle(
                                            color: Color(0xFF31394E),
                                            fontSize: 14),
                                        prefixIcon: Icon(Icons.add,
                                            color: Color(0xFFC58189), size: 18),
                                        border: InputBorder.none,
                                        contentPadding: EdgeInsets.symmetric(
                                            vertical: 12, horizontal: 12),
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

                    // Apply button in fixed position at bottom
                    Container(
                      padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            spreadRadius: 1,
                            blurRadius: 4,
                            offset: Offset(0, -1),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                final double? lowPrice =
                                    double.tryParse(lowPriceController.text);
                                final double? highPrice =
                                    double.tryParse(highPriceController.text);
                                final double? lowWeight =
                                    double.tryParse(lowWeightController.text);
                                final double? highWeight =
                                    double.tryParse(highWeightController.text);

                                applyFilter(
                                  selectedTypes,
                                  selectedPurities,
                                  selectedMetalTypes,
                                  lowPrice: lowPrice,
                                  highPrice: highPrice,
                                  lowWeight: lowWeight,
                                  highWeight: highWeight,
                                );

                                Navigator.pop(context);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Color(0xFF31394E),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding: EdgeInsets.symmetric(vertical: 16),
                                elevation: 0,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Apply Filters',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (activeFilterCount > 0) ...[
                                    SizedBox(width: 8),
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        activeFilterCount.toString(),
                                        style: TextStyle(
                                          color: Color(0xFF31394E),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCategoryBox({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        decoration: BoxDecoration(
          color: isSelected ? Color(0xFFC58189) : Colors.grey[200],
          borderRadius: BorderRadius.circular(10.0),
          border: Border.all(
            color: isSelected ? Color(0xFFC58189) : Colors.grey.shade300,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // Widget Box Placeholder Shimmer
  Widget shimmerBox() {
    return Expanded(
      flex: 1,
      child: Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: 8),
          height: 100,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterOption({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      splashColor: Colors.grey[200],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: Colors.blueGrey, size: 24),
            SizedBox(width: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
