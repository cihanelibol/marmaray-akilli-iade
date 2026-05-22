# Marmaray Akıllı İade

> Marmaray'da QR ile geçen yolcular için konum tabanlı otomatik iade prototipi.
> Telefonu cebe koy, iniş istasyonunda iade bildirim olarak gelsin.


## Hikaye

3 haftadır her sabah Marmaray ile işe gidiyorum. QR ile geçiyorum, ₺74,70 girişte alınıyor (en uzun mesafe ücreti), inişte iade makinesine giderek fark iade alıyorum. Yoğun saatlerde makinenin önündeki kuyruk dakikalara çıkıyor.

Kart kullananlar için makineye temas zorunlu, anladım. Ama mobil QR ile geçen biri için bu ikinci adım niye var? Telefon zaten cebimde, konum zaten biliniyor.

Hafta sonu oturup yazdım. 21 Mayıs 2026 sabahı gerçek Marmaray hattında test ettim, çalıştı.

## Test Sonucu

| Saat | Olay |
|------|------|
| 07:18 | Küçükçekmece , yolculuk başladı, ₺74,70 girişte alındı |
| 07:19 | Telefon cebe |
| 07:58 | Yenikapı, iniş, ₺33,70 otomatik iade bildirimi |

Makineye gitmedim. Kuyruğa girmedim. 10 durak gittim, mesafe farkı otomatik bakiyeye yansıdı.

## Nasıl Çalışıyor?

GPS + hız + konum doğruluğu birlikte analiz ediliyor. Üç farklı yolcu senaryosu için ayrı algoritma:

### Yol A , Yer üstü, uzaklaşan yolcu
İstasyona yaklaş, 50m dışına çık, 90 saniye geri dönme → iade onayı.

### Yol B , İstasyon dibinde çalışan/yaşayan yolcu
İstasyonun 30m yakınında, GPS accuracy ≤25m, hız ≤5.4 km/h koşulları kümülatif 15 dakika sağlandığında → iade onayı.

### Yol C , Yer altı istasyonlar (Yenikapı, Sirkeci, Üsküdar)
GPS sinyali kesildi → "tünel modu" aktive, son istasyon hafızada tutulur. Sinyal geri geldiğinde 15 saniye stabilizasyon → en yakın istasyon 200m içindeyse iade onayı.

**Güvenlik felsefesi:** konum kalitesi yetersizse sistem hiç karar vermez. Yanlış iade riski minimize edilir.

## Mimari

```
lib/
├── data/stations.dart              43 Marmaray durağı
├── models/trip.dart                Yolculuk modeli
├── services/
│   ├── fare_calculator.dart        Mesafe → ücret
│   ├── trip_tracker.dart           Konum izleme + 3 algoritma
│   ├── trip_storage.dart           Lokal geçmiş
│   └── notification_service.dart   İade bildirimleri
├── theme/app_theme.dart            Tasarım
└── screens/                        UI ekranları
```

## Kurulum

```bash
git clone https://github.com/cihanelibol/marmaray-akilli-iade.git
cd marmaray-akilli-iade
flutter create --platforms=ios .
flutter pub get
cd ios && pod install && cd ..
flutter run
```

---

## Bu Bir Prototip , Production'a Geçiş İçin

Bu kod, **konseptin teknik fizibilitesini gösteren** açık kaynak bir prototip. Gerçek bir ulaşım operatöründe canlı kullanım için aşağıdaki çalışmaların yapılması gerekir. Mevcut prototip bu konuların hiçbirini içermez , sadece konsept doğrulaması yapar.

### 1. Güvenlik Katmanı

- **GPS spoofing tespit ve önleme** , Sensor fusion (ivmeölçer, jiroskop, manyetometre ile GPS tutarlılığı), spatial-temporal anomaly detection, ML tabanlı kullanıcı desen analizi
- **Cihaz güvenliği** , Jailbreak/root tespiti, attestation API entegrasyonu (Apple App Attest, Google Play Integrity)
- **API güvenliği** , Token-based auth, rate limiting, replay attack koruması

### 2. Server Tarafı Mimari

- **Yolculuk state management** , Lokal değil, server'da takip
- **Telefon kapalıyken kurtarma akışı** , Askıda yolculuk tespit, manuel onay flow'u
- **Anomali ve fraud tespit** , Şüpheli yolculukları işaretle, manuel inceleme
- **Audit log** , Her iade kararının izlenebilir kaydı

### 3. Belbim / İBB / TCDD Entegrasyonu

- **Mevcut sistem mimarisi keşfi** , Hangi API'ler mevcut, hangi yeni endpoint'lere ihtiyaç var
- **NFC kart ↔ Mobil QR eşleştirme** , Kullanıcı kimliği nasıl tutulur
- **Gerçek bakiye değişikliği akışı** , İade onaylandığında para nasıl döner
- **PCI-DSS uyumluluk** , Eğer kart bilgisi varsa

### 4. Algoritma Optimizasyonu

- **Parametre tuning** , 50m, 90sn, 30m, 15dk gibi değerler prototip için seçildi. Production'da gerçek kullanıcı verisi ile A/B test ile optimize edilmeli
- **Edge case'ler** , Tren arızası, uzun bekleme, çoklu yolcu hareketi, özel günler
- **Yer altı duraklar için gelişmiş çözümler** , BLE beacon hibrit, UHF RFID, hücre kulesi triangulation
- **Engelli yolcular için özel akış** , Erişilebilirlik gereksinimleri

### 5. Pilot ve Rollout Stratejisi

- **Limited pilot** , Belirli durak/saat aralığında küçük kullanıcı grubuyla başla
- **A/B karşılaştırma** , Yeni sistem vs. eski iade makinesi UX
- **Kademeli rollout** , Hat hat, durak durak yaygınlaştırma
- **Manuel iade fallback** , İade makineleri kapatılmadan paralel çalıştırılmalı

### 6. Operasyonel

- **Müşteri hizmetleri akışı** , "İademi alamadım" şikayetleri nasıl çözülür
- **Yasal/regülatif uyum** , KVKK, konum verisi saklanma süresi, kullanıcı rızası
- **Performans ve maliyet** , Ölçekte konum verisi işleme, sunucu maliyetleri

## İletişim

**Cihan Elibol**
[LinkedIn](https://www.linkedin.com/in/cihanelibol/) · cihanelibol47@gmail.com

Kod açık kaynak, MIT lisansı altında özgürce kullanılabilir. Yukarıdaki **production roadmap'i** hakkında danışmanlık, prototipi gerçek sistemle entegre etme veya geliştirme için iş birliğine açığım. Belbim, İBB, İstanbul Ulaşım, TCDD veya benzeri kurumların ekipleriyle görüşmeye ve katkı vermeye gönüllüyüm.

## Tarife (Şubat 2026)

| Durak aralığı | Tam bilet |
|---|---|
| 1-7 | ₺34,00 |
| 8-15 | ₺41,00 |
| 16-23 | ₺47,50 |
| 24-30 | ₺54,00 |
| 31-35 | ₺64,50 |
| 36-43 | ₺74,70 |

## Lisans

[MIT](LICENSE) , açık kaynak, ticari kullanım dahil her kullanıma izinlidir.
