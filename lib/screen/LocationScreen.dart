import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:marketplace_logamas/function/Utils.dart';
import 'package:marketplace_logamas/screen/NearbyStore.dart';
import 'package:marketplace_logamas/screen/SearchResultPage.dart';
import 'package:marketplace_logamas/widget/BottomNavigationBar.dart';
import 'package:marketplace_logamas/widget/Dialog.dart';
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'package:shimmer/shimmer.dart';
import 'package:cached_network_image/cached_network_image.dart';

class LocationScreen extends StatefulWidget {
  const LocationScreen({Key? key}) : super(key: key);

  @override
  _LocationScreenState createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen>
    with SingleTickerProviderStateMixin {
  double? _latitude;
  double? _longitude;
  List<Map<String, dynamic>> _tokoDalamRadius = [];
  int _selectedIndex = 1;
  bool _isLoading = true;
  bool _locationEnabled = true;
  bool _locationPermissionGranted = true;
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  late AnimationController _animationController;
  bool _showStoreList = false;
  String _errorMessage = '';

  // Theme colors
  final Color primaryColor = const Color(0xFFC58189);
  final Color secondaryColor = const Color(0xFF31394E);
  final Color backgroundColor = Colors.white;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _initializeLocation();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    navigate(context, index);
  }

  Future<void> _fetchTokoData() async {
    try {
      final response = await http.get(Uri.parse('$apiBaseUrl/store'));
      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        final List<dynamic> data = jsonResponse['data'];

        List<Map<String, dynamic>> tokoList = [];

        for (var item in data) {
          double tokoLat = item['latitude']?.toDouble() ?? 0.0;
          double tokoLon = item['longitude']?.toDouble() ?? 0.0;
          double distance = 0.0;

          // Calculate distance only if user location is available
          if (_latitude != null && _longitude != null) {
            distance = _haversine(_latitude!, _longitude!, tokoLat, tokoLon);
          }

          tokoList.add({
            "store_id": item['store_id'],
            "nama": item['store_name'],
            "lat": tokoLat,
            "lon": tokoLon,
            "distance": distance,
            "logo": item['logo'],
            "address": item['address'],
          });
        }

        tokoList.sort((a, b) => a["distance"].compareTo(b["distance"]));

        setState(() {
          _tokoDalamRadius = tokoList;
        });
      } else {
        setState(() {
          _errorMessage = "Failed to fetch stores: ${response.statusCode}";
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Error fetching store data";
      });
    }
  }

  Future<List<Map<String, dynamic>>> searchStores(String query) async {
    final url = Uri.parse('$apiBaseUrl/store/search?q=$query');
    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body) as Map<String, dynamic>;

        if (jsonResponse['success'] == true) {
          return List<Map<String, dynamic>>.from(jsonResponse['data']);
        } else {
          throw Exception(jsonResponse['message'] ?? 'Search failed.');
        }
      } else {
        throw Exception('Failed to fetch stores: ${response.statusCode}');
      }
    } catch (error) {
      throw Exception('Error fetching search results');
    }
  }

  void _initializeLocation() async {
    try {
      await _getCurrentLocation();
      await _fetchTokoData();
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        if (e.toString().contains('Location services are disabled')) {
          _locationEnabled = false;
        } else if (e.toString().contains('Permission denied')) {
          _locationPermissionGranted = false;
        }
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Check if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        _locationEnabled = false;
      });
      return Future.error('Location services are disabled.');
    }

    // Check location permissions
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() {
          _locationPermissionGranted = false;
        });
        return Future.error('Location permission denied.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() {
        _locationPermissionGranted = false;
      });
      return Future.error('Location permissions are permanently denied.');
    }

    // Get current position
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
      });
    } catch (e) {
      return Future.error('Failed to get current location: $e');
    }
  }

  double _haversine(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371;
    final dLat = _degToRad(lat2 - lat1);
    final dLon = _degToRad(lon2 - lon1);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degToRad(lat1)) *
            math.cos(_degToRad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return R * c;
  }

  double _degToRad(double deg) {
    return deg * (math.pi / 180);
  }

  void _goToMyLocation() {
    if (_latitude != null && _longitude != null) {
      // Use the standard move method instead of animatedMove
      _mapController.move(LatLng(_latitude!, _longitude!), 15);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Centering to your location'),
          backgroundColor: secondaryColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          action: SnackBarAction(
            label: 'OK',
            textColor: Colors.white,
            onPressed: () {},
          ),
        ),
      );
    } else {
      _showLocationErrorSnackbar();
    }
  }

  void _showLocationErrorSnackbar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          !_locationEnabled
              ? 'Location services are disabled. Please enable them in settings.'
              : !_locationPermissionGranted
                  ? 'Location permission denied. Please enable in app settings.'
                  : 'Could not get your location. Please try again.',
        ),
        backgroundColor: Colors.red[700],
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        action: SnackBarAction(
          label: 'Settings',
          textColor: Colors.white,
          onPressed: () {
            Geolocator.openLocationSettings();
          },
        ),
      ),
    );
  }

  TileLayer get openStreetMapLayer => TileLayer(
        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
        userAgentPackageName: 'dev.fleatflet.fluter_map.example',
        subdomains: const ['a', 'b', 'c'],
      );

  void _showTokoDetails(Map<String, dynamic> toko) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          child: Container(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Store Logo with Hero animation
                Hero(
                  tag: 'store-logo-${toko['store_id']}',
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: toko['logo'] != null && toko['logo'].isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: "$apiBaseUrlImage${toko['logo']}",
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Center(
                                child: CircularProgressIndicator(
                                  color: primaryColor,
                                  strokeWidth: 2,
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                color: Colors.grey[200],
                                child: const Icon(Icons.store,
                                    size: 50, color: Colors.grey),
                              ),
                            )
                          : Container(
                              color: Colors.grey[200],
                              child: const Icon(Icons.store,
                                  size: 50, color: Colors.grey),
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Store Name
                Text(
                  toko['nama'] ?? "Unknown Store",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF31394E),
                  ),
                ),
                const SizedBox(height: 8),

                // Address
                if (toko['address'] != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.location_on, color: primaryColor, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            toko['address'],
                            textAlign: TextAlign.start,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black54,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),

                // Distance with badge
                if (toko.containsKey('distance'))
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: _getDistanceBadgeColor(toko['distance'])
                          .withOpacity(0.1),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: _getDistanceBadgeColor(toko['distance'])
                            .withOpacity(0.5),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.directions_car,
                          size: 16,
                          color: _getDistanceBadgeColor(toko['distance']),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          "${toko['distance'].toStringAsFixed(1)} km away",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: _getDistanceBadgeColor(toko['distance']),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 24),

                // Action Buttons
                Row(
                  children: [
                    // "Open in Maps" Button
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          _openGoogleMaps(toko['lat'], toko['lon']);
                        },
                        icon:
                            const Icon(Icons.map_outlined, color: Colors.white),
                        label: const Text(
                          "Directions",
                          style: TextStyle(color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF31394E),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // "Visit Store" Button
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          context.push('/store/${toko['store_id']}');
                        },
                        icon: const Icon(Icons.store, color: Colors.white),
                        label: const Text(
                          'Visit Store',
                          style: TextStyle(color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _getDistanceBadgeColor(double distance) {
    if (distance <= 2) {
      return Colors.green;
    } else if (distance <= 5) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  void _openGoogleMaps(double lat, double lon) async {
    final url = 'http://maps.google.com/maps?z=12&t=m&q=loc:$lat+$lon';
    await launchUrl(Uri.parse(url));
    if (await canLaunchUrl(Uri.parse(url))) {
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open Google Maps')),
      );
    }
  }

  void _toggleStoreList() {
    setState(() {
      _showStoreList = !_showStoreList;
    });

    if (_showStoreList) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildBody(),
      bottomNavigationBar: BottomNavBar(
        selectedIndex: _selectedIndex,
        onItemTapped: _onItemTapped,
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return _buildLoadingState();
    }

    if (_errorMessage.isNotEmpty && _tokoDalamRadius.isEmpty) {
      return _buildErrorState();
    }

    return Stack(
      children: [
        // Map
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _latitude != null && _longitude != null
                ? LatLng(_latitude!, _longitude!)
                : const LatLng(
                    -6.2088, 106.8456), // Default to Jakarta if no location
            initialZoom: 13,
            onTap: (_, __) {
              // Close store list if open
              if (_showStoreList) {
                _toggleStoreList();
              }
            },
          ),
          children: [
            openStreetMapLayer,
            MarkerLayer(
              markers: [
                if (_latitude != null && _longitude != null)
                  Marker(
                    point: LatLng(_latitude!, _longitude!),
                    width: 60,
                    height: 60,
                    child: _buildUserLocationMarker(),
                  ),
                ..._tokoDalamRadius.map(
                  (toko) => Marker(
                    point: LatLng(toko['lat'], toko['lon']),
                    width: 50,
                    height: 50,
                    child: GestureDetector(
                      onTap: () => _showTokoDetails(toko),
                      child: _buildStoreMarker(toko),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),

        // Search Bar and Nearby Button
        Positioned(
          top: MediaQuery.of(context).padding.top + 10,
          left: 16,
          right: 16,
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search for stores...',
                        hintStyle: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                        prefixIcon: Icon(Icons.search, color: primaryColor),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      onSubmitted: (value) async {
                        if (value.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Please enter a search term')),
                          );
                          return;
                        }

                        try {
                          // Show loading indicator
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Searching...'),
                              duration: Duration(seconds: 1),
                            ),
                          );

                          // Call search API
                          List<Map<String, dynamic>> results =
                              await searchStores(value);

                          // Clear the search field
                          _searchController.clear();

                          // Navigate to results page
                          if (mounted) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => SearchResultPage(
                                  searchResults: results,
                                ),
                              ),
                            );
                          }
                        } catch (error) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content:
                                    Text('Search failed: ${error.toString()}'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      context.push(
                        '/nearby-stores',
                        extra: _tokoDalamRadius,
                      );
                    },
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: secondaryColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.storefront_outlined,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    tooltip: 'Nearby Stores',
                  ),
                ],
              ),
            ),
          ),
        ),

        // Action Buttons (Bottom Right)
        Positioned(
          bottom: 20,
          right: 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // List stores button
              FloatingActionButton(
                heroTag: 'listButton',
                backgroundColor: _showStoreList ? primaryColor : Colors.white,
                onPressed: _toggleStoreList,
                elevation: 2,
                child: Icon(
                  _showStoreList ? Icons.list_alt : Icons.format_list_bulleted,
                  color: _showStoreList ? Colors.white : secondaryColor,
                ),
              ),
              const SizedBox(height: 12),
              // My location button
              FloatingActionButton(
                heroTag: 'locationButton',
                backgroundColor: Colors.white,
                onPressed: _goToMyLocation,
                elevation: 2,
                child: Icon(
                  Icons.my_location,
                  color: secondaryColor,
                ),
              ),
            ],
          ),
        ),

        // Store list panel (animated)
        AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: MediaQuery.of(context).size.height *
                  0.4 *
                  _animationController.value,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                  child: Column(
                    children: [
                      // Handle
                      Container(
                        width: 50,
                        height: 5,
                        margin: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      // Title
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: [
                            const Text(
                              'Nearby Stores',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Spacer(),
                            TextButton.icon(
                              onPressed: () {
                                context.push(
                                  '/nearby-stores',
                                  extra: _tokoDalamRadius,
                                );
                              },
                              icon: const Icon(Icons.arrow_forward, size: 16),
                              label: const Text('View All'),
                              style: TextButton.styleFrom(
                                foregroundColor: primaryColor,
                                padding: EdgeInsets.zero,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(),
                      // List
                      Expanded(
                        child: _tokoDalamRadius.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    Icon(
                                      Icons.store_mall_directory_outlined,
                                      size: 50,
                                      color: Colors.grey,
                                    ),
                                    SizedBox(height: 16),
                                    Text(
                                      'No stores found nearby',
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                itemCount: _tokoDalamRadius.length > 10
                                    ? 10
                                    : _tokoDalamRadius.length,
                                itemBuilder: (context, index) {
                                  final store = _tokoDalamRadius[index];
                                  return _buildStoreListItem(store);
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildUserLocationMarker() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 6,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: primaryColor,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
        ),
      ),
    );
  }

  Widget _buildStoreMarker(Map<String, dynamic> store) {
    return Stack(
      children: [
        const Icon(
          Icons.location_on,
          color: Color(0xFF31394E),
          size: 40,
        ),
        Positioned(
          top: 8,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF31394E), width: 1),
              ),
              child: Center(
                child: store['logo'] != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          '$apiBaseUrlImage${store['logo']}',
                          width: 12,
                          height: 12,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(),
                        ),
                      )
                    : Container(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStoreListItem(Map<String, dynamic> store) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      elevation: 2,
      child: InkWell(
        onTap: () => _showTokoDetails(store),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Store logo
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: store['logo'] != null
                    ? CachedNetworkImage(
                        imageUrl: '$apiBaseUrlImage${store['logo']}',
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          width: 50,
                          height: 50,
                          color: Colors.grey[200],
                          child: const Icon(Icons.store, color: Colors.grey),
                        ),
                      )
                    : Container(
                        width: 50,
                        height: 50,
                        color: Colors.grey[200],
                        child: const Icon(Icons.store, color: Colors.grey),
                      ),
              ),
              const SizedBox(width: 12),
              // Store info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Store name
                    Text(
                      store['nama'] ?? 'Unknown Store',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    // Store address (shortened)
                    Text(
                      store['address'] ?? 'No address',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Distance badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getDistanceBadgeColor(store['distance'])
                      .withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _getDistanceBadgeColor(store['distance'])
                        .withOpacity(0.3),
                  ),
                ),
                child: Text(
                  "${store['distance'].toStringAsFixed(1)} km",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _getDistanceBadgeColor(store['distance']),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 100,
            height: 100,
            child: CircularProgressIndicator(
              color: primaryColor,
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Finding nearby stores...',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'We are locating you and searching for stores in your area',
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

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              !_locationEnabled
                  ? Icons.location_off
                  : !_locationPermissionGranted
                      ? Icons.location_disabled
                      : Icons.error_outline,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 24),
            Text(
              !_locationEnabled
                  ? 'Location Services Disabled'
                  : !_locationPermissionGranted
                      ? 'Location Permission Denied'
                      : 'Could Not Find Your Location',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              !_locationEnabled
                  ? 'Please enable location services in your device settings to find stores near you.'
                  : !_locationPermissionGranted
                      ? 'This app needs location permission to show you nearby stores.'
                      : 'We couldn\'t determine your current location. $_errorMessage',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                if (!_locationEnabled) {
                  Geolocator.openLocationSettings();
                } else if (!_locationPermissionGranted) {
                  Geolocator.openAppSettings();
                } else {
                  setState(() {
                    _isLoading = true;
                    _errorMessage = '';
                  });
                  _initializeLocation();
                }
              },
              icon: Icon(
                !_locationEnabled
                    ? Icons.settings
                    : !_locationPermissionGranted
                        ? Icons.app_settings_alt
                        : Icons.refresh,
                color: Colors.white,
              ),
              label: Text(
                !_locationEnabled
                    ? 'Open Settings'
                    : !_locationPermissionGranted
                        ? 'Open App Settings'
                        : 'Try Again',
                style: const TextStyle(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                // Load store list anyway, without filtering by distance
                _fetchTokoData();
                setState(() {
                  _errorMessage = '';
                  _isLoading = false;
                });
              },
              child: const Text(
                'Show All Stores Anyway',
                style: TextStyle(
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
