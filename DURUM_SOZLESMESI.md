# Durum sözleşmesi (v8.838, dal `claude/tutarli-karar`)

Amaç: botlar **aynı durumu aynı yorumlasın** (çelişmesin, titremesin), modüller birbirine dolanmadan **tek bir ortak dil** üzerinden konuşsun.

## 1. Ortak okuyucular (tek tanım)
| Fonksiyon | Ne verir | Seviyeler |
|---|---|---|
| `fnc_baskiEf` | etkin baskı 0–1 = max(motor baskısı, korku × 0.7) | ham değer |
| `fnc_baskiSeviye` | etkin baskının seviyesi (0.3 sn önbellekli) | 0 YOK (<0.15) · 1 HAFİF (<0.35) · 2 ORTA (<0.5) · 3 AĞIR (<0.7) · 4 AŞIRI (≥0.7) |
| `fnc_temasSeviye` | grup temas yaşı | 0 TAZE (≤8 sn) · 1 SICAK (≤30) · 2 ILIK (≤120) · 3 SOĞUK |
| `fnc_korkuDeger` | yakın mermi korkusu 0–1 (6 sn azalır) | ham değer |
| `fnc_emirKilitli` | **hakem**: bu askere şimdi refleks/kozmetik emir verilebilir mi | bool |

**Kural:** yeni kod `getSuppression` ya da `QGVAR(contact)` yaşını ham eşikle OKUMAZ; `baskiSeviye >= N` / `temasSeviye <= N` kullanır. Eşik değiştirmek tek yerden olur.

## 2. Hakem önceliği (kim emir verebilir)
**HAYATTA KALMA** (korku, retreat, temas kes, kaçış, `forceMove`) **> KOMUTAN** (taktik kilidi) **> REFLEKS** (siper mikro, ağaç gizlen, hendek, hava farkındalığı, topçu tepkisi) **> KOZMETİK** (bakış, jest).
Refleks / kozmetik katman `doMove` vermeden önce `[_u] call FUNC(emirKilitli)` sorar; `true` ise vermez. Bağlananlar: `agacGizlen`, `hendekBilinc`, `havaFarkindalik`, `topSiper`. (Önceden kilide hiç bakmayan 25 dosyadan 21'i araç / dron / topçu / komutan-katmanı: bilerek dokunulmadı.)

## 3. Eşik taşıma tablosu (otomatik; tasarım)
Baskı: 0.05–0.2 → **1** · 0.25–0.4 → **2** · 0.45–0.55 → **3** · 0.6 ve ≥0.7 → **4** (0.6 → 4: önceki tasarım 0.6'da "ağır" sayıyordu; 0.7'ye yükseldi, ±0.1 kayma).
Temas yaşı: ≤12 sn → TAZE · 15–45 sn → SICAK · 60–120 sn → ILIK. Taşınan: baskı 84 yer (56 dosya), temas 33 yer (28 dosya). `diag_log` satırları, yorumlar ve `fnc_ozguven` (hesaplama) taşınmadı.
Taşınmayan: ham `getSuppression` kullanımları (ör. `x - y` aritmetiği, değişkenli eşikler) — `tools/mimari_tara.py` kalanı sayar.

## 4. Smooth karar için ilkeler
- Karar değişimi **histerezisli** olmalı (en az bekleme: kaçış kilidi, duruş akıcılığı, mekan sınıfı 60 sn, korku azalması 6 sn zaten var; yeni kod aynısını izler).
- Aynı durumu ölçen iki yer **aynı seviye fonksiyonunu** çağırır (aynı karede aynı cevap: önbellek).
- Bir modül başka modülün iç değişkenini okumaz; ortak durum yalnızca yukarıdaki okuyucular + `fnc_dk` (doktrin) üzerinden.

## 5. Test planı (dal ayrı: sorun çıkarsa `claude/sade-waypoint`'e dönülür)
1. Boot `v8.843`, karne `SURUM` GEÇTİ, script hatası 0.
2. Karar sayıları önceki RPT'lerle benzer: retreat varışı %60+, siper oturtulamadı %0–10, ayakta ≤ %30.
3. `[KORKU-OZET]` var ve baskı seviyeleri tetikleniyor (grup baskısı seviyesi ≥1).
4. Gözlem: botlar vurulunca/yakından ateş alınca **tutarlı** davranıyor mu (bir yerde siper alıp diğerinde ayakta yürümek yok).
