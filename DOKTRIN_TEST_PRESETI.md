# Doktrin test preset'i (v8.833)

Dosya: `CBA_LAMBS_Danger_DOKTRIN_TEST_v8.833.txt` (deponun kökünde). Kendi dosyanın (`CBA_LAMBS_Danger_v8.833.txt` = senin değerlerin + yeni anahtarlar) üstüne **90 satır** değişiklik; geri kalan 615 satır aynı.
İçe aktarma: CBA → Eklenti Ayarları → içe aktar (ya da dosyayı `userconfig`/profil CBA ayar dosyasının yerine koy). Eski haline dönmek için `CBA_LAMBS_Danger_v8.833.txt`'i aktar.

## Amaç
Doktrine uygun, zeki ve insansı bot: **ölmemek için** elinden geleni yapar (siper, geri çekilme, kaçış, duruş disiplini, sis, bastırma altında tepki), **öldürmek için** elinden geleni yapar (bastırma + manevra, kanat, bomba, bina girişi, RPG, CQB isabeti). **Teslimiyet kapalı.** Test ölçümleri açık.

## Değişenler (özet)
| Grup | Ayar | Eski → Yeni | Neden |
|---|---|---|---|
| **Teslimiyet KAPALI** | `teslimV1` (ana anahtar) | false → false (zaten kapalıydı) | Ana anahtar kapalıyken kimse teslim olmaz |
| | `teslimWest/East/Ind`, `teslimDuzensiz`, `teslimDron`, `teslimBomba`, `teslimBirey` | → false | Hiçbir yoldan teslim ya da "son anda koşan teslim" yok |
| **Beceri (insani)** | `skillIsabetMin/Max` | taraf bazlı 0.08–0.24 (EAST/IND), 0.65–0.92 (WEST) → **0.20–0.40 herkes** | Gerçekçi tablo (kalibrasyon: kitapta sayı yok = tasarım) |
| | `skillTitremeMin/Max` (aimingShake) | WEST **0.02–0.08**, EAST/IND 0.22–0.42 → **0.35–0.55** | **Önemli:** aimingShake'te yüksek = silah az sallanır. WEST'te 0.02–0.08 maksimum sallanma demek, yüksek isabet değerlerini ve CQB'de 131 atışta 0 isabeti açıklar |
| | `skillTavanIsabet` | 0.30 (EAST/IND), 0.95 (WEST) → **0.45** | Kusursuz nişan yok (insan sınırı) |
| | `skillHiz*`, `skillFark*` | 0.55–0.82 / 0.65–0.88; WEST 0.88–1.0 → **0.70–0.90** | WEST'in 1.0 değeri insanüstü |
| | `skillAcemiOran` / `skillAcemiCarpan` | 0.45 / 0.6 → **0.15 / 0.75** | Askerlerin %45'i acemi olmasın |
| | `dogrulukMaks` | 0.08 (EAST/IND), 0.55 (WEST) → **0.15** | Seri atışta nişan artışı makul |
| **Algı (anlık değil)** | `hizliFarkS` / `hizliFarkSeviye` / `hizliFarkAci` / `hizliFarkM` | WEST 0.15 sn / 2.8 → **0.5 sn / 1.5 / 65° / 120 m** | RPT'de görünür→fark ort. 0.09 sn (insanüstü); hedef 0.8–2.5 sn |
| | `reaksiyonArtis` | 0.85 → **0.30** | Düşünme gecikmesi aşırı büyütülmesin |
| **Hayatta kalma** | `kacisBireysel`, `siperDurusCesit` (0.5 → 0.25), `durusKati`, `siperAyaktaYok`, `siperDurusTut`, `vurulmaTepki`, `hareketDestek`, `hareketKurtar*`, `mgOnde` ... | açık | Tek kalan kaçar, siperde ayakta durulmaz, vurulunca siper değişir |
| | `cekilKosuModu` | true → **false** | Takılan koşucuyu AWARE + hedef alma kapalı yapıyordu (karşılık vermiyordu, "çatışmada AWARE geçiyor") |
| **Öldürme** | `rpgZorlaAtis` false → true, `cqbBomba`, `cqbOlumcul`, `binaSaldiri`, `binaGirisBomba`, `pencereAtesi`, `penetreAtes`, `yakinAtes`, `mgDestek`, `kanatBounding`, `kanatZamanli`, `ikiliSicrama`, `isabetCqbYardim` 0.45 / `isabetCqbM` 25 / `isabetYakinYardim` 0.15 | açık | Bastırma + manevra, CQB isabeti |
| **Doktrin** | `mekanDoktrin`, `tehlikeAcikAktif/Dolas`, `hakimNokta`, `avantajliYer`, `rolDisiplini`, `sektorPlan` | açık | Arazi/mekâna göre sayılar, tehlike alanı, hâkim nokta |
| **Test / log** | `durumLogOff` true → **false**, `perfOlcum`, `fovOlcum`, `ongoruOlcum`, `coverOlcum` | açık | RPT'de karne verisi |

Tam fark listesi: `CBA_LAMBS_Danger_v8.833.txt` ile `diff`.

## Doktrin dayanağı (depodaki kaynaklar; sayılar tasarım = T)
- Bastırma + manevra, bounding overwatch, tehlike alanları: TC 3-21.76 (Bölük/manga saldırısı, Danger Areas 6-8), MCWP 3-11.2 (manga), MCWP 3-11.1.
- Temas kesme / geri çekilme: TC 3-21.76 Break Contact; `kacis*`, `erkenCekilme`.
- Bina savaşı (MOUT): ATP 3-21.8 / MCWP 3-11.2 (kapı yığılma, eşzamanlı giriş, oda temizleme): `binaSaldiri`, `binaGirisBomba`.
- Beceri tablosu: kalibrasyon araştırması (200–300 m açık nişangâh ~%55–71, optikli ~%87–90) — kesin sayı kitapta yok.

## Bilinen riskler (T, denenmedi)
- `rpgZorlaAtis = true`: motor görünmeyen hedefe atmıyor, zorla atış konumu görmeden ateşletebilir. Rahatsız ederse kapat.
- WEST'in üstünlüğünü (0.65–0.92 isabet vb.) kaldırır: tarafların farkı yok. Asimetri istiyorsan WEST için `skill*West` ve `hizliFark*West` değerlerini elle yükselt, ama `skillTitremeMin/MaxWest` **yüksek** (0.5+) olsun (düşük = çok sallanır).

## Test planı
1. İlk RPT'de boot satırı `v8.833` ve karne `SURUM` GEÇTİ olmalı.
2. CQB: karne `BOT ISABET` < 50 m bandı hedef %10–20 (en az 10 isabet), `GENEL MERMI / ISABET` 30–100.
3. Reaksiyon: `REAKSIYON` ort. 0.8–2.5 sn.
4. Teslimiyet: `[TESLIM]` satırı olmamalı.
5. Cover/duruş: `GIZLENME / DURUS` ayakta ≤ %30.
6. Bina: `BINA-SALDIRI-OZET` `GIRIS_BASLATILDI` > 1 (oyuncu bina içindeyken).
