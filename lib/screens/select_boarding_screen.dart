import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../data/stations.dart';
import '../models/trip.dart';
import '../services/fare_calculator.dart';
import '../services/trip_storage.dart';
import '../services/trip_tracker.dart';
import '../theme/app_theme.dart';
import 'active_trip_screen.dart';

class SelectBoardingScreen extends StatefulWidget {
  const SelectBoardingScreen({super.key});

  @override
  State<SelectBoardingScreen> createState() => _SelectBoardingScreenState();
}

class _SelectBoardingScreenState extends State<SelectBoardingScreen> {
  String _query = '';
  MarmarayStation? _selected;
  bool _starting = false;
  final _tracker = TripTracker();

  @override
  void initState() {
    super.initState();
    _suggestNearest();
  }

  Future<void> _suggestNearest() async {
    try {
      final hasPerm = await _tracker.ensurePermission();
      if (!hasPerm) return;
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      final near = _tracker.nearestStation(LatLng(pos.latitude, pos.longitude));
      if (near.distanceMeters < 300 && mounted) {
        setState(() => _selected = near.station);
      }
    } catch (_) {}
  }

  List<MarmarayStation> get _filtered {
    if (_query.isEmpty) return kMarmarayStations;
    final q = _query.toLowerCase();
    return kMarmarayStations.where((s) => s.name.toLowerCase().contains(q)).toList();
  }

  Future<void> _startTrip() async {
    if (_selected == null || _starting) return;
    setState(() => _starting = true);

    // Konum izni kontrolü
    final ok = await _tracker.ensurePermission();
    if (!ok && mounted) {
      setState(() => _starting = false);
      _showLocationRequiredDialog();
      return;
    }

    final trip = Trip(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      boardingStationOrder: _selected!.order,
      startedAt: DateTime.now(),
      chargedFare: FareCalculator.maxFare,
      status: TripStatus.boarded,
    );

    await TripStorage().save(trip);

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => ActiveTripScreen(trip: trip)),
      );
    }
  }

  void _showLocationRequiredDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Konum izni gerekli'),
        content: const Text(
          'İade alabilmek için konumunuzun her zaman paylaşılması gerekiyor. '
          'İniş istasyonunuz konum üzerinden tespit edilir.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Vazgeç'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Geolocator.openLocationSettings();
            },
            child: const Text('Ayarları aç'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kalkış İstasyonu'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'İstasyon ara...',
                prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.textSecondary),
                filled: true,
                fillColor: AppTheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppTheme.divider),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppTheme.divider),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
                ),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (_, i) {
                final s = _filtered[i];
                final isSelected = _selected?.order == s.order;
                return InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => setState(() => _selected = s),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                      color: isSelected ? AppTheme.primary.withOpacity(0.08) : AppTheme.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected ? AppTheme.primary : AppTheme.divider,
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isSelected ? AppTheme.primary : AppTheme.background,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${s.order}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isSelected ? Colors.white : AppTheme.textSecondary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(s.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                              if (s.transfers.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    s.transfers.join(' • '),
                                    style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          const Icon(Icons.check_circle_rounded, color: AppTheme.primary, size: 22),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          if (_selected != null) _buildSummary(),
        ],
      ),
    );
  }

  Widget _buildSummary() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: AppTheme.divider)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Girişte alınacak', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                      Text(
                        '₺${FareCalculator.maxFare.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                      ),
                      const Text(
                        'İnişinde mesafeye göre iade edilecek',
                        style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.refundGreen.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.location_on_rounded, size: 14, color: AppTheme.refundGreen),
                      SizedBox(width: 4),
                      Text(
                        'Konum izleme aktif',
                        style: TextStyle(fontSize: 11, color: AppTheme.refundGreen, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _starting ? null : _startTrip,
              icon: _starting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.qr_code_2_rounded),
              label: Text(_starting ? 'Başlatılıyor...' : 'QR ile Geçiş Yap'),
            ),
          ],
        ),
      ),
    );
  }
}
