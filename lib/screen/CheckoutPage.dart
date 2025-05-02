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
  bool isLoading = false;

  String? selectedPaymentMethod; // Store selected payment method code
  String? selectedPaymentMethodName;
  final List<Map<String, dynamic>> paymentMethods = [
    {
      "code": "PERMATAVA",
      "name": "Permata Virtual Account",
      "group": "Virtual Account",
      "image":
          'https://assets.tripay.co.id/upload/payment-icon/szezRhAALB1583408731.png',
      "icon": Icons.bakery_dining
    },
    {
      "code": "BNIVA",
      "name": "BNI Virtual Account",
      "group": "Virtual Account",
      "image":
          'https://assets.tripay.co.id/upload/payment-icon/n22Qsh8jMa1583433577.png',
      "icon": Icons.bakery_dining
    },
    {
      "code": "BCAVA",
      "name": "BCA Virtual Account",
      "group": "Virtual Account",
      "image":
          'https://assets.tripay.co.id/upload/payment-icon/ytBKvaleGy1605201833.png',
      "icon": Icons.bakery_dining
    },
    {
      "code": "BRIVA",
      "name": "BRI Virtual Account",
      "group": "Virtual Account",
      "image":
          'https://assets.tripay.co.id/upload/payment-icon/8WQ3APST5s1579461828.png',
      "icon": Icons.bakery_dining
    },
     {
      "code": "MANDIRIVA",
      "name": "Mandiri Virtual Account",
      "group": "Virtual Account",
      "image":
          'https://assets.tripay.co.id/upload/payment-icon/T9Z012UE331583531536.png',
      "icon": Icons.bakery_dining
    },
  ];

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
    final poinConfig = storeProducts['store']['poin_config'];
    if (poinConfig == 0) {
      return 0;
    }
    final totalAmount = storeProducts['ProductList'].fold(
        0,
        (sum, product) =>
            sum + (product['productPrice'] * product['quantity']));

    points = (totalAmount / poinConfig)
        .floor(); // Hitung jumlah poin berdasarkan akumulasi

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

  Future<void> _checkout() async {
    if (selectedPaymentMethod == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Please select a payment method"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    setState(() {
      isLoading = true;
    });

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
                "price_per_gram": product['productWeight'] > 0
                    ? (product['productPrice'] / product['productWeight'])
                        .toDouble()
                    : 0.0,
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
          "tax_percent": storeProducts['store']['tax_percentage'],
          "poin_earned": _calculateTotalPoints(),
          "paymentMethod": selectedPaymentMethod,
        }),
      );

      setState(() {
        isLoading = false;
      });

      if (response.statusCode != 201) {
        throw Exception("Failed to create transaction: ${response.body}");
      }

      final responseData = jsonDecode(response.body);
      print(responseData);
      final redirectUrl = responseData['data']['paymentLink'];
      final no_ref = responseData['data']['no_ref'];
      print(no_ref);

      if (redirectUrl == null || redirectUrl.isEmpty) {
        throw Exception("Payment link is missing in the response");
      }

      // Navigate to the payment page
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => WaitingForPaymentPage(
            orderId: orderId,
            referenceId: no_ref,
          ),
        ),
      );

      // Open the payment URL in the browser
      final uri = Uri.parse(redirectUrl);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e, stackTrace) {
      setState(() {
        isLoading = false;
      });

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

  void _showPaymentMethodDrawer(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            return FractionallySizedBox(
              heightFactor: 0.6,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDrawerHeader(context, 'Select Payment Method'),

                  Expanded(
                    child: SingleChildScrollView(
                      physics: BouncingScrollPhysics(),
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding:
                                const EdgeInsets.only(top: 16.0, bottom: 8.0),
                            child: Text(
                              "Virtual Account",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF31394E),
                              ),
                            ),
                          ),

                          // Payment method cards
                          ...paymentMethods.map((method) {
                            final bool isSelected =
                                selectedPaymentMethod == method['code'];

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
                                  onTap: () {
                                    setSheetState(() {
                                      selectedPaymentMethod = method['code'];
                                      selectedPaymentMethodName =
                                          method['name'];
                                    });

                                    // Also update the parent state
                                    setState(() {
                                      selectedPaymentMethod = method['code'];
                                      selectedPaymentMethodName =
                                          method['name'];
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Ink(
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? Color(0xFFFBE9E7)
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isSelected
                                            ? Color(0xFFC58189)
                                            : Colors.grey.shade200,
                                        width: isSelected ? 1.5 : 1,
                                      ),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Row(
                                        children: [
                                          // Payment method icon
                                          Container(
                                            width: 50,
                                            height: 50,
                                            padding: EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: isSelected
                                                  ? Color(0xFFC58189)
                                                      .withOpacity(0.2)
                                                  : Colors.grey.shade100,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Image.network(
                                              method['image'],
                                              width: 34,
                                              height: 34,
                                              fit: BoxFit.contain,
                                              errorBuilder:
                                                  (context, error, stackTrace) {
                                                return Icon(
                                                  Icons.account_balance,
                                                  color: isSelected
                                                      ? Color(0xFFC58189)
                                                      : Colors.grey.shade700,
                                                  size: 24,
                                                );
                                              },
                                            ),
                                          ),
                                          SizedBox(width: 16),

                                          // Payment method details
                                          Expanded(
                                            child: Text(
                                              method['name'],
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF31394E),
                                              ),
                                            ),
                                          ),

                                          // Selection indicator
                                          isSelected
                                              ? Container(
                                                  padding: EdgeInsets.all(6),
                                                  decoration: BoxDecoration(
                                                    color: Color(0xFFC58189),
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: Icon(
                                                    Icons.check,
                                                    color: Colors.white,
                                                    size: 16,
                                                  ),
                                                )
                                              : Container(
                                                  width: 24,
                                                  height: 24,
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    border: Border.all(
                                                      color:
                                                          Colors.grey.shade400,
                                                      width: 1.5,
                                                    ),
                                                  ),
                                                ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                  ),

                  // Apply button
                  Container(
                    padding: EdgeInsets.fromLTRB(16, 12, 16, 24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: Offset(0, -5),
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: selectedPaymentMethod != null
                            ? () {
                                Navigator.pop(context);
                              }
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF31394E),
                          disabledBackgroundColor: Colors.grey[400],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.check_circle_outline,
                              color: Colors.white,
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Confirm Payment Method',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
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

  List<Widget> _buildPaymentMethodGroups() {
    // Group payment methods by their type
    Map<String, List<dynamic>> groupedMethods = {};

    for (var method in paymentMethods) {
      final group = method['group'] ?? 'Other';
      if (!groupedMethods.containsKey(group)) {
        groupedMethods[group] = [];
      }
      groupedMethods[group]!.add(method);
    }

    List<Widget> widgets = [];

    groupedMethods.forEach((group, methods) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
          child: Text(
            group,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF31394E),
            ),
          ),
        ),
      );

      for (var method in methods) {
        widgets.add(
          _buildPaymentMethodCard(method),
        );
      }
    });

    return widgets;
  }

  Widget _buildPaymentMethodCard(dynamic method) {
    final bool isSelected = selectedPaymentMethod == method['code'];

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
          onTap: () {
            setState(() {
              selectedPaymentMethod = method['code'];
            });
          },
          borderRadius: BorderRadius.circular(12),
          child: Ink(
            decoration: BoxDecoration(
              color: isSelected ? Color(0xFFFBE9E7) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? Color(0xFFC58189) : Colors.grey.shade200,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  // Payment method icon
                  Container(
                    width: 50,
                    height: 50,
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Color(0xFFC58189).withOpacity(0.2)
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Image.network(
                      method['image'],
                      width: 32,
                      height: 32,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(
                          Icons.account_balance,
                          color: isSelected
                              ? Color(0xFFC58189)
                              : Colors.grey.shade700,
                          size: 24,
                        );
                      },
                    ),
                  ),
                  SizedBox(width: 16),

                  // Payment method details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          method['name'] ?? 'Unknown',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF31394E),
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          method['group'] ?? '',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Selection indicator
                  isSelected
                      ? Container(
                          padding: EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Color(0xFFC58189),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 16,
                          ),
                        )
                      : Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.grey.shade400,
                              width: 1.5,
                            ),
                          ),
                        ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return FractionallySizedBox(
              heightFactor: 0.8,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDrawerHeader(context, 'Select Voucher'),

                  // Current points display
                  Container(
                    margin: EdgeInsets.fromLTRB(16, 4, 16, 16),
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.shopping_cart_checkout,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Transaction Total',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.white.withOpacity(0.8),
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Rp ${formatCurrency(totalPrice)}',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  Expanded(
                    child: !isVoucherDataLoaded
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Color(0xFFC58189)),
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'Loading vouchers...',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Color(0xFF31394E),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : SingleChildScrollView(
                            physics: BouncingScrollPhysics(),
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildSectionHeader('Available Vouchers',
                                    availableVouchers.length),
                                SizedBox(height: 12),
                                availableVouchers.isEmpty
                                    ? _buildEmptyVoucherState(
                                        'No Available Vouchers',
                                        'There are no vouchers available for this transaction.')
                                    : ListView.builder(
                                        shrinkWrap: true,
                                        physics: NeverScrollableScrollPhysics(),
                                        itemCount: availableVouchers.length,
                                        itemBuilder: (context, index) {
                                          final voucher =
                                              availableVouchers[index];
                                          return _buildVoucherCard(
                                            name: voucher['voucher_name'],
                                            discount:
                                                voucher['discount_amount'],
                                            points: voucher['poin_price'],
                                            startDate: voucher['start_date']
                                                .split('T')[0],
                                            endDate: voucher['end_date']
                                                .split('T')[0],
                                            minimumPurchase: double.parse(
                                                voucher['minimum_purchase']
                                                    .toString()),
                                            maxDiscount: double.parse(
                                                voucher['max_discount']
                                                    .toString()),
                                            isSelected: tempSelectedVoucher ==
                                                voucher['voucher_name'],
                                            onTap: () {
                                              setState(() {
                                                tempSelectedVoucher =
                                                    tempSelectedVoucher ==
                                                            voucher[
                                                                'voucher_name']
                                                        ? null
                                                        : voucher[
                                                            'voucher_name'];
                                              });
                                            },
                                          );
                                        },
                                      ),
                                SizedBox(height: 24),
                                _buildSectionHeader('Not Applicable Vouchers',
                                    notApplicableVouchers.length),
                                SizedBox(height: 12),
                                notApplicableVouchers.isEmpty
                                    ? _buildEmptyVoucherState(
                                        'No Ineligible Vouchers',
                                        'There are no ineligible vouchers for this transaction.')
                                    : ListView.builder(
                                        shrinkWrap: true,
                                        physics: NeverScrollableScrollPhysics(),
                                        itemCount: notApplicableVouchers.length,
                                        itemBuilder: (context, index) {
                                          final voucher =
                                              notApplicableVouchers[index];
                                          return _buildVoucherCard(
                                            name: voucher['voucher_name'],
                                            discount:
                                                voucher['discount_amount'],
                                            points: voucher['poin_price'],
                                            startDate: voucher['start_date']
                                                .split('T')[0],
                                            endDate: voucher['end_date']
                                                .split('T')[0],
                                            minimumPurchase: double.parse(
                                                voucher['minimum_purchase']
                                                    .toString()),
                                            maxDiscount: double.parse(
                                                voucher['max_discount']
                                                    .toString()),
                                            isNotApplicable: true,
                                            subTotal: totalPrice,
                                          );
                                        },
                                      ),
                                SizedBox(height: 80), // Space for button
                              ],
                            ),
                          ),
                  ),
                  // Apply button in fixed position at bottom
                  Container(
                    padding: EdgeInsets.fromLTRB(16, 12, 16, 24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: Offset(0, -5),
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: () {
                        if (tempSelectedVoucher != null) {
                          final selectedVoucherDetails =
                              availableVouchers.firstWhere(
                            (voucher) =>
                                voucher['voucher_name'] == tempSelectedVoucher,
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
                            : Color(0xFFC58189),
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            tempSelectedVoucher != null
                                ? Icons.check_circle_outline
                                : Icons.not_interested_outlined,
                            color: Colors.white,
                            size: 18,
                          ),
                          SizedBox(width: 8),
                          Text(
                            tempSelectedVoucher != null
                                ? 'Apply Selected Voucher'
                                : 'Continue Without Voucher',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
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
            color: Colors.black.withOpacity(0.05),
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

  Widget _buildEmptyVoucherState(String title, String subtitle) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 30),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.local_offer_outlined,
                size: 48,
                color: Colors.grey.shade400,
              ),
            ),
            SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF31394E),
              ),
            ),
            SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
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
    required dynamic discount,
    required dynamic points,
    required String startDate,
    required String endDate,
    required double minimumPurchase,
    required double maxDiscount,
    bool isSelected = false,
    bool isNotApplicable = false,
    VoidCallback? onTap,
    double? subTotal,
  }) {
    // Format dates for better readability
    final formattedStartDate = _formatDate(startDate);
    final formattedEndDate = _formatDate(endDate);
    final shortfall = isNotApplicable && subTotal != null
        ? (minimumPurchase - subTotal).toDouble()
        : 0.0;

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
          onTap: isNotApplicable ? null : onTap,
          borderRadius: BorderRadius.circular(12),
          child: Ink(
            decoration: BoxDecoration(
              color: isNotApplicable
                  ? Colors.grey.shade100
                  : isSelected
                      ? Color(0xFFFBE9E7)
                      : Color(0xFF31394E),
              borderRadius: BorderRadius.circular(12),
              border: isSelected
                  ? Border.all(color: Color(0xFFC58189), width: 1.5)
                  : isNotApplicable
                      ? Border.all(color: Colors.grey.shade300, width: 1)
                      : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Voucher header with discount badge
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isNotApplicable
                                    ? Colors.grey.shade200
                                    : isSelected
                                        ? Color(0xFFC58189).withOpacity(0.2)
                                        : Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                isNotApplicable
                                    ? Icons.not_interested_outlined
                                    : isSelected
                                        ? Icons.check_circle_outline
                                        : Icons.local_offer_outlined,
                                color: isNotApplicable
                                    ? Colors.grey.shade600
                                    : isSelected
                                        ? Color(0xFFC58189)
                                        : Colors.white,
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
                                      color: isNotApplicable
                                          ? Colors.grey.shade800
                                          : isSelected
                                              ? Color(0xFF31394E)
                                              : Colors.white,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.circle,
                                        size: 8,
                                        color: isNotApplicable
                                            ? Colors.grey.shade500
                                            : isSelected
                                                ? Color(0xFFC58189)
                                                    .withOpacity(0.7)
                                                : Colors.white.withOpacity(0.6),
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        '$points points',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: isNotApplicable
                                              ? Colors.grey.shade600
                                              : isSelected
                                                  ? Color(0xFFC58189)
                                                  : Colors.white
                                                      .withOpacity(0.7),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: isNotApplicable
                              ? Colors.grey.shade200
                              : isSelected
                                  ? Color(0xFFC58189)
                                  : Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$discount% OFF',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isNotApplicable
                                ? Colors.grey.shade700
                                : isSelected
                                    ? Colors.white
                                    : Color(0xFFC58189),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Divider
                Container(
                  height: 1,
                  color: isNotApplicable
                      ? Colors.grey.shade200
                      : isSelected
                          ? Color(0xFFC58189).withOpacity(0.2)
                          : Colors.white.withOpacity(0.1),
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
                            color: isNotApplicable
                                ? Colors.grey.shade500
                                : isSelected
                                    ? Color(0xFF31394E).withOpacity(0.7)
                                    : Colors.white.withOpacity(0.7),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Valid: $formattedStartDate - $formattedEndDate',
                            style: TextStyle(
                              fontSize: 13,
                              color: isNotApplicable
                                  ? Colors.grey.shade600
                                  : isSelected
                                      ? Color(0xFF31394E).withOpacity(0.8)
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
                            color: isNotApplicable
                                ? Colors.grey.shade500
                                : isSelected
                                    ? Color(0xFF31394E).withOpacity(0.7)
                                    : Colors.white.withOpacity(0.7),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Min. Transaction: ${formatCurrency(minimumPurchase)}',
                            style: TextStyle(
                              fontSize: 13,
                              color: isNotApplicable
                                  ? Colors.grey.shade600
                                  : isSelected
                                      ? Color(0xFF31394E).withOpacity(0.8)
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
                            color: isNotApplicable
                                ? Colors.grey.shade500
                                : isSelected
                                    ? Color(0xFF31394E).withOpacity(0.7)
                                    : Colors.white.withOpacity(0.7),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Max. Discount: ${formatCurrency(maxDiscount)}',
                            style: TextStyle(
                              fontSize: 13,
                              color: isNotApplicable
                                  ? Colors.grey.shade600
                                  : isSelected
                                      ? Color(0xFF31394E).withOpacity(0.8)
                                      : Colors.white.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),

                      // Shortfall warning for non-applicable vouchers
                      if (isNotApplicable && shortfall > 0) ...[
                        SizedBox(height: 12),
                        Container(
                          padding:
                              EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Color(0xFFFFF9C4),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Color(0xFFFFD600).withOpacity(0.5),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 16,
                                color: Color(0xFFD47F00),
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Add ${formatCurrency(shortfall)} more to use this voucher',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFFD47F00),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Get voucher button for available vouchers that are not selected
                      if (!isNotApplicable && !isSelected) ...[
                        SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Color(0xFFC58189),
                                width: 1,
                              ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Select Voucher',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFC58189),
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

  // Helper function to format date
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
      backgroundColor: Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/appbar.png',
              fit: BoxFit.cover,
            ),
            Container(
              color: Colors.black.withOpacity(0.2),
            ),
          ],
        ),
        title: const Text(
          'Checkout',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      // Main content in a scrollable view
      body: SingleChildScrollView(
        physics:
            AlwaysScrollableScrollPhysics(), // Always allow scrolling even with small content
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Order summary header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: Text(
                'Order Summary',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF31394E),
                ),
              ),
            ),

            // Store and products details
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Store header
                    Container(
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: Color(0xFFF5F7FA),
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(16)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.store_outlined,
                            color: Color(0xFF31394E),
                            size: 20,
                          ),
                          SizedBox(width: 10),
                          Text(
                            storeProducts['store']['store_name'],
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF31394E),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Products list
                    ListView.separated(
                      shrinkWrap: true,
                      physics:
                          NeverScrollableScrollPhysics(), // Disable scrolling for this list
                      itemCount: storeProducts['ProductList'].length,
                      separatorBuilder: (context, index) => Divider(
                        color: Colors.grey.shade200,
                        height: 1,
                      ),
                      itemBuilder: (context, index) {
                        final product = storeProducts['ProductList'][index];
                        return Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Product image
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  width: 80,
                                  height: 80,
                                  color: Colors.grey[200],
                                  child: Image.network(
                                    "$apiBaseUrlImage${product['image']}",
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Center(
                                        child: Icon(
                                          Icons.image_not_supported_outlined,
                                          color: Colors.grey[400],
                                          size: 24,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              SizedBox(width: 16),

                              // Product details
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      product['productName'],
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF31394E),
                                      ),
                                    ),
                                    SizedBox(height: 6),

                                    // Product attributes
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.scale_outlined,
                                          size: 14,
                                          color: Colors.grey[600],
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          '${product['productWeight']} gr',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        SizedBox(width: 12),
                                        Icon(
                                          Icons.shopping_bag_outlined,
                                          size: 14,
                                          color: Colors.grey[600],
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          'x${product['quantity']}',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 8),

                                    // Price and subtotal
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Rp ${formatCurrency(product['productPrice'].toDouble())}',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Color(0xFF31394E),
                                          ),
                                        ),
                                        Text(
                                          'Rp ${formatCurrency((product['quantity'] * product['productPrice']).toDouble())}',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF31394E),
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
                      },
                    ),
                  ],
                ),
              ),
            ),

            // Voucher section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      _showVoucherDrawer(context);
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: selectedVoucher != null
                                  ? Color(0xFFE8F5E9)
                                  : Color(0xFFFBE9E7),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              selectedVoucher != null
                                  ? Icons.local_offer
                                  : Icons.local_offer_outlined,
                              color: selectedVoucher != null
                                  ? Colors.green[700]
                                  : Color(0xFFC58189),
                              size: 20,
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  selectedVoucher != null
                                      ? 'Voucher Applied'
                                      : 'Use Voucher',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: selectedVoucher != null
                                        ? Colors.green[700]
                                        : Color(0xFF31394E),
                                  ),
                                ),
                                if (selectedVoucher != null)
                                  Text(
                                    selectedVoucher!,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            color: Colors.grey[400],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: 16),

            // Payment Method Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      _showPaymentMethodDrawer(context);
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: selectedPaymentMethod != null
                                  ? Color(0xFFE8F5E9)
                                  : Color(0xFFFBE9E7),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              selectedPaymentMethod != null
                                  ? Icons.payments
                                  : Icons.payment_outlined,
                              color: selectedPaymentMethod != null
                                  ? Colors.green[700]
                                  : Color(0xFFC58189),
                              size: 20,
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  selectedPaymentMethod != null
                                      ? 'Payment Method Selected'
                                      : 'Select Payment Method',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: selectedPaymentMethod != null
                                        ? Colors.green[700]
                                        : Color(0xFF31394E),
                                  ),
                                ),
                                if (selectedPaymentMethodName != null)
                                  Text(
                                    selectedPaymentMethodName!,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            color: Colors.grey[400],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: 8),

            // Payment Summary
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        "Payment Details",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF31394E),
                        ),
                      ),
                    ),
                    Divider(height: 1, color: Colors.grey[200]),

                    // Price breakdown
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          // Subtotal
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Subtotal',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[700],
                                ),
                              ),
                              Text(
                                'Rp ${formatCurrency(initialTotalPrice)}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF31394E),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8),

                          // Tax
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Tax (${storeProducts['store']['tax_percentage']}%)',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[700],
                                ),
                              ),
                              Text(
                                'Rp ${formatCurrency(taxAmount)}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF31394E),
                                ),
                              ),
                            ],
                          ),

                          // Discount if applicable
                          if (selectedVoucher != null) ...[
                            SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    'Discount ($selectedVoucher)',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.green[700],
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                                Text(
                                  '- Rp ${formatCurrency(discount)}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green[700],
                                  ),
                                ),
                              ],
                            ),
                          ],

                          SizedBox(height: 16),
                          Divider(height: 1, color: Colors.grey[200]),
                          SizedBox(height: 16),

                          // Total
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Total',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF31394E),
                                ),
                              ),
                              Text(
                                'Rp ${formatCurrency(totalPrice)}',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF31394E),
                                ),
                              ),
                            ],
                          ),

                          // Points earned
                          SizedBox(height: 12),
                          Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Color(0xFFFBE9E7).withOpacity(0.7),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.card_giftcard,
                                  size: 18,
                                  color: Color(0xFFC58189),
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'You will earn ',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[800],
                                  ),
                                ),
                                Text(
                                  '${_calculateTotalPoints()} points',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFC58189),
                                  ),
                                ),
                                Text(
                                  ' from this purchase',
                                  style: TextStyle(
                                    fontSize: 13,
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
            ),

            // Add extra space at the bottom to ensure everything can be scrolled above the bottom button
            SizedBox(height: 100),
          ],
        ),
      ),

      // Use bottomNavigationBar property to create a fixed bottom bar
      bottomNavigationBar: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          // This ensures the content stays above the bottom notch/home indicator
          child: Column(
            mainAxisSize:
                MainAxisSize.min, // Keep the column as small as possible
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Total Payment',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                  Spacer(),
                  Text(
                    'Rp ${formatCurrency(totalPrice)}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF31394E),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              ElevatedButton(
                onPressed: isLoading ? null : _checkout,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF31394E),
                  disabledBackgroundColor: Colors.grey[400],
                  minimumSize: Size(double.infinity, 54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: isLoading
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Processing...',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      )
                    : Text(
                        'Proceed to Payment',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
