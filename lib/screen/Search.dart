import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:marketplace_logamas/function/Utils.dart';

class SearchPage extends StatefulWidget {
  @override
  _SearchPageState createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  TextEditingController _searchController = TextEditingController();
  List<dynamic> products = [];
  List<dynamic> stores = [];

  void search(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        products = [];
        stores = [];
      });
      return;
    }

    try {
      final productResponse =
          await http.get(Uri.parse('$apiBaseUrl/products/search?q=$query'));
      final storeResponse =
          await http.get(Uri.parse('$apiBaseUrl/store/search/?q=$query'));

      if (productResponse.statusCode == 200 &&
          storeResponse.statusCode == 200) {
        setState(() {
          products = json.decode(productResponse.body)['data'];
          stores = json.decode(storeResponse.body)['data'];
        });
      } else {
        throw Exception('Failed to search');
      }
    } catch (e) {
      print('Error: $e');
      setState(() {
        products = [];
        stores = [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
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
          child: Container(
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Colors.white,
            ),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              onChanged: search,
              style: TextStyle(fontSize: 14, color: Colors.black),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Cari...',
                hintStyle: TextStyle(
                  fontSize: 14,
                  color: Color(0xFFC58189),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.transparent),
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.transparent),
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.white,
                prefixIcon: Icon(
                  Icons.search,
                  color: Color(0xFFC58189),
                ),
              ),
            ),
          ),
        ),
        backgroundColor: Color(0xFF31394E),
      ),
      body: Padding(
        padding: const EdgeInsets.only(top: 5.0), // Tambahkan padding di sini
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (products.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Products',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                ListView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final product = products[index];
                    return ListTile(
                      title: Text(product['name'] ?? 'Unknown Product'),
                      onTap: () {
                        context.push('/search-result',
                            extra: {'query': product['name'] ?? ''});
                      },
                    );
                  },
                ),
              ],
              if (stores.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Stores',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                ListView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  itemCount: stores.length,
                  itemBuilder: (context, index) {
                    final store = stores[index];
                    return ListTile(
                      leading: SizedBox(
                        width: 50,
                        height: 50,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(30),
                          child: Image.network(
                            "$apiBaseUrlImage${store['image_url']}",
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return CircleAvatar(
                                backgroundColor: Colors.grey[300],
                                child: Text(
                                  (store['store_name'] ?? 'U')
                                      .substring(0, 1)
                                      .toUpperCase(),
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      title: Text(store['store_name'] ?? 'Unknown Store'),
                      subtitle: Text('Tap to view store'),
                      onTap: () {
                        context.push('/store/${store['store_id']}');
                      },
                    );
                  },
                ),
              ],
              if (products.isEmpty && stores.isEmpty) ...[
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 80,
                          color: Colors.grey[400],
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No results found!',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[700],
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Try searching with a different keyword.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
