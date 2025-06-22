class MetalTypeConverter {
  static const Map<int, String> metalTypeMap = {
    1: 'Gold',
    2: 'Silver',
    3: 'Red Gold',
    4: 'White Gold',
    5: 'Platinum',
  };

  static String getMetalType(int type) {
    return metalTypeMap[type] ??
        'Unknown'; // Default jika nilai tidak ditemukan
  }
}
