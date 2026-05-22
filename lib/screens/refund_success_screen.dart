import 'package:flutter/material.dart';
import '../models/trip.dart';
import '../theme/app_theme.dart';

class RefundSuccessScreen extends StatelessWidget {
  final Trip trip;
  const RefundSuccessScreen({super.key, required this.trip});

  @override
  Widget build(BuildContext context) {
    final stops = (trip.exitStationOrder! - trip.boardingStationOrder).abs();
    final actualFare = trip.chargedFare - trip.refundAmount!;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 600),
                curve: Curves.elasticOut,
                builder: (_, value, child) => Transform.scale(scale: value, child: child),
                child: Container(
                  width: 100, height: 100,
                  decoration: BoxDecoration(
                    color: AppTheme.refundGreen,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: AppTheme.refundGreen.withOpacity(0.4), blurRadius: 24, spreadRadius: 4),
                    ],
                  ),
                  child: const Icon(Icons.check_rounded, color: Colors.white, size: 56),
                ),
              ),
              const SizedBox(height: 28),
              const Text('İade Tamamlandı',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
              const SizedBox(height: 6),
              Text(
                '${trip.exitStation!.name} istasyonunda inişiniz onaylandı',
                style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.divider),
                ),
                child: Column(
                  children: [
                    Text(
                      '+₺${trip.refundAmount!.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.refundGreen,
                        letterSpacing: -1,
                      ),
                    ),
                    const Text('İade tutarı', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    const SizedBox(height: 16),
                    const Divider(color: AppTheme.divider),
                    const SizedBox(height: 12),
                    _row('Geçilen durak', '$stops durak'),
                    const SizedBox(height: 8),
                    _row('Girişte alınan', '₺${trip.chargedFare.toStringAsFixed(2)}'),
                    const SizedBox(height: 8),
                    _row('Gerçek ücret', '₺${actualFare.toStringAsFixed(2)}'),
                    const SizedBox(height: 8),
                    _row('Rota',
                        '${trip.boardingStation.name} → ${trip.exitStation!.name}',
                        small: true),
                  ],
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
                  child: const Text('Ana Sayfaya Dön'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String value, {bool small = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
        Flexible(
          child: Text(
            value,
            style: TextStyle(
              fontSize: small ? 12 : 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}
