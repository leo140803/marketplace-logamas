import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:marketplace_logamas/function/Utils.dart';
import 'package:marketplace_logamas/widget/BottomNavigationBar.dart';
import 'package:marketplace_logamas/widget/Dialog.dart';
import 'dart:convert';

import 'package:url_launcher/url_launcher.dart';

class LocationScreen extends StatefulWidget {
  @override
  _LocationScreenState createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> {
  double? _latitude;
  double? _longitude;
  List<Map<String, dynamic>> _tokoDalamRadius = [];
  int _selectedIndex = 1;
  bool _isLoading = true;
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    navigate(context, index);
  }

  final List<Map<String, dynamic>> _tokoList = [];

  Future<void> _fetchTokoData() async {
    try {
      final response =
          await http.get(Uri.parse('$apiBaseUrl/store'));
      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body) as Map<String, dynamic>;
        final data = jsonResponse['data'] as List<dynamic>;

        setState(() {
          _tokoList.clear();
          for (var item in data) {
            _tokoList.add({
              "nama": item['store_name'],
              "lat": double.parse(item['latitude'].toString()),
              "lon": double.parse(item['longitude'].toString()),
            });
          }
        });
      } else {
        dialog(context, 'Error', 'An Error Occured');
        throw Exception('Failed to fetch data: ${response.statusCode}');
      }
    } catch (e) {
      print(e);
      dialog(context, 'Error', 'An Error Occured');
    }
  }

  void _initializeLocation() async {
    await _fetchTokoData();
    await _getCurrentLocation();
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Layanan lokasi tidak aktif.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Izin lokasi ditolak.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error(
          'Izin lokasi ditolak secara permanen. Tidak dapat meminta izin.');
    }

    final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);

    setState(() {
      _latitude = position.latitude;
      _longitude = position.longitude;
    });

    _filterTokoDalamRadius(position.latitude, position.longitude, 20);
  }

  void _filterTokoDalamRadius(double userLat, double userLon, double radiusKm) {
    List<Map<String, dynamic>> filteredToko = [];
    for (var toko in _tokoList) {
      double distance = _haversine(userLat, userLon, toko['lat'], toko['lon']);
      toko['distance'] = distance;
      if (distance <= radiusKm) {
        filteredToko.add(toko);
      }
    }
    setState(() {
      _tokoDalamRadius = filteredToko;
    });
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
      _mapController.move(LatLng(_latitude!, _longitude!), 13);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lokasi belum tersedia')),
      );
    }
  }

  TileLayer get openStreetMapLayer => TileLayer(
        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
        userAgentPackageName: 'dev.fleatflet.fluter_map.example',
      );
  void _showTokoDetails(Map<String, dynamic> toko) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Color(0xFF31394E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  toko['nama'],
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
                SizedBox(height: 10),
                if (toko.containsKey('distance'))
                  Text(
                    'Distance: ${toko['distance'].toStringAsFixed(2)} km',
                    style: TextStyle(
                        fontSize: 16,
                        color: Color(0xFFC58189),
                        fontWeight: FontWeight.bold),
                  ),
                SizedBox(height: 20),
                TextButton(
                  onPressed: () {
                    _openGoogleMaps(toko['lat'], toko['lon']);
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.all(12),
                    backgroundColor: Color(0xFFC58189),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.map_outlined,
                        color: Colors.white,
                        weight: 10,
                      ),
                      SizedBox(width: 8),
                      Text(
                        "Open in Maps",
                        style: TextStyle(color: Color(0xFF31394E)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openGoogleMaps(double lat, double lon) async {
    final url = 'http://maps.google.com/maps?z=12&t=m&q=loc:$lat+$lon';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open Google Maps')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appBar: AppBar(
      //   title: Text("Nearby Store",
      //       style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
      //   backgroundColor: Color(0xFF31394E),
      // ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(),
            )
          : Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: LatLng(_latitude ?? 0.0, _longitude ?? 0.0),
                    initialZoom: 12,
                  ),
                  children: [
                    openStreetMapLayer,
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: LatLng(_latitude ?? 0.0, _longitude ?? 0.0),
                          width: 60,
                          height: 60,
                          child: Icon(
                            Icons.my_location,
                            color: Color(0xFFC58189),
                            size: 30,
                          ),
                        ),
                        ..._tokoList.map(
                          (toko) => Marker(
                            point: LatLng(toko['lat'], toko['lon']),
                            width: 50,
                            height: 50,
                            child: GestureDetector(
                              onTap: () {
                                _showTokoDetails(toko);
                              },
                              child: Icon(
                                Icons.location_on,
                                color: Color(0xFF31394E),
                                size: 40,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Positioned(
                  bottom: 20,
                  right: 20,
                  child: FloatingActionButton(
                    backgroundColor: Color(0xFF31394E),
                    onPressed: _goToMyLocation,
                    child: Icon(Icons.my_location, color: Color(0xFFC58189)),
                  ),
                ),
              ],
            ),
      bottomNavigationBar: BottomNavBar(
        selectedIndex: _selectedIndex,
        onItemTapped: _onItemTapped,
      ),
    );
  }
}
