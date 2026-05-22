import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../data/stations.dart';
import '../models/trip.dart';
import '../services/fare_calculator.dart';
import '../services/notification_service.dart';
import '../services/trip_storage.dart';
import '../services/trip_tracker.dart';
import '../theme/app_theme.dart';
import 'refund_success_screen.dart';

class ActiveTripScreen extends StatefulWidget {
  final Trip trip;
  const ActiveTripScreen({super.key, required this.trip});

  @override
  State<ActiveTripScreen> createState() => _ActiveTripScreenState();
}

class _ActiveTripScreenState extends State<ActiveTripScreen> {
  final _tracker = TripTracker();
  final _storage = TripStorage();
  final _mapController = MapController();

  LatLng? _currentLocation;
  NearestStationResult? _nearest;
  MarmarayStation? _candidateExit;
  double _currentSpeedMps = 0;
  double _currentAccuracy = 0;
  LocationQuality _currentQuality = LocationQuality.outsideDwellRadius;
  Duration _accumulatedDwell = Duration.zero;

  // Tünel modu state
  bool _inTunnel = false;
  MarmarayStation? _lastKnownStation;
  NearestStationResult? _tunnelRecovery;

  // Yol A geri sayım (50m dışına çıkma onayı)
  Duration _exitCountdown = Duration.zero;
  Timer? _exitCountdownTimer;

  bool _finalizing = false;

  @override
  void initState() {
    super.initState();
    _startTracking();
  }

  Future<void> _startTracking() async {
    final exitStation = await _tracker.trackUntilExit(
      boardingOrder: widget.trip.boardingStationOrder,
      onEvent: _handleEvent,
    );

    if (exitStation != null && mounted) {
      await _finalizeTrip(exitStation);
    }
  }

  void _handleEvent(TripTrackerEvent event) {
    if (!mounted) return;

    switch (event) {
      case LocationUpdateEvent e:
        setState(() {
          _currentLocation = e.location;
          _nearest = e.nearest;
          _currentSpeedMps = e.speedMps;
          _currentAccuracy = e.accuracyMeters;
          _currentQuality = e.quality;
          _accumulatedDwell = e.accumulatedDwell;
          _inTunnel = e.inTunnel;
          _lastKnownStation = e.lastKnownStation;
        });
        if (_currentLocation != null) {
          _mapController.move(_currentLocation!, _mapController.camera.zoom);
        }
        break;

      case ApproachedStationEvent e:
        setState(() {
          _candidateExit = e.station;
          _exitCountdown = Duration.zero;
        });
        _exitCountdownTimer?.cancel();
        break;

      case LeftStationEvent e:
        setState(() {
          _candidateExit = e.station;
          _exitCountdown = _tracker.config.confirmExitAfter;
        });
        _exitCountdownTimer?.cancel();
        _exitCountdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
          if (!mounted || _exitCountdown.inSeconds <= 0) {
            t.cancel();
            return;
          }
          setState(() {
            _exitCountdown = _exitCountdown - const Duration(seconds: 1);
          });
        });
        break;

      case TunnelEnteredEvent e:
        setState(() {
          _inTunnel = true;
          _lastKnownStation = e.lastKnownStation;
        });
        break;

      case TunnelExitedEvent e:
        setState(() {
          _tunnelRecovery = e.recovery;
        });
        break;

      case ExitConfirmedEvent _:
        _exitCountdownTimer?.cancel();
        break;
    }
  }

  Future<void> _finalizeTrip(MarmarayStation exitStation) async {
    if (_finalizing) return;
    _finalizing = true;

    final refund = FareCalculator.calculateRefund(
      boardingStationOrder: widget.trip.boardingStationOrder,
      exitStationOrder: exitStation.order,
    );

    widget.trip
      ..exitStationOrder = exitStation.order
      ..endedAt = DateTime.now()
      ..refundAmount = refund
      ..status = TripStatus.refunded;

    await _storage.save(widget.trip);
    await NotificationService.showRefundNotification(
      exitStationName: exitStation.name,
      refundAmount: refund,
    );

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => RefundSuccessScreen(trip: widget.trip)),
      );
    }
  }

  Future<void> _cancelTrip() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Yolculuğu iptal et?'),
        content: const Text(
          'İptal edersen iade alamazsın. Standart sistemde olduğu gibi en uzun mesafe ücreti üzerinden işlem görür.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppTheme.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('İptal et'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      widget.trip
        ..status = TripStatus.cancelled
        ..endedAt = DateTime.now();
      await _storage.save(widget.trip);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _exitCountdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final boardingStation = widget.trip.boardingStation;
    return Scaffold(
      body: Stack(
        children: [
          _buildMap(boardingStation),
          _buildTopBar(),
          _buildBottomSheet(boardingStation),
        ],
      ),
    );
  }

  Widget _buildMap(MarmarayStation boarding) {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _currentLocation ?? boarding.location,
        initialZoom: 14.5,
        maxZoom: 18,
        minZoom: 10,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.marmaray_iade',
        ),
        PolylineLayer(polylines: [
          Polyline(
            points: kMarmarayStations.map((s) => s.location).toList(),
            strokeWidth: 4,
            color: AppTheme.primary.withOpacity(0.5),
          ),
        ]),
        // Candidate istasyon için 30m dwell yarıçapı çizimi
        if (_candidateExit != null)
          CircleLayer(circles: [
            CircleMarker(
              point: _candidateExit!.location,
              radius: _tracker.config.dwellRadiusMeters,
              useRadiusInMeter: true,
              color: AppTheme.refundGreen.withOpacity(0.15),
              borderColor: AppTheme.refundGreen,
              borderStrokeWidth: 1.5,
            ),
          ]),
        MarkerLayer(
          markers: kMarmarayStations.map((s) {
            final isBoarding = s.order == boarding.order;
            final isCandidate = _candidateExit?.order == s.order;
            return Marker(
              point: s.location,
              width: isBoarding || isCandidate ? 36 : 14,
              height: isBoarding || isCandidate ? 36 : 14,
              child: Container(
                decoration: BoxDecoration(
                  color: isBoarding
                      ? AppTheme.primary
                      : isCandidate
                          ? AppTheme.accent
                          : AppTheme.primary.withOpacity(0.4),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: (isBoarding || isCandidate)
                    ? const Icon(Icons.flag_rounded, color: Colors.white, size: 18)
                    : null,
              ),
            );
          }).toList(),
        ),
        // Kullanıcı konumu - accuracy halkası ile birlikte
        if (_currentLocation != null) ...[
          CircleLayer(circles: [
            CircleMarker(
              point: _currentLocation!,
              radius: _currentAccuracy.clamp(5, 200),
              useRadiusInMeter: true,
              color: Colors.blue.withOpacity(0.12),
              borderColor: Colors.blue.withOpacity(0.4),
              borderStrokeWidth: 1,
            ),
          ]),
          MarkerLayer(markers: [
            Marker(
              point: _currentLocation!,
              width: 24,
              height: 24,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                ),
              ),
            ),
          ]),
        ],
      ],
    );
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 0, left: 0, right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _CircleButton(icon: Icons.close_rounded, onTap: _cancelTrip),
              const Spacer(),
              _buildQualityChip(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQualityChip() {
    Color color;
    String label;
    IconData icon;

    if (_inTunnel) {
      color = AppTheme.accent;
      label = _lastKnownStation != null
          ? 'Yer altı — son: ${_lastKnownStation!.name}'
          : 'Yer altı modu';
      icon = Icons.train_rounded;
    } else {
      switch (_currentQuality) {
        case LocationQuality.reliable:
          color = AppTheme.refundGreen;
          label = 'GPS güvenilir (±${_currentAccuracy.toStringAsFixed(0)}m)';
          icon = Icons.gps_fixed_rounded;
          break;
        case LocationQuality.poorAccuracy:
          color = AppTheme.danger;
          label = 'GPS zayıf (±${_currentAccuracy.toStringAsFixed(0)}m)';
          icon = Icons.gps_off_rounded;
          break;
        case LocationQuality.movingTooFast:
          color = AppTheme.primary;
          label = 'Hareket halinde';
          icon = Icons.directions_transit_rounded;
          break;
        case LocationQuality.outsideDwellRadius:
          color = AppTheme.textSecondary;
          label = 'Konum izleniyor';
          icon = Icons.location_searching_rounded;
          break;
      }
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }

  Widget _buildBottomSheet(MarmarayStation boarding) {
    final hasCandidate = _candidateExit != null;
    final isWaitingExit = _exitCountdown.inSeconds > 0;
    final isDwelling = hasCandidate &&
        _accumulatedDwell > Duration.zero &&
        !isWaitingExit;

    return Positioned(
      left: 0, right: 0, bottom: 0,
      child: Container(
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 24)],
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              _buildTripHeader(boarding),
              const SizedBox(height: 16),
              const Divider(color: AppTheme.divider, height: 1),
              const SizedBox(height: 16),
              if (_inTunnel)
                _buildTunnelState()
              else if (isWaitingExit)
                _buildExitConfirmingState()
              else if (isDwelling)
                _buildDwellProgressState()
              else if (hasCandidate)
                _buildAtStationState()
              else
                _buildEnRouteState(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTripHeader(MarmarayStation boarding) {
    return Row(
      children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.flag_rounded, color: AppTheme.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Kalkış', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.w500)),
              Text(boarding.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Text('Çekilen', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
            Text(
              '₺${widget.trip.chargedFare.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTunnelState() {
    return Column(
      children: [
        Container(
          width: 56, height: 56,
          decoration: BoxDecoration(
            color: AppTheme.accent.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.train_rounded, color: AppTheme.accent, size: 30),
        ),
        const SizedBox(height: 10),
        const Text(
          'Yer altı modu aktif',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
        ),
        const SizedBox(height: 4),
        Text(
          _lastKnownStation != null
              ? 'Sinyal kesildi — son konum: ${_lastKnownStation!.name}'
              : 'GPS sinyali bekleniyor',
          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.background,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.info_outline_rounded, size: 14, color: AppTheme.textSecondary),
              SizedBox(width: 6),
              Flexible(
                child: Text(
                  'İniş istasyonu, yer üstüne çıkıp GPS geri\ngeldiğinde otomatik tespit edilecek',
                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEnRouteState() {
    return Column(
      children: [
        const Icon(Icons.directions_transit_rounded, size: 36, color: AppTheme.textSecondary),
        const SizedBox(height: 8),
        const Text('Yolculuk sürüyor', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
        const SizedBox(height: 4),
        Text(
          _nearest != null
              ? 'En yakın: ${_nearest!.station.name} (${_nearest!.distanceMeters.toStringAsFixed(0)}m)'
              : 'Konum bekleniyor...',
          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.background,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lightbulb_outline_rounded, size: 14, color: AppTheme.textSecondary),
              SizedBox(width: 6),
              Flexible(
                child: Text(
                  'Telefonu cebe koyabilirsiniz — iade otomatik',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAtStationState() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.accent.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.location_on_rounded, color: AppTheme.accent, size: 28),
        ),
        const SizedBox(height: 8),
        Text(
          '${_candidateExit!.name} istasyonunda',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
        ),
        const SizedBox(height: 4),
        const Text(
          'İniş onayı için 50m uzaklaş ya da istasyonun 30m yakınında kal',
          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          textAlign: TextAlign.center,
        ),
        if (_currentQuality == LocationQuality.poorAccuracy) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.danger.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.danger.withOpacity(0.2)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.warning_amber_rounded, size: 14, color: AppTheme.danger),
                SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'GPS zayıf — açık alana çıkın veya iade makinesini kullanın',
                    style: TextStyle(fontSize: 11, color: AppTheme.danger, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDwellProgressState() {
    final possibleRefund = FareCalculator.calculateRefund(
      boardingStationOrder: widget.trip.boardingStationOrder,
      exitStationOrder: _candidateExit!.order,
    );
    final progress = _accumulatedDwell.inSeconds /
        _tracker.config.confirmDwellAfter.inSeconds;
    final remaining = _tracker.config.confirmDwellAfter - _accumulatedDwell;
    final m = remaining.inMinutes;
    final s = remaining.inSeconds % 60;

    final isPaused = _currentQuality != LocationQuality.reliable;

    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 80, height: 80,
              child: CircularProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                strokeWidth: 6,
                backgroundColor: AppTheme.divider,
                valueColor: AlwaysStoppedAnimation(
                  isPaused ? AppTheme.textSecondary : AppTheme.primary,
                ),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$m:${s.toString().padLeft(2, "0")}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                ),
                Text(
                  'kaldı',
                  style: TextStyle(fontSize: 10, color: AppTheme.textSecondary.withOpacity(0.7)),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          '${_candidateExit!.name} yakınında bekleniyor',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          isPaused
              ? _pausedReason()
              : 'Trende olmadığınız doğrulanıyor',
          style: TextStyle(
            fontSize: 12,
            color: isPaused ? AppTheme.danger : AppTheme.textSecondary,
            fontWeight: isPaused ? FontWeight.w600 : FontWeight.normal,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          'İade tutarı: ₺${possibleRefund.toStringAsFixed(2)}',
          style: const TextStyle(fontSize: 13, color: AppTheme.refundGreen, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  String _pausedReason() {
    switch (_currentQuality) {
      case LocationQuality.poorAccuracy:
        return 'GPS hassasiyeti yetersiz — sayaç duraklatıldı';
      case LocationQuality.movingTooFast:
        return 'Hareket halinde — sayaç duraklatıldı';
      case LocationQuality.outsideDwellRadius:
        return 'İstasyondan uzaklaştınız — sayaç duraklatıldı';
      case LocationQuality.reliable:
        return '';
    }
  }

  Widget _buildExitConfirmingState() {
    final possibleRefund = FareCalculator.calculateRefund(
      boardingStationOrder: widget.trip.boardingStationOrder,
      exitStationOrder: _candidateExit!.order,
    );
    final progress = 1 - (_exitCountdown.inSeconds /
        _tracker.config.confirmExitAfter.inSeconds);

    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 70, height: 70,
              child: CircularProgressIndicator(
                value: progress,
                strokeWidth: 5,
                backgroundColor: AppTheme.divider,
                valueColor: const AlwaysStoppedAnimation(AppTheme.refundGreen),
              ),
            ),
            Text(
              '${_exitCountdown.inSeconds}s',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          '${_candidateExit!.name}\'den ayrıldığınız onaylanıyor',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          'İade tutarı: ₺${possibleRefund.toStringAsFixed(2)}',
          style: const TextStyle(fontSize: 13, color: AppTheme.refundGreen, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircleButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surface,
      shape: const CircleBorder(),
      elevation: 4,
      shadowColor: Colors.black26,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: AppTheme.textPrimary, size: 22),
        ),
      ),
    );
  }
}
