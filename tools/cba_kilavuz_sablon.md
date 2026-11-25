# LAMBS Danger ELITE (sade-waypoint) — CBA Ayarları Kullanım Kılavuzu

Sürüm: {SURUM} · Preset: {PRESET} · {SAYI} CBA ayarı · Tüm ayarlar oyunda **CBA → Eklenti Ayarları → LAMBS Danger** altında. Oyun içinde her ayarın açıklaması ipucu metninde de yazıyor.

## 1. Preset nasıl kullanılır

1. {PRESET} dosyasını indirin.
2. CBA Ayarları → ilgili sekmede **Preset / İçe aktar** (ya da dosyadaki `force lambs_danger_… = değer;` satırlarını tek tek girin).
3. Sunucuda `force` satırları istemci ayarını ezer; tek oyunculu testte oyuna yeniden başlamak gerekmez (görev yeniden başlatın).
4. Bir ayarı kapatıp açarak etkisini RPT'deki ilgili `[...]` logundan doğrulayın (aşağıda her bölümde yazılı).

## 2. Hızlı profiller (sık kullanılanlar)

### RPG (roketatar)
| Ayar | Anlam | Önerilen (güçlü) | Sınır |
|---|---|---|---|
| `rpgSistem` | atış kapısı + ölçüm (kapalı = hiçbir şey yapmaz) | açık | – |
| `rpgKarar` | MG yuvası / binadaki düşman / küme / tek hedefe roketatar emri | açık | – |
| `rpgTekHedef` | tek görünen piyadeye de roket | açık | – |
| `rpgOyuncuOncelik` | insan oyuncuyu önce hedefle | açık | – |
| `rpgMuhimmat` / `rpgMuhimmatAdet` / `rpgMuhimmatDegis` | piyadeye uygun (AP) roket taşı, yüklü AT mermisini AP ile değiştir | açık / 3 / açık | 1–3 |
| `rpgIsabetDuzeltme` | roket yönünü hedefin önceden tahmin edilen konumuna çevir (tiradorun `aimingAccuracy` becerisine bağlı, hilesiz) | 1 | 0–1 |
| `rpgDurAt` | hareket ederken durup ateş et | açık | – |
| `rpgSilahKoru` | ateşten önce tüfeğe geçerse roketatarı geri seç | açık | – |
| `rpgZorlaAtis` | atmazsa `fireAtTarget` ile zorla (isabeti düşürür) | **kapalı** | – |
| `rpgAtisGecikme` | ateş emri gecikmesi (sn) | 0 | 0–3 |
| `atAtisGecikme` | zırha atan AT'de silah seçimi → ateş (sn) | 0.3 | 0.3–8 |
| `atDirekt` | zırhı görüyorsa yer değiştirmeden at | açık | – |
| `zirhKacis` | AT'siz grup zırhtan kaçsın mı | kapalı = kaçmaz | – |
| `rpgTaramaS` / `rpgBekleS` / `rpgGrupBekleS` | karar tarama / birim bekleme / grup içi aralık (sn) | 0.3 / 5 / 0 | 0.3–5 / 5–120 / 0–30 |
| `rpgYedek` | zırh için saklanan roket sayısı | 0 (vahşi) / 1–2 (dengeli) | 0–4 |
| `rpgMinM` / `rpgMaxM` / `rpgDostM` | en yakın / en uzak atış, düşüşte dost yarıçapı (m) | 10–15 / 350–600 / 4–10 | 10–80 / 100–600 / 4–40 |

Loglar: `[RPG-KARAR]`, `[RPG-KARAR-OZET]`, `[RPG-ATIS]`, `[RPG-IPTAL]`, `[RPG-ZAMAN]`, `[RPG-IZI]` (isabet ölçümü, ≤10 m = isabet), `[RPG-DUZELTME]`.
Not: 600 m'de güdümsüz roketin isabeti düşer; isabet için `rpgMaxM = 350`, `rpgZorlaAtis = false`.

### Reaksiyon / algı
| Ayar | Anlam | Önerilen |
|---|---|---|
| `reaksiyonArtis` | tüm botların karar/tepki hızı çarpanı | 0.8–1 |
| `hizliFark*` | görünen insan oyuncuyu hızlı fark etme (`hizliFarkS` 0.3 sn, `hizliFarkM` 200 m) | açık |
| `bilgiArtis` / `bilgiTaban` | bilinen hedefin bilgi artışı / tabanı | 0.8–1 / 3.0 |
| `temasCombat` | düşman görününce AWARE → COMBAT | açık |

### Siper (cover)
| Ayar | Anlam | Not |
|---|---|---|
| `siperCokAcili` / `siperCokAciliAg` | siper adayını ±35/±70° atıcı konumlarından sına | 6 puan |
| `siperArazOncelik` | arazi çukuru / yamacı nesne siperine karşı öncelik (v8.788: 4 → 8; "sert siper yok" kalibrasyonu) | 8 (0–12) |
| `siperKentselArazi` | kentselde arazi çukuruna ceza (v8.788: 6 → 2; duvar/ev güvenilmez) | 2 (0–20) |
| `bndSiperSnap` / `bndSiperSnapM` | sıçrama/geri çekilme varış noktasını siperin arkasına oturt | açık / 12 m |
| `siperSafCeza` / `siperKarsilikBonus` | ateş edemeyen saklanma cezası / karşılık verebilen siper bonusu | 14 / 6 |
| `vurulmaGercekYon` / `vurulmaKilitAs` | vurulunca gerçek vuruş yönüyle, taktik kilidini aşarak yeni siper | açık |
| `siperDusuk` | siperde duruş ne kadar alçak | 2 |

### Duruş / hareket
| Ayar | Anlam | Not |
|---|---|---|
| `durusDisiplin` / `durusDisiplinSn` | temasta hareketsiz asker ayakta kalmaz | açık / 1–2 sn |
| `durusYatMesafe` | düşman bu mesafeden uzak + hat açıksa yat | 60–150 m |
| `durusAkici*` | yat-kalk salınımını sönümle (kilit yatık/çömelik durumu korur) | kilit 10 sn |
| `hareketDestekS` | takılan askere ilk yeniden emir süresi | 3 sn |
| `animHiz` | bot animasyon hızı artışı (%) | oyuncu grubuna da `oyuncuGrubuBot` ile |

### Duman (smoke)
| Ayar | Anlam | Not |
|---|---|---|
| `sisPerde` / `sisPerdeAdet` / `sisPerdeAralik` | olay başına çok dumanlı perde, dik hat | açık / 3 / 9 m |
| `sisPerdeRuzgar` / `sisPerdeTasi` | rüzgâr telafisi 4 sn / en az 2 duman taşı | açık |
| `sisButceMax` / `sisGrupAralik` | taraf bütçesi (120 sn'de olay) / grup aralığı | 3 / 90 sn |

### Bastırma / diğer
| Ayar | Anlam |
|---|---|
| `baskiKapisi` / `baskiYakinM` / `baskiGozlemciM` | uzak + gözlemcisiz bastırma yok (80 / 250 m) |
| `baskiBombaci` | koşan piyade bombacıya bastırma ateşi yok, bombacı da bastırma atmaz (araç bombası hariç) |
| `oyuncuGrubuBot` | oyuncu grubundaki botlar da düşman kadar güçlü/hızlı |
| `bombaYuzYuzeM` | yüz yüze el bombası yasağı (20 m) |

### Bomba / EYP / canlı bomba / teslim bomba (v8.775–v8.791)
| Ayar | Anlam | Kod varsayılanı / öneri |
|---|---|---|
| `canliBomba` | grup ağır kayıpta (≤ 2 canlı ya da kayıp ≥ %60) bilinen düşman menzildeyse hedefe en yakın sağlıklı askeri **otomatik** canlı bomba yapar | kapalı / açık |
| `canliBombaMax` | taraf başına 600 sn'de en çok kaç olay | 1 (1–5) |
| `canliBombaMenzilM` | lider–düşman mesafesi bu değerin altındaysa seçilir | 150 (50–300) |
| `canliBombaTetikM` | patlama mesafesi (hedef ya da herhangi bir düşman bu kadar yakına girince) | 5 (3–12); Zeus/3DEN'de 8 |
| `canliBombaCatis` | KAPALI = **agresif** (baştan sprint, hedef almaz, ateş için durmaz); AÇIK = çatışarak (hedef alır ama AI durup ateş eder, yavaş) | kapalı |
| `canliBombaAtilmaM` / `canliBombaAracAtilmaM` | piyade / araç son-an sprint–tam gaz mesafesi | 45 / 120 |
| `canliBombaOlumSans` | hedefe varamadan vurulursa cihazın ölünce patlama olasılığı | 0.5 (0–1) |
| `canliBombaTereddutS` | menzile girince rastgele 0.5 – bu kadar sn duraksar, sonra patlar (araç hariç); 0 = tereddüt yok | 3 (0–8) |
| `eypPatlamaGucu` | 0 hafif (DemoCharge) · 1 orta · 2 referans (araç GBU-12: ölüm yarıçapı çok büyük) | 1 (0–2) |
| `eypKur` / `eypButce` / `eypAralikS` | geri çekilen grup düşman yönüne tuzak kurar; taraf başına eşzamanlı tuzak; grup başına aralık (sn) | kapalı / 3 / 180 |
| `eypKomutlu` | tuzak = komutla patlayan EYP pususu (kur, gözetle, düşman 12 m'ye girince patlat) | açık |
| `eypStandoffCarpan` | IED emniyet çemberi çarpanı (ATP 3-34.20) | 1 (öneri 1.5) |
| `teslimBomba` / `teslimBombaSans` / `teslimBombaTabanca` | teslim olmuş ve üzerinde patlayıcı olan (ya da şansla gizli cihaz taşıyan) düşman, son anda kalkıp koşar; silahı yoksa gizli tabanca | kapalı / 0 / açık |

**Zeus / 3DEN / editör init satırı** (CBA'dan bağımsız çalışır): Zeus'ta *ELITE Canlı Bomba (PBIED / VBIED)* ve *ELITE EYP Kur*, 3DEN'de aynı adlı modüller (SYNC). Init satırı: `[this] call lambs_danger_fnc_eypBombaYap;` ya da `[this, [menzil, tarz, sonAn, güç, ölümŞansı, hedefTaraf, varil, patlamaMesafesi, tereddütSn]] call lambs_danger_fnc_eypBombaYap;` (tarz: 0 çatışarak, 1 gizli, 2 agresif; −1 = CBA değeri). EYP kurucu: `[this, getMarkerPos "eyp", getMarkerPos "pusu"] spawn lambs_danger_fnc_eypKomut;`.

### Mekanize (BMP / BTR / kamyon) (v8.789)
| Ayar | Anlam | Kod varsayılanı |
|---|---|---|
| `mekanizeHareket` | ≥ 2 AI yolcu taşıyan IFV / APC / kamyon temas + bilinen düşman iniş eşiğinde (ya da hasar / baskı / hareketsiz) durup yolcusunu indirir | açık |
| `mekanizeInisCarpan` | iniş mesafesi çarpanı (taban: doktrin `mekInisM` 300 m; ABD/USMC 350, RUS 200, CHN 220, PESHMERGA 250, DUZENSIZ 280; sınıf: IFV ×0.85 / APC ×1 / kamyon ×1.3) | 1 (0.5–2) |
| `mekanizeDestekS` | indikten sonra IFV'nin yerinde ateş desteği süresi (sn) | 30 (10–120) |
| `mekanizeRezervM` | APC / kamyonun düşmandan geriye çekilme mesafesi (m); 90 sn bekler | 120 (60–250) |

### Hostile act: ölü / baygına yere ateş (v8.789–v8.790)
| Ayar | Anlam | Kod varsayılanı |
|---|---|---|
| `yereAtes` | 0 doktrine göre (DUZENSIZ 0.7, PESHMERGA 0.35, RUS 0.15, diğerleri 0) · 1 hep (olasılık 1) · 2 kapalı | 0 |
| `yereAtesBaygin` | baygın (INCAPACITATED / UNCONSCIOUS / ACE) düşmana magdump | açık |
| `yereAtesOlu` | taze (≤ 120 sn) ölü düşman gövdesine magdump | açık |
| `yereAtesOyuncu` | baygın oyuncuyu da hedef say (revive için captive olsa da; teslim / kelepçeli hariç) | açık |
| `yereAtesM` / `yereAtesMermi` | menzil (m) / boşaltılan mermi (hep modunda; doktrine göre modunda doktrinin değeri) | 40 / 30 |

Koşullar: grubun lideri 100 m içinde canlı bilinen düşman görmüyor, 3 m içinde dost yok, görüş hattı açık, en çok 2 asker, 25 sn bekleme. Teşhis: RPT'de `[YERE-ATES]` ve `[YERE-ATES-OZET]` sayaçları.

### Motor sesi duyma (v8.792; kategori "ELITE zirh / mekanize")
| Ayar | Anlam | Kod varsayılanı |
|---|---|---|
| `motorSes` | düşman AI gruplarının çalışan araç / heli / uçak motorunu duyması (aç / kapa) | açık |
| `motorSesCarpan` | TÜM motor sesi taban menzilleri (tank 900 / IFV-APC 700 / kamyon-cip 500 / heli 2500 / uçak 2500–4000 m) çarpanı | 1 (0.2–3) |
| `motorSesZirhCarpan` / `motorSesHafifCarpan` / `motorSesHavaCarpan` | sınıf başına ek çarpan | 1 |
| `motorSesRolanti` | duran motor (< 3 km/s) menzil çarpanı | 1 (0.2–2) |
| `motorSesTemasCarpan` | dinleyici temastayken (çatışma sesi bastırır) çarpan | 0.4 (0.1–1) |
| `motorSesArazi` | araya arazi girince çarpan | 0.6 (0.2–1) |
Tepki: grup AWARE olur ve hata paylı yöne bakar (konum bilgisi verilmez).

## 3. Sık sorulanlar
- **Kodu değiştirmeden isabet nasıl artar?** `rpgIsabetDuzeltme = 1`, beceri ayarları (`skillIsabet*`, `skillTavanIsabet`, `skillCarpan`) en üstte, `rpgZorlaAtis = false`, `rpgMaxM ≈ 350`.
- **RPG çok bekletiyor:** `rpgBekleS`, `rpgGrupBekleS`, `rpgTaramaS`, `rpgAtisGecikme`, `atAtisGecikme` düşürün.
- **AT araçtan kaçıyor:** `zirhKacis = false`.
- **Botlar sipere yapışıyor ama ateş edemiyor:** `siperSafCeza` ve `siperKarsilikBonus` yükseltin.
- **Dur-kalk:** `durusAkici` açık tutun, `durusAkiciKilitS` 10.
- **Haritada sert siper yok (Arma'da hiçbir terrainde güvenilir değil):** `siperArazOncelik` 8 (çukur / yamaç önce), `siperKentselArazi` 2; karnede "gerçek siper %" yerine **KORUNAKLILIK** (arazi + nesne; açıkta ≤ %15) ve `[COVER-OLCUM-DURUS]` (yatsa / çömelse gizlenir miydi) okunur.
- **Bombacı yavaş / duruyor:** `canliBombaCatis` kapalı olsun (açıkken AI ateş için durur); `canliBombaTereddutS` 0–3; Zeus'ta tarz "Agresif".
- **Bombacı hiç patlamıyor / çok uzaktan patlıyor:** `canliBombaTetikM` (3–12), `eypPatlamaGucu`; ölü / vurulmuş bombacı için `canliBombaOlumSans`.
- **Baygın / ölüye magdump çalışmıyor:** `yereAtes` 1, `yereAtesBaygin` ve `yereAtesOyuncu` açık; RPT `[YERE-ATES-OZET]` sayaçları (`tehdit_var`: yakında canlı düşman var, `atici_yok`, `sans_hayir`).
- **BMP / BTR / kamyon yolcusunu indirmiyor:** `mekanizeHareket` açık, en az 2 AI yolcu olmalı, iniş eşiği için `mekanizeInisCarpan`; MEDEVAC / TASIMA / HARIC görevli araçlar muaf; RPT `[MEKANIZE-INIS]`.
- **Motoru çok uzaktan / hiç duymuyorlar:** `motorSesCarpan` ve sınıf çarpanları; rölanti için `motorSesRolanti`.
