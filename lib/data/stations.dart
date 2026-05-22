import 'package:latlong2/latlong.dart';

class MarmarayStation {
  final int order; // Gebze=1, Halkalı=43
  final String name;
  final LatLng location;
  final List<String> transfers;

  const MarmarayStation({
    required this.order,
    required this.name,
    required this.location,
    this.transfers = const [],
  });
}

/// Gebze (1) -> Halkalı (43) sıralı 43 istasyon.
/// Koordinatlar OpenStreetMap / TCDD kaynaklarından alınmış yaklaşık değerlerdir.
/// Prototip için yeterli hassasiyet sağlar (~50m hata payı).
const List<MarmarayStation> kMarmarayStations = [
  MarmarayStation(order: 1, name: 'Gebze', location: LatLng(40.7873, 29.4313), transfers: ['YHT', 'Adapazarı Bölgesel']),
  MarmarayStation(order: 2, name: 'Darıca', location: LatLng(40.7798, 29.3961), transfers: ['Darıca Metro']),
  MarmarayStation(order: 3, name: 'Osmangazi', location: LatLng(40.7790, 29.3837)),
  MarmarayStation(order: 4, name: 'GTÜ - Fatih', location: LatLng(40.7847, 29.3672)),
  MarmarayStation(order: 5, name: 'Çayırova', location: LatLng(40.7929, 29.3539)),
  MarmarayStation(order: 6, name: 'Tuzla', location: LatLng(40.8154, 29.3293)),
  MarmarayStation(order: 7, name: 'İçmeler', location: LatLng(40.8281, 29.3215)),
  MarmarayStation(order: 8, name: 'Aydıntepe', location: LatLng(40.8345, 29.3132)),
  MarmarayStation(order: 9, name: 'Güzelyalı', location: LatLng(40.8421, 29.3043)),
  MarmarayStation(order: 10, name: 'Tersane', location: LatLng(40.8493, 29.2933), transfers: ['M4']),
  MarmarayStation(order: 11, name: 'Kaynarca', location: LatLng(40.8597, 29.2772)),
  MarmarayStation(order: 12, name: 'Pendik', location: LatLng(40.8745, 29.2566), transfers: ['M10']),
  MarmarayStation(order: 13, name: 'Yunus', location: LatLng(40.8843, 29.2412)),
  MarmarayStation(order: 14, name: 'Kartal', location: LatLng(40.9007, 29.2167), transfers: ['M4']),
  MarmarayStation(order: 15, name: 'Başak', location: LatLng(40.9091, 29.2073)),
  MarmarayStation(order: 16, name: 'Atalar', location: LatLng(40.9143, 29.1988)),
  MarmarayStation(order: 17, name: 'Cevizli', location: LatLng(40.9216, 29.1856)),
  MarmarayStation(order: 18, name: 'Maltepe', location: LatLng(40.9343, 29.1573), transfers: ['M4']),
  MarmarayStation(order: 19, name: 'Süreyya Plajı', location: LatLng(40.9407, 29.1487)),
  MarmarayStation(order: 20, name: 'İdealtepe', location: LatLng(40.9495, 29.1393)),
  MarmarayStation(order: 21, name: 'Küçükyalı', location: LatLng(40.9548, 29.1313)),
  MarmarayStation(order: 22, name: 'Bostancı', location: LatLng(40.9598, 29.1131), transfers: ['M8']),
  MarmarayStation(order: 23, name: 'Suadiye', location: LatLng(40.9627, 29.1012)),
  MarmarayStation(order: 24, name: 'Erenköy', location: LatLng(40.9678, 29.0876)),
  MarmarayStation(order: 25, name: 'Göztepe', location: LatLng(40.9728, 29.0739), transfers: ['M12']),
  MarmarayStation(order: 26, name: 'Feneryolu', location: LatLng(40.9784, 29.0618)),
  MarmarayStation(order: 27, name: 'Söğütlüçeşme', location: LatLng(40.9879, 29.0517), transfers: ['Metrobüs']),
  MarmarayStation(order: 28, name: 'Ayrılık Çeşmesi', location: LatLng(40.9959, 29.0356), transfers: ['M4']),
  MarmarayStation(order: 29, name: 'Üsküdar', location: LatLng(41.0246, 29.0152), transfers: ['M5']),
  MarmarayStation(order: 30, name: 'Sirkeci', location: LatLng(41.0150, 28.9772), transfers: ['T1', 'İDO']),
  MarmarayStation(order: 31, name: 'Yenikapı', location: LatLng(41.0033, 28.9492), transfers: ['M1A', 'M1B', 'M2', 'İDO']),
  MarmarayStation(order: 32, name: 'Kazlıçeşme', location: LatLng(40.9907, 28.9215)),
  MarmarayStation(order: 33, name: 'Zeytinburnu', location: LatLng(40.9869, 28.8993), transfers: ['T1']),
  MarmarayStation(order: 34, name: 'Yenimahalle', location: LatLng(40.9831, 28.8783)),
  MarmarayStation(order: 35, name: 'Bakırköy', location: LatLng(40.9783, 28.8718), transfers: ['M3']),
  MarmarayStation(order: 36, name: 'Ataköy', location: LatLng(40.9711, 28.8576), transfers: ['M9']),
  MarmarayStation(order: 37, name: 'Yeşilyurt', location: LatLng(40.9697, 28.8362)),
  MarmarayStation(order: 38, name: 'Yeşilköy', location: LatLng(40.9658, 28.8232)),
  MarmarayStation(order: 39, name: 'Florya Akvaryum', location: LatLng(40.9756, 28.7967)),
  MarmarayStation(order: 40, name: 'Florya', location: LatLng(40.9812, 28.7853)),
  MarmarayStation(order: 41, name: 'Küçükçekmece', location: LatLng(40.9893, 28.7745)),
  MarmarayStation(order: 42, name: 'Mustafa Kemal', location: LatLng(40.9989, 28.7847)),
  MarmarayStation(order: 43, name: 'Halkalı', location: LatLng(41.0345, 28.7706), transfers: ['M1B', 'YHT']),
];

MarmarayStation stationByOrder(int order) =>
    kMarmarayStations.firstWhere((s) => s.order == order);
