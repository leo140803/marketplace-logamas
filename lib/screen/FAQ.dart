import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:marketplace_logamas/function/Utils.dart';
import 'package:url_launcher/url_launcher.dart';

class FAQPage extends StatefulWidget {
  @override
  _FAQPageState createState() => _FAQPageState();
}

class _FAQPageState extends State<FAQPage> {
  List<Map<String, dynamic>> faqList = [];
  bool isLoading = true;
  String errorMessage = '';
  String _waNumber = '';

  @override
  void initState() {
    super.initState();
    _fetchWANumber();
    _fetchFAQData();
  }

  Future<void> _fetchWANumber() async {
    final url = Uri.parse('http://127.0.0.1:3020/api/config/key?key=wa_number');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success']) {
          setState(() {
            print(data['data']['value']);
            _waNumber = data['data']['value'];
          });
        }
      }
    } catch (error) {
      print("Failed to fetch WhatsApp number: $error");
    }
  }

  Future<void> _fetchFAQData() async {
    final url = '$apiBaseUrlPlatform/api/faq/type/1';
    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          faqList = List<Map<String, dynamic>>.from(
            data['data'].map((item) => {
                  'faq_id': item['faq_id'],
                  'question': item['question'],
                  'answer': item['answer'],
                  'type': item['type'],
                  'created_at': item['created_at'],
                  'updated_at': item['updated_at'],
                }),
          );
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = 'Failed to load FAQs';
          isLoading = false;
        });
      }
    } catch (error) {
      setState(() {
        errorMessage = 'Error: $error';
        isLoading = false;
      });
    }
  }

  /// 🔹 **Fungsi untuk membuka WhatsApp**
  Future<void> _openWhatsApp() async {
    String phoneNumber = _waNumber.trim(); // Pastikan tidak ada spasi

    if (!phoneNumber.startsWith("62")) {
      phoneNumber =
          "62$phoneNumber"; // Tambahkan kode negara Indonesia jika belum ada
    }

    final Uri whatsappUrl = Uri.parse("https://wa.me/$phoneNumber");

    if (await canLaunchUrl(whatsappUrl)) {
      await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
    } else {
      _showErrorDialog(
          "Gagal membuka WhatsApp. Periksa koneksi internet Anda.");
    }
  }

  /// 🔹 **Menampilkan dialog error jika gagal membuka WhatsApp**
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: _openWhatsApp, // ✅ Pastikan fungsi dipanggil dengan benar
        child: Icon(Icons.chat_bubble_outline, color: Colors.white),
        backgroundColor: Color(0xFF31394E),
      ),
      backgroundColor: Color(0xFFF4F4F4),
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
          "FAQ",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          onPressed: () => context.go('/information'),
          icon: const Icon(Icons.arrow_back, color: Colors.white),
        ),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : errorMessage.isNotEmpty
              ? Center(child: Text(errorMessage))
              : ListView.builder(
                  padding: EdgeInsets.all(16.0),
                  itemCount: faqList.length,
                  itemBuilder: (context, index) {
                    final faq = faqList[index];
                    return Container(
                      margin: EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Theme(
                        data: Theme.of(context).copyWith(
                          dividerColor: Colors.transparent,
                        ),
                        child: ExpansionTile(
                          tilePadding:
                              EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          childrenPadding: EdgeInsets.all(16),
                          title: Text(
                            faq['question'],
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          iconColor: Colors.blue,
                          collapsedIconColor: Colors.grey,
                          children: [
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                faq['answer'],
                                style: TextStyle(
                                    fontSize: 14, color: Colors.grey[700]),
                                textAlign: TextAlign.justify,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
