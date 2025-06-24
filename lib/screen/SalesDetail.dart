import 'dart:io';
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:marketplace_logamas/function/Utils.dart';
import 'package:marketplace_logamas/screen/FullScreenImageView.dart';
import 'package:marketplace_logamas/screen/PDFScreen.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shimmer/shimmer.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

// Theme constants
class AppTheme {
  static const primaryColor = Color(0xFF31394E);
  static const accentColor = Color(0xFFC58189);
  static const cardBgColor = Colors.white;
  static const backgroundColor = Color(0xFFF5F5F5);
  static const successColor = Color(0xFF4CAF50);
  static const warningColor = Color(0xFFFFC107);
  static const errorColor = Color(0xFFF44336);
  static const infoColor = Color(0xFF2196F3);

  static const TextStyle headingStyle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: primaryColor,
  );

  static const TextStyle subheadingStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: primaryColor,
  );

  static const TextStyle bodyStyle = TextStyle(
    fontSize: 14,
    color: Color(0xFF555555),
  );

  static const TextStyle accentTextStyle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: accentColor,
  );
}

class SalesDetailsPage extends StatefulWidget {
  final String transactionId;

  const SalesDetailsPage({
    Key? key,
    required this.transactionId,
  }) : super(key: key);

  @override
  _SalesDetailsPageState createState() => _SalesDetailsPageState();
}

class _SalesDetailsPageState extends State<SalesDetailsPage> {
  Timer? _timer;
  Duration _timeLeft = Duration.zero;
  Map<String, dynamic>? _transactionData;
  bool _isLoading = true;
  bool _isExpired = false;
  String? _accessToken;

  @override
  void initState() {
    super.initState();
    loadAccessToken();
    _fetchTransactionData();

    // Add haptic feedback for page load
    HapticFeedback.lightImpact();
  }

  Future<void> loadAccessToken() async {
    try {
      final token = await getAccessToken();
      ;
      setState(() {
        _accessToken = token;
      });
    } catch (e) {
      print('Error loading access token or user data: $e');
    }
  }

  // Show error with retry option
  void _showErrorSnackBar(String message, {Function? onRetry}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.errorColor,
        action: onRetry != null
            ? SnackBarAction(
                label: 'Retry',
                textColor: Colors.white,
                onPressed: () => onRetry(),
              )
            : null,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.all(8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Future<void> _fetchTransactionData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final url = Uri.parse('$apiBaseUrl/transactions/${widget.transactionId}');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success']) {
          setState(() {
            _transactionData = data['data']['data'];
            _isLoading = false;
            _setCountdown();
          });
        } else {
          _showErrorSnackBar("Failed to load sales details",
              onRetry: _fetchTransactionData);
          setState(() {
            _isLoading = false;
          });
        }
      } else {
        _showErrorSnackBar("Server error. Please try again later",
            onRetry: _fetchTransactionData);
        setState(() {
          _isLoading = false;
        });
      }
    } catch (error) {
      _showErrorSnackBar("Network error. Please check your connection",
          onRetry: _fetchTransactionData);
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Improved PDF download with progress indicator
  Future<void> _downloadNota() async {
    final String transactionId = widget.transactionId;
    final String url =
        '$apiBaseUrlNota/transaction/transaction-nota/$transactionId';

    // Show download progress dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              SpinKitRing(
                color: AppTheme.primaryColor,
                size: 40.0,
              ),
              SizedBox(height: 16),
              Text("Downloading receipt..."),
            ],
          ),
        );
      },
    );

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_accessToken',
        },
      );

      // Close the progress dialog
      Navigator.pop(context);

      if (response.statusCode == 200) {
        final directory = await getApplicationDocumentsDirectory();
        final filePath = '${directory.path}/nota_$transactionId.pdf';
        final file = File(filePath);

        await file.writeAsBytes(response.bodyBytes);
        _openPdf(filePath);

        // Success feedback
        HapticFeedback.mediumImpact();
      } else {
        _showErrorSnackBar("Failed to download receipt");
      }
    } catch (error) {
      // Close the progress dialog
      Navigator.pop(context);
      _showErrorSnackBar("Error downloading receipt");
    }
  }

  void _openPdf(String filePath) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PDFScreen(filePath: filePath),
      ),
    );
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));

    // Provide haptic feedback
    HapticFeedback.selectionClick();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 8),
            Text("Transaction code copied!"),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppTheme.successColor,
        duration: Duration(seconds: 2),
        margin: EdgeInsets.all(8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  String _formatDateTime(String dateTime) {
    DateTime parsedDate = DateTime.parse(dateTime)
        .toUtc()
        .add(Duration(hours: 7)); // Convert UTC to WIB
    return DateFormat("dd MMM yyyy • HH:mm").format(parsedDate);
  }

  double _getTaxPercentage() {
    double subTotal =
        double.tryParse(_transactionData!['sub_total_price'].toString()) ?? 0;
    double taxPrice =
        double.tryParse(_transactionData!['tax_price'].toString()) ?? 0;

    if (subTotal == 0) {
      return 0;
    }

    return ((taxPrice / subTotal) * 100).roundToDouble();
  }

  double _getDiscountAmount() {
    if (_transactionData == null) return 0;

    double totalPrice =
        double.tryParse(_transactionData!['total_price'].toString()) ?? 0;
    double subTotal =
        double.tryParse(_transactionData!['sub_total_price'].toString()) ?? 0;
    double taxPrice =
        double.tryParse(_transactionData!['tax_price'].toString()) ?? 0;

    double discount = subTotal + taxPrice - totalPrice;
    return discount.abs(); // Return absolute value to handle edge cases
  }

  void _setCountdown() {
    if (_transactionData != null && _transactionData!['status'] == 0) {
      if (_transactionData!['expired_at'] == null) {
        setState(() {
          _isExpired = false;
        });
        return;
      }

      DateTime expiredAt = DateTime.parse(_transactionData!['expired_at'])
          .subtract(Duration(hours: 7));

      Duration difference = expiredAt.difference(DateTime.now());

      if (difference.isNegative) {
        setState(() {
          _isExpired = true;
        });
        return;
      }

      setState(() {
        _timeLeft = difference;
        _isExpired = false;
      });

      _timer?.cancel();
      _timer = Timer.periodic(Duration(seconds: 1), (timer) {
        if (_timeLeft.inSeconds > 0) {
          setState(() {
            _timeLeft = _timeLeft - Duration(seconds: 1);
          });
        } else {
          setState(() {
            _isExpired = true;
          });
          timer.cancel();
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: _buildAppBar(),
      body: _isLoading ? _buildLoadingState() : _buildOrderDetails(),
    );
  }

  // Extracted app bar widget
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
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
        'Sales Details',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      leading: IconButton(
        onPressed: () => context.pop(),
        icon: const Icon(
          Icons.arrow_back,
          color: Colors.white,
        ),
      ),
      actions: [
        if (!_isLoading &&
            _transactionData != null &&
            _transactionData!['status'] != 0)
          IconButton(
            onPressed: _downloadNota,
            tooltip: 'Download Receipt',
            icon: const Icon(
              Icons.receipt_long,
              color: Colors.white,
            ),
          ),
      ],
    );
  }

  // Shimmer loading effect
  Widget _buildLoadingState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      physics: const BouncingScrollPhysics(),
      child: Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Transaction details
            Container(
              height: 20,
              width: MediaQuery.of(context).size.width * 0.7,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            SizedBox(height: 8),
            Container(
              height: 18,
              width: MediaQuery.of(context).size.width * 0.5,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            SizedBox(height: 24),

            // Status container
            Container(
              height: 60,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            SizedBox(height: 24),

            // Store name
            Container(
              height: 24,
              width: MediaQuery.of(context).size.width * 0.6,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            SizedBox(height: 24),

            // Product items (3 placeholders)
            for (int i = 0; i < 3; i++) ...[
              Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              SizedBox(height: 16),
            ],

            // Order details
            for (int i = 0; i < 4; i++) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    height: 18,
                    width: MediaQuery.of(context).size.width * 0.4,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  Container(
                    height: 18,
                    width: MediaQuery.of(context).size.width * 0.3,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOrderDetails() {
    int paymentStatus = _transactionData!['status'];
    final operations = _transactionData!['TransactionOperation'] ?? [];

    return RefreshIndicator(
      onRefresh: _fetchTransactionData,
      color: AppTheme.primaryColor,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTransactionHeader(),
            SizedBox(height: 16),

            _buildStatusSection(paymentStatus),
            SizedBox(height: 16),

            _buildStoreInfo(),
            SizedBox(height: 16),

            // Products list
            ..._transactionData!['transaction_products']
                .map<Widget>((product) => _buildProductItem(product))
                .toList(),

            if (operations.isNotEmpty) _buildOperationsSection(operations),

            SizedBox(height: 16),
            _buildOrderSummary(),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionHeader() {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Transaction ID: ${_transactionData!['code']}',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                InkWell(
                  onTap: () => _copyToClipboard(_transactionData!['code']),
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.all(6.0),
                    child: Icon(
                      Icons.copy,
                      color: AppTheme.primaryColor,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              'Sale Date: ${_formatDateTime(_transactionData!['created_at'])}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusSection(int paymentStatus) {
    return paymentStatus == 0 && !_isExpired
        ? _buildCountdownWidget()
        : _buildStatusMessage(paymentStatus);
  }

  Widget _buildCountdownWidget() {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  Icons.timer,
                  color: AppTheme.warningColor,
                  size: 24,
                ),
                SizedBox(width: 8),
                Text(
                  'Payment Deadline:',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.warningColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_timeLeft.inHours}:${(_timeLeft.inMinutes % 60).toString().padLeft(2, '0')}:${(_timeLeft.inSeconds % 60).toString().padLeft(2, '0')}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.warningColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusMessage(int status) {
    String message;
    Color color;
    IconData icon;

    if (_isExpired) {
      message = 'Payment Expired';
      color = AppTheme.errorColor;
      icon = Icons.error_outline;
    } else if (status == 1) {
      message = 'Paid';
      color = AppTheme.infoColor;
      icon = Icons.inventory;
    } else if (status == 2) {
      message = 'Sale Completed';
      color = AppTheme.successColor;
      icon = Icons.check_circle_outline;
    } else {
      message = 'Awaiting Payment';
      color = AppTheme.warningColor;
      icon = Icons.payment;
    }

    return Card(
      elevation: 0,
      color: color.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(
              icon,
              color: color,
              size: 24,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoreInfo() {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          // Navigate to store page
          context.push('/store/${_transactionData!['store']['store_id']}');
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: _transactionData!['store']['logo'] != null
                      ? CachedNetworkImage(
                          imageUrl:
                              '$apiBaseUrlImage${_transactionData!['store']['logo']}',
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Center(
                            child: CircularProgressIndicator(
                              color: AppTheme.accentColor,
                              strokeWidth: 2,
                            ),
                          ),
                          errorWidget: (context, url, error) => Icon(
                            Icons.image_not_supported_outlined,
                            color: AppTheme.primaryColor,
                            size: 28,
                          ),
                        )
                      : Icon(
                          Icons.store,
                          color: AppTheme.primaryColor,
                          size: 28,
                        ),
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _transactionData!['store']['store_name'],
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (_transactionData!['store']['address'] != null)
                      Text(
                        _transactionData!['store']['address'],
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: AppTheme.primaryColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOperationsSection(List operations) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Additional Services",
              style: AppTheme.headingStyle,
            ),
            SizedBox(height: 12),
            ...operations.map<Widget>((operation) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.handyman,
                          size: 18,
                          color: AppTheme.accentColor,
                        ),
                        SizedBox(width: 8),
                        Text(
                          "${operation['name']} (x${operation['unit']})",
                          style: AppTheme.bodyStyle,
                        ),
                      ],
                    ),
                    Text(
                      "Rp ${formatCurrency(double.tryParse(operation['total_price'].toString()) ?? 0)}",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderSummary() {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sale Summary',
              style: AppTheme.headingStyle,
            ),
            SizedBox(height: 16),
            _buildSummaryRow(
              'Subtotal',
              'Rp ${formatCurrency(double.tryParse(_transactionData!['sub_total_price'].toString()) ?? 0)}',
            ),
            _buildSummaryRow(
              'Tax (${_transactionData!['tax_percent'].toString()}%)',
              'Rp ${formatCurrency(double.tryParse(_transactionData!['tax_price'].toString()) ?? 0)}',
            ),
            if (_getDiscountAmount() > 0)
              _buildSummaryRow(
                'Voucher Discount',
                '-Rp ${formatCurrency(_getDiscountAmount())}',
                valueColor: AppTheme.successColor,
              ),
            Divider(height: 24, thickness: 1),
            _buildSummaryRow(
              'Total Amount',
              'Rp ${formatCurrency(double.tryParse(_transactionData!['total_price'].toString()) ?? 0)}',
              isBold: true,
              labelColor: AppTheme.primaryColor,
              valueColor: AppTheme.accentColor,
            ),
          ],
        ),
      ),
    );
  }

  // Fungsi untuk menampilkan baris summary
  Widget _buildSummaryRow(
    String label,
    String value, {
    bool isBold = false,
    Color? labelColor,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isBold ? 16 : 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: labelColor ?? Colors.grey[700],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isBold ? 16 : 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: valueColor ??
                  (isBold ? AppTheme.primaryColor : Colors.grey[800]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductItem(Map<String, dynamic> product) {
    // Extract product details
    double price = double.tryParse(product['price'].toString()) ?? 0;
    double adjPrice =
        double.tryParse(product['adjustment_price'].toString()) ?? 0;
    double discount = double.tryParse(product['discount'].toString()) ?? 0;
    double totalPrice = double.tryParse(product['total_price'].toString()) ?? 0;

    // Check if product_code is null and display "OutSide Product"
    String productName = product['product_code'] != null
        ? product['product_code']['product']['name'] ?? 'Unknown Product'
        : 'External Product';

    // Check if product image is null and provide a placeholder
    String? productImageUrl = product['product_code'] != null
        ? product['product_code']['image']
        : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Card(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product Image
                  GestureDetector(
                    onTap: () {
                      if (productImageUrl != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => FullScreenImageView(
                              imageUrl: '$apiBaseUrlImage$productImageUrl',
                            ),
                          ),
                        );
                      }
                    },
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.grey[200],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: productImageUrl != null
                            ? CachedNetworkImage(
                                imageUrl: '$apiBaseUrlImage$productImageUrl',
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        AppTheme.primaryColor),
                                  ),
                                ),
                                errorWidget: (context, url, error) => Icon(
                                  Icons.image_not_supported,
                                  size: 30,
                                  color: Colors.grey[400],
                                ),
                              )
                            : Icon(
                                Icons.shopping_bag,
                                size: 30,
                                color: Colors.grey[400],
                              ),
                      ),
                    ),
                  ),
                  SizedBox(width: 16),

                  // Product Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          productName,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Weight: ${product['weight']}g',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                        SizedBox(height: 8),

                        // Price breakdown
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Price:',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[700],
                              ),
                            ),
                            Text(
                              'Rp ${formatCurrency(price)}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[800],
                              ),
                            ),
                          ],
                        ),

                        // Show adjustment price if applicable
                        if (adjPrice != 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Adjustment:',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: adjPrice > 0
                                        ? AppTheme.infoColor
                                        : AppTheme.successColor,
                                  ),
                                ),
                                Text(
                                  adjPrice > 0
                                      ? '+Rp ${formatCurrency(adjPrice)}'
                                      : '-Rp ${formatCurrency(adjPrice.abs())}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: adjPrice > 0
                                        ? AppTheme.infoColor
                                        : AppTheme.successColor,
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Show discount if applicable
                        if (discount > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Discount:',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppTheme.successColor,
                                  ),
                                ),
                                Text(
                                  '-Rp ${formatCurrency(discount)}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: AppTheme.successColor,
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Total price
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Subtotal:',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                              Text(
                                'Rp ${formatCurrency(totalPrice)}',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.accentColor,
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
            ],
          ),
        ),
      ),
    );
  }

  // Show error dialog with custom styling
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error_outline, color: AppTheme.errorColor),
            SizedBox(width: 8),
            Text("Error", style: TextStyle(color: AppTheme.errorColor)),
          ],
        ),
        content: Text(message),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text("OK", style: TextStyle(color: AppTheme.primaryColor)),
          ),
        ],
      ),
    );
  }
}
