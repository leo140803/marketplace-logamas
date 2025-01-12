import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:marketplace_logamas/api/firebase_api.dart';
import 'package:marketplace_logamas/screen/Barcode.dart';
import 'package:marketplace_logamas/screen/Cart.dart';
import 'package:marketplace_logamas/screen/CheckoutPage.dart';
import 'package:marketplace_logamas/screen/ConfirmationScreen.dart';
import 'package:marketplace_logamas/screen/EditProfile.dart';
import 'package:marketplace_logamas/screen/FAQ.dart';
import 'package:marketplace_logamas/screen/Home.dart';
import 'package:marketplace_logamas/screen/LocationScreen.dart';
import 'package:marketplace_logamas/screen/LoginPage.dart';
import 'package:marketplace_logamas/screen/MenuScreen.dart';
import 'package:marketplace_logamas/screen/Order.dart';
import 'package:marketplace_logamas/screen/PaymentSuccessScreen.dart';
import 'package:marketplace_logamas/screen/ProductDetail.dart';
import 'package:marketplace_logamas/screen/RegisterScreen.dart';
import 'package:marketplace_logamas/screen/Search.dart';
import 'package:marketplace_logamas/screen/SearchResult.dart';
import 'package:marketplace_logamas/screen/StorePage.dart';

final navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isAndroid) {
    print('Running on Android');
    await Firebase.initializeApp();
    await FirebaseApi().initNotifications();
  }

  runApp(MaterialApp.router(routerConfig: router));
}

final router = GoRouter(
  // '/store/72574284-33f6-4ca8-a725-f00df1a62291',
  initialLocation: '/home',
  navigatorKey: navigatorKey,
  debugLogDiagnostics: true,
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => HomePageWidget(),
      routes: [
        GoRoute(
          path: 'login',
          builder: (context, state) => LoginPage(),
        ),
        GoRoute(
          path: '/search',
          builder: (context, state) => SearchPage(),
        ),
        GoRoute(
          path: '/search-result',
          builder: (context, state) {
            final extra =
                state.extra as Map<String, dynamic>?;
            final query =
                extra?['query'] as String? ?? '';
            return SearchResultPage(query: query);
          },
        ),
        GoRoute(
          path: '/product-detail/:productId', // Path dengan parameter productId
          builder: (context, state) {
            // Ambil productId dari path parameter
            final productId = state.pathParameters['productId'];
            if (productId == null || productId.isEmpty) {
              return const Scaffold(
                body: Center(
                    child: Text(
                        'Product ID is missing')), // Error handling jika productId tidak ada
              );
            }
            return ProductDetailPage(
                productId: productId); // Navigasi ke ProductDetailPage
          },
        ),
        GoRoute(
          path: 'register',
          builder: (context, state) => RegisterScreen(),
        ),
        GoRoute(
          path: 'information',
          builder: (context, state) => MenuScreen(),
        ),
        GoRoute(
          path: 'order',
          name: 'order',
          builder: (context, state) => OrdersPage(),
        ),
        GoRoute(
          path: 'myQR',
          name: 'myQR',
          builder: (context, state) => BarcodePage(),
        ),
        GoRoute(
          path: 'faq',
          name: 'faq',
          builder: (context, state) => FAQPage(),
        ),
        GoRoute(
          path: 'edit-profile',
          builder: (context, state) => const EditProfileScreen(),
        ),
        GoRoute(
          path: 'cart',
          builder: (context, state) => CartPage(),
        ),
        GoRoute(
          path: 'home',
          builder: (context, state) => HomePageWidget(),
        ),
        GoRoute(
          path: 'nearby',
          builder: (context, state) => LocationScreen(),
        ),
        GoRoute(
          path: 'store/:storeId', // Tambahkan parameter :storeId di path
          builder: (context, state) {
            final storeId = state
                .pathParameters['storeId']; // Ambil storeId dari path parameter
            if (storeId == null || storeId.isEmpty) {
              return const Scaffold(
                body: Center(child: Text("Store ID must be provided!")),
              );
            }
            return StorePage(
                storeId:
                    storeId); // Navigasi ke StorePage dengan ID yang diambil
          },
        ),
        GoRoute(
          path: '/checkout',
          builder: (context, state) {
            final checkoutData = state.extra as Map<String, dynamic>?;
            if (checkoutData == null) {
              return const Center(
                  child: Text("Checkout data must be provided!"));
            }
            return CheckoutPage(cartData: checkoutData);
          },
        ),
        GoRoute(
          path: '/payment_success',
          builder: (context, state) {
            final orderId = state.uri.queryParameters['order_id'];
            if (orderId == null || orderId.isEmpty) {
              return const Center(child: Text("Order ID must be provided!"));
            }
            return PaymentSuccessScreen(orderId: orderId);
          },
        ),
        GoRoute(
          path: 'confirmation',
          builder: (context, state) {
            final email = state.uri.queryParameters['email'] ?? 'Unknown';
            return ConfirmationScreen(email: email);
          },
        ),
      ],
    ),
  ],
  redirect: (context, state) {
    print('Incoming URL: ${state.uri}');

    if (state.uri.path.startsWith('/deeplink-website')) {
      final newPath = state.uri.path.replaceFirst('/deeplink-website', '');
      print('Redirecting to: $newPath');
      return newPath;
    }

    final uriString = state.uri.toString();
    if (uriString.startsWith('marketplace-logamas://')) {
      final parse = uriString
          .replaceFirst('marketplace-logamas://', '')
          .replaceAll("/", "");
      final newUri = Uri.parse(parse);
      final path = newUri.path;
      final queryParams = newUri.queryParameters;

      print('Redirecting to: /$path with params: $queryParams');

      final redirectPath = Uri(
        path: '/$path',
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      ).toString();

      return redirectPath;
    }

    return null;
  },
);
