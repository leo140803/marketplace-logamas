class MetalTypeConverter {
  static const Map<int, String> metalTypeMap = {
    0: 'Gold',
    1: 'Silver',
    2: 'Red Gold',
    3: 'White Gold',
    4: 'Platinum',
  };

  static String getMetalType(int type) {
    return metalTypeMap[type] ??
        'Unknown'; // Default jika nilai tidak ditemukan
  }
}
