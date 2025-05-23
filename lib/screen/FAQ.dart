import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:marketplace_logamas/function/Utils.dart';
import 'package:marketplace_logamas/function/app_color.dart';
import 'package:marketplace_logamas/widget/BottomNavigationBar.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shimmer/shimmer.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';

class FAQPage extends StatefulWidget {
  const FAQPage({Key? key}) : super(key: key);

  @override
  _FAQPageState createState() => _FAQPageState();
}

class _FAQPageState extends State<FAQPage> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> faqList = [];
  List<Map<String, dynamic>> filteredFaqList = [];
  bool isLoading = true;
  bool hasError = false;
  String errorMessage = '';
  String _waNumber = '';
  int _selectedIndex = 3;
  final TextEditingController _searchController = TextEditingController();
  final RefreshController _refreshController =
      RefreshController(initialRefresh: false);

  // Animation controllers
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Track expanded FAQ items
  int? expandedIndex;

  // Track current search query
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();

    // Initialize animations
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    // Load data
    _loadData();

    // Add listener to search controller
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animationController.dispose();
    _refreshController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
      _filterFaqList();
    });
  }

  void _filterFaqList() {
    if (_searchQuery.isEmpty) {
      filteredFaqList = List.from(faqList);
    } else {
      filteredFaqList = faqList.where((faq) {
        final question = faq['question'].toString().toLowerCase();
        final answer = faq['answer'].toString().toLowerCase();
        return question.contains(_searchQuery) || answer.contains(_searchQuery);
      }).toList();
    }
  }

  Future<void> _loadData() async {
    setState(() {
      isLoading = true;
      hasError = false;
    });

    try {
      // Load data in parallel
      await Future.wait([
        _fetchWANumber(),
        _fetchFAQData(),
      ]);

      if (mounted) {
        _animationController.forward();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          hasError = true;
          errorMessage = 'Failed to load data. Please try again.';
          isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchWANumber() async {
    final url = Uri.parse('$apiBaseUrlPlatform/api/config/key?key=wa_number');
    try {
      final response = await http.get(url);
      if (!mounted) return;

      print(json.decode(response.body));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success']) {
          setState(() {
            _waNumber = data['data']['value'];
          });
        }
      }
    } catch (error) {
      print("Failed to fetch WhatsApp number: $error");
      // We don't want to show an error just for the WhatsApp number
      // So we just log it and continue
    }
  }

  Future<void> _fetchFAQData() async {
    final url = '$apiBaseUrlPlatform/api/faq/type/1';
    try {
      final response = await http.get(Uri.parse(url));
      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> faqData = data['data'] ?? [];

        setState(() {
          faqList = List<Map<String, dynamic>>.from(
            faqData.map((item) => {
                  'faq_id': item['faq_id'],
                  'question': item['question'],
                  'answer': item['answer'],
                  'type': item['type'],
                  'created_at': item['created_at'],
                  'updated_at': item['updated_at'],
                }),
          );
          _filterFaqList();
          isLoading = false;
          hasError = false;
        });
      } else {
        setState(() {
          errorMessage =
              'Failed to load FAQs. Server responded with error ${response.statusCode}.';
          hasError = true;
          isLoading = false;
        });
      }
    } catch (error) {
      setState(() {
        errorMessage =
            'Network error. Please check your connection and try again.';
        hasError = true;
        isLoading = false;
      });
    }
  }

  void _onRefresh() async {
    await _loadData();
    _refreshController.refreshCompleted();
  }

  Future<void> _openWhatsApp() async {
    if (_waNumber.isEmpty) {
      _showErrorDialog(
          "WhatsApp number is not available. Please try again later.");
      return;
    }

    String phoneNumber = _waNumber.trim();

    // Remove any '+' at the beginning if present
    if (phoneNumber.startsWith('+')) {
      phoneNumber = phoneNumber.substring(1);
    }

    // Make sure it starts with country code
    if (!phoneNumber.startsWith("62")) {
      phoneNumber = "62$phoneNumber";
    }

    final Uri whatsappUrl = Uri.parse("https://wa.me/$phoneNumber");

    try {
      await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
      // if (await canLaunchUrl(whatsappUrl)) {

      // } else {
      //   _showErrorDialog(
      //       "Failed to open WhatsApp. Please make sure WhatsApp is installed on your device.");
      // }
    } catch (e) {
      _showErrorDialog("Failed to open WhatsApp. Please try again.");
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red),
            SizedBox(width: 10),
            Text("Error"),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text("OK"),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  void _showContactSupportDialog() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              "Contact Support",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 20),
            Text(
              "Couldn't find your answer in the FAQs? Contact our support team directly through WhatsApp for personalized assistance.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
            SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                _openWhatsApp();
              },
              icon: Icon(Icons.phone, color: Colors.white),
              label: Text(
                "Chat with Support",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF25D366), // WhatsApp green
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                minimumSize: Size(double.infinity, 50),
              ),
            ),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    navigate(context, index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: _showContactSupportDialog,
        child: Icon(Icons.headset_mic, color: Colors.white),
        backgroundColor: AppColors.primary,
        tooltip: "Contact Support",
      ),
      backgroundColor: Color(0xFFF4F4F4),
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

  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 60.0,
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
          "FAQ",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios, color: Colors.white, size: 22),
        onPressed: () => context.go('/information'),
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

    if (faqList.isEmpty) {
      return _buildEmptyState();
    }

    if (filteredFaqList.isEmpty && _searchQuery.isNotEmpty) {
      return _buildNoSearchResults();
    }

    return SmartRefresher(
      controller: _refreshController,
      enablePullDown: true,
      header: WaterDropHeader(
        waterDropColor: AppColors.primary,
      ),
      onRefresh: _onRefresh,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: ListView.builder(
          padding: EdgeInsets.all(16.0),
          itemCount: filteredFaqList.length,
          itemBuilder: (context, index) {
            final faq = filteredFaqList[index];
            final isExpanded = expandedIndex == index;

            return Container(
              margin: EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 5,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Theme(
                data: Theme.of(context).copyWith(
                  dividerColor: Colors.transparent,
                ),
                child: ExpansionTile(
                  initiallyExpanded: isExpanded,
                  onExpansionChanged: (expanded) {
                    setState(() {
                      expandedIndex = expanded ? index : null;
                    });
                  },
                  tilePadding:
                      EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  childrenPadding: EdgeInsets.only(
                    left: 20,
                    right: 20,
                    bottom: 20,
                  ),
                  expandedCrossAxisAlignment: CrossAxisAlignment.start,
                  expandedAlignment: Alignment.centerLeft,
                  title: Text(
                    faq['question'],
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isExpanded ? AppColors.primary : Colors.black87,
                    ),
                  ),
                  iconColor: AppColors.primary,
                  collapsedIconColor: Colors.grey,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  children: [
                    Divider(
                      color: Colors.grey[300],
                      thickness: 1,
                    ),
                    SizedBox(height: 12),
                    Text(
                      faq['answer'],
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey[800],
                        height: 1.5,
                      ),
                      textAlign: TextAlign.left,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: ListView.builder(
        padding: EdgeInsets.all(16.0),
        itemCount: 6,
        itemBuilder: (context, index) {
          return Container(
            margin: EdgeInsets.only(bottom: 16),
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
          );
        },
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 60,
            color: Colors.red[300],
          ),
          SizedBox(height: 16),
          Text(
            'Oops! Something went wrong',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              setState(() {
                isLoading = true;
                hasError = false;
              });
              _loadData();
            },
            icon: Icon(Icons.refresh, color: Colors.white),
            label: Text(
              'Try Again',
              style: TextStyle(color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
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
          Icon(
            Icons.question_answer_outlined,
            size: 70,
            color: Colors.grey[400],
          ),
          SizedBox(height: 16),
          Text(
            'No FAQs Available',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'We\'re currently updating our FAQ section. Please check back later or contact support for assistance.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showContactSupportDialog,
            icon: Icon(Icons.headset_mic, color: Colors.white),
            label: Text(
              'Contact Support',
              style: TextStyle(color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoSearchResults() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 70,
            color: Colors.grey[400],
          ),
          SizedBox(height: 16),
          Text(
            'No Results Found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'We couldn\'t find any FAQs matching "$_searchQuery". Please try a different search term or contact support.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  _searchController.clear();
                },
                icon: Icon(Icons.clear, color: Colors.white),
                label: Text(
                  'Clear Search',
                  style: TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[700],
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _showContactSupportDialog,
                icon: Icon(Icons.headset_mic, color: Colors.white),
                label: Text(
                  'Get Help',
                  style: TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
