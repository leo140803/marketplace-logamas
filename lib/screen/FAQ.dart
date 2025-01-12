import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:marketplace_logamas/function/Utils.dart';

class FAQPage extends StatefulWidget {
  @override
  _FAQPageState createState() => _FAQPageState();
}

class _FAQPageState extends State<FAQPage> {
  List<Map<String, dynamic>> faqList = [];
  bool isLoading = true;
  String errorMessage = '';

  @override
  void initState() {
    super.initState();
    _fetchFAQData();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF4F4F4),
      appBar: AppBar(
        title: Text(
          "FAQ",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Color(0xFF31394E),
        leading: IconButton(
          onPressed: () => {context.go('/information')},
          icon: Icon(Icons.arrow_back, color: Colors.white),
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
                                textAlign: TextAlign
                                    .justify, // Gunakan justify untuk meratakan teks
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
