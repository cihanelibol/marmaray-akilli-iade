import 'package:flutter/material.dart';
import '../models/trip.dart';
import '../services/trip_storage.dart';
import '../theme/app_theme.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _storage = TripStorage();
  List<Trip> _trips = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final trips = await _storage.loadAll();
    if (mounted) setState(() => _trips = trips);
  }

  @override
  Widget build(BuildContext context) {
    final totalRefund = _trips
        .where((t) => t.refundAmount != null)
        .fold(0.0, (sum, t) => sum + t.refundAmount!);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Geçmiş Hareketler'),
        actions: [
          if (_trips.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Tümünü sil?'),
                    content: const Text('Tüm yolculuk geçmişiniz silinecek.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
                      TextButton(
                        style: TextButton.styleFrom(foregroundColor: AppTheme.danger),
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Sil'),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await _storage.clear();
                  _load();
                }
              },
            ),
        ],
      ),
      body: _trips.isEmpty
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.history_rounded, size: 48, color: AppTheme.textSecondary),
                  SizedBox(height: 12),
                  Text('Henüz yolculuk yok', style: TextStyle(fontSize: 16, color: AppTheme.textSecondary)),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.refundGreen.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.refundGreen.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.savings_rounded, color: AppTheme.refundGreen),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Toplam iade', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                            Text(
                              '₺${totalRefund.toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.refundGreen),
                            ),
                          ],
                        ),
                      ),
                      Text('${_trips.length} yolculuk',
                          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ..._trips.map(_buildTile),
              ],
            ),
    );
  }

  Widget _buildTile(Trip trip) {
    Color statusColor;
    String statusLabel;
    switch (trip.status) {
      case TripStatus.refunded:
        statusColor = AppTheme.refundGreen;
        statusLabel = 'İade alındı';
        break;
      case TripStatus.cancelled:
        statusColor = AppTheme.danger;
        statusLabel = 'İptal';
        break;
      default:
        statusColor = AppTheme.accent;
        statusLabel = 'Devam ediyor';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(statusLabel,
                    style: TextStyle(fontSize: 10, color: statusColor, fontWeight: FontWeight.w700)),
              ),
              const Spacer(),
              Text(_formatDate(trip.startedAt),
                  style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(trip.boardingStation.name,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                    const SizedBox(height: 2),
                    Row(children: [
                      const Icon(Icons.arrow_downward_rounded, size: 12, color: AppTheme.textSecondary),
                      const SizedBox(width: 4),
                      Text(trip.exitStation?.name ?? '—',
                          style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, fontWeight: FontWeight.w500)),
                    ]),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('-₺${trip.chargedFare.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                  if (trip.refundAmount != null && trip.refundAmount! > 0)
                    Text('+₺${trip.refundAmount!.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 12, color: AppTheme.refundGreen, fontWeight: FontWeight.w700)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) {
    const months = ['Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz', 'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara'];
    return '${d.day} ${months[d.month - 1]} • ${d.hour.toString().padLeft(2, "0")}:${d.minute.toString().padLeft(2, "0")}';
  }
}
