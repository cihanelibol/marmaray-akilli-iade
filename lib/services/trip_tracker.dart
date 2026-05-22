import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../data/stations.dart';

/// İniş tespit algoritmasının parametreleri.
class TripTrackerConfig {
  final double stationApproachRadiusMeters;
  final double stationExitRadiusMeters;
  final double dwellRadiusMeters;
  final double accuracyThresholdMeters;
  final Duration confirmExitAfter;
  final Duration confirmDwellAfter;
  final double dwellSpeedThresholdMps;

  /// Yol C parametreleri ---
  ///
  /// GPS sinyali bu süreden uzun süre kayıpsa "yer altı modu" aktive olur.
  /// Bu süre kısa olursa şehir merkezinde bina arası geçişlerde de tetiklenir,
  /// uzun olursa Boğaz tüneli (~4dk) kaçırılır.
  final Duration signalLossThreshold;

  /// Sinyal geri geldiğinde, kullanıcının iniş istasyonu olarak kabul edilmesi
  /// için en yakın istasyona maksimum mesafe. Bunun dışındaysa hâlâ tünelde
  /// olabilir veya rayda olabilir, bekle.
  final double signalRecoveryStationRadiusMeters;

  /// Sinyal geri geldiğinde, konum güvenli sayılması için minimum accuracy.
  final double signalRecoveryAccuracyThresholdMeters;

  /// Sinyal geri gelince konumun istikrara kavuşması için bekleme süresi.
  /// (İlk birkaç GPS fix'i genelde yanlıştır.)
  final Duration signalRecoveryStabilizationTime;

  const TripTrackerConfig({
    this.stationApproachRadiusMeters = 120,
    this.stationExitRadiusMeters = 50,
    this.dwellRadiusMeters = 30,
    this.accuracyThresholdMeters = 25,
    this.confirmExitAfter = const Duration(seconds: 90),
    this.confirmDwellAfter = const Duration(minutes: 15),
    this.dwellSpeedThresholdMps = 1.5,
    this.signalLossThreshold = const Duration(seconds: 45),
    this.signalRecoveryStationRadiusMeters = 200,
    this.signalRecoveryAccuracyThresholdMeters = 50,
    this.signalRecoveryStabilizationTime = const Duration(seconds: 15),
  });
}

class NearestStationResult {
  final MarmarayStation station;
  final double distanceMeters;
  const NearestStationResult(this.station, this.distanceMeters);
}

enum LocationQuality {
  reliable,
  poorAccuracy,
  outsideDwellRadius,
  movingTooFast,
}

class TripTracker {
  final TripTrackerConfig config;
  TripTracker({this.config = const TripTrackerConfig()});

  static const Distance _distance = Distance();

  Future<bool> ensurePermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    return perm == LocationPermission.always ||
        perm == LocationPermission.whileInUse;
  }

  NearestStationResult nearestStation(LatLng point) {
    MarmarayStation? best;
    double bestDist = double.infinity;
    for (final s in kMarmarayStations) {
      final d = _distance.as(LengthUnit.Meter, point, s.location);
      if (d < bestDist) {
        bestDist = d;
        best = s;
      }
    }
    return NearestStationResult(best!, bestDist);
  }

  Stream<Position> positionStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 3,
      ),
    );
  }

  /// İniş tespit algoritması — üç yollu.
  ///
  /// **Yol A (yer üstü, uzaklaşan kullanıcı):** Bir istasyona yaklaş, 50m
  /// dışına çık, 90sn geri dönme → iade.
  ///
  /// **Yol B (yer üstü, kalan kullanıcı):** Bir istasyonun 30m yakınında
  /// kümülatif 15dk düşük hızla kal (accuracy≤25m) → iade.
  ///
  /// **Yol C (yer altı, sinyal kaybı):** GPS sinyali kesilince son bilinen
  /// istasyon "potansiyel iniş" sayılır. Sinyal geri geldiğinde:
  ///   - En yakın istasyon 200m içindeyse → o istasyon iniş istasyonu
  ///   - Stabilize olma için 15sn beklenir (GPS ilk fix'leri yanlış olabilir)
  ///
  /// Yol C'nin senaryoları:
  /// - Yenikapı'da indi, yer üstüne çıktı, GPS geldi → en yakın Yenikapı → Yenikapı
  /// - Üsküdar'da indi, yer üstüne çıktı → en yakın Üsküdar → Üsküdar
  /// - Sirkeci'de indi, çıktı → en yakın Sirkeci → Sirkeci
  /// - Trende uyuyup geçti, Söğütlüçeşme'de sinyal geldi → Yol A/B normal işler
  Future<MarmarayStation?> trackUntilExit({
    required int boardingOrder,
    Duration timeout = const Duration(hours: 3),
    void Function(TripTrackerEvent event)? onEvent,
  }) async {
    final completer = Completer<MarmarayStation?>();
    MarmarayStation? lastApproachedStation;
    bool currentlyInsideApproach = false;

    // Yol A: 50m dışına çıkma onay timer'ı
    Timer? exitConfirmTimer;

    // Yol B: dwell birikim
    Duration accumulatedDwell = Duration.zero;
    DateTime? lastReliableTickAt;

    // Yol C: yer altı modu
    DateTime? lastReliableSignalAt;
    MarmarayStation? lastKnownStationBeforeTunnel;
    bool inTunnelMode = false;
    DateTime? signalRecoveredAt;
    MarmarayStation? recoveryCandidate;
    Timer? signalStabilizationTimer;

    late StreamSubscription<Position> sub;
    final timeoutTimer = Timer(timeout, () {
      if (!completer.isCompleted) completer.complete(null);
    });

    // Sinyal kaybını izleyen timer — düzenli olarak son fix zamanını kontrol et
    Timer? signalLossWatchdog = Timer.periodic(const Duration(seconds: 10), (_) {
      if (lastReliableSignalAt == null) return;
      final timeSinceLastFix = DateTime.now().difference(lastReliableSignalAt!);
      if (timeSinceLastFix >= config.signalLossThreshold && !inTunnelMode) {
        inTunnelMode = true;
        onEvent?.call(TripTrackerEvent.tunnelEntered(lastKnownStationBeforeTunnel));
      }
    });

    void confirmExit(MarmarayStation station, ExitReason reason) {
      if (completer.isCompleted) return;
      exitConfirmTimer?.cancel();
      signalStabilizationTimer?.cancel();
      signalLossWatchdog?.cancel();
      sub.cancel();
      timeoutTimer.cancel();
      onEvent?.call(TripTrackerEvent.exitConfirmed(station, reason));
      completer.complete(station);
    }

    sub = positionStream().listen((pos) {
      final here = LatLng(pos.latitude, pos.longitude);
      final near = nearestStation(here);
      final speed = pos.speed.isNaN || pos.speed < 0 ? 0.0 : pos.speed;
      final accuracy = pos.accuracy.isNaN ? 999.0 : pos.accuracy;

      final hasReliableSignal =
          accuracy <= config.signalRecoveryAccuracyThresholdMeters;

      // --- Yol C: Sinyal geri geldi mi? ---
      if (inTunnelMode && hasReliableSignal) {
        // Yer altından çıktık! Konumun stabilize olmasını bekle, sonra karar ver.
        if (signalRecoveredAt == null) {
          signalRecoveredAt = DateTime.now();
          recoveryCandidate = near.station;
          onEvent?.call(TripTrackerEvent.tunnelExited(near));

          // Stabilizasyon sonunda iniş kararını ver
          signalStabilizationTimer?.cancel();
          signalStabilizationTimer = Timer(
              config.signalRecoveryStabilizationTime, () {
            if (recoveryCandidate == null) return;

            // En yakın istasyon yeterince yakınsa onayla
            if (near.distanceMeters <=
                config.signalRecoveryStationRadiusMeters) {
              // Kalkış istasyonuysa onaylama (henüz hareket etmemiş olabilir)
              if (recoveryCandidate!.order != boardingOrder) {
                confirmExit(
                    recoveryCandidate!, ExitReason.signalRecovery);
                return;
              }
            }
            // Henüz bir istasyona yakın değil → normal akışa dön
            inTunnelMode = false;
            signalRecoveredAt = null;
            recoveryCandidate = null;
          });
        } else {
          // Stabilizasyon süresince konum güncel candidate'ı takip etsin
          if (near.distanceMeters <=
              config.signalRecoveryStationRadiusMeters) {
            recoveryCandidate = near.station;
          }
        }
        // Tünel modunda normal Yol A/B mantığını çalıştırma
        lastReliableSignalAt = DateTime.now();
        if (near.distanceMeters <= 200) {
          lastKnownStationBeforeTunnel = near.station;
        }
        onEvent?.call(TripTrackerEvent.locationUpdate(
          location: here,
          nearest: near,
          speedMps: speed,
          accuracyMeters: accuracy,
          quality: LocationQuality.reliable,
          accumulatedDwell: accumulatedDwell,
          inTunnel: inTunnelMode,
          lastKnownStation: lastKnownStationBeforeTunnel,
        ));
        return;
      }

      // Normal akış (yer üstü) ---
      if (hasReliableSignal) {
        lastReliableSignalAt = DateTime.now();
        // En yakın istasyon yakındaysa "tünele girmeden önceki son istasyon"
        // bilgisini güncelle
        if (near.distanceMeters <= 500) {
          lastKnownStationBeforeTunnel = near.station;
        }
        // Eğer tünel modundaydı ama hâlâ accuracy iyi değilse beklemeye devam
      }

      LocationQuality quality;
      if (accuracy > config.accuracyThresholdMeters) {
        quality = LocationQuality.poorAccuracy;
      } else if (speed > config.dwellSpeedThresholdMps) {
        quality = LocationQuality.movingTooFast;
      } else if (near.distanceMeters > config.dwellRadiusMeters ||
          near.station.order == boardingOrder) {
        quality = LocationQuality.outsideDwellRadius;
      } else {
        quality = LocationQuality.reliable;
      }

      onEvent?.call(TripTrackerEvent.locationUpdate(
        location: here,
        nearest: near,
        speedMps: speed,
        accuracyMeters: accuracy,
        quality: quality,
        accumulatedDwell: accumulatedDwell,
        inTunnel: inTunnelMode,
        lastKnownStation: lastKnownStationBeforeTunnel,
      ));

      // Tünel modundaysak Yol A/B'yi atla
      if (inTunnelMode) return;

      final isInApproachRadius =
          near.distanceMeters <= config.stationApproachRadiusMeters &&
              near.station.order != boardingOrder;
      final isOutsideExitRadius =
          near.distanceMeters > config.stationExitRadiusMeters;

      if (isInApproachRadius) {
        if (lastApproachedStation?.order != near.station.order) {
          lastApproachedStation = near.station;
          accumulatedDwell = Duration.zero;
          lastReliableTickAt = null;
          onEvent?.call(TripTrackerEvent.approachedStation(near.station));
        }
        currentlyInsideApproach = true;
        exitConfirmTimer?.cancel();
        exitConfirmTimer = null;

        // Yol B
        final now = DateTime.now();
        if (quality == LocationQuality.reliable) {
          if (lastReliableTickAt != null) {
            accumulatedDwell += now.difference(lastReliableTickAt!);
          }
          lastReliableTickAt = now;

          if (accumulatedDwell >= config.confirmDwellAfter) {
            confirmExit(lastApproachedStation!, ExitReason.dwellAtStation);
            return;
          }
        } else {
          lastReliableTickAt = null;
        }
      } else if (currentlyInsideApproach &&
          isOutsideExitRadius &&
          lastApproachedStation != null) {
        currentlyInsideApproach = false;
        accumulatedDwell = Duration.zero;
        lastReliableTickAt = null;

        onEvent?.call(TripTrackerEvent.leftStation(lastApproachedStation!));

        exitConfirmTimer?.cancel();
        exitConfirmTimer = Timer(config.confirmExitAfter, () {
          if (lastApproachedStation != null) {
            confirmExit(lastApproachedStation!, ExitReason.walkedAway);
          }
        });
      }
    });

    final result = await completer.future;
    exitConfirmTimer?.cancel();
    signalStabilizationTimer?.cancel();
    signalLossWatchdog?.cancel();
    timeoutTimer.cancel();
    await sub.cancel();
    return result;
  }
}

enum ExitReason {
  /// Yol A: İstasyondan 50m+ uzaklaştı, 90sn geri dönmedi.
  walkedAway,

  /// Yol B: İstasyon yakınında 15dk düşük hızla kaldı.
  dwellAtStation,

  /// Yol C: GPS sinyali yer altında kaybolup yer üstünde bir istasyon
  /// yakınında geri geldi.
  signalRecovery,
}

sealed class TripTrackerEvent {
  const TripTrackerEvent();

  factory TripTrackerEvent.locationUpdate({
    required LatLng location,
    required NearestStationResult nearest,
    required double speedMps,
    required double accuracyMeters,
    required LocationQuality quality,
    required Duration accumulatedDwell,
    required bool inTunnel,
    required MarmarayStation? lastKnownStation,
  }) = LocationUpdateEvent;

  factory TripTrackerEvent.approachedStation(MarmarayStation s) =
      ApproachedStationEvent;
  factory TripTrackerEvent.leftStation(MarmarayStation s) = LeftStationEvent;
  factory TripTrackerEvent.tunnelEntered(MarmarayStation? lastKnown) =
      TunnelEnteredEvent;
  factory TripTrackerEvent.tunnelExited(NearestStationResult recovery) =
      TunnelExitedEvent;
  factory TripTrackerEvent.exitConfirmed(MarmarayStation s, ExitReason r) =
      ExitConfirmedEvent;
}

class LocationUpdateEvent extends TripTrackerEvent {
  final LatLng location;
  final NearestStationResult nearest;
  final double speedMps;
  final double accuracyMeters;
  final LocationQuality quality;
  final Duration accumulatedDwell;
  final bool inTunnel;
  final MarmarayStation? lastKnownStation;
  const LocationUpdateEvent({
    required this.location,
    required this.nearest,
    required this.speedMps,
    required this.accuracyMeters,
    required this.quality,
    required this.accumulatedDwell,
    required this.inTunnel,
    required this.lastKnownStation,
  });
}

class ApproachedStationEvent extends TripTrackerEvent {
  final MarmarayStation station;
  const ApproachedStationEvent(this.station);
}

class LeftStationEvent extends TripTrackerEvent {
  final MarmarayStation station;
  const LeftStationEvent(this.station);
}

class TunnelEnteredEvent extends TripTrackerEvent {
  final MarmarayStation? lastKnownStation;
  const TunnelEnteredEvent(this.lastKnownStation);
}

class TunnelExitedEvent extends TripTrackerEvent {
  final NearestStationResult recovery;
  const TunnelExitedEvent(this.recovery);
}

class ExitConfirmedEvent extends TripTrackerEvent {
  final MarmarayStation station;
  final ExitReason reason;
  const ExitConfirmedEvent(this.station, this.reason);
}
