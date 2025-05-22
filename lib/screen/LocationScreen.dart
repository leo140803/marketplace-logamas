import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'dart:async';
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

  // Navigation related variables
  List<LatLng> _routePoints = [];
  bool _isNavigating = false;
  bool _isCalculatingRoute = false;
  Map<String, dynamic>? _destinationStore;
  StreamSubscription<Position>? _positionStream;
  List<String> _navigationInstructions = [];
  int _currentInstructionIndex = 0;
  double _totalDistance = 0;
  double _remainingDistance = 0;
  String _estimatedTime = '';
  double _currentHeading = 0;

  // Theme colors
  final Color primaryColor = const Color(0xFFC58189);
  final Color secondaryColor = const Color(0xFF31394E);
  final Color backgroundColor = Colors.white;

  // Default coordinates (Jakarta)
  static const double _defaultLat = -6.2088;
  static const double _defaultLon = 106.8456;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    // Add error handler for map controller
    FlutterError.onError = (FlutterErrorDetails details) {
      if (details.exception.toString().contains('Infinity or NaN toInt')) {
        debugPrint(
            'Map coordinate error caught and handled: ${details.exception}');
        // Reset to safe coordinates if this happens
        if (mounted) {
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted) {
              _safeMapMove(_getSafeCoordinates(), 13.0);
            }
          });
        }
      } else {
        FlutterError.presentError(details);
      }
    };

    _initializeLocation();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    _positionStream?.cancel();

    // Reset error handler
    FlutterError.onError = FlutterError.presentError;

    super.dispose();
  }

  // Helper method to validate coordinates
  bool _isValidCoordinate(double? value) {
    return value != null &&
        !value.isNaN &&
        value.isFinite &&
        value.abs() <= 180; // Basic range check for lat/lng
  }

  // Helper method to validate zoom level
  bool _isValidZoom(double? zoom) {
    return zoom != null &&
        !zoom.isNaN &&
        zoom.isFinite &&
        zoom >= 1 &&
        zoom <= 20;
  }

  // Helper method to get safe coordinates
  LatLng _getSafeCoordinates() {
    if (_isValidCoordinate(_latitude) && _isValidCoordinate(_longitude)) {
      return LatLng(_latitude!, _longitude!);
    }
    return const LatLng(_defaultLat, _defaultLon);
  }

  // Helper method to safely move map
  void _safeMapMove(LatLng center, double zoom) {
    if (!mounted) return;

    try {
      // Validate coordinates
      if (!_isValidCoordinate(center.latitude) ||
          !_isValidCoordinate(center.longitude)) {
        print(
            'Invalid coordinates for map move: ${center.latitude}, ${center.longitude}');
        return;
      }

      // Validate zoom
      if (!_isValidZoom(zoom)) {
        print('Invalid zoom level: $zoom');
        zoom = 13.0; // Use safe default
      }

      _mapController.move(center, zoom);
    } catch (e) {
      print('Error moving map: $e');
    }
  }

  // Helper method to safely fit camera
  void _safeFitCamera(LatLngBounds bounds,
      {EdgeInsets padding = const EdgeInsets.all(50)}) {
    if (!mounted) return;

    try {
      // Validate bounds
      if (!_isValidCoordinate(bounds.north) ||
          !_isValidCoordinate(bounds.south) ||
          !_isValidCoordinate(bounds.east) ||
          !_isValidCoordinate(bounds.west)) {
        print('Invalid bounds for camera fit');
        return;
      }

      // Check if bounds are reasonable
      if (bounds.north <= bounds.south || bounds.east <= bounds.west) {
        print('Invalid bounds dimensions');
        return;
      }

      _mapController
          .fitCamera(CameraFit.bounds(bounds: bounds, padding: padding));
    } catch (e) {
      print('Error fitting camera: $e');
    }
  }

  // Helper method to safely format distance
  String _formatDistance(double distance) {
    if (!_isValidCoordinate(distance) || distance < 0) {
      return '0.0';
    }
    return distance.toStringAsFixed(1);
  }

  // Helper method to safely update coordinates
  void _updateCoordinates(double lat, double lon, {double? heading}) {
    if (_isValidCoordinate(lat) && _isValidCoordinate(lon)) {
      setState(() {
        _latitude = lat;
        _longitude = lon;
        if (heading != null && _isValidCoordinate(heading)) {
          _currentHeading = heading;
        }
      });
    } else {
      print('Warning: Invalid coordinates received: lat=$lat, lon=$lon');
    }
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

          // Validate store coordinates before processing
          if (!_isValidCoordinate(tokoLat) || !_isValidCoordinate(tokoLon)) {
            continue; // Skip invalid store coordinates
          }

          if (_isValidCoordinate(_latitude) && _isValidCoordinate(_longitude)) {
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

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        _locationEnabled = false;
      });
      return Future.error('Location services are disabled.');
    }

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

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      _updateCoordinates(position.latitude, position.longitude,
          heading: position.heading);
    } catch (e) {
      return Future.error('Failed to get current location: $e');
    }
  }

  // Navigation Functions
  Future<void> _calculateRoute(double destLat, double destLon) async {
    if (!_isValidCoordinate(_latitude) || !_isValidCoordinate(_longitude)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Invalid current location for route calculation')),
      );
      return;
    }

    if (!_isValidCoordinate(destLat) || !_isValidCoordinate(destLon)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid destination coordinates')),
      );
      return;
    }

    setState(() {
      _isCalculatingRoute = true;
    });

    try {
      // Using OpenRouteService (free API)
      final apiKey = '5b3ce3597851110001cf62489cbeaa660b1444fe9d07890be7bae821';
      final url = Uri.parse(
        'https://api.openrouteservice.org/v2/directions/driving-car?'
        'api_key=$apiKey&'
        'start=${_longitude!},${_latitude!}&'
        'end=$destLon,$destLat&'
        'format=geojson&'
        'instructions=true',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        final coordinates =
            data['features'][0]['geometry']['coordinates'] as List;
        final properties = data['features'][0]['properties'];

        List<LatLng> routePoints = [];
        for (var coord in coordinates) {
          if (coord != null && coord.length >= 2) {
            double lat = coord[1]?.toDouble() ?? 0.0;
            double lon = coord[0]?.toDouble() ?? 0.0;
            if (_isValidCoordinate(lat) && _isValidCoordinate(lon)) {
              routePoints.add(LatLng(lat, lon));
            }
          }
        }

        // Only proceed if we have valid route points
        if (routePoints.isEmpty) {
          throw Exception('No valid route points received');
        }

        List<String> instructions = [];
        if (properties['segments'] != null &&
            properties['segments'].isNotEmpty) {
          final steps = properties['segments'][0]['steps'] as List;
          instructions =
              steps.map((step) => step['instruction'].toString()).toList();
        }

        setState(() {
          _routePoints = routePoints;
          _navigationInstructions = instructions;
          final distance = properties['summary']['distance'];
          _totalDistance = _isValidCoordinate(distance?.toDouble())
              ? (distance / 1000)
              : 0.0;
          _remainingDistance = _totalDistance;
          final duration = properties['summary']['duration'];
          _estimatedTime = _isValidCoordinate(duration?.toDouble())
              ? _formatDuration(duration)
              : '0m';
          _currentInstructionIndex = 0;
        });
      } else {
        throw Exception('Failed to calculate route');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Route calculation failed: ${e.toString()}')),
        );
      }
    } finally {
      setState(() {
        _isCalculatingRoute = false;
      });
    }
  }

  void _startNavigation(Map<String, dynamic> store) async {
    if (!_isValidCoordinate(store['lat']) ||
        !_isValidCoordinate(store['lon'])) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid store coordinates')),
      );
      return;
    }

    _destinationStore = store;
    await _calculateRoute(store['lat'], store['lon']);

    if (_routePoints.isNotEmpty) {
      setState(() {
        _isNavigating = true;
      });

      // Start real-time location tracking
      _startLocationTracking();

      // Fit map to show route
      _fitMapToRoute();
    }
  }

  void _startLocationTracking() {
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 1,
    );

    _positionStream = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) {
      // Validate position before updating
      if (_isValidCoordinate(position.latitude) &&
          _isValidCoordinate(position.longitude)) {
        _updateCoordinates(position.latitude, position.longitude,
            heading: position.heading);

        // Update navigation progress
        _updateNavigationProgress();

        // Center map on user location during navigation
        if (_isNavigating && mounted) {
          try {
            _mapController.move(
              LatLng(position.latitude, position.longitude),
              17,
            );
          } catch (e) {
            print('Error moving map: $e');
          }
        }
      } else {
        print(
            'Invalid position received: ${position.latitude}, ${position.longitude}');
      }
    }, onError: (error) {
      print('Location stream error: $error');
    });
  }

  void _updateNavigationProgress() {
    if (_destinationStore == null ||
        !_isValidCoordinate(_latitude) ||
        !_isValidCoordinate(_longitude) ||
        !_isValidCoordinate(_destinationStore!['lat']) ||
        !_isValidCoordinate(_destinationStore!['lon'])) {
      return;
    }

    // Calculate remaining distance to destination
    double distanceToDestination = _haversine(
      _latitude!,
      _longitude!,
      _destinationStore!['lat'],
      _destinationStore!['lon'],
    );

    // Validate the calculated distance
    if (!_isValidCoordinate(distanceToDestination) ||
        distanceToDestination < 0) {
      return; // Skip update if distance is invalid
    }

    setState(() {
      _remainingDistance = distanceToDestination;
    });

    // Check if arrived (within 50 meters)
    if (distanceToDestination < 0.05) {
      _arriveAtDestination();
    }
  }

  void _arriveAtDestination() {
    if (!mounted) return;

    // Add haptic feedback
    HapticFeedback.heavyImpact();

    // Stop navigation immediately to prevent further updates
    _stopNavigation();

    // Show celebration animation after a brief delay
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        _showArrivalCelebration();
      }
    });
  }

  void _showArrivalCelebration() {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.7),
      transitionDuration: const Duration(milliseconds: 600),
      pageBuilder: (context, animation, secondaryAnimation) {
        return _buildCelebrationDialog(animation);
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.elasticOut,
          )),
          child: child,
        );
      },
    );
    // setState(() {
    //   _destinationStore= null;
    // });
  }

  Widget _buildCelebrationDialog(Animation<double> animation) {
    return Center(
      child: Material(
        type: MaterialType.transparency,
        child: Container(
          margin: const EdgeInsets.all(20),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Confetti particles
              ...List.generate(15, (index) {
                return AnimatedBuilder(
                  animation: animation,
                  builder: (context, child) {
                    // Fix: Ensure delay never exceeds 0.8 to stay within bounds
                    final delay = (index * 0.05).clamp(0.0, 0.8);
                    final particleAnimation = Tween<double>(
                      begin: 0,
                      end: 1,
                    ).animate(CurvedAnimation(
                      parent: animation,
                      curve: Interval(delay, 1.0, curve: Curves.easeOut),
                    ));

                    return _buildConfettiParticle(
                      particleAnimation,
                      index,
                      MediaQuery.of(context).size,
                    );
                  },
                );
              }),

              // Main dialog card
              ScaleTransition(
                scale: Tween<double>(begin: 0.3, end: 1.0).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.elasticOut,
                  ),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.green[400]!,
                        Colors.green[600]!,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(30),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Animated success icon
                      RotationTransition(
                        turns: Tween<double>(begin: 0, end: 1).animate(
                          CurvedAnimation(
                            parent: animation,
                            curve: const Interval(0.2, 0.8,
                                curve: Curves.elasticOut),
                          ),
                        ),
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.navigation,
                            color: Colors.green,
                            size: 40,
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Animated title
                      SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.5),
                          end: Offset.zero,
                        ).animate(CurvedAnimation(
                          parent: animation,
                          curve:
                              const Interval(0.3, 1.0, curve: Curves.easeOut),
                        )),
                        child: const Text(
                          '🎉 Destination Reached!',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Store info with fade-in
                      FadeTransition(
                        opacity: Tween<double>(begin: 0, end: 1).animate(
                          CurvedAnimation(
                            parent: animation,
                            curve:
                                const Interval(0.5, 1.0, curve: Curves.easeIn),
                          ),
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(
                                'Welcome to',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white.withOpacity(0.9),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _destinationStore?['nama'] ??
                                    'Your Destination',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              if (_destinationStore?['address'] != null) ...[
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.location_on,
                                      size: 16,
                                      color: Colors.white.withOpacity(0.8),
                                    ),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        _destinationStore!['address'],
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.white.withOpacity(0.8),
                                        ),
                                        textAlign: TextAlign.center,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Action buttons with stagger animation
                      Row(
                        children: [
                          Expanded(
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(-1, 0),
                                end: Offset.zero,
                              ).animate(CurvedAnimation(
                                parent: animation,
                                curve: const Interval(0.6, 1.0,
                                    curve: Curves.easeOut),
                              )),
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.pop(context);
                                  if (_destinationStore != null) {
                                    context.push(
                                        '/store/${_destinationStore!['store_id']}');
                                  }
                                  setState(() {
                                    _destinationStore = null;
                                  });
                                },
                                icon: const Icon(Icons.store,
                                    color: Colors.green),
                                label: const Text(
                                  'Visit Store',
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(25),
                                  ),
                                  elevation: 0,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(1, 0),
                                end: Offset.zero,
                              ).animate(CurvedAnimation(
                                parent: animation,
                                curve: const Interval(0.7, 1.0,
                                    curve: Curves.easeOut),
                              )),
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.pop(context);
                                  setState(() {
                                    _destinationStore = null;
                                  });
                                },
                                icon: const Icon(Icons.check,
                                    color: Colors.white),
                                label: const Text(
                                  'Perfect!',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      Colors.white.withOpacity(0.2),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(25),
                                    side: BorderSide(
                                      color: Colors.white.withOpacity(0.5),
                                    ),
                                  ),
                                  elevation: 0,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConfettiParticle(
      Animation<double> animation, int index, Size screenSize) {
    final colors = [
      Colors.yellow,
      Colors.orange,
      Colors.pink,
      Colors.blue,
      Colors.purple,
      Colors.red,
      Colors.green,
    ];

    final random = math.Random(index);
    final color = colors[index % colors.length];
    final startX = random.nextDouble() * screenSize.width;
    final endX = startX + (random.nextDouble() - 0.5) * 200;
    final endY = screenSize.height * 0.8 + random.nextDouble() * 100;
    final isCircle = random.nextBool();

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final progress = animation.value;
        final x = startX + (endX - startX) * progress;
        final y = -50 + endY * progress * progress; // Parabolic fall
        final rotation = progress * 4 * math.pi;
        final opacity = (1 - progress).clamp(0.0, 1.0);

        return Positioned(
          left: x,
          top: y,
          child: Transform.rotate(
            angle: rotation,
            child: Opacity(
              opacity: opacity,
              child: Container(
                width: 8 + random.nextDouble() * 6,
                height: 8 + random.nextDouble() * 6,
                decoration: BoxDecoration(
                  color: color,
                  shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
                  borderRadius: isCircle ? null : BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _stopNavigation() {
    // Cancel location stream first
    _positionStream?.cancel();
    _positionStream = null;

    // Clear navigation state
    if (mounted) {
      setState(() {
        _isNavigating = false;
        _routePoints.clear();
        _navigationInstructions.clear();
        // _destinationStore = null;
        _currentInstructionIndex = 0;
        _totalDistance = 0;
        _remainingDistance = 0;
        _estimatedTime = '';

        // Ensure coordinates remain valid
        if (!_isValidCoordinate(_latitude)) {
          _latitude = _defaultLat;
        }
        if (!_isValidCoordinate(_longitude)) {
          _longitude = _defaultLon;
        }
      });
    }
  }

  void _fitMapToRoute() {
    if (_routePoints.isEmpty || !mounted) return;

    try {
      final bounds = LatLngBounds.fromPoints(_routePoints);
      _safeFitCamera(bounds, padding: const EdgeInsets.all(50));
    } catch (e) {
      print('Error fitting map to route: $e');
    }
  }

  String _formatDuration(double seconds) {
    if (!seconds.isFinite || seconds.isNaN) return '0m';

    int hours = (seconds / 3600).floor();
    int minutes = ((seconds % 3600) / 60).floor();

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  double _haversine(double lat1, double lon1, double lat2, double lon2) {
    // Validate all inputs
    if (!_isValidCoordinate(lat1) ||
        !_isValidCoordinate(lon1) ||
        !_isValidCoordinate(lat2) ||
        !_isValidCoordinate(lon2)) {
      return 0.0;
    }

    const R = 6371;
    final dLat = _degToRad(lat2 - lat1);
    final dLon = _degToRad(lon2 - lon1);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degToRad(lat1)) *
            math.cos(_degToRad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    final result = R * c;

    // Validate result
    return _isValidCoordinate(result) ? result : 0.0;
  }

  double _degToRad(double deg) {
    if (!_isValidCoordinate(deg)) return 0.0;
    return deg * (math.pi / 180);
  }

  void _goToMyLocation() {
    final safeCoords = _getSafeCoordinates();

    _safeMapMove(safeCoords, 15.0);

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
                          "${_formatDistance(toko['distance'])} km away",
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
                    // Navigate Button
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _startNavigation(toko);
                        },
                        icon: const Icon(Icons.navigation, color: Colors.white),
                        label: const Text(
                          "Navigate",
                          style: TextStyle(color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[600],
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // "Open in Maps" Button
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          _openGoogleMaps(toko['lat'], toko['lon']);
                        },
                        icon:
                            const Icon(Icons.map_outlined, color: Colors.white),
                        label: const Text(
                          "Maps",
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
                    const SizedBox(width: 8),
                    // "Visit Store" Button
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          context.push('/store/${toko['store_id']}');
                        },
                        icon: const Icon(Icons.store, color: Colors.white),
                        label: const Text(
                          'Visit',
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
    if (!_isValidCoordinate(distance) || distance < 0) {
      return Colors.grey;
    }

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
    try {
      await launchUrl(Uri.parse(url));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open Google Maps')),
        );
      }
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

    if (_errorMessage.isNotEmpty &&
        !_isValidCoordinate(_latitude) &&
        !_isValidCoordinate(_longitude)) {
      return _buildErrorState();
    }

    return Stack(
      children: [
        // Map
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _getSafeCoordinates(),
            initialZoom: 13.0, // Always use valid zoom
            minZoom: 1.0,
            maxZoom: 19.0,
            onTap: (_, __) {
              if (_showStoreList) {
                _toggleStoreList();
              }
            },
            // Add bounds to prevent invalid coordinates
            cameraConstraint: CameraConstraint.contain(
              bounds: LatLngBounds(
                const LatLng(-85.0, -180.0), // South-West
                const LatLng(85.0, 180.0), // North-East
              ),
            ),
          ),
          children: [
            openStreetMapLayer,

            // Route polyline
            if (_routePoints.isNotEmpty)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: _routePoints,
                    strokeWidth: 5.0,
                    color: Colors.blue[600]!,
                  ),
                ],
              ),

            MarkerLayer(
              markers: [
                // User location marker (only if coordinates are valid)
                if (_isValidCoordinate(_latitude) &&
                    _isValidCoordinate(_longitude))
                  Marker(
                    point: LatLng(_latitude!, _longitude!),
                    width: 60,
                    height: 60,
                    child: _buildUserLocationMarker(),
                  ),

                // Store markers (filter out invalid coordinates)
                ..._tokoDalamRadius.where((toko) {
                  return _isValidCoordinate(toko['lat']) &&
                      _isValidCoordinate(toko['lon']);
                }).map(
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

        // Navigation Panel
        if (_isNavigating)
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            right: 16,
            child: _buildNavigationPanel(),
          ),

        // Search Bar (modified position when navigating)
        if (!_isNavigating)
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
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Searching...'),
                                duration: Duration(seconds: 1),
                              ),
                            );

                            List<Map<String, dynamic>> results =
                                await searchStores(value);

                            _searchController.clear();

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
                                  content: Text(
                                      'Search failed: ${error.toString()}'),
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
              // Stop Navigation Button
              if (_isNavigating)
                FloatingActionButton(
                  heroTag: 'stopNavigationButton',
                  backgroundColor: Colors.red[600],
                  onPressed: _stopNavigation,
                  elevation: 2,
                  child: const Icon(
                    Icons.stop,
                    color: Colors.white,
                  ),
                ),
              if (_isNavigating) const SizedBox(height: 12),

              // List stores button
              if (!_isNavigating)
                FloatingActionButton(
                  heroTag: 'listButton',
                  backgroundColor: _showStoreList ? primaryColor : Colors.white,
                  onPressed: _toggleStoreList,
                  elevation: 2,
                  child: Icon(
                    _showStoreList
                        ? Icons.list_alt
                        : Icons.format_list_bulleted,
                    color: _showStoreList ? Colors.white : secondaryColor,
                  ),
                ),
              if (!_isNavigating) const SizedBox(height: 12),

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

        // Store list panel (hidden during navigation)
        if (!_isNavigating)
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
                        Container(
                          width: 50,
                          height: 5,
                          margin: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
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
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
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

  // Navigation Panel Widget
  Widget _buildNavigationPanel() {
    return Card(
      elevation: 8,
      color: Colors.blue[700],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Destination info
            Row(
              children: [
                Icon(Icons.navigation, color: Colors.white, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Navigating to',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      Text(
                        _destinationStore?['nama'] ?? 'Unknown',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Distance and time info
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '${_formatDistance(_remainingDistance)} km',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Remaining',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Text(
                          _estimatedTime,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Est. Time',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // Current instruction
            if (_navigationInstructions.isNotEmpty &&
                _currentInstructionIndex < _navigationInstructions.length)
              Container(
                margin: const EdgeInsets.only(top: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.turn_right, color: Colors.blue[700], size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _navigationInstructions[_currentInstructionIndex],
                        style: TextStyle(
                          color: Colors.blue[700],
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
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
            color: _isNavigating ? Colors.blue[600] : primaryColor,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
          // Show direction arrow during navigation
          child: _isNavigating && _isValidCoordinate(_currentHeading)
              ? Transform.rotate(
                  angle: _currentHeading * (math.pi / 180),
                  child: const Icon(
                    Icons.navigation,
                    color: Colors.white,
                    size: 16,
                  ),
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildStoreMarker(Map<String, dynamic> store) {
    return Stack(
      children: [
        Icon(
          Icons.location_on,
          color: _destinationStore != null &&
                  _destinationStore!['store_id'] == store['store_id']
              ? Colors.green
              : const Color(0xFF31394E),
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
                border: Border.all(
                  color: _destinationStore != null &&
                          _destinationStore!['store_id'] == store['store_id']
                      ? Colors.green
                      : const Color(0xFF31394E),
                  width: 1,
                ),
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                  "${_formatDistance(store['distance'])} km",
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
