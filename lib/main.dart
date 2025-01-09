import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:marketplace_logamas/api/firebase_api.dart';
import 'package:marketplace_logamas/screen/PaymentSuccessScreen.dart';
import 'package:marketplace_logamas/screen/StorePage.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:marketplace_logamas/screen/Cart.dart';
import 'package:marketplace_logamas/screen/CheckoutPage.dart';
import 'package:marketplace_logamas/screen/ConfirmationScreen.dart';
// import 'package:marketplace_logamas/screen/FAQPage.dart';
import 'package:marketplace_logamas/screen/Home.dart';
import 'package:marketplace_logamas/screen/LocationScreen.dart';
import 'package:marketplace_logamas/screen/LoginPage.dart';
import 'package:marketplace_logamas/screen/RegisterScreen.dart';
// import 'package:deeplink2/screen/WelcomeScreen.dart';
// import 'package:deeplink2/screen/PaymentSuccessScreen.dart';

final navigatorKey = GlobalKey<NavigatorState>();
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Cek apakah platform adalah Android
  if (Platform.isAndroid) {
    print('android');
    await Firebase.initializeApp();
    await FirebaseApi().initNotifications();
  }

  runApp(MaterialApp.router(routerConfig: router));
}

/// This handles '/' and '/details'.
final router = GoRouter(
  navigatorKey: navigatorKey,
  debugLogDiagnostics: true,
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => LoginPage(
          // storeId: '72574284-33f6-4ca8-a725-f00df1a62291',
          ),
      routes: [
        // GoRoute(
        //   path: 'landing',
        //   builder: (context, state) => WelcomeScreen(),
        // ),
        GoRoute(
          path: 'login',
          builder: (context, state) => LoginPage(),
        ),
        GoRoute(
          path: 'register',
          builder: (context, state) => RegisterScreen(),
        ),
        GoRoute(
          path: 'home',
          builder: (context, state) => HomePageWidget(),
        ),
        GoRoute(
          path: 'email_verified',
          builder: (context, state) => EmailVerifiedPage(),
        ),
        GoRoute(
          path: 'cart',
          builder: (context, state) => CartPage(),
        ),
        GoRoute(
          path: 'nearby',
          builder: (context, state) => LocationScreen(),
        ),
        GoRoute(
          path: '/checkout',
          builder: (context, state) {
            // Extract checkoutData using `state.extra`
            final checkoutData = state.extra as Map<String, dynamic>?;
            if (checkoutData == null) {
              return Center(child: Text("Car Data must passing!"));
            }
            return CheckoutPage(cartData: checkoutData);
          },
        ),
        GoRoute(
          path: '/payment_success',
          builder: (context, state) {
            final orderId = state.uri.queryParameters['order_id'];
            if (orderId == null || orderId.isEmpty) {
              return Center(child: Text("Order ID must passing!"));
            }
            return PaymentSuccessScreen(orderId: orderId);
          },
        ),

        // GoRoute(
        //   path: 'confirmation',
        //   builder: (context, state) {
        //     final email = state.queryParameters['email'] ?? 'Unknown';
        //     return ConfirmationScreen(email: email);
        //   },
        // ),
        GoRoute(
          path: 'store',
          builder: (context, state) {
            // Extract storeId from state.extra
            final storeId = (state.extra as Map<String, dynamic>?)?['storeId'];
            if (storeId == null || storeId.isEmpty) {
              return Center(
                child: Text("Store ID must be provided!"),
              );
            }
            return StorePage(storeId: storeId);
          },
        ),

        // GoRoute(
        //   path: 'payment-success',
        //   builder: (context, state) {
        //     final orderId = state.queryParameters['order_id'] ?? 'Unknown';
        //     return PaymentSuccessScreen(orderId: orderId);
        //   },
        // ),
      ],
    ),
  ],
  redirect: (context, state) {
    // Log URL yang diterima
    print('Incoming URL: ${state.uri}');

    // Periksa jika URL memiliki prefix '/deeplink-website'
    if (state.uri.path.startsWith('/deeplink-website')) {
      // Buang '/deeplink-website' dari path dan arahkan ulang
      final newPath = state.uri.path.replaceFirst('/deeplink-website', '');
      print('Redirecting to: $newPath');
      return newPath;
    }

    // Periksa skema 'marketplace://'
    final uriString = state.uri.toString();
    if (uriString.startsWith('marketplace-logamas://')) {
      // Ubah 'marketplace-logamas://' menjadi path yang valid
      var parse = uriString
          .replaceFirst('marketplace-logamas://', '')
          .replaceAll("/", "");
      final newUri = Uri.parse(parse);
      final path = newUri.path; // path seperti 'payment_success'
      final queryParams = newUri.queryParameters; // Ambil query parameters

      print('Redirecting to: /$path dengan params: $queryParams');

      // Bangun kembali path dengan parameter query jika ada
      final redirectPath = Uri(
        path: '/$path',
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      ).toString();

      return redirectPath;
    }

    // Jika tidak ada perubahan, biarkan navigasi berjalan seperti biasa
    return null;
  },
);
