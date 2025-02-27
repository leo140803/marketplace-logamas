import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:marketplace_logamas/function/Utils.dart';

class NearbyStoresPage extends StatefulWidget {
  final List<Map<String, dynamic>> stores;

  NearbyStoresPage({required this.stores});

  @override
  _NearbyStoresPageState createState() => _NearbyStoresPageState();
}

class _NearbyStoresPageState extends State<NearbyStoresPage> {
  double? maxDistance; // Default null (tampilkan semua)
  List<Map<String, dynamic>> filteredStores = [];

  @override
  void initState() {
    super.initState();
    _applyFilter();
  }

  void _applyFilter() {
    setState(() {
      if (maxDistance == null) {
        filteredStores = List.from(widget.stores);
      } else {
        filteredStores = widget.stores
            .where((store) => store['distance'] <= maxDistance!)
            .toList();
      }
    });
  }

  void _showFilterDrawer(BuildContext context) {
    double tempDistance = maxDistance ?? 10.0; // Nilai default 10 km jika null

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            return Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 50,
                      height: 6,
                      margin: EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  Text(
                    'Filter Stores by Distance',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 15),

                  // Slider untuk memilih jarak
                  Text('Max Distance: ${tempDistance.toStringAsFixed(1)} km'),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor:
                          Color(0xFFC58189), // Warna track yang aktif
                      inactiveTrackColor:
                          Colors.grey[300], // Warna track yang tidak aktif
                      trackShape: RoundedRectSliderTrackShape(),
                      trackHeight: 6.0,
                      thumbColor: Color(0xFFC58189), // Warna tombol slider
                      thumbShape:
                          RoundSliderThumbShape(enabledThumbRadius: 10.0),
                      overlayColor:
                          Color(0x66C58189), // Warna overlay saat thumb ditekan
                      overlayShape:
                          RoundSliderOverlayShape(overlayRadius: 20.0),
                      tickMarkShape: RoundSliderTickMarkShape(),
                      activeTickMarkColor: Colors.white,
                      inactiveTickMarkColor: Colors.grey[400],
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

                  SizedBox(height: 20),

                  // Tombol Apply & Reset
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              maxDistance = tempDistance;
                              _applyFilter();
                            });
                            Navigator.pop(
                                context); // Tutup drawer setelah Apply
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF31394E),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            minimumSize: Size(double.infinity, 50),
                          ),
                          child: Text(
                            'Apply',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      SizedBox(width: 10),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            maxDistance = null;
                            _applyFilter();
                          });
                          Navigator.pop(context); // Tutup drawer setelah Reset
                        },
                        child: Text(
                          'Reset',
                          style: TextStyle(
                              color: Color(0xFF31394E),
                              fontSize: 16,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
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
      appBar: AppBar(
        backgroundColor:
            Colors.transparent, // Buat transparan agar gambar terlihat
        flexibleSpace: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/appbar.png', // Ganti dengan path gambar yang sesuai
              fit: BoxFit.cover, // Pastikan gambar memenuhi seluruh AppBar
            ),
            Container(
              color: Colors.black
                  .withOpacity(0.2), // Overlay agar teks tetap terbaca
            ),
          ],
        ),
        title: Text(
          'Nearby Stores',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: GestureDetector(
          onTap: () => context.pop(),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10.0),
            child: Icon(
              Icons.arrow_back,
              color: Colors.white,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.filter_alt_outlined, color: Colors.white),
            onPressed: () => _showFilterDrawer(context),
          ),
        ],
      ),
      body: filteredStores.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.store_mall_directory, // Ikon toko dengan gaya modern
                    size: 80,
                    color: Colors.grey.shade400,
                  ),
                  SizedBox(height: 10),
                  Text(
                    'No Nearby Stores Found',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    'Try adjusting your distance filter or check later.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: filteredStores.length,
              itemBuilder: (context, index) {
                final store = filteredStores[index];
                return Card(
                  margin: EdgeInsets.all(10),
                  child: ListTile(
                    leading: store['logo'] != null
                        ? Image.network(
                            '$apiBaseUrlImage${store['logo']}',
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(Icons.store,
                                  size: 50, color: Colors.grey);
                            },
                          )
                        : Icon(Icons.store, size: 50, color: Colors.grey),
                    title: Text(store['nama']),
                    subtitle: Text(
                      '${store['address']}\nDistance: ${store['distance'].toStringAsFixed(2)} km',
                    ),
                    isThreeLine: true,
                    onTap: () {
                      context.push('/store/${store['store_id']}');
                    },
                  ),
                );
              },
            ),
    );
  }
}
