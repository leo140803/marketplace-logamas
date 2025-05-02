import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:marketplace_logamas/function/app_color.dart';
import 'package:shimmer/shimmer.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:intl/intl.dart';

import 'package:marketplace_logamas/function/Utils.dart';

class StorePointsPage extends StatefulWidget {
  final String storeId;
  final String storeName;
  final String? storeLogo;

  const StorePointsPage({
    Key? key,
    required this.storeId,
    required this.storeName,
    this.storeLogo,
  }) : super(key: key);

  @override
  _StorePointsPageState createState() => _StorePointsPageState();
}

class _StorePointsPageState extends State<StorePointsPage>
    with SingleTickerProviderStateMixin {
  int storePoints = 0;
  List<dynamic> history = [];
  bool isLoading = true;
  bool hasError = false;
  String errorMessage = '';
  String? _accessToken;

  final RefreshController _refreshController =
      RefreshController(initialRefresh: false);

  // Initialize animation controller and animation as late variables
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    // Initialize animation controller here with the correct vsync
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    // Initialize animation
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadData();
      }
    });
  }

  @override
  void dispose() {
    _refreshController.dispose();
    _animationController.dispose();
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
      await _fetchAllData();
    } catch (e) {
      _handleError('Unable to authenticate. Please log in again.', e);
    }
  }

  Future<void> _fetchAllData() async {
    try {
      // Fetch both points and history in parallel
      await Future.wait([
        fetchStorePoints(),
        fetchHistory(),
      ]);
    } catch (e) {
      _handleError('Error loading data', e);
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

  Future<void> fetchStorePoints() async {
    if (_accessToken == null) {
      _handleError(
          'Authentication failed. Please login again.', 'No access token');
      return;
    }

    final apiUrl = '$apiBaseUrl/user-poin/${widget.storeId}';

    try {
      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {'Authorization': 'Bearer $_accessToken'},
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          storePoints = (data['data']['points'] as num? ?? 0).toInt();
        });
      } else if (response.statusCode == 401) {
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

  Future<void> fetchHistory() async {
    if (_accessToken == null) return;

    final apiUrl = '$apiBaseUrl/poin-history/${widget.storeId}';

    try {
      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {'Authorization': 'Bearer $_accessToken'},
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          history = data['data'] ?? [];
          isLoading = false;
          hasError = false;
        });
      } else if (response.statusCode == 401) {
        _handleError('Session expired. Please login again.',
            'Status code: ${response.statusCode}');
      } else {
        _handleError('Unable to load history (${response.statusCode})',
            'API error: ${response.body}');
      }
    } catch (e) {
      _handleError('Network error. Please check your connection.', e);
    }
  }

  void _onRefresh() async {
    await _fetchAllData();
    _refreshController.refreshCompleted();
  }

  String _formatDateTime(String dateTimeStr) {
    try {
      final dateTime = DateTime.parse(dateTimeStr);
      return DateFormat('dd MMM yyyy, HH:mm').format(dateTime);
    } catch (e) {
      return 'Invalid date';
    }
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
        title: Text(
          widget.storeName,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => context.pop(),
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
              child: _buildStoreInfoCard(),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              sliver: SliverToBoxAdapter(
                child: const Text(
                  'Transaction History',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            history.isEmpty
                ? SliverFillRemaining(
                    child: _buildEmptyHistory(),
                  )
                : SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _buildHistoryItem(history[index]),
                      childCount: history.length,
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
              height: 200,
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Container(
                    width: 150,
                    height: 24,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
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
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 60, color: Colors.red[300]),
          const SizedBox(height: 16),
          Text(
            'Oops! Something went wrong',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              setState(() {
                isLoading = true;
                hasError = false;
              });
              _loadData();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildStoreInfoCard() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
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
          const SizedBox(height: 20),
          Hero(
            tag: 'store_logo_${widget.storeId}',
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(40),
                child: widget.storeLogo != null
                    ? CachedNetworkImage(
                        imageUrl: widget.storeLogo!,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => const Center(
                          child: SizedBox(
                            width: 30,
                            height: 30,
                            child: CircularProgressIndicator(
                              color: Colors.white54,
                              strokeWidth: 2,
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => const Icon(
                          Icons.store,
                          color: Colors.white70,
                          size: 40,
                        ),
                      )
                    : const Icon(
                        Icons.store,
                        color: Colors.white70,
                        size: 40,
                      ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Your Points at ${widget.storeName}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.stars,
                color: Colors.amber[300],
                size: 28,
              ),
              const SizedBox(width: 8),
              Text(
                storePoints.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'points',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: () {
                      // Navigate to Store Details
                      context.push('/store/${widget.storeId}');
                    },
                    icon: const Icon(
                      Icons.store,
                      color: Colors.white,
                    ),
                    label: const Text(
                      'Visit Store',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.black45,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildEmptyHistory() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history,
            size: 70,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No Transaction History',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Complete a transaction at ${widget.storeName} to start earning points!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryItem(dynamic item) {
    final points = item['poin_used'] as num? ?? 0;
    final purpose = item['purpose'] as String? ?? 'Unknown Transaction';
    final createdAt = item['created_at'] as String? ?? '';
    final formattedDate = _formatDateTime(createdAt);
    final isEarned = points > 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            // Show more details in a modal bottom sheet
            _showTransactionDetails(item);
          },
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                // Transaction icon
                Container(
                  width: 45,
                  height: 45,
                  decoration: BoxDecoration(
                    color: isEarned
                        ? Colors.green.withOpacity(0.1)
                        : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Icon(
                    isEarned ? Icons.add_circle : Icons.remove_circle,
                    color: isEarned ? Colors.green : Colors.red,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                // Transaction details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        purpose,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        formattedDate,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                // Points
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isEarned
                        ? Colors.green.withOpacity(0.1)
                        : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isEarned ? '+$points pts' : '$points pts',
                    style: TextStyle(
                      color: isEarned ? Colors.green[700] : Colors.red[700],
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showTransactionDetails(dynamic transaction) {
    final points = transaction['poin_used'] as num? ?? 0;
    final purpose = transaction['purpose'] as String? ?? 'Unknown Transaction';
    final createdAt = transaction['created_at'] as String? ?? '';
    final formattedDate = _formatDateTime(createdAt);
    final isEarned = points > 0;
    final transactionId = transaction['id'] ?? 'Unknown ID';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 16),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Transaction Details',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
            ),
            const Divider(height: 32),
            // Transaction icon and type
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: isEarned
                          ? Colors.green.withOpacity(0.1)
                          : Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: Icon(
                      isEarned ? Icons.add_circle : Icons.remove_circle,
                      color: isEarned ? Colors.green : Colors.red,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isEarned ? 'Points Earned' : 'Points Used',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        formattedDate,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isEarned
                          ? Colors.green.withOpacity(0.1)
                          : Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isEarned ? '+$points pts' : '$points pts',
                      style: TextStyle(
                        color: isEarned ? Colors.green[700] : Colors.red[700],
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Transaction details
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _detailItem('Transaction ID', '#$transactionId'),
                  const SizedBox(height: 16),
                  _detailItem('Store', widget.storeName),
                  const SizedBox(height: 16),
                  _detailItem('Purpose', purpose),
                  const SizedBox(height: 16),
                  _detailItem('Date & Time', formattedDate),
                ],
              ),
            ),
            const Spacer(),
            // Close button
            Padding(
              padding: const EdgeInsets.all(20),
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Close',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
