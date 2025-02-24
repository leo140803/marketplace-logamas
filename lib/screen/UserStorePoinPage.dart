import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:go_router/go_router.dart';
import 'package:marketplace_logamas/function/Utils.dart';

class StorePointsPage extends StatefulWidget {
  final String storeId;
  final String storeName;
  final String? storeLogo;

  StorePointsPage(
      {required this.storeId, required this.storeName, this.storeLogo});

  @override
  _StorePointsPageState createState() => _StorePointsPageState();
}

class _StorePointsPageState extends State<StorePointsPage> {
  int storePoints = 0;
  List<dynamic> history = [];
  bool isLoading = true;
  String? _accessToken;

  Future<void> _loadAccessToken() async {
    try {
      final token = await getAccessToken();
      setState(() {
        _accessToken = token;
      });
      await fetchStorePoints();
      await fetchHistory();
    } catch (e) {
      print('Error loading access token or user data: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _loadAccessToken();
  }

  Future<void> fetchStorePoints() async {
    final apiUrl = 'http://127.0.0.1:3001/api/user-poin/${widget.storeId}';
    final token = _accessToken;

    try {
      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          storePoints = (data['data']['points'] as num).toInt();
        });
      } else {
        throw Exception('Failed to load store points');
      }
    } catch (e) {
      print('Error fetching store points: $e');
    }
  }

  Future<void> fetchHistory() async {
    final apiUrl = 'http://127.0.0.1:3001/api/poin-history/${widget.storeId}';
    final token = _accessToken;

    try {
      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          history = data['data'];
          isLoading = false;
        });
      } else {
        throw Exception('Failed to load history');
      }
    } catch (e) {
      print('Error fetching history: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.storeName, style: TextStyle(color: Colors.white)),
        backgroundColor: Color(0xFF31394E),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Store Info & Points
                Container(
                  width: double.infinity,
                  margin: EdgeInsets.all(16),
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Color(0xFFC58189),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      if (widget.storeLogo != null)
                        CircleAvatar(
                          backgroundImage: NetworkImage(widget.storeLogo!),
                          radius: 40,
                        ),
                      SizedBox(height: 10),
                      Text(
                        'Total Points di ${widget.storeName}',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                      SizedBox(height: 5),
                      Text(
                        storePoints.toString(),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 10),
                      ElevatedButton.icon(
                        onPressed: () {
                          // Navigate to Store Details
                          context.push('/store/${widget.storeId}');
                        },
                        icon: Icon(Icons.store, color: Colors.white),
                        label: Text('Visit Store',
                            style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black87,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Transaction History
                Expanded(
                  child: history.isEmpty
                      ? Center(child: Text('No history available'))
                      : ListView.builder(
                          itemCount: history.length,
                          itemBuilder: (context, index) {
                            final item = history[index];
                            final points = item['poin_used'];
                            final purpose = item['purpose'];
                            final createdAt =
                                DateTime.parse(item['created_at']);

                            return Card(
                              margin: EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              child: ListTile(
                                title: Text(
                                  purpose,
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Text(
                                  '${createdAt.day}-${createdAt.month}-${createdAt.year} ${createdAt.hour}:${createdAt.minute}',
                                  style: TextStyle(color: Colors.grey),
                                ),
                                trailing: Text(
                                  '${points > 0 ? '+' : ''}$points',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color:
                                        points > 0 ? Colors.green : Colors.red,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
