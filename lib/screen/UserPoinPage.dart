import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:marketplace_logamas/function/app_color.dart';
import 'dart:convert';
import 'package:shimmer/shimmer.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';

import 'package:marketplace_logamas/function/Utils.dart';

class UserPointsPage extends StatefulWidget {
  const UserPointsPage({Key? key}) : super(key: key);

  @override
  _UserPointsPageState createState() => _UserPointsPageState();
}

class _UserPointsPageState extends State<UserPointsPage>
    with SingleTickerProviderStateMixin {
  List<dynamic> userPoints = [];
  bool isLoading = true;
  bool hasError = false;
  String errorMessage = '';
  int totalPoints = 0;
  String? _accessToken;
  final RefreshController _refreshController =
      RefreshController(initialRefresh: false);
  // Initialize animation controller and animation directly to avoid late initialization error
  late AnimationController _animationController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  );
  late Animation<double> _fadeAnimation =
      Tween<double>(begin: 0.0, end: 1.0).animate(
    CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
  );

  @override
  void initState() {
    super.initState();
    // No need to reinitialize here since we did it in the field declaration
    // Just start loading data after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadData();
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _refreshController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      await _loadAccessToken();
      if (!mounted) return;
      _animationController.forward();
    } catch (e) {
      _handleError('Failed to load data. Please try again.', e);
    }
  }

  Future<void> _loadAccessToken() async {
    try {
      final token = await getAccessToken();
      if (!mounted) return;
      setState(() {
        _accessToken = token;
      });
      await fetchUserPoints();
    } catch (e) {
      _handleError('Unable to authenticate. Please log in again.', e);
    }
  }

  void _handleError(String message, dynamic error) {
    print('Error: $message - $error');
    if (!mounted) return;
    setState(() {
      isLoading = false;
      hasError = true;
      errorMessage = message;
    });
  }

  Future<void> fetchUserPoints() async {
    if (_accessToken == null) {
      _handleError(
          'Authentication failed. Please login again.', 'No access token');
      return;
    }

    final apiUrl = '$apiBaseUrl/user-poin';

    try {
      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {'Authorization': 'Bearer $_accessToken'},
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          userPoints = data['data'] ?? [];
          totalPoints = userPoints.fold<int>(
            0,
            (sum, item) => sum + (item['points'] as num? ?? 0).toInt(),
          );
          isLoading = false;
          hasError = false;
        });
      } else if (response.statusCode == 401) {
        // Token expired or invalid
        _handleError('Session expired. Please login again.',
            'Status code: ${response.statusCode}');
      } else {
        _handleError('Unable to load points (${response.statusCode})',
            'API error: ${response.body}');
      }
    } catch (e) {
      _handleError('Network error. Please check your connection.', e);
    }
  }

  void _onRefresh() async {
    await fetchUserPoints();
    _refreshController.refreshCompleted();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            _buildAppBar(context),
          ];
        },
        body: _buildBody(),
      ),
    );
  }

  SliverAppBar _buildAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 40.0,
      floating: false,
      pinned: true,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/appbar.png',
              fit: BoxFit.cover,
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.4),
                    Colors.black.withOpacity(0.1),
                  ],
                ),
              ),
            ),
          ],
        ),
        title: const Text(
          'My Points',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      leading: GestureDetector(
        onTap: () => context.pop(),
        child: const Icon(
          Icons.arrow_back,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return _buildShimmerLoading();
    }

    if (hasError) {
      return _buildErrorWidget();
    }

    if (userPoints.isEmpty) {
      return _buildEmptyState();
    }

    return SmartRefresher(
      controller: _refreshController,
      enablePullDown: true,
      header: const WaterDropHeader(),
      onRefresh: _onRefresh,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _buildTotalPointsCard(),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              sliver: SliverToBoxAdapter(
                child: const Text(
                  'Your Points by Store',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.only(bottom: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildStoreCard(userPoints[index]),
                  childCount: userPoints.length,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              height: 100,
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            ...List.generate(
              5,
              (index) => Container(
                width: double.infinity,
                height: 80,
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_border, size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 10),
          Text(
            'No Points',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Make Transactions and Get your Points!',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.stars, size: 80, color: Colors.amber[300]),
          const SizedBox(height: 16),
          const Text(
            'No Points Yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Start earning points by completing transactions in our partner stores!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => context.push('/home'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Explore Product'),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalPointsCard() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Points',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                totalPoints.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              const Padding(
                padding: EdgeInsets.only(bottom: 6),
                child: Text(
                  'points',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                ),
              ),
              const Spacer(),
              const Icon(
                Icons.star,
                color: Colors.amber,
                size: 40,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStoreCard(dynamic item) {
    final store = item['store'] ?? {};
    final storeName = store['store_name'] ?? 'Unknown Store';
    final storeId = store['store_id'];
    final storeLogo =
        store['logo'] != null ? '$apiBaseUrlImage${store['logo']}' : null;
    final points = item['points'] ?? 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            if (storeId != null) {
              context.push(
                '/store-points/$storeId',
                extra: {
                  'storeName': storeName,
                  'storeLogo': storeLogo,
                  'points': points,
                },
              );
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Hero(
                  tag: 'store_logo_$storeId',
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.grey[100],
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          spreadRadius: 1,
                          blurRadius: 3,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(25),
                      child: storeLogo != null
                          ? CachedNetworkImage(
                              imageUrl: storeLogo,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => const Center(
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                              errorWidget: (context, url, error) => const Icon(
                                Icons.store,
                                color: Colors.grey,
                              ),
                            )
                          : const Icon(
                              Icons.store,
                              color: Colors.grey,
                              size: 24,
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        storeName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tap to view details',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.star,
                        color: AppColors.primary,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$points pts',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right,
                  color: Colors.grey[400],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
