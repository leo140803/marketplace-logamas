import 'package:flutter/material.dart';

class WaitingForPaymentPage extends StatefulWidget {
  final String orderId;

  const WaitingForPaymentPage({Key? key, required this.orderId})
      : super(key: key);

  @override
  State<WaitingForPaymentPage> createState() => _WaitingForPaymentPageState();
}

class _WaitingForPaymentPageState extends State<WaitingForPaymentPage> {
  @override
  void initState() {
    super.initState();
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
            Icon(
              Icons.payments_outlined,
              size: 80,
              color: Color(0xFF31394E),
            ),
            SizedBox(height: 20),
            Text(
              'Waiting for payment confirmation...',
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
