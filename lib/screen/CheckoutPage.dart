import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:marketplace_logamas/function/Utils.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:marketplace_logamas/screen/PaymentPage.dart';
import 'package:marketplace_logamas/screen/WaitingForPayment.dart';
import 'package:url_launcher/url_launcher.dart';

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

  @override
  void initState() {
    super.initState();
    storeProducts = widget.cartData;
    initialTotalPrice = _calculateTotalPrice();
    totalPrice = initialTotalPrice; // Awalnya sama dengan total harga awal
    _fetchVoucherData();
  }

  double _calculateTotalPrice() {
    double price = 0;
    for (var product in storeProducts['selectedProducts']) {
      price += product['productPrice'] * product['quantity'];
    }
    return price;
  }

  void _applyVoucher(Map<String, dynamic>? voucher) {
    setState(() {
      if (voucher == null) {
        // Reset jika voucher dihapus
        discount = 0;
        totalPrice = initialTotalPrice;
        selectedVoucher = null;
      } else {
        // Hitung diskon berdasarkan persentase
        double calculatedDiscount =
            (voucher['discount_amount'] / 100) * initialTotalPrice;

        // Batasi diskon hingga nilai max_discount
        discount = calculatedDiscount > voucher['max_discount']
            ? voucher['max_discount']
            : calculatedDiscount;

        // Perbarui total harga setelah diskon
        totalPrice = initialTotalPrice - discount;

        // Simpan nama voucher yang diterapkan
        selectedVoucher = voucher['voucher_name'];
      }
    });
  }

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

  void _checkout() async {
    try {
      final orderId = "ORDER-${DateTime.now().millisecondsSinceEpoch}";
      final List<Map<String, dynamic>> items = storeProducts['selectedProducts']
          .map<Map<String, dynamic>>((product) => {
                "id": product['productName'].replaceAll(' ', '_'),
                "price": product['productPrice'].toInt(),
                "quantity": product['quantity'],
                "name": product['productName'],
                "brand": "Toko Emas ABC",
                "category": "Perhiasan",
                "merchant_name": storeProducts['store']['store_name'],
                "url":
                    "http://toko/${storeProducts['store']['store_id']}?item=${product['productName']}"
              })
          .toList();

      // Tambahkan diskon sebagai item terpisah
      if (discount > 0) {
        items.add({
          "id": "DISCOUNT",
          "price": -discount.toInt(),
          "quantity": 1,
          "name": "Discount Applied",
        });
      }

      // Validasi harga akhir
      final calculatedGrossAmount = items.fold<int>(
        0,
        (total, item) {
          final price = (item['price'] as num?)?.toInt() ?? 0;
          final quantity = (item['quantity'] as num?)?.toInt() ?? 0;
          return total + (price * quantity);
        },
      );

      if (calculatedGrossAmount != (initialTotalPrice - discount).toInt()) {
        throw Exception(
            "Gross amount mismatch! Calculated: $calculatedGrossAmount, Expected: ${initialTotalPrice - discount}");
      }

      final customerDetails = {
        "first_name": "John",
        "last_name": "Doe",
        "email": "john.doe@example.com",
        "phone": "+6281234567890",
        "billing_address": {
          "first_name": "John",
          "last_name": "Doe",
          "email": "john.doe@example.com",
          "phone": "+6281234567890",
          "address": "Jl. Sudirman",
          "city": "Jakarta",
          "postal_code": "12190",
          "country_code": "IDN",
        },
        "shipping_address": {
          "first_name": "John",
          "last_name": "Doe",
          "email": "john.doe@example.com",
          "phone": "+6281234567890",
          "address": "Jl. Sudirman",
          "city": "Jakarta",
          "postal_code": "12190",
          "country_code": "IDN",
        }
      };

      // Log informasi transaksi untuk debugging
      print("Order ID: $orderId");
      print("Items: ${jsonEncode(items)}");
      print("Gross Amount: ${totalPrice - discount}");
      print("Customer Details: ${jsonEncode(customerDetails)}");

      final response = await createMidtransTransaction(
        orderId: orderId,
        grossAmount: calculatedGrossAmount.toDouble(),
        items: items,
        customerDetails: customerDetails,
      );

      final redirectUrl = response['redirect_url'];
      if (redirectUrl == null || redirectUrl.isEmpty) {
        throw Exception("Redirect URL is missing in the response");
      }

      // Navigasi ke WaitingForPaymentPage
      // context.go(location)
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => WaitingForPaymentPage(orderId: orderId),
        ),
      );

      // Buka URL pembayaran di browser
      final uri = Uri.parse(redirectUrl);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e, stackTrace) {
      // Log kesalahan dan stack trace
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
    print(jsonDecode(response.body));
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
                                physics: NeverScrollableScrollPhysics(),
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
    bool isNotApplicable = false, // Parameter to decide color
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: !isNotApplicable
          ? onTap
          : null, // Disable tap for not applicable vouchers
      child: Card(
        color: isNotApplicable
            ? Colors.grey[300] // Grey for not applicable vouchers
            : isSelected
                ? Color(0xFFC58189)
                : Color(0xFF31394E),
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
                  color: isNotApplicable ? Colors.grey[700] : Colors.white,
                ),
              ),
              SizedBox(height: 5),
              Text(
                discount,
                style: TextStyle(
                  fontSize: 14,
                  color: isNotApplicable ? Colors.grey[600] : Colors.white70,
                ),
              ),
              Text(
                'Max Discount: Rp ${formatCurrency(maxDiscount)}',
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
                'Min. Transaction: ${formatCurrency(minimumPurchase)}',
                style: TextStyle(
                  fontSize: 14,
                  color: isNotApplicable ? Colors.grey[600] : Colors.white70,
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
      print(transactionAmount);
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
                      children: storeProducts['selectedProducts']
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
                    if (selectedVoucher != null) ...[
                      SizedBox(height: 8),
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
