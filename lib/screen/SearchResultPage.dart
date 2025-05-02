import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:marketplace_logamas/function/Utils.dart';
import 'package:google_fonts/google_fonts.dart';

class SearchResultPage extends StatefulWidget {
  final List<Map<String, dynamic>> searchResults;

  const SearchResultPage({Key? key, required this.searchResults})
      : super(key: key);

  @override
  State<SearchResultPage> createState() => _SearchResultPageState();
}

class _SearchResultPageState extends State<SearchResultPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  List<Map<String, dynamic>> sortedResults = [];
  String _currentSortMethod = 'alphabetical'; // Default sort method

  @override
  void initState() {
    super.initState();

    // Sort results initially
    _sortResults();

    // Setup animation
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _sortResults() {
    sortedResults = List.from(widget.searchResults);

    switch (_currentSortMethod) {
      case 'alphabetical':
        sortedResults.sort((a, b) => (a['store_name'] ?? '')
            .toLowerCase()
            .compareTo((b['store_name'] ?? '').toLowerCase()));
        break;
      case 'location':
        // Assuming there might be a distance field in the future
        // For now, just keeping alphabetical as fallback
        sortedResults.sort((a, b) => (a['store_name'] ?? '')
            .toLowerCase()
            .compareTo((b['store_name'] ?? '').toLowerCase()));
        break;
      case 'rating':
        // Assuming there might be a rating field in the future
        // For now, just keeping alphabetical as fallback
        sortedResults.sort((a, b) => (a['store_name'] ?? '')
            .toLowerCase()
            .compareTo((b['store_name'] ?? '').toLowerCase()));
        break;
    }

    setState(() {});
  }

  void _showSortOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 50,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Sort By',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF31394E),
                ),
              ),
              const SizedBox(height: 16),
              _buildSortOption(
                title: 'Alphabetical (A-Z)',
                icon: Icons.sort_by_alpha,
                method: 'alphabetical',
              ),
              _buildSortOption(
                title: 'Location',
                icon: Icons.location_on_outlined,
                method: 'location',
              ),
              _buildSortOption(
                title: 'Rating',
                icon: Icons.star_outline,
                method: 'rating',
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSortOption({
    required String title,
    required IconData icon,
    required String method,
  }) {
    final isSelected = _currentSortMethod == method;

    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? const Color(0xFFC58189) : Colors.grey[600],
        size: 22,
      ),
      title: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? const Color(0xFFC58189) : Colors.black87,
        ),
      ),
      trailing: isSelected
          ? const Icon(
              Icons.check_circle,
              color: Color(0xFFC58189),
              size: 22,
            )
          : null,
      onTap: () {
        setState(() {
          _currentSortMethod = method;
        });
        _sortResults();
        Navigator.pop(context);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/images/appbar.png'),
              fit: BoxFit.cover,
            ),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Hasil Pencarian',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: widget.searchResults.isEmpty
            ? _buildEmptyState()
            : _buildSearchResults(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(70),
            ),
            child: Icon(
              Icons.search_off_rounded,
              size: 70,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Tidak ada toko yang ditemukan',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Coba gunakan kata kunci lain atau periksa koneksi Anda.',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey.shade500,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 30),
          ElevatedButton.icon(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.arrow_back),
            label: Text(
              'Kembali',
              style: GoogleFonts.poppins(),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF31394E),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Results count and sort info
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Ditemukan ${widget.searchResults.length} toko',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
        ),

        // Store list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            physics: const BouncingScrollPhysics(),
            itemCount: sortedResults.length,
            itemBuilder: (context, index) {
              final toko = sortedResults[index];
              return StoreCard(
                toko: toko,
                onTap: () {
                  if (toko['store_id'] != null) {
                    context.push('/store/${toko['store_id']}');
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          "Store ID is missing!",
                          style: GoogleFonts.poppins(),
                        ),
                        backgroundColor: Colors.red,
                        behavior: SnackBarBehavior.floating,
                        margin: const EdgeInsets.all(16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    );
                  }
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class StoreCard extends StatelessWidget {
  final Map<String, dynamic> toko;
  final VoidCallback onTap;

  const StoreCard({
    Key? key,
    required this.toko,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Store image/logo
                  Hero(
                    tag: 'store-${toko['store_id']}',
                    child: Container(
                      width: 85,
                      height: 85,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.grey.shade200,
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: toko['logo'] != null && toko['logo'].isNotEmpty
                            ? Image.network(
                                '$apiBaseUrlImage${toko["logo"]}',
                                fit: BoxFit.cover,
                                loadingBuilder:
                                    (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Container(
                                    color: Colors.grey[200],
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        value: loadingProgress
                                                    .expectedTotalBytes !=
                                                null
                                            ? loadingProgress
                                                    .cumulativeBytesLoaded /
                                                (loadingProgress
                                                        .expectedTotalBytes ??
                                                    1)
                                            : null,
                                        strokeWidth: 2,
                                        valueColor:
                                            const AlwaysStoppedAnimation<Color>(
                                          Color(0xFFC58189),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: Colors.grey[200],
                                    child: const Icon(
                                      Icons.store,
                                      size: 32,
                                      color: Colors.grey,
                                    ),
                                  );
                                },
                              )
                            : Container(
                                color: Colors.grey[200],
                                child: const Icon(
                                  Icons.store,
                                  size: 32,
                                  color: Colors.grey,
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Store information
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          toko['store_name'] ?? 'Unknown Store',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF31394E),
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (toko['address'] != null &&
                            toko['address'].isNotEmpty)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.location_on_outlined,
                                size: 16,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  toko['address'],
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    color: Colors.grey[600],
                                    height: 1.3,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        const SizedBox(height: 8),
                        if (toko['information'] != null &&
                            toko['information'].isNotEmpty)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 16,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  toko['information'],
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    color: Colors.grey[600],
                                    height: 1.3,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // View Store button
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFBE9E7).withOpacity(0.3),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Center(
                child: Text(
                  'Lihat Toko',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFFC58189),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
