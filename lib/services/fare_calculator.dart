/// 2026 Şubat zammı sonrası Marmaray tam tarifesi (mesafe kademeli).
/// Kaynak: TCDD Taşımacılık güncel ücret tarifesi.
class FareCalculator {
  /// Kademe sınırları: [maxStops, fiyatTL]
  static const List<List<num>> _fullFareTable = [
    [7, 34.00],   // 1-7 durak
    [15, 41.00],  // 8-15 durak
    [23, 47.50],  // 16-23 durak
    [30, 54.00],  // 24-30 durak
    [35, 64.50],  // 31-35 durak
    [43, 74.70],  // 36-43 durak (en uzun mesafe)
  ];

  /// Girişte sistem en uzak mesafe ücretini düşer (= en yüksek tarife).
  static double get maxFare => _fullFareTable.last[1].toDouble();

  /// İki istasyon arası geçilen durak sayısına göre gerçek ücret.
  static double fareForStops(int stopCount) {
    if (stopCount <= 0) return 0;
    for (final tier in _fullFareTable) {
      if (stopCount <= tier[0]) return tier[1].toDouble();
    }
    return maxFare;
  }

  /// Bir yolculuk için iade miktarı.
  /// Giriş istasyonu -> iniş istasyonu arası durak farkı kadar ücretle hesaplanır.
  static double calculateRefund({
    required int boardingStationOrder,
    required int exitStationOrder,
  }) {
    final stops = (exitStationOrder - boardingStationOrder).abs();
    if (stops == 0) return 0;
    final actualFare = fareForStops(stops);
    final refund = maxFare - actualFare;
    return double.parse(refund.toStringAsFixed(2));
  }

  /// İniş istasyonu sayısı verildiğinde alınan ücret.
  static double actualFareFor({
    required int boardingStationOrder,
    required int exitStationOrder,
  }) {
    final stops = (exitStationOrder - boardingStationOrder).abs();
    return fareForStops(stops);
  }
}
