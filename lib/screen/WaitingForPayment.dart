import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:marketplace_logamas/screen/PaymentSuccessScreen.dart';
// import 'package:uni_links/uni_links.dart';
import 'package:http/http.dart' as http;

class WaitingForPaymentPage extends StatefulWidget {
  final String orderId;

  const WaitingForPaymentPage({Key? key, required this.orderId})
      : super(key: key);

  @override
  State<WaitingForPaymentPage> createState() => _WaitingForPaymentPageState();
}

class _WaitingForPaymentPageState extends State<WaitingForPaymentPage> {
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _cancelTransaction(String orderId) async {
    const String midtransUrl = "https://api.sandbox.midtrans.com/v2";
    const String midtransServerKey =
        "U0ItTWlkLXNlcnZlci1Rc1pJYjdkT01FUm1QMmdpWi1KZjhmMnE=";

    try {
      final response = await http.post(
        Uri.parse("$midtransUrl/$orderId/cancel"),
        headers: {
          'Authorization': 'Basic $midtransServerKey',
          'Content-Type': 'application/json',
        },
      );
      final responseData= jsonDecode(response.body);
      print(jsonDecode(response.body));
      if (responseData['status_code'] == '200' || responseData['status_code'] == '404') {
        final data = jsonDecode(response.body);
        print("Transaction canceled successfully: $data");

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Transaction canceled successfully!')),
        );

        // Navigate back to the previous screen
        Navigator.pop(context);
      } else {
        print("Failed to cancel transaction: ${response.body}");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to cancel transaction.')),
        );
      }
    } catch (error) {
      print("Error canceling transaction: $error");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error canceling transaction.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Waiting for Payment'),
        backgroundColor: Color(0xFF31394E),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text(
              'Waiting for payment confirmation...',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // Handle cancellation or back action
                _cancelTransaction(widget.orderId);
              },
              child: Text('Cancel Payment'),
            ),
          ],
        ),
      ),
    );
  }
}
