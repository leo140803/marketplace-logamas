import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:marketplace_logamas/api/firebase_api.dart';
import 'package:marketplace_logamas/screen/Barcode.dart';
import 'package:marketplace_logamas/screen/Cart.dart';
import 'package:marketplace_logamas/screen/ChangePasswordScreen.dart';
import 'package:marketplace_logamas/screen/ChatScreen.dart';
import 'package:marketplace_logamas/screen/CheckoutPage.dart';
import 'package:marketplace_logamas/screen/ConfirmationScreen.dart';
import 'package:marketplace_logamas/screen/Conversation.dart';
import 'package:marketplace_logamas/screen/EditProfile.dart';
import 'package:marketplace_logamas/screen/FAQ.dart';
import 'package:marketplace_logamas/screen/ForgotPass.dart';
import 'package:marketplace_logamas/screen/Home.dart';
import 'package:marketplace_logamas/screen/LocationScreen.dart';
import 'package:marketplace_logamas/screen/LoginPage.dart';
import 'package:marketplace_logamas/screen/MenuScreen.dart';
import 'package:marketplace_logamas/screen/NearbyStore.dart';
import 'package:marketplace_logamas/screen/NotFoundPage.dart';
import 'package:marketplace_logamas/screen/Order.dart';
import 'package:marketplace_logamas/screen/OrderDetail.dart';
import 'package:marketplace_logamas/screen/PaymentFailed.dart';
import 'package:marketplace_logamas/screen/PaymentSuccessScreen.dart';
import 'package:marketplace_logamas/screen/ProductCodeDetail.dart';
import 'package:marketplace_logamas/screen/ProductDetail.dart';
import 'package:marketplace_logamas/screen/RegisterScreen.dart';
import 'package:marketplace_logamas/screen/ResetPassword.dart';
import 'package:marketplace_logamas/screen/Sales.dart';
import 'package:marketplace_logamas/screen/SalesDetail.dart';
import 'package:marketplace_logamas/screen/ScanQRPage.dart';
import 'package:marketplace_logamas/screen/Search.dart';
import 'package:marketplace_logamas/screen/SearchResult.dart';
import 'package:marketplace_logamas/screen/StorePage.dart';
import 'package:marketplace_logamas/screen/TnC.dart';
import 'package:marketplace_logamas/screen/Trade.dart';
import 'package:marketplace_logamas/screen/TradeDetail.dart';
import 'package:marketplace_logamas/screen/UserPoinPage.dart';
import 'package:marketplace_logamas/screen/UserStorePoinPage.dart';
import 'package:marketplace_logamas/screen/Welcome.dart';
import 'package:marketplace_logamas/screen/WishlistPage.dart';

final navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  print(Platform);
  if (!kIsWeb) {
    // Hanya berjalan di Android/iOS
    if (Platform.isAndroid) {
      print('Running on Android');
      await Firebase.initializeApp();
      await FirebaseApi().initNotifications();
    }
  } else {
    print('Running on Web');
  }

  runApp(MaterialApp.router(
    routerConfig: router,
    debugShowCheckedModeBanner: false,
  ));
}

final router = GoRouter(
  // '/store/72574284-33f6-4ca8-a725-f00df1a62291',
  initialLocation: '/tnc',
  navigatorKey: navigatorKey,
  debugLogDiagnostics: true,
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => WelcomeScreen(),
      routes: [
        GoRoute(
          path: 'landing',
          builder: (context, state) => WelcomeScreen(),
        ),
        GoRoute(
          path: 'login',
          builder: (context, state) => LoginPage(),
        ),
        GoRoute(
          path: 'detail/:transactionId',
          builder: (context, state) {
            final transactionId = state.pathParameters['transactionId']!;
            return OrderDetailsPage(transactionId: transactionId);
          },
        ),
        GoRoute(
          path: 'salesd/:transactionId',
          builder: (context, state) {
            final transactionId = state.pathParameters['transactionId']!;
            return SalesDetailsPage(transactionId: transactionId);
          },
        ),
        GoRoute(
          path: '/scan',
          builder: (context, state) => const ScanQRPage(),
        ),
        GoRoute(
          path: 'traded/:transactionId',
          builder: (context, state) {
            final transactionId = state.pathParameters['transactionId']!;
            return TradeDetailsPage(transactionId: transactionId);
          },
        ),

        GoRoute(
          path: '/search',
          builder: (context, state) => SearchPage(),
        ),
        GoRoute(
          path: '/forgot-password',
          builder: (context, state) => ForgotPasswordPage(),
        ),
        GoRoute(
          path: 'wishlist',
          builder: (context, state) => WishlistPage(),
        ),
        GoRoute(
          path: '/search-result',
          builder: (context, state) {
            final extra = state.extra as Map<String, dynamic>?;
            final query = extra?['query'] as String? ?? '';
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
          path: 'tnc',
          builder: (context, state) => TermsConditionsPage(),
        ),
        GoRoute(
          path: 'order',
          name: 'order',
          builder: (context, state) => OrdersPage(),
        ),
        GoRoute(
          path: 'sell',
          name: 'sell',
          builder: (context, state) => SalesPage(),
        ),
        GoRoute(
          path: 'trade',
          name: 'trade',
          builder: (context, state) => TradePage(),
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
          path: '/nearby-stores',
          builder: (context, state) {
            final stores = state.extra as List<Map<String, dynamic>>;
            return NearbyStoresPage(stores: stores);
          },
        ),

        GoRoute(
          path: 'my-poin',
          builder: (context, state) => UserPointsPage(),
        ),
        GoRoute(
          path: '/email_verified',
          builder: (context, state) => EmailVerifiedPage(),
        ),
        GoRoute(
          path: '/store-points/:storeId',
          builder: (context, state) {
            final storeId = state.pathParameters['storeId'];
            final extra = state.extra as Map<String, dynamic>?;

            if (storeId == null || storeId.isEmpty) {
              return const Scaffold(
                body: Center(child: Text("Store ID must be provided!")),
              );
            }

            final storeName = extra?['storeName'] ?? 'Unknown Store';
            final storeLogo = extra?['storeLogo'];

            return StorePointsPage(
              storeId: storeId,
              storeName: storeName,
              storeLogo: storeLogo,
            );
          },
        ),

        // Tambahkan ini ke router Anda
        GoRoute(
          path: '/change-password',
          name: 'changePassword',
          builder: (context, state) => ChangePasswordScreen(),
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
          path: '/payment_failed',
          builder: (context, state) {
            final orderId = state.uri.queryParameters['order_id'] ?? '';
            final status =
                state.uri.queryParameters['status'] ?? 'Pembayaran Gagal';

            return PaymentFailedPage(
              orderId: orderId,
              status: status,
            );
          },
        ),
        GoRoute(
          path: '/reset-password',
          builder: (context, state) {
            // Ambil parameter `email` dan `token` dari query parameters
            final email = state.uri.queryParameters['email'] ?? '';
            final token = state.uri.queryParameters['token'] ?? '';

            if (email.isEmpty || token.isEmpty) {
              return const Scaffold(
                body: Center(child: Text("Invalid reset password link")),
              );
            }

            return ResetPasswordPage(
              email: email,
              token: token,
            );
          },
        ),
        GoRoute(
          path: 'confirmation',
          builder: (context, state) {
            final email = state.uri.queryParameters['email'] ?? 'Unknown';
            return ConfirmationScreen(email: email);
          },
        ),
        GoRoute(
          path: '/product-code-detail',
          builder: (context, state) {
            final barcode = state.uri.queryParameters['barcode']!;
            return ProductCodeDetailPage(barcode: barcode);
          },
        ),
        GoRoute(
          path: '/chat/:storeId',
          builder: (context, state) {
            final storeId = state.pathParameters['storeId']!;
            final extra = state.extra as Map<String, dynamic>?;

            return ChatScreen(
              storeId: storeId,
              storeName: extra?['storeName'] ?? 'Store',
              storeLogo: extra?['storeLogo'],
            );
          },
        ),
        GoRoute(
          path: '/conversations',
          builder: (context, state) => ConversationListScreen(),
        ),

        GoRoute(
          path: '/chat/:storeId',
          builder: (context, state) {
            final storeId = state.pathParameters['storeId']!;
            final extra = state.extra as Map<String, dynamic>?;

            return ChatScreen(
              storeId: storeId,
              storeName: extra?['storeName'] ?? 'Store',
              storeLogo: extra?['storeLogo'],
            );
          },
        ),
      ],
    ),
  ],

  errorBuilder: (context, state) => NotFoundPage(),
  redirect: (context, state) {
    final uri = state.uri;
    final uriString = uri.toString();
    print('Incoming URL: ${uri.path}');
    if (uri.path == '/scan') return null;

    if (state.uri.path.startsWith('/deeplink-website')) {
      final newPath = state.uri.path.replaceFirst('/deeplink-website', '');
      print('Redirecting to: $newPath');
      return newPath;
    }

    // final uriString = state.uri.toString();
    if (state.uri
        .toString()
        .startsWith('marketplace-logamas://reset-password')) {
      // Tangkap path dan query parameters dari deeplink

      final token = state.uri.queryParameters['token'];
      final email = state.uri.queryParameters['email'];
      print(state.uri.queryParameters);
      // Pastikan email dan token tersedia
      if (email != null && token != null) {
        return '/reset-password?email=$email&token=$token';
      }

      return '/reset-password?error=missing_parameters';
    }
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
