import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'dart:convert';

import 'package:marketplace_logamas/function/Utils.dart';
import 'package:marketplace_logamas/screen/FullScreenImageView.dart';
import 'package:url_launcher/url_launcher.dart';

class OrderDetailsPage extends StatefulWidget {
  final String transactionId;

  OrderDetailsPage({required this.transactionId});
  @override
  _OrderDetailsPageState createState() => _OrderDetailsPageState();
}

class _OrderDetailsPageState extends State<OrderDetailsPage> {
  Timer? _timer;
  Duration _timeLeft = Duration.zero;
  Map<String, dynamic>? _transactionData;
  bool _isLoading = true;
  bool _isExpired = false;
  int _reviewExpirationDays = 7;

  @override
  void initState() {
    super.initState();
    _fetchReviewExpiration();
    _fetchTransactionData();
  }

  Future<void> _fetchReviewExpiration() async {
    final url =
        Uri.parse('http://127.0.0.1:3020/api/config/key?key=review_exp');
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
      print("Failed to fetch review expiration: $error");
    }
  }

  Future<void> _fetchTransactionData() async {
    final url = Uri.parse('$apiBaseUrl/transactions/${widget.transactionId}');
    final response = await http.get(url);
    print(json.decode(response.body));
    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      if (data['success']) {
        setState(() {
          _transactionData = data['data']['data'];
          print(_transactionData!['transaction_products'][1]);
          _isLoading = false;
          _setCountdown();
        });
      }
    }
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Kode transaksi disalin ke clipboard!"),
        duration: Duration(seconds: 2),
        backgroundColor: Color(0xFF31394E),
      ),
    );
  }

  String _formatDateTime(String dateTime) {
    DateTime parsedDate = DateTime.parse(dateTime)
        .toUtc()
        .add(Duration(hours: 7)); // Convert UTC to WIB

    return DateFormat("dd-MM-yyyy HH:mm").format(parsedDate); // Format properly
  }

  double _getTaxPercentage() {
    double subTotal =
        double.tryParse(_transactionData!['sub_total_price'].toString()) ?? 0;
    double taxPrice =
        double.tryParse(_transactionData!['tax_price'].toString()) ?? 0;

    if (subTotal == 0) {
      return 0; // Avoid division by zero
    }

    return ((taxPrice / subTotal) * 100).roundToDouble();
  }

  double _getDiscountAmount() {
    if (_transactionData == null) return 0;

    // Ambil nilai dari response API
    double totalPrice =
        double.tryParse(_transactionData!['total_price'].toString()) ?? 0;
    double subTotal =
        double.tryParse(_transactionData!['sub_total_price'].toString()) ?? 0;
    double taxPrice =
        double.tryParse(_transactionData!['tax_price'].toString()) ?? 0;

    // Hitung diskon berdasarkan rumus
    double discount = totalPrice - (subTotal + taxPrice);

    return discount; // Hasil akhir diskon
  }

  void _setCountdown() {
    if (_transactionData != null && _transactionData!['status'] == 0) {
      DateTime expiredAt = DateTime.parse(_transactionData!['expired_at']);
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
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        backgroundColor:
            Colors.transparent, // Buat transparan agar gambar terlihat
        elevation: 0,
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
          'Rincian Pemesanan',
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
          IconButton(
            onPressed: () {
              // TODO: Tambahkan logika untuk melihat nota order
            },
            icon: const Icon(
              Icons.receipt_long,
              color: Colors.white,
            ),
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _buildOrderDetails(),
    );
  }

  Widget _buildOrderDetails() {
    int paymentStatus = _transactionData!['status']; // Status pembayaran
    final operations = _transactionData!['TransactionOperation'] ?? [];

    return Container(
      color: Colors.grey[200],
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Kode Transaksi: ${_transactionData!['code']}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.copy, color: Colors.grey[700], size: 14),
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(),
                    onPressed: () {
                      _copyToClipboard(_transactionData!['code']);
                    },
                  ),
                ],
              ),
              Text(
                'Tanggal Transaksi: ${_formatDateTime(_transactionData!['created_at'])}',
                style: TextStyle(fontSize: 14, color: Colors.black54),
              ),
              Divider(color: Colors.grey[400]),

              // 🔹 STATUS PEMBAYARAN
              if (paymentStatus == 1)
                _buildStatusMessage('Siap Diambil', Colors.blue),
              if (paymentStatus == 2)
                _buildStatusMessage('Sudah Diambil (Done)', Colors.green),
              if (paymentStatus == 0) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Expired In:',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    Text(
                      _isExpired
                          ? 'Expired'
                          : '${_timeLeft.inHours}:${(_timeLeft.inMinutes % 60).toString().padLeft(2, '0')}:${(_timeLeft.inSeconds % 60).toString().padLeft(2, '0')}',
                      style: TextStyle(
                          fontSize: 18,
                          color: _isExpired ? Colors.red : Colors.redAccent,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                SizedBox(height: 16),
              ],

              // 🔹 INFORMASI TOKO
              Text(
                _transactionData!['store']['store_name'],
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),

              // 🔹 LIST PRODUK
              Column(
                children: _transactionData!['transaction_products']
                    .map<Widget>((product) => _buildProductItem(product))
                    .toList(),
              ),

              // 🔹 LIST TRANSACTION OPERATIONS (JIKA ADA)
              if (operations.isNotEmpty) ...[
                SizedBox(height: 16),
                Text(
                  "Additional Service",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Divider(color: Colors.grey[400]),
                Column(
                  children: operations.map<Widget>((operation) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "${operation['name']} (x${operation['unit']})",
                            style: TextStyle(fontSize: 16),
                          ),
                          Text(
                            "Rp ${formatCurrency(double.tryParse(operation['total_price'].toString()) ?? 0)}",
                            style: TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
                SizedBox(height: 16),
              ],

              Divider(color: Colors.grey[400]),

              // 🔹 RINCIAN PESANAN
              Text('Rincian Pesanan',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(height: 8),

              _buildOrderDetailRow('Harga Sebelum Voucher',
                  'Rp ${formatCurrency(double.tryParse(_transactionData!['sub_total_price'].toString()) ?? 0)}'),
              _buildOrderDetailRow('Tax (${_getTaxPercentage()}%)',
                  'Rp ${formatCurrency(double.tryParse(_transactionData!['tax_price'].toString()) ?? 0)}'),
              _buildOrderDetailRow('Potongan Voucher',
                  '-Rp ${formatCurrency(_getDiscountAmount())}'),
              _buildOrderDetailRow(
                  'Poin Earned', '${_transactionData!['poin_earned']} Poin'),

              Divider(color: Colors.grey[400]),
              _buildOrderDetailRow('Total Bayar',
                  'Rp ${formatCurrency(double.tryParse(_transactionData!['total_price'].toString()) ?? 0)}',
                  isBold: true),
              SizedBox(height: 16),

              if (paymentStatus == 0)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 15),
                      backgroundColor: Color(0xFF31394E),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    onPressed: () {
                      _openPaymentLink();
                    },
                    child: Text(
                      'Bayar Sekarang',
                      style: TextStyle(
                          fontSize: 18,
                          color: Colors.white,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

// 🔹 FUNCTION MEMBANGUN ROW DETAIL ORDER
  Widget _buildOrderDetailRow(String label, String value,
      {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
                fontSize: 16,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                color: Color(0xFF31394E)),
          ),
          Text(
            value,
            style: TextStyle(
                fontSize: 16,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                color: isBold ? Colors.redAccent : Colors.grey[700]),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusMessage(String text, Color color) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12),
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style:
            TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }

  void _showEditReviewDialog(
      String reviewId, String userId, int currentRating, String currentReview) {
    double rating = currentRating.toDouble();
    TextEditingController reviewController =
        TextEditingController(text: currentReview);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Color(0xFF31394E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.0),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // 📝 Title
                    Text(
                      "Edit Review",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      "Perbarui penilaian dan ulasanmu.",
                      style: TextStyle(fontSize: 14, color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 15),

                    // ⭐ Star Rating Selection
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        return IconButton(
                          icon: Icon(
                            index < rating ? Icons.star : Icons.star_border,
                            color: Colors.amber,
                            size: 32,
                          ),
                          onPressed: () {
                            setDialogState(() {
                              rating = index + 1.0;
                            });
                          },
                        );
                      }),
                    ),

                    SizedBox(height: 10),

                    // 📝 Review Input Field
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: TextField(
                        controller: reviewController,
                        maxLines: 3,
                        style: TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: "Edit ulasan kamu...",
                          hintStyle: TextStyle(color: Colors.white54),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                        ),
                      ),
                    ),

                    SizedBox(height: 15),

                    // 🔹 Submit Button with Gradient
                    TextButton(
                      onPressed: () {
                        _submitEditReview(
                          reviewId,
                          userId,
                          rating.toInt(),
                          reviewController.text,
                        );
                        Navigator.pop(context);
                      },
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                      ),
                      child: Container(
                        width: 120,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Color(0xFFE8C4BD),
                              Color(0xFFC58189),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        alignment: Alignment.center,
                        child: const Text(
                          "Perbarui",
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: 5),

                    // 🔹 Cancel Button
                    TextButton(
                      onPressed: () =>
                          Navigator.of(context, rootNavigator: true).pop(),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                      ),
                      child: Container(
                        width: 100,
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        alignment: Alignment.center,
                        child: const Text(
                          "Batal",
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white,
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

  Future<void> _submitEditReview(
      String reviewId, String userId, int rating, String review) async {
    final String url = '$apiBaseUrl/review';
    String token = await getAccessToken();

    final response = await http.patch(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        "review_id": reviewId, // Ensure correct API field names
        "user_id": userId, // Include user ID
        "rating": rating,
        "review": review,
      }),
    );

    final Map<String, dynamic> responseData = json.decode(response.body);

    if (response.statusCode == 200 && responseData['success']) {
      print("Review updated successfully!");
      setState(() {
        _fetchTransactionData(); // Refresh transaction details after update
      });
    } else {
      print("Error updating review: ${responseData['message']}");
    }
  }

  Widget _buildProductItem(Map<String, dynamic> product) {
    int paymentStatus = _transactionData!['status']; // Get transaction status
    var transactionReview =
        product['TransactionReview']; // Ambil review jika ada

    // 🕒 Perhitungan batas akhir review (updated_at + 7 hari)
    DateTime updatedAt = DateTime.parse(product['updated_at']);
    DateTime reviewDeadline = updatedAt.add(Duration(days: _reviewExpirationDays));
    bool canReview = DateTime.now().isBefore(reviewDeadline);

    // Ambil Harga, Adjustment Price, dan Discount
    double price = double.tryParse(product['price'].toString()) ?? 0;
    double adjPrice =
        double.tryParse(product['adjustment_price'].toString()) ?? 0;
    double discount = double.tryParse(product['discount'].toString()) ?? 0;
    double totalPrice = double.tryParse(product['total_price'].toString()) ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              blurRadius: 6,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product Image
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => FullScreenImageView(
                          imageUrl:
                              '$apiBaseUrlImage${product['product_code']['image']}',
                        ),
                      ),
                    );
                  },
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: Colors.grey[300],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        '$apiBaseUrlImage${product['product_code']['image']}',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(
                          Icons.image_not_supported,
                          size: 40,
                          color: Colors.grey,
                        ),
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
                        product['product_code']['product']['name'],
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Subtotal: Rp ${formatCurrency(totalPrice)}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Weight: ${product['weight']}gr',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                      ),

                      // 🔹 Tampilkan Adjustment Price Jika > 0
                      if (adjPrice > 0)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("Adjustment Price",
                                style: TextStyle(
                                    fontSize: 14, color: Colors.blue)),
                            Text(
                              "+Rp ${formatCurrency(adjPrice)}",
                              style: const TextStyle(
                                  fontSize: 14, color: Colors.blue),
                            ),
                          ],
                        ),

                      // 🔹 Tampilkan Discount Jika > 0
                      if (discount > 0)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("Discount",
                                style: TextStyle(
                                    fontSize: 14, color: Colors.green)),
                            Text("-Rp ${formatCurrency(discount)}",
                                style: const TextStyle(
                                    fontSize: 14, color: Colors.green)),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),

            SizedBox(height: 10),

            // ⭐ Tampilkan Review jika ada
            if (transactionReview != null)
              Container(
                margin: EdgeInsets.only(top: 8),
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Color(0xFFC58189).withOpacity(0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.star, color: Colors.amber, size: 18),
                        SizedBox(width: 4),
                        Text(
                          "${transactionReview['rating']} / 5",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 6),
                    Text(
                      '"${transactionReview['review']}"',
                      style: TextStyle(
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 6),
                    if (transactionReview['reply_admin'] != null)
                      Container(
                        margin: EdgeInsets.only(top: 6),
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Color(0xFF31394E),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.admin_panel_settings_rounded,
                                color: Colors.white, size: 16),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '"${transactionReview['reply_admin']}"',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (transactionReview != null &&
                        canReview &&
                        transactionReview['reply_admin'] == null)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () => _showEditReviewDialog(
                              transactionReview['id'], // ✅ Pass reviewId
                              _transactionData!['customer_id'], // ✅ Pass userId
                              transactionReview['rating'],
                              transactionReview['review']),
                          icon: Icon(Icons.edit,
                              size: 16, color: Colors.blueAccent),
                          label: Text(
                            "Edit Review",
                            style: TextStyle(color: Colors.blueAccent),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

            // 🎯 Tampilkan tombol "Beri Penilaian" jika review belum ada dan masih dalam batas waktu
            if (paymentStatus == 2 && transactionReview == null && canReview)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // 🕒 Batas Akhir Review
                  Text(
                    "Beri review sebelum: ${DateFormat('dd MMM yyyy').format(reviewDeadline)}",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[600],
                    ),
                  ),

                  // 📝 Tombol Beri Penilaian
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      padding:
                          EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () => _showRatingDialog(product['id']),
                    child: Text(
                      "Beri Penilaian",
                      style: TextStyle(fontSize: 14, color: Colors.white),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  void _showRatingDialog(String productId) {
    double rating = 0; // Default rating
    TextEditingController reviewController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Color(0xFF31394E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.0),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      "Beri Penilaian",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      "Bagaimana kualitas produk ini?",
                      style: TextStyle(fontSize: 14, color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 15),

                    // ⭐ Star Rating Selection
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        return IconButton(
                          icon: Icon(
                            index < rating ? Icons.star : Icons.star_border,
                            color: Colors.amber,
                            size: 32,
                          ),
                          onPressed: () {
                            setDialogState(() {
                              rating = index + 1.0;
                            });
                          },
                        );
                      }),
                    ),

                    SizedBox(height: 10),

                    // 📝 Review Text Input
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: TextField(
                        autocorrect: false,
                        controller: reviewController,
                        maxLines: 3,
                        style: TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: "Tulis ulasanmu...",
                          hintStyle: TextStyle(color: Colors.white54),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                        ),
                      ),
                    ),

                    SizedBox(height: 15),

                    // Submit Button
                    TextButton(
                      onPressed: () {
                        _submitRating(productId, rating, reviewController.text);
                        Navigator.pop(context);
                      },
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                      ),
                      child: Container(
                        width: 120,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Color(0xFFE8C4BD),
                              Color(0xFFC58189),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        alignment: Alignment.center,
                        child: const Text(
                          "Kirim",
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: 5),

                    // Cancel Button
                    TextButton(
                      onPressed: () =>
                          Navigator.of(context, rootNavigator: true).pop(),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                      ),
                      child: Container(
                        width: 100,
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        alignment: Alignment.center,
                        child: const Text(
                          "Batal",
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white,
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

  Future<void> _submitRating(
      String productId, double rating, String review) async {
    final String url = '$apiBaseUrl/review'; // API Gateway
    String token = await getAccessToken();

    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        "transaction_product_id": productId,
        "rating": rating.toInt(),
        "review": review,
      }),
    );

    final Map<String, dynamic> responseData = json.decode(response.body);

    if (response.statusCode == 201) {
      print("Review submitted successfully!");
      setState(() {
        _fetchTransactionData(); // Refresh the page to show the review
      });
    } else {
      print("Error: ${responseData['message']}");
    }
  }

  void _openPaymentLink() async {
    if (_transactionData != null && _transactionData!['payment_link'] != null) {
      final String paymentUrl = _transactionData!['payment_link'];
      final Uri url = Uri.parse(paymentUrl); // Format URL dengan benar

      if (await canLaunchUrl(url)) {
        await launchUrl(url,
            mode: LaunchMode.externalApplication); // Gunakan mode yang tepat
      } else {
        _showErrorDialog("Gagal membuka link pembayaran.");
      }
    } else {
      _showErrorDialog("Link pembayaran tidak tersedia.");
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Error"),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text("OK"),
          ),
        ],
      ),
    );
  }
}
