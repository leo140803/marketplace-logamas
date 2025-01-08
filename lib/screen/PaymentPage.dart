import 'dart:async';

import 'package:flutter/material.dart';
import 'package:marketplace_logamas/screen/PaymentSuccessScreen.dart';
// import 'package:uni_links/uni_links.dart';
import 'package:webview_flutter/webview_flutter.dart';

class PaymentWebView extends StatefulWidget {
  final String url;

  const PaymentWebView({Key? key, required this.url}) : super(key: key);

  @override
  State<PaymentWebView> createState() => _PaymentWebViewState();
}

class _PaymentWebViewState extends State<PaymentWebView> {
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Payment',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        automaticallyImplyLeading: false,
        backgroundColor: Color(0xFF31394E),
      ),
      body: WebViewWidget(
        controller: WebViewController()
          ..loadRequest(Uri.parse(widget.url))
          ..setJavaScriptMode(JavaScriptMode.unrestricted),
      ),
    );
  }
}
