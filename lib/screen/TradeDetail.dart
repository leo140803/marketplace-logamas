import 'dart:io';
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:marketplace_logamas/function/Utils.dart';
import 'package:marketplace_logamas/screen/FullScreenImageView.dart';
import 'package:marketplace_logamas/screen/PDFScreen.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shimmer/shimmer.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:path/path.dart' as path;

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
  static const tradeColor = Color(0xFFFF9800); // Warna khusus untuk trade

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

class TradeDetailsPage extends StatefulWidget {
  final String transactionId;

  const TradeDetailsPage({
    Key? key,
    required this.transactionId,
  }) : super(key: key);

  @override
  _TradeDetailsPageState createState() => _TradeDetailsPageState();
}

class _TradeDetailsPageState extends State<TradeDetailsPage> {
  Timer? _timer;
  Duration _timeLeft = Duration.zero;
  Map<String, dynamic>? _transactionData;
  bool _isLoading = true;
  bool _isExpired = false;
  int _reviewExpirationDays = 7;
  List<XFile> selectedImages = [];
  final ImagePicker _picker = ImagePicker();
  List<XFile> editImages = []; // gambar baru yg dipilih
  List<String> oldImages = []; // url gambar lama (preview saja)

  @override
  void initState() {
    super.initState();
    _fetchReviewExpiration();
    _fetchTransactionData();

    // Add haptic feedback for page load
    HapticFeedback.lightImpact();
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

  Future<void> _fetchReviewExpiration() async {
    final url = Uri.parse('$apiBaseUrlPlatform/api/config/key?key=review_exp');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success']) {
          setState(() {
            _reviewExpirationDays = int.tryParse(data['data']['value']) ?? 7;
          });
        }
      }
    } catch (error) {
      _showErrorSnackBar("Failed to fetch review expiration settings");
    }
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
          _showErrorSnackBar("Failed to load trade details",
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
    final String url = '$apiBaseUrlNota/nota/$transactionId';

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
      final response = await http.get(Uri.parse(url));

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
      bottomNavigationBar: _buildBottomNavigationBar(),
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
        'Trade Details',
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
            _transactionData!['status'] == 2)
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

  // Bottom navigation bar that shows payment button if applicable
  Widget? _buildBottomNavigationBar() {
    if (_isLoading || _transactionData == null) return null;

    // Only show for unpaid transactions
    if (_transactionData!['status'] == 0 && !_isExpired) {
      final double totalPrice =
          double.tryParse(_transactionData!['total_price'].toString()) ?? 0;

      return Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: 16),
              backgroundColor: totalPrice <= 0
                  ? AppTheme.successColor
                  : AppTheme.primaryColor,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: _openPaymentLink,
            child: Text(
              totalPrice <= 0 ? 'Complete Trade' : 'Pay Now',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      );
    }
    return null;
  }

  Widget _buildOrderDetails() {
    int paymentStatus = _transactionData!['status'];
    final operations = _transactionData!['TransactionOperation'] ?? [];
    final totalPrice =
        double.tryParse(_transactionData!['total_price'].toString()) ?? 0;

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

            // Produk
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 🔻 Produk Dibeli oleh Customer
                if (_transactionData!['transaction_products']
                    .any((p) => p['transaction_type'] == 1)) ...[
                  _buildSectionHeader(
                    title: 'Produk yang dibeli',
                    icon: Icons.shopping_cart_outlined,
                    color: AppTheme.infoColor,
                  ),
                  SizedBox(height: 8),
                  ..._transactionData!['transaction_products']
                      .where((product) => product['transaction_type'] == 1)
                      .map<Widget>((product) => _buildProductItem(product))
                      .toList(),
                ],

                SizedBox(height: 16),

                // 🔺 Produk Dijual oleh Customer
                if (_transactionData!['transaction_products']
                    .any((p) => p['transaction_type'] == 2)) ...[
                  _buildSectionHeader(
                    title: 'Produk yang dijual',
                    icon: Icons.sell_outlined,
                    color: AppTheme.successColor,
                  ),
                  SizedBox(height: 8),
                  ..._transactionData!['transaction_products']
                      .where((product) => product['transaction_type'] == 2)
                      .map<Widget>((product) => _buildProductItem(product))
                      .toList(),
                ],
              ],
            ),

            if (operations.isNotEmpty) ...[
              SizedBox(height: 16),
              _buildOperationsSection(operations),
            ],

            SizedBox(height: 16),
            _buildOrderSummary(totalPrice),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
      {required String title, required IconData icon, required Color color}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: color,
            size: 18,
          ),
          SizedBox(width: 10),
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
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
              'Trade Date: ${_formatDateTime(_transactionData!['created_at'])}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
            SizedBox(height: 4),
            // Special label for Trade
            Container(
              margin: EdgeInsets.only(top: 8),
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.tradeColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppTheme.tradeColor.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.swap_horiz,
                    size: 14,
                    color: AppTheme.tradeColor,
                  ),
                  SizedBox(width: 4),
                  Text(
                    'Trade Transaction',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.tradeColor,
                    ),
                  ),
                ],
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
      message = 'Ready for Pickup';
      color = AppTheme.infoColor;
      icon = Icons.inventory;
    } else if (status == 2) {
      message = 'Trade Completed';
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
              final double basePrice =
                  double.tryParse(operation['price']?.toString() ?? '0') ?? 0;
              final double units =
                  double.tryParse(operation['unit']?.toString() ?? '1') ?? 1;
              final double adjustmentPrice = double.tryParse(
                      operation['adjustment_price']?.toString() ?? '0') ??
                  0;
              final double totalPrice = double.tryParse(
                      operation['total_price']?.toString() ?? '0') ??
                  0;

              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
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
                          "Rp ${formatCurrency(basePrice * units)}",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    // Only show adjustment if it's not zero
                    if (adjustmentPrice != 0)
                      Padding(
                        padding: const EdgeInsets.only(left: 26.0, top: 4.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Adjustment",
                              style: TextStyle(
                                fontSize: 13,
                                fontStyle: FontStyle.italic,
                                color: Colors.grey[600],
                              ),
                            ),
                            Text(
                              adjustmentPrice >= 0
                                  ? "+ Rp ${formatCurrency(adjustmentPrice)}"
                                  : "- Rp ${formatCurrency(adjustmentPrice.abs())}",
                              style: TextStyle(
                                fontSize: 13,
                                fontStyle: FontStyle.italic,
                                color: adjustmentPrice >= 0
                                    ? Colors.green
                                    : Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ),
                    // Show total price if there's an adjustment
                    if (adjustmentPrice != 0)
                      Padding(
                        padding: const EdgeInsets.only(left: 26.0, top: 2.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Total",
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              "Rp ${formatCurrency(totalPrice)}",
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    SizedBox(height: 4),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderSummary(double totalPrice) {
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
              'Trade Summary',
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
            _buildSummaryRow(
              'Trade-in Fee',
              'Rp ${formatCurrency(double.tryParse(_transactionData!['adjustment_price'].toString()) ?? 0)}',
              valueColor: AppTheme.tradeColor,
            ),
            Divider(height: 24, thickness: 1),
            _buildSummaryRow(
              totalPrice >= 0 ? 'Total Payment' : 'Total Money Received',
              'Rp ${formatCurrency(totalPrice.abs())}',
              isBold: true,
              labelColor: AppTheme.primaryColor,
              valueColor: totalPrice >= 0
                  ? AppTheme.accentColor
                  : AppTheme.successColor,
            ),
          ],
        ),
      ),
    );
  }

  // Function to display summary rows
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
    int paymentStatus = _transactionData!['status'];
    var transactionReview = product['TransactionReview'];
    int transactionType = product['transaction_type'] ?? 1;
    bool isProductBought = transactionType == 1;

    // Calculate review deadline
    DateTime updatedAt = DateTime.parse(product['updated_at']);
    DateTime reviewDeadline =
        updatedAt.add(Duration(days: _reviewExpirationDays));
    bool canReview = DateTime.now().isBefore(reviewDeadline);

    // Extract product details
    double price = double.tryParse(product['price'].toString()) ?? 0;
    double adjPrice =
        double.tryParse(product['adjustment_price'].toString()) ?? 0;
    double discount = double.tryParse(product['discount'].toString()) ?? 0;
    double totalPrice = double.tryParse(product['total_price'].toString()) ?? 0;

    // Check if product_code is null and display "External Product"
    String productName = product['product_code'] != null
        ? product['product_code']['product']['name'] ?? 'Unknown Product'
        : 'External Product';

    var certificateLink = product['product_code'] != null
        ? product['product_code']['certificate_link']
        : null;

    // Check if product image is null and provide a placeholder
    String? productImageUrl = product['product_code'] != null
        ? product['product_code']['image']
        : null;

    void _showErrorSnackBar(BuildContext context, String message) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppTheme.errorColor,
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.all(8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }

    Future<void> _openCertificateLink(
        BuildContext context, String? certificateLink) async {
      if (certificateLink != null) {
        final Uri url = Uri.parse(certificateLink);

        // Tampilkan indikator loading
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext dialogContext) {
            // Gunakan dialogContext untuk Navigator.pop
            return AlertDialog(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  SpinKitRing(
                    color: AppTheme.primaryColor,
                    size: 40.0,
                  ),
                  SizedBox(height: 16),
                  Text("Opening certificate..."),
                ],
              ),
            );
          },
        );

        try {
          if (await canLaunchUrl(url)) {
            Navigator.pop(
                context); // Tutup dialog menggunakan context yang sesuai
            await launchUrl(url, mode: LaunchMode.externalApplication);
            HapticFeedback.mediumImpact();
          } else {
            Navigator.pop(context); // Tutup dialog
            _showErrorSnackBar(context, "Unable to open the certificate link.");
          }
        } catch (e) {
          Navigator.pop(context); // Tutup dialog
          _showErrorSnackBar(
              context, "Error opening certificate link: ${e.toString()}");
        }
      } else {
        _showErrorSnackBar(context, "Certificate link is not available.");
      }
    }

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
                                isProductBought
                                    ? Icons.shopping_bag_outlined
                                    : Icons.sell_outlined,
                                size: 30,
                                color: isProductBought
                                    ? AppTheme.primaryColor
                                    : AppTheme.successColor,
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
                            color: isProductBought
                                ? AppTheme.primaryColor
                                : AppTheme.successColor,
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
                                  color: isProductBought
                                      ? AppTheme.primaryColor
                                      : AppTheme.successColor,
                                ),
                              ),
                              Text(
                                'Rp ${formatCurrency(totalPrice)}',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: isProductBought
                                      ? AppTheme.accentColor
                                      : AppTheme.successColor,
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

              // Review section
              if (transactionReview != null)
                _buildReviewSection(transactionReview, canReview),

              // Show "Rate Product" button if applicable
              if (paymentStatus == 2 &&
                  transactionReview == null &&
                  canReview &&
                  isProductBought)
                _buildRateProductButton(reviewDeadline, product['id']),

              if (paymentStatus == 2 && certificateLink != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.primaryColor,
                          AppTheme.primaryColor.withOpacity(0.8),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryColor.withOpacity(0.3),
                          blurRadius: 8,
                          offset: Offset(0, 4),
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () =>
                            _openCertificateLink(context, certificateLink),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                              vertical: 14, horizontal: 20),
                          child: Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.verified,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'View Certificate',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.arrow_forward_ios,
                                color: Colors.white.withOpacity(0.8),
                                size: 16,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReviewSection(Map<String, dynamic> review, bool canReview) {
    return Container(
      margin: EdgeInsets.only(top: 16),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.accentColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.accentColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Star rating display
              Row(
                children: List.generate(5, (index) {
                  return Icon(
                    index < (review['rating'] ?? 0)
                        ? Icons.star
                        : Icons.star_border,
                    color: Colors.amber,
                    size: 18,
                  );
                }),
              ),
              SizedBox(width: 8),
              Text(
                "${review['rating']} / 5",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),

              // Date display
              if (review['updated_at'] != null)
                Expanded(
                  child: Text(
                    DateFormat("dd MMM yyyy")
                        .format(DateTime.parse(review['updated_at'])),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
            ],
          ),
          SizedBox(height: 8),

          // Review text
          Text(
            '"${review['review']}"',
            style: TextStyle(
              fontSize: 14,
              fontStyle: FontStyle.italic,
              color: Colors.grey[800],
            ),
          ),

          if (review['images'] != null &&
              review['images'] is List &&
              review['images'].isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12.0),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(review['images'].length, (index) {
                  final imageUrl = review['images'][index];
                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FullScreenImageView(
                              imageUrl: '$apiBaseUrlImage2$imageUrl'),
                        ),
                      );
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        '$apiBaseUrlImage2$imageUrl',
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: 80,
                          height: 80,
                          color: Colors.grey[300],
                          child:
                              Icon(Icons.broken_image, color: Colors.grey[700]),
                        ),
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return Container(
                            width: 80,
                            height: 80,
                            alignment: Alignment.center,
                            child: CircularProgressIndicator(
                              value: progress.expectedTotalBytes != null
                                  ? progress.cumulativeBytesLoaded /
                                      progress.expectedTotalBytes!
                                  : null,
                              strokeWidth: 2,
                            ),
                          );
                        },
                      ),
                    ),
                  );
                }),
              ),
            ),

          // Admin reply if available
          if (review['reply_admin'] != null)
            Container(
              margin: EdgeInsets.only(top: 12),
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.support_agent,
                          color: AppTheme.primaryColor, size: 16),
                      SizedBox(width: 6),
                      Text(
                        "Admin Response",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 6),
                  Text(
                    '"${review['reply_admin']}"',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ],
              ),
            ),

          // Edit review button (only if admin hasn't replied and within time limit)
          if (canReview && review['reply_admin'] == null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () {
                  _showEditReviewDialog(
                    review['id'],
                    _transactionData!['customer_id'],
                    review['rating'],
                    review['review'],
                    review['images'] ?? [],
                  );
                },
                icon: Icon(Icons.edit, size: 16, color: AppTheme.accentColor),
                label: Text(
                  "Edit Review",
                  style: TextStyle(color: AppTheme.accentColor),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRateProductButton(DateTime reviewDeadline, String productId) {
    return Container(
      margin: EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Deadline: ${DateFormat('dd MMM yyyy').format(reviewDeadline)}",
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _showRatingDialog(productId),
                icon: Icon(Icons.star_border, size: 16),
                label: Text("Rate Product"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentColor,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showRatingDialog(String productId) {
    double rating = 0;
    TextEditingController reviewController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.0),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      "Rate This Product",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      "Share your experience with this product",
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 20),

                    // Star Rating Selection
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        return GestureDetector(
                          onTap: () {
                            setDialogState(() {
                              rating = index + 1.0;
                              // Add a subtle haptic feedback
                              HapticFeedback.selectionClick();
                            });
                          },
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 5.0),
                            child: Icon(
                              index < rating ? Icons.star : Icons.star_border,
                              color: Colors.amber,
                              size: 36,
                            ),
                          ),
                        );
                      }),
                    ),
                    SizedBox(height: 20),

                    // Review Text Input
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: TextField(
                        controller: reviewController,
                        maxLines: 3,
                        style: TextStyle(color: Colors.black87),
                        decoration: InputDecoration(
                          hintText: "Write your review here...",
                          hintStyle: TextStyle(color: Colors.grey[400]),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.all(16),
                        ),
                      ),
                    ),
                    SizedBox(height: 24),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (var img in selectedImages)
                          Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(
                                  File(img.path),
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                top: 0,
                                right: 0,
                                child: GestureDetector(
                                  onTap: () {
                                    setDialogState(() {
                                      selectedImages.remove(img);
                                    });
                                  },
                                  child: CircleAvatar(
                                    radius: 10,
                                    backgroundColor: Colors.black54,
                                    child: Icon(Icons.close,
                                        size: 14, color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        if (selectedImages.length < 3)
                          GestureDetector(
                            onTap: () async {
                              final picked = await _picker.pickMultiImage();
                              if (picked != null &&
                                  picked.length + selectedImages.length <= 3) {
                                setDialogState(() {
                                  selectedImages.addAll(picked);
                                });
                              } else {
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(SnackBar(
                                  content: Text("Maximum 3 images allowed"),
                                  backgroundColor: AppTheme.warningColor,
                                ));
                              }
                            },
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey),
                              ),
                              child: Icon(Icons.add_a_photo,
                                  color: Colors.grey[800]),
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: 16),
                    // Submit and Cancel Buttons
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(color: Colors.grey[300]!),
                              ),
                            ),
                            child: Text(
                              "Cancel",
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              if (rating > 0) {
                                _submitRating(
                                    productId, rating, reviewController.text);
                                Navigator.pop(context);
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content:
                                        Text("Please select a rating first"),
                                    backgroundColor: AppTheme.warningColor,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              backgroundColor: AppTheme.accentColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              "Submit",
                              style: TextStyle(
                                color: Colors.white,
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
            );
          },
        );
      },
    );
  }

  void _showEditReviewDialog(
    String reviewId,
    String userId,
    int currentRating,
    String currentReview,
    List<dynamic> currentImages, // <= TERIMA gambar lama
  ) {
    double rating = currentRating.toDouble();
    TextEditingController reviewController =
        TextEditingController(text: currentReview);

    // inisialisasi
    editImages.clear();
    oldImages = currentImages.cast<String>();
    print(oldImages);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "Edit Your Review",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      "Update your rating and review",
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 20),

                    // Star Rating Selection
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        return GestureDetector(
                          onTap: () {
                            setDialogState(() {
                              rating = index + 1.0;
                              HapticFeedback.selectionClick();
                            });
                          },
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 5.0),
                            child: Icon(
                              index < rating ? Icons.star : Icons.star_border,
                              color: Colors.amber,
                              size: 36,
                            ),
                          ),
                        );
                      }),
                    ),
                    SizedBox(height: 20),

                    // Review Text Input
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: TextField(
                        controller: reviewController,
                        maxLines: 3,
                        style: TextStyle(color: Colors.black87),
                        decoration: InputDecoration(
                          hintText: "Update your review...",
                          hintStyle: TextStyle(color: Colors.grey[400]),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.all(16),
                        ),
                      ),
                    ),
                    SizedBox(height: 24),

                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text("Images (max 3)",
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryColor)),
                    ),
                    SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        // Gambar lama (network)
                        for (int i = 0; i < oldImages.length; i++)
                          Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  '$apiBaseUrlImage2${oldImages[i]}',
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                top: 0,
                                right: 0,
                                child: GestureDetector(
                                  onTap: () {
                                    setDialogState(() {
                                      oldImages.removeAt(i);
                                    });
                                  },
                                  child: CircleAvatar(
                                    radius: 10,
                                    backgroundColor: Colors.black54,
                                    child: Icon(Icons.close,
                                        size: 14, color: Colors.white),
                                  ),
                                ),
                              )
                            ],
                          ),

                        // Gambar baru (file)
                        for (int i = 0; i < editImages.length; i++)
                          Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(
                                  File(editImages[i].path),
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                top: 0,
                                right: 0,
                                child: GestureDetector(
                                  onTap: () {
                                    setDialogState(() {
                                      editImages.removeAt(i);
                                    });
                                  },
                                  child: CircleAvatar(
                                    radius: 10,
                                    backgroundColor: Colors.black54,
                                    child: Icon(Icons.close,
                                        size: 14, color: Colors.white),
                                  ),
                                ),
                              )
                            ],
                          ),

                        // Tombol tambah (hanya jika total < 3)
                        if (oldImages.length + editImages.length < 3)
                          GestureDetector(
                            onTap: () async {
                              final picked = await _picker.pickMultiImage();
                              if (picked != null &&
                                  picked.length +
                                          oldImages.length +
                                          editImages.length <=
                                      3) {
                                setDialogState(() {
                                  editImages.addAll(picked);
                                });
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text("Maximum 3 images allowed"),
                                    backgroundColor: AppTheme.warningColor,
                                  ),
                                );
                              }
                            },
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey)),
                              child: Icon(Icons.add_a_photo,
                                  color: Colors.grey[800]),
                            ),
                          ),
                      ],
                    ),

                    SizedBox(height: 24),

                    // ----------  BUTTON  ----------
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentColor,
                          minimumSize: Size(double.infinity, 48)),
                      onPressed: () {
                        _submitEditReview(
                          reviewId,
                          userId,
                          rating.toInt(),
                          reviewController.text,
                          oldImages, // <-- kirim sisa gambar lama
                        );
                        Navigator.pop(context);
                      },
                      child:
                          Text("Update", style: TextStyle(color: Colors.white)),
                    )
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Function to submit rating
  Future<void> _submitRating(
      String productId, double rating, String review) async {
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
              Text("Submitting your review..."),
            ],
          ),
        );
      },
    );

    try {
      final url = Uri.parse('$apiBaseUrl/review');
      final request = http.MultipartRequest('POST', url);
      String token = await getAccessToken();

      request.headers['Authorization'] = 'Bearer $token';
      request.fields['transaction_product_id'] = productId;
      request.fields['rating'] = rating.toInt().toString();
      request.fields['review'] = review;

      for (int i = 0; i < selectedImages.length; i++) {
        final imageFile = File(selectedImages[i].path);
        final stream = http.ByteStream(imageFile.openRead());
        final length = await imageFile.length();

        final multipartFile = http.MultipartFile(
          'images', // harus disesuaikan dengan nama field multer backend
          stream,
          length,
          filename: path.basename(imageFile.path),
        );

        request.files.add(multipartFile);
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      Navigator.pop(context); // close loading

      final Map<String, dynamic> responseData = json.decode(response.body);
      if (response.statusCode == 201 && responseData['success']) {
        HapticFeedback.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Review submitted successfully!"),
          backgroundColor: AppTheme.successColor,
        ));
        setState(() {
          selectedImages.clear();
          _fetchTransactionData();
        });
      } else {
        _showErrorDialog("Failed: ${responseData['message']}");
      }
    } catch (e) {
      Navigator.pop(context);
      _showErrorDialog("Error submitting review: $e");
    }
  }

  // Function to edit an existing review
  Future<void> _submitEditReview(
    String reviewId,
    String userId,
    int rating,
    String review,
    List<String> remainingOld, // url yg masih dipertahankan
  ) async {
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
              Text("Updating your review..."),
            ],
          ),
        );
      },
    );

    try {
      final url = Uri.parse('$apiBaseUrl/review');
      final req = http.MultipartRequest('PATCH', url);
      final token = await getAccessToken();

      req.headers['Authorization'] = 'Bearer $token';

      // field biasa
      req.fields['review_id'] = reviewId;
      req.fields['user_id'] = userId;
      req.fields['rating'] = rating.toString();
      req.fields['review'] = review;

      // url gambar lama yang masih dipakai
      // backend akan meng-gabung images dari file + field ini
      req.fields['keep_images'] = jsonEncode(remainingOld);

      // file gambar baru
      for (var x in editImages) {
        final f = File(x.path);
        req.files.add(
          await http.MultipartFile.fromPath('images', f.path,
              filename: path.basename(f.path)),
        );
      }

      final res = await http.Response.fromStream(await req.send());
      Navigator.pop(context);

      final body = json.decode(res.body);
      if (res.statusCode == 200 && body['success']) {
        HapticFeedback.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("Review updated successfully!"),
            backgroundColor: AppTheme.successColor));
        setState(() {
          editImages.clear();
          oldImages.clear();
          _fetchTransactionData();
        });
      } else {
        _showErrorDialog("Failed: ${body['message']}");
      }
    } catch (e) {
      Navigator.pop(context);
      _showErrorDialog("Error updating review: $e");
    }
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

  // Payment link handling with progress indicator
  Future<void> _openPaymentLink() async {
    if (_transactionData != null && _transactionData!['payment_link'] != null) {
      final Uri url = Uri.parse(_transactionData!['payment_link']);

      // Show a loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SpinKitRing(
                  color: AppTheme.primaryColor,
                  size: 40.0,
                ),
                SizedBox(height: 16),
                Text("Opening payment gateway..."),
              ],
            ),
          );
        },
      );

      try {
        if (await canLaunchUrl(url)) {
          // Close the dialog
          Navigator.pop(context);
          await launchUrl(url, mode: LaunchMode.externalApplication);

          // Provide haptic feedback
          HapticFeedback.mediumImpact();
        } else {
          // Close the dialog
          Navigator.pop(context);
          _showErrorDialog("Unable to open the payment link.");
        }
      } catch (e) {
        // Close the dialog
        Navigator.pop(context);
        _showErrorDialog("Error opening payment link: ${e.toString()}");
      }
    } else {
      _showErrorDialog("Payment link is not available.");
    }
  }
}
