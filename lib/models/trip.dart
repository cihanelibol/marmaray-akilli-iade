import '../data/stations.dart';

enum TripStatus { boarded, monitoring, completed, refunded, cancelled }

class Trip {
  final String id;
  final int boardingStationOrder;
  int? exitStationOrder;
  final DateTime startedAt;
  DateTime? endedAt;
  final double chargedFare;
  double? refundAmount;
  TripStatus status;
  final String method; // 'qr' veya 'card'

  Trip({
    required this.id,
    required this.boardingStationOrder,
    this.exitStationOrder,
    required this.startedAt,
    this.endedAt,
    required this.chargedFare,
    this.refundAmount,
    this.status = TripStatus.boarded,
    this.method = 'qr',
  });

  MarmarayStation get boardingStation => stationByOrder(boardingStationOrder);
  MarmarayStation? get exitStation =>
      exitStationOrder == null ? null : stationByOrder(exitStationOrder!);

  Map<String, dynamic> toJson() => {
        'id': id,
        'boardingStationOrder': boardingStationOrder,
        'exitStationOrder': exitStationOrder,
        'startedAt': startedAt.toIso8601String(),
        'endedAt': endedAt?.toIso8601String(),
        'chargedFare': chargedFare,
        'refundAmount': refundAmount,
        'status': status.name,
        'method': method,
      };

  factory Trip.fromJson(Map<String, dynamic> json) => Trip(
        id: json['id'] as String,
        boardingStationOrder: json['boardingStationOrder'] as int,
        exitStationOrder: json['exitStationOrder'] as int?,
        startedAt: DateTime.parse(json['startedAt'] as String),
        endedAt: json['endedAt'] != null
            ? DateTime.parse(json['endedAt'] as String)
            : null,
        chargedFare: (json['chargedFare'] as num).toDouble(),
        refundAmount: (json['refundAmount'] as num?)?.toDouble(),
        status: TripStatus.values.firstWhere((s) => s.name == json['status']),
        method: json['method'] as String? ?? 'qr',
      );
}
