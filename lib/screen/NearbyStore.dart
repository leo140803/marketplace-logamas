import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:marketplace_logamas/function/Utils.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

class NearbyStoresPage extends StatefulWidget {
  final List<Map<String, dynamic>> stores;

  const NearbyStoresPage({Key? key, required this.stores}) : super(key: key);

  @override
  _NearbyStoresPageState createState() => _NearbyStoresPageState();
}

class _NearbyStoresPageState extends State<NearbyStoresPage>
    with SingleTickerProviderStateMixin {
  double? maxDistance = 10.0; // Default 10km filter on load
  List<Map<String, dynamic>> filteredStores = [];
  bool isFilterApplied = true; // Set to true since we're auto-filtering
  late AnimationController _animationController;
  Animation<double>? _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // Setup animation
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );

    // Apply initial filter with default 10km
    _applyFilter();

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _applyFilter() {
    setState(() {
      if (maxDistance == null) {
        filteredStores = List.from(widget.stores);
        isFilterApplied = false;
      } else {
        filteredStores = widget.stores
            .where((store) => store['distance'] <= maxDistance!)
            .toList();
        isFilterApplied = true;
      }

      // Sort by distance (closest first)
      filteredStores.sort((a, b) =>
          (a['distance'] as double).compareTo(b['distance'] as double));
    });
  }

  void _showFilterDrawer(BuildContext context) {
    double tempDistance = maxDistance ?? 10.0; // Default 10 km if null

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            return Container(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with drag handle and title
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(20)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          spreadRadius: 1,
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Drag handle
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
                        const SizedBox(height: 16),
                        // Header with title
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Set Distance Filter',
                                  style: GoogleFonts.poppins(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF31394E),
                                  ),
                                ),
                                if (isFilterApplied)
                                  Container(
                                    margin: const EdgeInsets.only(left: 8),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFC58189),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '1',
                                      style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            if (isFilterApplied)
                              TextButton(
                                onPressed: () {
                                  setStateModal(() {
                                    tempDistance = 10.0;
                                  });
                                },
                                child: Text(
                                  'Reset',
                                  style: GoogleFonts.poppins(
                                    color: const Color(0xFFC58189),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Current value display
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on_outlined,
                              color: Color(0xFF31394E),
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Maximum Distance',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF31394E),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Current value with indicator
                        Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 12, horizontal: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFBE9E7),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: const Color(0xFFC58189), width: 1),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${tempDistance.toStringAsFixed(1)} km',
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFFC58189),
                                ),
                              ),
                              const Icon(
                                Icons.my_location,
                                color: Color(0xFFC58189),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Slider section
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: const Color(0xFFC58189),
                            inactiveTrackColor: Colors.grey[300],
                            trackHeight: 6.0,
                            thumbColor: const Color(0xFFC58189),
                            thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 10.0),
                            overlayColor: const Color(0x66C58189),
                            overlayShape: const RoundSliderOverlayShape(
                                overlayRadius: 20.0),
                            tickMarkShape: const RoundSliderTickMarkShape(),
                            activeTickMarkColor: Colors.white,
                            inactiveTickMarkColor: Colors.grey[400],
                            valueIndicatorColor: const Color(0xFF31394E),
                            valueIndicatorTextStyle: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                          child: Slider(
                            value: tempDistance,
                            min: 1.0,
                            max: 50.0,
                            divisions: 49,
                            label: '${tempDistance.toStringAsFixed(1)} km',
                            onChanged: (value) {
                              setStateModal(() {
                                tempDistance = value;
                              });
                            },
                          ),
                        ),

                        // Min-max labels
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '1 km',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                              Text(
                                '50 km',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Apply button
                        Container(
                          width: double.infinity,
                          height: 55,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF31394E).withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() {
                                maxDistance = tempDistance;
                                _applyFilter();
                              });
                              Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                              backgroundColor: const Color(0xFF31394E),
                            ),
                            child: Center(
                              child: Text(
                                'Apply Filter',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
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
        title: Text(
          'Nearby Stores',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: Icon(
                    isFilterApplied
                        ? Icons.filter_alt
                        : Icons.filter_alt_outlined,
                    color: Colors.white,
                  ),
                  onPressed: () => _showFilterDrawer(context),
                ),
                if (isFilterApplied)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFC58189),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 10,
                        minHeight: 10,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation ?? const AlwaysStoppedAnimation(1.0),
        child: filteredStores.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.store_mall_directory,
                      size: 80,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No Nearby Stores Found',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40.0),
                      child: Text(
                        isFilterApplied
                            ? 'Try increasing your distance filter to see more stores.'
                            : 'There are no stores in your area. Please check again later.',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.grey.shade500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (isFilterApplied)
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            maxDistance = null;
                            _applyFilter();
                          });
                        },
                        icon: const Icon(Icons.refresh),
                        label: Text(
                          'Reset Filter',
                          style: GoogleFonts.poppins(),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF31394E),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                  ],
                ),
              )
            : Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 8, 4, 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Found ${filteredStores.length} ${filteredStores.length == 1 ? 'store' : 'stores'} nearby',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF31394E),
                            ),
                          ),
                          if (isFilterApplied)
                            Row(
                              children: [
                                const Icon(
                                  Icons.filter_list,
                                  size: 16,
                                  color: Color(0xFFC58189),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Within ${maxDistance?.toStringAsFixed(1)} km',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: const Color(0xFFC58189),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        itemCount: filteredStores.length,
                        itemBuilder: (context, index) {
                          final store = filteredStores[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12.0),
                            child: StoreCard(
                              store: store,
                              onTap: () {
                                context.push('/store/${store['store_id']}');
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class StoreCard extends StatelessWidget {
  final Map<String, dynamic> store;
  final VoidCallback onTap;

  const StoreCard({
    Key? key,
    required this.store,
    required this.onTap,
  }) : super(key: key);

  void _openGoogleMaps(BuildContext context, double lat, double lon) async {
    final url = 'http://maps.google.com/maps?z=12&t=m&q=loc:$lat+$lon';

    try {
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url));
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Could not open Google Maps',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: Colors.red[700],
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error launching maps: $e',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get latitude and longitude from the store data
    final double latitude = store['lat'] ?? 0.0;
    final double longitude = store['lon'] ?? 0.0;
    final bool hasCoordinates = latitude != 0.0 && longitude != 0.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.0),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Store logo
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.grey[300]!,
                        width: 1,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: store['logo'] != null
                          ? Image.network(
                              '$apiBaseUrlImage${store['logo']}',
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(
                                  Icons.store,
                                  size: 32,
                                  color: Colors.grey,
                                );
                              },
                            )
                          : const Icon(
                              Icons.store,
                              size: 32,
                              color: Colors.grey,
                            ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Store details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          store['nama'] ?? 'Unknown Store',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF31394E),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          store['address'] ?? 'No address',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: Colors.grey[700],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              size: 16,
                              color: const Color(0xFFC58189),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${store['distance']?.toStringAsFixed(2) ?? '0.0'} km away',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFFC58189),
                              ),
                            ),
                            if (hasCoordinates) ...[
                              const Spacer(),
                              InkWell(
                                onTap: () => _openGoogleMaps(
                                    context, latitude, longitude),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFC58189)
                                        .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.map_outlined,
                                        size: 14,
                                        color: const Color(0xFFC58189),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Maps',
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: const Color(0xFFC58189),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: onTap,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFBE9E7).withOpacity(0.3),
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(16),
                          bottomRight: hasCoordinates
                              ? Radius.zero
                              : Radius.circular(16),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          'View Store Details',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFFC58189),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // Google Maps button
                if (hasCoordinates)
                  InkWell(
                    onTap: () => _openGoogleMaps(context, latitude, longitude),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF31394E),
                        borderRadius: const BorderRadius.only(
                          bottomRight: Radius.circular(16),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.directions,
                            size: 16,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Directions',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
