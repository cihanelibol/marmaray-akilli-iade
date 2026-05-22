import 'package:flutter/material.dart';
import '../models/trip.dart';
import '../services/trip_storage.dart';
import '../theme/app_theme.dart';
import 'select_boarding_screen.dart';
import 'history_screen.dart';
import 'active_trip_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _storage = TripStorage();
  List<Trip> _trips = [];
  double _balance = 158.50; // Mock İstanbulkart bakiyesi

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final trips = await _storage.loadAll();
    if (mounted) setState(() => _trips = trips);
  }

  double get _totalRefundedThisMonth {
    final now = DateTime.now();
    return _trips
        .where((t) =>
            t.refundAmount != null &&
            t.startedAt.year == now.year &&
            t.startedAt.month == now.month)
        .fold(0.0, (sum, t) => sum + t.refundAmount!);
  }

  @override
  Widget build(BuildContext context) {
    final activeTrips = _trips.where((t) =>
        t.status == TripStatus.boarded || t.status == TripStatus.monitoring);
    final activeTrip = activeTrips.isEmpty ? null : activeTrips.first;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          color: AppTheme.primary,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              _buildHeader(),
              const SizedBox(height: 24),
              _buildBalanceCard(),
              const SizedBox(height: 16),
              _buildRefundStatsCard(),
              const SizedBox(height: 24),
              if (activeTrip != null) ...[
                _buildActiveTripBanner(activeTrip),
                const SizedBox(height: 16),
              ],
              _buildPrimaryAction(activeTrip != null),
              const SizedBox(height: 32),
              _buildRecentTripsHeader(),
              const SizedBox(height: 12),
              if (_trips.isEmpty)
                _buildEmptyTripsState()
              else
                ..._trips.take(3).map(_buildTripTile),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppTheme.primary, AppTheme.primaryDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.train_rounded, color: Colors.white, size: 24),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Marmaray', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, fontWeight: FontWeight.w500)),
              Text('Akıllı İade', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.history_rounded),
          onPressed: () async {
            await Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoryScreen()));
            _refresh();
          },
        ),
      ],
    );
  }

  Widget _buildBalanceCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primary, AppTheme.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withOpacity(0.25),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'İstanbulkart Bakiye',
                style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.qr_code_rounded, color: Colors.white, size: 14),
                    SizedBox(width: 6),
                    Text('QR Mobil', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '₺${_balance.toStringAsFixed(2)}',
            style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w800, letterSpacing: -1),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _balanceAction(Icons.add_rounded, 'Yükle'),
              const SizedBox(width: 8),
              _balanceAction(Icons.qr_code_2_rounded, 'QR Göster'),
              const SizedBox(width: 8),
              _balanceAction(Icons.swap_horiz_rounded, 'Aktar'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _balanceAction(IconData icon, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildRefundStatsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.refundGreen.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.savings_rounded, color: AppTheme.refundGreen),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Bu ay toplam iade', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                const SizedBox(height: 2),
                Text(
                  '₺${_totalRefundedThisMonth.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                ),
              ],
            ),
          ),
          Icon(Icons.trending_up_rounded, color: AppTheme.refundGreen.withOpacity(0.6)),
        ],
      ),
    );
  }

  Widget _buildActiveTripBanner(Trip trip) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.accent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.accent.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(color: AppTheme.accent, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Aktif Yolculuk', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
                Text(
                  '${trip.boardingStation.name} → izleniyor',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary),
        ],
      ),
    );
  }

  Widget _buildPrimaryAction(bool hasActive) {
    return ElevatedButton.icon(
      onPressed: () async {
        if (hasActive) {
          final activeTrip = _trips.firstWhere((t) =>
              t.status == TripStatus.boarded || t.status == TripStatus.monitoring);
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ActiveTripScreen(trip: activeTrip)),
          );
        } else {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SelectBoardingScreen()),
          );
        }
        _refresh();
      },
      icon: Icon(hasActive ? Icons.location_on_rounded : Icons.play_arrow_rounded),
      label: Text(hasActive ? 'Yolculuğa Devam Et' : 'Yolculuk Başlat'),
    );
  }

  Widget _buildRecentTripsHeader() {
    return const Row(
      children: [
        Text('Son Hareketler', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
      ],
    );
  }

  Widget _buildEmptyTripsState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.divider),
      ),
      child: const Column(
        children: [
          Icon(Icons.directions_transit_rounded, size: 40, color: AppTheme.textSecondary),
          SizedBox(height: 12),
          Text('Henüz yolculuk yok', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
          SizedBox(height: 4),
          Text(
            '"Yolculuk Başlat" ile ilk seyahatini başlat',
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTripTile(Trip trip) {
    final isRefunded = trip.refundAmount != null && trip.refundAmount! > 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.train_rounded, color: AppTheme.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${trip.boardingStation.name} → ${trip.exitStation?.name ?? "..."}',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatDate(trip.startedAt),
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '-₺${trip.chargedFare.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
              ),
              if (isRefunded)
                Text(
                  '+₺${trip.refundAmount!.toStringAsFixed(2)} iade',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.refundGreen),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) {
    const months = ['Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz', 'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara'];
    return '${d.day} ${months[d.month - 1]} ${d.hour.toString().padLeft(2, "0")}:${d.minute.toString().padLeft(2, "0")}';
  }
}
