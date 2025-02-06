import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:marketplace_logamas/function/Utils.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:marketplace_logamas/screen/PaymentPage.dart';
import 'package:marketplace_logamas/screen/WaitingForPayment.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

class CheckoutPage extends StatefulWidget {
  final Map<String, dynamic> cartData;

  CheckoutPage({required this.cartData});
  @override
  _CheckoutPageState createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  Map<String, dynamic> storeProducts = {'store': {}, 'selectedProducts': []};
  double initialTotalPrice = 0; // Total harga sebelum diskon
  double totalPrice = 0; // Total harga setelah diskon
  double discount = 0; // Nilai diskon yang diterapkan
  String? selectedVoucher; // Nama voucher yang diterapkan
  String? selectedVoucherOwnedId; // ID voucher yang dimiliki
  String? selectedVoucherId; // ID voucher
  double taxAmount = 0; // Pajak yang diterapkan
  String? _accessToken;
  String _name = 'Loading...';
  String _email = 'Loading...';
  String _phone = 'Loading...';
  String _userId = 'Loading...';

  @override
  void initState() {
    super.initState();
    storeProducts = widget.cartData['data'][0];
    print(widget.cartData);

    // Calculate initial total price
    initialTotalPrice = _calculateTotalPrice();

    // Now calculate the tax
    _calculateTax();

    // Calculate the total price after tax and discount
    totalPrice = initialTotalPrice + taxAmount - discount;

    // Fetch any available voucher data
    _fetchVoucherData();

    _loadAccessTokenAndUserData();
  }

  Future<void> _loadAccessTokenAndUserData() async {
    try {
      final token = await getAccessToken();
      final userId = await getUserId();
      setState(() {
        _accessToken = token;
        _userId = userId;
      });

      if (_accessToken != null) {
        await _fetchUserProfile();
      }
    } catch (e) {
      print('Error loading access token or user data: $e');
    }
  }

  Future<void> _fetchUserProfile() async {
    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/user/profile'),
        headers: {
          'Authorization': 'Bearer $_accessToken',
        },
      );
      print(jsonDecode(response.body));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print(data);
        setState(() {
          _name = data['data']['name'];
          _email = data['data']['email'];
          _phone = data['data']['phone'];
        });
      } else {
        print('Failed to fetch user profile: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching user profile: $e');
    }
  }

  double _calculateTotalPrice() {
    double price = 0;
    for (var product in storeProducts['ProductList']) {
      price += product['productPrice'] * product['quantity'];
    }
    print("Initial Total Price: $price");
    return price;
  }

  void _calculateTax() {
    final taxPercentage =
        double.tryParse(storeProducts['store']['tax_percentage'].toString()) ??
            0.0;
    print("Tax Percentage: $taxPercentage");
    print("Initial Total Price: $initialTotalPrice");

    // Calculate tax
    taxAmount = (initialTotalPrice * taxPercentage) / 100;
    print("Tax Amount: $taxAmount");

    // Update the total price with the tax applied
    totalPrice = initialTotalPrice + taxAmount - discount;
    print("Total Price after Tax: $totalPrice");
  }

  int _calculateTotalPoints() {
    int points = 0;
    final poinConfig = storeProducts['store']['poin_config'] ??
        0; // Pastikan poin_config tersedia
    for (var product in storeProducts['ProductList']) {
      points +=
          (((product['productPrice'] as int) * (product['quantity'] as int)) *
                  (poinConfig as int) /
                  100)
              .floor();
    }
    return points;
  }

  void _applyVoucher(Map<String, dynamic>? voucher) {
    setState(() {
      if (voucher == null) {
        discount = 0;
        totalPrice = initialTotalPrice + taxAmount;
        selectedVoucher = null;
        selectedVoucherOwnedId = null;
        selectedVoucherId = null;
      } else {
        double calculatedDiscount =
            (voucher['discount_amount'] / 100) * initialTotalPrice;
        discount = calculatedDiscount > voucher['max_discount']
            ? voucher['max_discount']
            : calculatedDiscount;
        totalPrice = initialTotalPrice + taxAmount - discount;
        selectedVoucher = voucher['voucher_name'];
        selectedVoucherOwnedId = voucher['voucher_owned_id'];
        selectedVoucherId = voucher['voucher_id'];
      }
    });
  }

  // void _applyVoucher(Map<String, dynamic>? voucher) {
  //   setState(() {
  //     if (voucher == null) {
  //       // Reset jika voucher dihapus
  //       discount = 0;
  //       totalPrice = initialTotalPrice;
  //       selectedVoucher = null;
  //       selectedVoucherOwnedId = null;
  //       selectedVoucherId = null;
  //     } else {
  //       // Hitung diskon berdasarkan persentase
  //       double calculatedDiscount =
  //           (voucher['discount_amount'] / 100) * initialTotalPrice;

  //       // Batasi diskon hingga nilai max_discount
  //       discount = calculatedDiscount > voucher['max_discount']
  //           ? voucher['max_discount']
  //           : calculatedDiscount;

  //       // Perbarui total harga setelah diskon
  //       totalPrice = initialTotalPrice - discount;

  //       // Simpan informasi voucher yang diterapkan
  //       selectedVoucher = voucher['voucher_name'];
  //       selectedVoucherOwnedId = voucher['voucher_owned_id'];
  //       selectedVoucherId = voucher['voucher_id'];
  //     }
  //   });
  // }

  List<Map<String, dynamic>> voucherList = [
    {
      'name': 'Discount 10%',
      'description': 'For orders above \$50',
      'discount': 10
    },
    {
      'name': 'Free Shipping',
      'description': 'Valid for all orders',
      'discount': 0
    },
    {
      'name': 'Buy 1 Get 1',
      'description': 'Applicable on selected items',
      'discount': 50
    },
  ];

  Future<void> _checkout() async {
    try {
      final uuid = Uuid();
      final orderId = uuid.v4();

      // Load user data before proceeding
      await _loadAccessTokenAndUserData();

      if (_name == null || _email == null || _phone == null) {
        throw Exception("User data is missing. Please log in again.");
      }

      // Map items from storeProducts
      final List<Map<String, dynamic>> items = storeProducts['ProductList']
          .map<Map<String, dynamic>>((product) => {
                "id": product['product_code_id'],
                "price": product['productPrice'].toInt(),
                "quantity": product['quantity'],
                "name": product['productName'],
                "weight": product['productWeight'],
              })
          .toList();
      print(items);

      // Calculate the total item price before discount
      final totalItemPrice = items.fold(
          0,
          (sum, item) =>
              sum + (item["price"] as int) * (item["quantity"] as int));

      final grossAmount = totalItemPrice - discount + taxAmount;

      // Add the discount as a negative item (if applicable)
      if (discount > 0) {
        items.add({
          "id": "DISCOUNT",
          "price": -discount.toInt(), // Negative price for discount
          "quantity": 1,
          "name": "Voucher Discount",
        });
      }

      // Add tax as a separate item if applicable
      if (taxAmount > 0) {
        items.add({
          "id": "TAX",
          "price": taxAmount.toInt(), // Tax amount
          "quantity": 1,
          "name": "Tax (${storeProducts['store']['tax_percentage']}%)",
        });
      }

      // Send the grossAmount and taxAmount to the backend
      final response = await http.post(
        Uri.parse('$apiBaseUrl/transactions/init-transaction'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_accessToken', // Ensure token is passed
        },
        body: jsonEncode({
          "orderId": orderId,
          "grossAmount": grossAmount, // Gross amount (before tax)
          "items": items,
          "customerDetails": {
            "first_name": _name.split(' ').first, // Extract first name
            "last_name": _name.split(' ').length > 1
                ? _name.split(' ').sublist(1).join(' ')
                : "",
            "email": _email,
            "phone": _phone,
          },
          "storeId": storeProducts['store']['store_id'],
          "customerId": _userId, // Dynamically fetched customer ID
          "voucherOwnedId": selectedVoucherOwnedId,
          "taxAmount": taxAmount,
          "poin_earned": _calculateTotalPoints(),
        }),
      );

      if (response.statusCode != 201) {
        throw Exception("Failed to create transaction: ${response.body}");
      }

      final responseData = jsonDecode(response.body);
      final redirectUrl = responseData['data']['paymentLink'];

      if (redirectUrl == null || redirectUrl.isEmpty) {
        throw Exception("Payment link is missing in the response");
      }

      // Navigate to the payment page
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => WaitingForPaymentPage(orderId: orderId),
        ),
      );

      // Open the payment URL in the browser
      final uri = Uri.parse(redirectUrl);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e, stackTrace) {
      print("Checkout Error: $e");
      print("Stack Trace: $stackTrace");

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to create transaction: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<Map<String, dynamic>> createMidtransTransaction({
    required String orderId,
    required double grossAmount,
    required List<Map<String, dynamic>> items,
    required Map<String, dynamic> customerDetails,
  }) async {
    const String midtransUrl =
        "https://app.sandbox.midtrans.com/snap/v1/transactions";
    const String midtransServerKey =
        "U0ItTWlkLXNlcnZlci1Rc1pJYjdkT01FUm1QMmdpWi1KZjhmMnE=";

    final response = await http.post(
      Uri.parse(midtransUrl),
      headers: {
        'Authorization': 'Basic $midtransServerKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        "transaction_details": {
          "order_id": orderId,
          "gross_amount": grossAmount,
        },
        "item_details": items,
        "customer_details": customerDetails,
        "enabled_payments": [
          "credit_card",
          "bca_va",
          "gopay",
          "shopeepay",
          "other_qris"
        ],
        "shopeepay": {"callback_url": "http://shopeepay.com"},
        "gopay": {
          "enable_callback": true,
          "callback_url": "http://gopay.com",
        },
        "page_expiry": {"duration": 3, "unit": "hours"}
      }),
    );
    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception("Failed to create transaction: ${response.body}");
    }
  }

  List<dynamic> availableVouchers = [];
  List<dynamic> notApplicableVouchers = [];
  bool isVoucherDataLoaded = false;

  void _fetchVoucherData() async {
    try {
      final results = await Future.wait([
        fetchApplicableVouchers(storeProducts['store']['store_id'], totalPrice),
        fetchNotApplicableVouchers(
            storeProducts['store']['store_id'], totalPrice),
      ]);

      setState(() {
        availableVouchers = results[0];
        notApplicableVouchers = results[1];
        isVoucherDataLoaded = true;
      });
    } catch (e) {
      print("Error fetching vouchers: $e");
      setState(() {
        isVoucherDataLoaded = true; // Tetap update state agar loading berhenti
      });
    }
  }

  void _showVoucherDrawer(BuildContext context) async {
    if (!isVoucherDataLoaded) {
      _fetchVoucherData(); // Pastikan data diambil sebelum membuka drawer
    }

    String? tempSelectedVoucher = selectedVoucher;

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
                padding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 5),
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
                      'Available Vouchers',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    SizedBox(height: 10),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (availableVouchers.isEmpty)
                              Center(
                                child: Text(
                                  'No available vouchers for this transaction.',
                                  style: TextStyle(
                                      fontSize: 16, color: Colors.grey),
                                ),
                              )
                            else
                              ListView.builder(
                                shrinkWrap: true,
                                physics: NeverScrollableScrollPhysics(),
                                itemCount: availableVouchers.length,
                                itemBuilder: (context, index) {
                                  final voucher = availableVouchers[index];
                                  return GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        tempSelectedVoucher =
                                            tempSelectedVoucher ==
                                                    voucher['voucher_name']
                                                ? null
                                                : voucher['voucher_name'];
                                      });
                                    },
                                    child: _buildVoucherCard(
                                      voucher['voucher_name'],
                                      'Discount: ${voucher['discount_amount']}%',
                                      'Points: ${voucher['poin_price']}',
                                      'Valid: ${voucher['start_date'].split('T')[0]} - ${voucher['end_date'].split('T')[0]}',
                                      double.parse(voucher['minimum_purchase']
                                          .toString()),
                                      double.parse(
                                          voucher['max_discount'].toString()),
                                      isSelected: tempSelectedVoucher ==
                                          voucher['voucher_name'],
                                    ),
                                  );
                                },
                              ),
                            SizedBox(height: 20),
                            Text(
                              'Not Applicable Vouchers',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                            SizedBox(height: 10),
                            if (notApplicableVouchers.isEmpty)
                              Center(
                                child: Text(
                                  'No not applicable vouchers.',
                                  style: TextStyle(
                                      fontSize: 16, color: Colors.grey),
                                ),
                              )
                            else
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: notApplicableVouchers.length,
                                itemBuilder: (context, index) {
                                  final voucher = notApplicableVouchers[index];
                                  return _buildVoucherCard(
                                    voucher['voucher_name'],
                                    'Discount: ${voucher['discount_amount']}%',
                                    'Points: ${voucher['poin_price']}',
                                    'Valid: ${voucher['start_date'].split('T')[0]} - ${voucher['end_date'].split('T')[0]}',
                                    double.parse(
                                        voucher['minimum_purchase'].toString()),
                                    double.parse(
                                        voucher['max_discount'].toString()),
                                    isNotApplicable: true,
                                    subTotal:
                                        totalPrice, // Kirim total harga transaksi ke widget
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 18),
                      child: ElevatedButton(
                        onPressed: () {
                          if (tempSelectedVoucher != null) {
                            final selectedVoucherDetails =
                                availableVouchers.firstWhere(
                              (voucher) =>
                                  voucher['voucher_name'] ==
                                  tempSelectedVoucher,
                              orElse: () => null,
                            );

                            if (selectedVoucherDetails != null) {
                              _applyVoucher({
                                'voucher_name':
                                    selectedVoucherDetails['voucher_name'],
                                'discount_amount': double.parse(
                                    selectedVoucherDetails['discount_amount']
                                        .toString()),
                                'max_discount': double.parse(
                                    selectedVoucherDetails['max_discount']
                                        .toString()),
                                'voucher_owned_id': selectedVoucherDetails[
                                    'voucher_owned_id'], // Simpan voucher_owned_id
                                'voucher_id': selectedVoucherDetails[
                                    'voucher_id'], // Simpan voucher_id
                              });
                            }
                          } else {
                            _applyVoucher(null);
                          }
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: tempSelectedVoucher != null
                              ? Color(0xFF31394E)
                              : Color.fromARGB(255, 199, 88, 101),
                          minimumSize: Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          tempSelectedVoucher != null
                              ? 'Apply Voucher'
                              : 'Unapply Voucher',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
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

  Widget _buildVoucherCard(
    String name,
    String discount,
    String points,
    String validity,
    double minimumPurchase,
    double maxDiscount, {
    bool isSelected = false,
    bool isNotApplicable =
        false, // Menentukan apakah voucher berlaku atau tidak
    VoidCallback? onTap,
    double?
        subTotal, // Tambahkan sub-total transaksi untuk perhitungan kekurangan
  }) {
    final shortfall = minimumPurchase - (subTotal ?? 0); // Hitung kekurangan

    return GestureDetector(
      onTap: !isNotApplicable ? onTap : null,
      child: Card(
        color: isNotApplicable
            ? Colors.grey[200]
            : isSelected
                ? const Color(0xFFC58189)
                : const Color(0xFF31394E),
        margin: const EdgeInsets.symmetric(vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Nama Voucher
              Text(
                name,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isNotApplicable ? Colors.grey[700] : Colors.white,
                ),
              ),
              const SizedBox(height: 5),
              // Informasi Diskon dan Detail
              Text(
                discount,
                style: TextStyle(
                  fontSize: 14,
                  color: isNotApplicable ? Colors.grey[600] : Colors.white70,
                ),
              ),
              Text(
                'Maks. Diskon: Rp ${formatCurrency(maxDiscount)}',
                style: TextStyle(
                  fontSize: 14,
                  color: isNotApplicable ? Colors.grey[600] : Colors.white70,
                ),
              ),
              Text(
                points,
                style: TextStyle(
                  fontSize: 14,
                  color: isNotApplicable ? Colors.grey[600] : Colors.white70,
                ),
              ),
              Text(
                validity,
                style: TextStyle(
                  fontSize: 14,
                  color: isNotApplicable ? Colors.grey[600] : Colors.white70,
                ),
              ),
              Text(
                'Min. Transaksi: Rp ${formatCurrency(minimumPurchase)}',
                style: TextStyle(
                  fontSize: 14,
                  color: isNotApplicable ? Colors.grey[600] : Colors.white70,
                ),
              ),
              // Keterangan untuk kekurangan
              if (isNotApplicable && shortfall > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 10.0),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Color(0xFFD47F00)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Tambah Rp ${formatCurrency(shortfall)} untuk menggunakan voucher ini.',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFD47F00),
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
    );
  }

  Future<List<dynamic>> fetchNotApplicableVouchers(
      String storeId, double transactionAmount) async {
    try {
      String token = await getAccessToken();
      final response = await http.get(
        Uri.parse(
            "$apiBaseUrl/vouchers/not-applicable?storeId=$storeId&transactionAmount=$transactionAmount"),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );
      print(jsonDecode(response.body));
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return responseData['data'];
      } else {
        throw Exception('Failed to load not applicable vouchers');
      }
    } catch (e) {
      print("Error fetching not applicable vouchers: $e");
      return [];
    }
  }

  Future<List<dynamic>> fetchApplicableVouchers(
      String storeId, double transactionAmount) async {
    try {
      String token = await getAccessToken();
      final response = await http.get(
        Uri.parse(
            "$apiBaseUrl/vouchers/applicable?storeId=$storeId&transactionAmount=$transactionAmount"),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );
      print(jsonDecode(response.body));
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return responseData['data'];
      } else {
        throw Exception('Failed to load vouchers');
      }
    } catch (e) {
      print("Error fetching applicable vouchers: $e");
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF4F4F4),
      appBar: AppBar(
        title: Text(
          'Checkout',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: Color(0xFF31394E),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Detail Produk
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.2),
                      blurRadius: 10,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      storeProducts['store']['store_name'],
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Column(
                      children: storeProducts['ProductList']
                          .map<Widget>((product) => Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8.0),
                                child: Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: Image.network(
                                        "https://picsum.photos/200/200?random=${Random().nextInt(1000)}",
                                        width: 80,
                                        height: 80,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            product['productName'],
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          SizedBox(height: 4),
                                          Text(
                                            '${product['quantity']} x Rp ${formatCurrency(product['productPrice'].toDouble())}',
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                          Text(
                                            'Weight: ${product['productWeight']} gr', // Berat produk
                                            style: TextStyle(
                                                color: Colors.grey[600]),
                                          ),
                                          Text(
                                            'Subtotal: Rp ${formatCurrency((product['quantity'] * product['productPrice']).toDouble())}',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ))
                          .toList(),
                    ),
                  ],
                ),
              ),
            ),

            // Tombol Gunakan Voucher
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: ElevatedButton(
                onPressed: () {
                  _showVoucherDrawer(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: selectedVoucher != null
                      ? Colors.green // Warna hijau jika voucher diterapkan
                      : const Color(0xFFC58189), // Warna default
                  minimumSize: Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(
                      color:
                          Colors.transparent, // Tidak ada border jika default
                      width: 2,
                    ),
                  ),
                  elevation: selectedVoucher != null ? 5 : 2, // Elevasi berbeda
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      selectedVoucher != null
                          ? Icons
                              .check_circle_outline // Ikon untuk voucher diterapkan
                          : Icons.local_offer_outlined, // Ikon default
                      color: Colors.white,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      selectedVoucher != null
                          ? 'Voucher Applied'
                          : 'Use Voucher',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Ringkasan Harga
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.2),
                      blurRadius: 10,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Ringkasan",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total Harga'),
                        Text(
                          'Rp ${formatCurrency(initialTotalPrice)}',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                            'Tax (${storeProducts['store']['tax_percentage']}%)'),
                        Text('Rp ${formatCurrency(taxAmount)}',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    if (selectedVoucher != null) ...[
                      // SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            flex: 2,
                            child: Text(
                              'Potongan Voucher (${selectedVoucher})',
                              style: TextStyle(fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                          Expanded(
                            flex: 1,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(
                                  '- Rp ${formatCurrency(discount)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                    Divider(thickness: 1, color: Colors.grey[300]),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total Bayar',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Rp ${formatCurrency(totalPrice)}',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    Divider(thickness: 1, color: Colors.grey[300]),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total Poin Didapatkan',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.normal),
                        ),
                        Text(
                          '${_calculateTotalPoints()} Poin',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Tombol Bayar
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton(
                onPressed: () {
                  _checkout();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF31394E),
                  minimumSize: Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  'Bayar',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
