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
  final TextEditingController _textController = TextEditingController();
  final FocusNode _textFieldFocusNode = FocusNode();
  Set<String> selectedTypes = {};
  String _userName = '';
  bool isRingSelected = false;
  bool isNecklaceSelected = false;
  bool isEarringSelected = false;
  bool isBraceletSelected = false;
  bool is24KSelected = false;
  bool is22KSelected = false;
  bool is18KSelected = false;
  bool is14KSelected = false;
  bool isYellowGoldSelected = false;
  bool isWhiteGoldSelected = false;
  bool isRoseGoldSelected = false;
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

    // Ambil semua type dari produk
    final types = products
        .map((product) => product['type'] as Map<String, dynamic>)
        .toList();

    // Hilangkan duplikasi berdasarkan `type_id`
    final uniqueTypes =
        types.fold<Map<String, Map<String, dynamic>>>({}, (acc, type) {
      acc[type['type_id']] = type;
      return acc;
    });

    return uniqueTypes.values.toList();
  }

  void applyFilter(Set<String> selectedTypeIds,
      {double? lowPrice, double? highPrice}) {
    setState(() {
      isFilterApplied =
          selectedTypeIds.isNotEmpty || lowPrice != null || highPrice != null;

      // Pastikan `products` memiliki tipe yang benar
      final products = List<Map<String, dynamic>>.from(storeData!['products']);

      filteredProducts = products.where((product) {
        final type = product['type'] as Map<String, dynamic>;
        final price = product['price'] as int;

        final typeMatches = selectedTypeIds.isEmpty ||
            selectedTypeIds.contains(type['type_id']);
        final priceMatches = (lowPrice == null || price >= lowPrice) &&
            (highPrice == null || price <= highPrice);

        return typeMatches && priceMatches;
      }).toList();
    });
  }

  Future<void> fetchStoreData() async {
    try {
      final response = await http.get(
        Uri.parse("$apiBaseUrl/store/${widget.storeId}"),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body)['data'];
        setState(() {
          storeData = data;
          // Inisialisasi filteredProducts dengan semua produk
          filteredProducts = List<Map<String, dynamic>>.from(data['products']);
        });
      } else {
        throw Exception("Failed to load store data");
      }

      String token = await getAccessToken();
      final pointsResponse = await http.get(
        Uri.parse("$apiBaseUrl/user-poin/${widget.storeId}"),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );
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
    const phoneNumber = "6281615750759"; // Replace with your WhatsApp number
    final whatsappUrl = Uri.parse("https://wa.me/$phoneNumber");

    if (await canLaunchUrl(whatsappUrl)) {
      await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
    } else {
      throw "Unable to open WhatsApp";
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
              return Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError || snapshot.data == null) {
              return Center(
                child: Text(
                  'Failed to load poin history',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              );
            }

            final poinHistory = snapshot.data!;

            if (poinHistory.isEmpty) {
              return Center(
                child: Text(
                  'No poin history available',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              );
            }

            return FractionallySizedBox(
              heightFactor: 0.65,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 50,
                        height: 6,
                        margin: EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    Text(
                      'Poin History',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    SizedBox(height: 10),
                    Expanded(
                      child: ListView.builder(
                        itemCount: poinHistory.length,
                        itemBuilder: (context, index) {
                          final history = poinHistory[index];
                          return _buildPoinHistoryCard(history);
                        },
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

  Widget _buildPoinHistoryCard(Map<String, dynamic> history) {
    final createdAt = DateTime.parse(history['created_at']);
    final formattedDate =
        "${createdAt.year}-${createdAt.month}-${createdAt.day}";

    // Tentukan warna berdasarkan poin
    final cardColor =
        history['poin_used'] < 0 ? Color(0xFFC58189) : Color(0xFF31394E);

    return Card(
      margin: EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              history['purpose'] ?? 'Unknown Purpose',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 5),
            Text(
              'Points: ${history['poin_used']}',
              style: TextStyle(fontSize: 14, color: Colors.white70),
            ),
            Text(
              'Date: $formattedDate',
              style: TextStyle(fontSize: 14, color: Colors.white70),
            ),
          ],
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return FutureBuilder(
          future: Future.wait([
            fetchOwnedVouchers(storeId), // Ambil owned vouchers
            fetchActiveVouchers(storeId), // Ambil available vouchers
          ]),
          builder: (context, AsyncSnapshot<List<dynamic>> snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Failed to load vouchers',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              );
            }

            final ownedVouchers = snapshot.data![0];
            final availableVouchers = snapshot.data![1];

            return FractionallySizedBox(
              heightFactor: 0.65,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 5),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 50,
                          height: 6,
                          margin: EdgeInsets.only(bottom: 2),
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      if (ownedVouchers.isNotEmpty) ...[
                        Text(
                          'Owned Vouchers',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        SizedBox(height: 10),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: NeverScrollableScrollPhysics(),
                          itemCount: ownedVouchers.length,
                          itemBuilder: (context, index) {
                            final voucher = ownedVouchers[index];
                            return _buildVoucherCard(
                              voucher['voucher_name'],
                              'Discount: ${voucher['discount_amount']}%',
                              'Points: ${voucher['poin_price']}',
                              'Valid: ${voucher['start_date'].split('T')[0]} - ${voucher['end_date'].split('T')[0]}',
                              double.parse(voucher['minimum_purchase']),
                            );
                          },
                        ),
                      ],
                      if (ownedVouchers.isNotEmpty) SizedBox(height: 0),
                      Text(
                        'Available Vouchers',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      SizedBox(height: 10),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
                        itemCount: availableVouchers.length,
                        itemBuilder: (context, index) {
                          final voucher = availableVouchers[index];
                          return _buildVoucherCard(
                            voucher['voucher_name'],
                            'Discount: ${voucher['discount_amount']}%',
                            'Points: ${voucher['poin_price']}',
                            'Valid: ${voucher['start_date'].split('T')[0]} - ${voucher['end_date'].split('T')[0]}',
                            double.parse(voucher['minimum_purchase']),
                            onTap: () async {
                              // Ambil token dan store ID
                              String accessToken =
                                  await getAccessToken(); // Ambil access token
                              String storeId =
                                  widget.storeId; // Ambil store ID dari widget

                              // Tampilkan dialog konfirmasi
                              showPurchaseConfirmationDialog(
                                context,
                                voucher['voucher_name'],
                                voucher['poin_price'],
                                () async {
                                  // Proses pembelian voucher
                                  await buyVoucher(context, accessToken,
                                      voucher['voucher_id'], storeId);
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
            );
          },
        );
      },
    );
  }

  Widget _buildVoucherCard(String name, String discount, String points,
      String validity, double minimumPurchase,
      {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap, // Tambahkan onTap untuk aksi
      child: Card(
        color: Color(0xFF31394E),
        margin: EdgeInsets.symmetric(vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 5),
              Text(
                discount,
                style: TextStyle(fontSize: 14, color: Colors.white70),
              ),
              Text(
                points,
                style: TextStyle(fontSize: 14, color: Colors.white70),
              ),
              Text(
                validity,
                style: TextStyle(fontSize: 14, color: Colors.white70),
              ),
              Text(
                'Min. Transaction: ${formatCurrency(minimumPurchase)}',
                style: TextStyle(fontSize: 14, color: Colors.white70),
              ),
            ],
          ),
        ),
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
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
                      backgroundColor: Color(0xFF31394E),
                      automaticallyImplyLeading: false,
                      toolbarHeight: 80,
                      leading: GestureDetector(
                        onTap: () => GoRouter.of(context).pop(),
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 10.0),
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
                                controller: _textController,
                                focusNode: _textFieldFocusNode,
                                decoration: InputDecoration(
                                  isDense: true,
                                  hintText: 'Cari...',
                                  hintStyle: TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFFC58189),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderSide:
                                        BorderSide(color: Colors.transparent),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderSide:
                                        BorderSide(color: Colors.transparent),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                  prefixIcon: Icon(
                                    Icons.search,
                                    color: Color(0xFFC58189),
                                  ),
                                  suffixIcon: IconButton(
                                    icon: Icon(isFilterApplied
                                        ? Icons.filter_alt
                                        : Icons.filter_alt_outlined),
                                    color: Color(0xFFC58189),
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
                                icon: Icon(
                                  Icons.shopping_cart_outlined,
                                  color: Colors.white,
                                ),
                                onPressed: () {
                                  getAccessToken();
                                  context.go('/cart');
                                  // Navigator.pushReplacementNamed(
                                  //     context, '/cart');
                                },
                              ),
                              Positioned(
                                right: 0,
                                top: 0,
                                child: Container(
                                  width: 18,
                                  height: 18,
                                  decoration: BoxDecoration(
                                    color: Color(0xFFC58189),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      '3',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
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
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 7),
                          padding: const EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 30,
                                      backgroundImage: NetworkImage(
                                        '$apiBaseUrlImage${storeData!["image_url"]}',
                                      ),
                                      backgroundColor: Colors.white,
                                    ),
                                    const SizedBox(width: 15),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            storeData!["store_name"],
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          SizedBox(height: 5),
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.star,
                                                color: Colors.amber,
                                                size: 16,
                                              ),
                                              SizedBox(width: 5),
                                              Text(
                                                storeData!['overall_rating'] !=
                                                        null
                                                    ? storeData![
                                                            'overall_rating']
                                                        .toString()
                                                    : 'No review',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.grey[700],
                                                ),
                                              ),
                                              SizedBox(width: 10),
                                              Text(
                                                "${storeData!['transaction_count'] ?? 0} transaksi",
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.grey[700],
                                                ),
                                              ),
                                            ],
                                          ),
                                          SizedBox(
                                              height: 10), // Jarak antar elemen
                                          Row(
                                            children: [
                                              Expanded(
                                                child: ElevatedButton.icon(
                                                  onPressed: () {
                                                    _showPoinHistoryDrawer(
                                                        context,
                                                        widget.storeId);
                                                  },
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                    elevation: 0,
                                                    backgroundColor:
                                                        Color(0xFFFBE9E7),
                                                    shape:
                                                        RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8),
                                                    ),
                                                    padding:
                                                        EdgeInsets.symmetric(
                                                            vertical: 8),
                                                  ),
                                                  icon: Icon(
                                                    Icons.card_giftcard,
                                                    color: Color(0xFFC58189),
                                                    size: 18,
                                                  ),
                                                  label: Text(
                                                    '${points} Poin',
                                                    style: TextStyle(
                                                      color: Color(0xFFC58189),
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              SizedBox(
                                                  width:
                                                      8), // Jarak antara tombol
                                              Expanded(
                                                child: ElevatedButton(
                                                  onPressed: () =>
                                                      _showVoucherDrawer(
                                                          context,
                                                          widget.storeId),
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        Color(0xFFC58189),
                                                    shape:
                                                        RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              10),
                                                    ),
                                                  ),
                                                  child: Text(
                                                    'Buy Voucher',
                                                    style: TextStyle(
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 12),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 15),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    GestureDetector(
                                      onTap: _openWhatsApp,
                                      child: Container(
                                        width:
                                            MediaQuery.of(context).size.width *
                                                0.4,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          border: Border.all(
                                            width: 2,
                                            color: const Color(0xFFC58189),
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 8),
                                        alignment: Alignment.center,
                                        child: const Text(
                                          'Chat',
                                          style: TextStyle(
                                            color: Color(0xFFC58189),
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () async {
                                        if (isFollow) {
                                          await unfollowStore();
                                        } else {
                                          await followStore();
                                        }
                                      },
                                      child: Container(
                                        width:
                                            MediaQuery.of(context).size.width *
                                                0.4,
                                        decoration: BoxDecoration(
                                          color: isFollow
                                              ? Colors.white
                                              : null, // Use Colors.white when isFollow is true
                                          border: Border.all(
                                            width: 2,
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
                                                  begin: Alignment.topCenter,
                                                  end: Alignment.bottomCenter,
                                                ),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 8),
                                        alignment: Alignment.center,
                                        child: Text(
                                          isFollow ? 'Unfollow' : 'Follow',
                                          style: TextStyle(
                                            color: isFollow
                                                ? const Color(0xFFC58189)
                                                : Colors.white,
                                            fontSize: 14,
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
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: SizedBox(height: 2),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      sliver: SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 0.65,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final product = filteredProducts[index];
                            return GestureDetector(
                              onTap: () {
                                final productId =
                                    product['product_id']; // Ambil ID produk
                                if (productId != null) {
                                  context.push(
                                      '/product-detail/$productId'); // Navigasi ke detail produk
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Product ID is missing'),
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
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  void _showFilterDrawer(BuildContext context) {
    final filters = extractFiltersFromStoreData(storeData!);

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
            return FractionallySizedBox(
              heightFactor: 0.8,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16.0, vertical: 16.0),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 50,
                          height: 6,
                          margin: EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      // Filter by Types
                      Text(
                        'Select Types',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 10),
                      Wrap(
                        spacing: 12.0,
                        runSpacing: 12.0,
                        children: filters.map((filter) {
                          final typeId = filter['type_id'] as String;
                          final isSelected = selectedTypes.contains(typeId);

                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                if (isSelected) {
                                  selectedTypes.remove(typeId);
                                } else {
                                  selectedTypes.add(typeId);
                                }
                              });
                            },
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 16.0, vertical: 12.0),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Color(0xFFC58189)
                                    : Colors.grey[200],
                                borderRadius: BorderRadius.circular(10.0),
                                border: Border.all(
                                  color: isSelected
                                      ? Color(0xFFC58189)
                                      : Colors.grey.shade300,
                                  width: 1.5,
                                ),
                              ),
                              child: Text(
                                "${filter['name']} - ${filter['purity']} - ${filter['metal_type']}",
                                style: TextStyle(
                                  color:
                                      isSelected ? Colors.white : Colors.black,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          );
                        }).toList(),
                      ),

                      SizedBox(height: 20),
                      // Filter by Price Range
                      Text(
                        'Set Price Range',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: lowPriceController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                    RegExp(r'^[1-9][0-9]*|0$')),
                              ],
                              decoration: InputDecoration(
                                labelText: 'Low Price',
                                labelStyle: TextStyle(
                                    color: Color(0xFF31394E),
                                    fontWeight: FontWeight.bold),
                                prefixIcon: Icon(Icons.price_change_outlined,
                                    color: Color(0xFFC58189)),
                                filled: true,
                                fillColor: Colors.grey[100],
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(
                                      color: Colors.grey.shade300, width: 1.5),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(
                                      color: Color(0xFFC58189), width: 2),
                                ),
                                contentPadding: EdgeInsets.symmetric(
                                    vertical: 16, horizontal: 16),
                              ),
                            ),
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: highPriceController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                    RegExp(r'^[1-9][0-9]*|0$')),
                              ],
                              decoration: InputDecoration(
                                labelText: 'High Price',
                                labelStyle: TextStyle(
                                    color: Color(0xFF31394E),
                                    fontWeight: FontWeight.bold),
                                prefixIcon: Icon(Icons.price_check_outlined,
                                    color: Color(0xFFC58189)),
                                filled: true,
                                fillColor: Colors.grey[100],
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(
                                      color: Colors.grey.shade300, width: 1.5),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(
                                      color: Color(0xFFC58189), width: 2),
                                ),
                                contentPadding: EdgeInsets.symmetric(
                                    vertical: 16, horizontal: 16),
                              ),
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () {
                          // Parse price values from the controllers
                          final double? lowPrice =
                              double.tryParse(lowPriceController.text);
                          final double? highPrice =
                              double.tryParse(highPriceController.text);

                          // Apply the selected types and price range to filter the products
                          applyFilter(
                            selectedTypes,
                            lowPrice: lowPrice,
                            highPrice: highPrice,
                          );

                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF31394E),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          minimumSize: Size(double.infinity, 50),
                        ),
                        child: Text(
                          'Apply',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
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
