# DOGRULANMAYANLAR - cephe simulasyonu HARIC, oyunda dogrulanmamis ozellikler + test senaryo plani (v8.275)

Kaynak: OZELLIKLER_LISTESI.md (T isaretleri), DEVIR_LOGU_v7.0.txt, bu oturumdaki RPT analizleri. Cephe simulasyonu (`10e`) kapsam disi.
Kural: bir madde, ASAGIDAKI senaryodaki beklenen log + kullanici gozlemi birlikte gorulunce T'den cikarilir (OZELLIKLER_LISTESI.md'de `(T)` silinir, bu dosyada [x] yapilir).

## 1. LISTE

### A. Eski bolumlerde (T) isaretli (v8.131 - v8.236)
- [ ] HQ medevac (hekim atama) ve ARACLI medevac (S9) — KISMEN: HQ-MEDEVAC atamasi+[TCCC] GUVENLI goruldu (21:28:27), yarali yaklasirken oldu; ARACLI medevac 3 kez "uygun arac YOK" -> hala T
- [x] Arac-piyade senkronu (`aracSenkron`) ve kara araci nakli + taksi (S1, S9) — [ARAC-SENKRON] SENKRON/SERBEST + ozet BEKLE:31 YAVASLA:7; [TASIMA] 3 arac/16 asker eslesti, yolda 51 km/s. [TAKSI] yalniz watchdog basladi -> taksi hala T
- [x] Istihbarat / PID (iddia != gercek) (S1) — [PLAN-ISTIHBARAT] 21:13:55 IDDIA 20 / GOZLENEN 2 UYUSMAZLIK
- [x] Plan nakli (erken baslama), nakil iyilestirmeleri (ogrenilen koltuk kapasitesi), kapasite uyarisi (S1) — [TASIMA] "kalan koltuk 12 < yaya asker 33" (21:04:59), yola cekilen inis noktasi; kapasite UYARISI (Zeus 15 asker testi) gorulmedi -> o kisim T
- [x] Ezme korumasi, arac carpisma guvenligi (S9) — 37x [EZME] ... -> FREN (T-72, Abrams, Stryker). Arac carpisma guvenligi (kinematik) tetiklenmedi -> T
- [ ] Murettebat koruma (GET OUT iptali / geri donus) - AI gruplarinda (S9) — yalniz watchdog basladi (20:54:09); IPTAL / koltuguna dondu logu yok -> S9c yapilmadi
- [ ] Oyuncu komutasi (oyunculu gruplar ELITE'ten muaf mi) (S6) — test edilmedi (oyunculu AI grubu yok)
- [x] Komutan zihni + tavir motoru, arac sinifi + roller (S1) — [KOMUTAN-ZIHIN] 68, [KOMUTAN-TAVIR] 11, [ARAC-SINIF] 8 (IFV/TANK siniflari)
- [ ] Hendek alani: yol bulma / rampa gereksinimi (S2); IHA gorevi: mod davranisi (S5) — hendek alani bu gorevde yok ([HENDEK-DURUM]=0) -> S2 yapilmadi; IHA mod davranisi [IHA-SORTI] mod SORTI goruldu

### B. v8.238 - v8.259 (10f; bolumun tamami T)
- [ ] Hendek: oncelik, coklu mevzi, mevzi tutma, hendek kilidi, statik silah, kalicilik 2 (S2) — hendek yok; [MEVZI] "bina true, statik 0" (bina mevzisi calisiyor, hendek / statik test edilmedi)
- [x] Karsi saldiri donusu, savunma suresi uzatma, savunma atesi, savunma temassiz sure siniri (S2) — [PLAN-SAVUNMA] KARSI SALDIRI 21:18:34 / 21:22:10 ve "KARSI SALDIRI BITTI ... mevziye donuyor" 21:22:58; sure siniri / savunma atesi ayri dogrulanmadi
- [ ] Tank / IFV savunma mevzisi, gozetleme araci yonu, otomatik tank (S2, S3) — S2/S3 yapilmadi (tank savunma mevzisi logu yok)
- [x] Arac surus A/B testi, Stryker FFV duzeltmesi, BTR-80 FFV muafiyeti, IFV surucu emri onarimi, surucu yenileme (S1, S9) — Stryker FFV: [FFV-DUZELT] 21:05:28-40 duz cargo koltuguna tasindi. BTR-80 muafiyeti, IFV surucu emri onarimi, surucu yenileme: log yok -> o kisimlar T
- [x] Arac-piyade senkronu BEKLE tavani, nakil yol zinciri, nakilde genis dusman mesafesi (S1) — nakil yol zinciri ([TASIMA] "inis noktasi yola cekildi" 21:04:59); BEKLE tavani ve genis dusman mesafesi ayri kanitlanmadi
- [x] Arac zirhtan kacis, tank ates kontrolu + AT tepkisi + tank koruma, tank murettebati (1 ve 2), duman duzeltmesi (S3) — [ARAC-ZIRH-KAC] 70, [TANK-ATES] hedef dagitimi, [ARAC-AT-TEPKI] (duman true, yer degistirme), [TANK-KORU], [TANK-MURETTEBAT] (koltuga donus) + 40 [ARAC-BINDI], [ARAC-DUMAN] ATILDI 11/ATILMADI 0
- [ ] Tank mevzi kilidi (`disableAI "MOVE"` RHS'de tutuyor mu) (S2, S3) — tank mevzi kilidi bu gorevde yok
- [x] Motor sesi farkindaligi, gercek hedef filtresi, ORP gerisi temas destegi, topcu erken kacis (`[TOP-TEPKI]`) (S1, S2) — [MOTOR-SES] 20 satir. Gercek hedef filtresi / ORP gerisi destek / [TOP-TEPKI] (tek satir = baslangic) kanitlanmadi -> o kisimlar T
- [ ] Kayip esiginde HQ'ya donus; guc orani kapisi + zirh korkusu + tank surunme duzeltmesi; teslim esikleri + CBA + fraksiyon (S1, S2, S10) — KISMEN: [PLAN-ORAN] SALDIRI IZINLI goruldu (guc orani kapisi calisiyor); BEKLEME dali, kayip esiginde HQ donusu (en yuksek %41 < esik 50), teslim: 0 -> T
- [x] Tani paketi (`--tani` ciktilari) (her senaryo) — [OLUM-TANI]/[OLUM-OZET] 45 olum, [ARAC-TERK] 25, [ARAC-BINDI] 40, [TANK-IMMOBIL] 2; hendek / topcu / recon bolumleri bos (olay yoktu)
- [x] Zeus IHA gorevi: dron yarat (S5) — [IHA-BEKLEME] FIRLATMA 21:28:46 (tetik 1200 m, 5 sn bekledi)

### C. v8.260 - v8.275 (10g; hepsi T)
- [x] 260 IHA gorevi duzeltmesi (sunucuda yaratma, "Suspending" hatasi yok) (S5) — [IHA-SORTI] sunucuda yaratildi, "Suspending" hatasi 0
- [x] 261 Erken kuvvet orani kapisi + hibrit dusman tahmini (S1) — [PLAN-ORAN] "TAHMIN 15.2 (gozlenen 4.0 + OPORD iddia 20 x agirlik 0.70)" = 2.96 / esik 2.00 -> SALDIRI IZINLI
- [x] 262 Nakilde ek arac + medevac rezervi koltuk kontrolu (S1) — [TASIMA] MEDEVAC REZERVI ATLANDI (kalan koltuk 12 < yaya 33)
- [ ] 263 Kinematik surus carpisma korumasi (S1) — tetiklenmedi; [SURME-TANI-*] yalniz tani
- [ ] 264 Recon araci AI surusune sabir (S1) — [GOREV-ATAMA] RECON_ARAC var, [RECON-ARAC-HAREKET] satiri YOK
- [ ] 265 Tank piyade bagi + hareket edemeyen tank (S1, S3) — KISMEN: PIYADE BAGI calisti (21:06:41 tank 426 m onde -> BEKLIYOR, 21:07:02 yetisti, 21 sn). [TANK-IMMOBIL] loglandi; [TANK-TERK] 0, M1A1FEP immobil kaldi ([TANK-YALNIZ]) -> hareket edemeyen tank kismi T
- [ ] 266 Oyuncu grubu arac murettebati muaf (S6) — test edilmedi (S6)
- [x] 267 IHA bilincli firlatma, 268 operator bagi, 272 Crocus cantasi, 273 FPV dalis (S5) — 267 (IHA-BEKLEME tetik 1200 m, FIRLATMA 5 sn) + 273 (HEDEFE VURDU, AI pilot MOVE/PATH kapatildi, hiz 29 km/s, havada glitch yok). 268 operator bagi: kayitli ("olunce hedefe dalar"), operator OLDURULMEDI -> T; 272 canta tuketimi test edilmedi
- [x] 269 Seyir formasyonu (RPT 04dfc9d7 + kullanici: 'formasyon yuruyusu guzel calisiyor'); 270 politika tablosu hala T (S4)
- [x] 271 / 274 Dusman isaretlerini gizleme (kullanici teyidi, RPT 372b264e) - savunmada ORP yok hala T (S2)
- [ ] 275 Recon kismi binme iptali, tank ARAC-SENKRON muaf, moral cokme + teslim esikleri (S1, S10) — v8.275 SUNUCUDA YOKTU (RPT build v8.274-ISARET-ZEUS) -> bu testle dogrulanamaz

### D. Log kanitli ama belgede hala T (kapatilabilir, S ile teyit yeterli)
- Hendek kapasite / ek ekipler (90 sn'de %85-97 icinde), MEVZI-KILIT etkin, statik silah (NSV) atamasi, PLAN-KAYIP-DONUS, ARAC-ZIRH-KAC, OLUM-TANI, formasyon hakemi (FORM-SET) salinimsiz.

### E. Acik / cozulmemis (kanit bekliyor)
- [ ] T-14 `SmokeLauncher` atesleniyor mu (T-72 duman calisiyor) (S3)
- [ ] `allowCrewInImmobile` motor hasarinda murettebati tutuyor mu / `[TANK-IMMOBIL]`, `[TANK-TERK]` (S3)
- [ ] UAZ-469 recon araci neden kalkmiyor (`[RECON-ARAC-HAREKET]`) (S1)
- [x] Guc orani kapisi hic degerlendirilmedi (`[PLAN-ORAN]` satiri yok) (S1) — [PLAN-ORAN] 21:13:55 goruldu
- [x] HQ-DESTEK "musait destek grubu yok" (S1) — [HQ-DESTEK] EMIR 21:14:56 / VARIS 21:16:41 / BITTI 21:17:29 (destek Alpha 1-1)
- [ ] LAMBS "Group Suppress / Hide (holding)" cagri yolu (S2)
- [ ] Crocus canta -> arac sinifi esleme (`assembleTo`), FPV mod motoru operator olunce dusurme (S5)
- [x] `[ISARET-GIZLE]` istemci logu (S7) — istemci RPT: "[ISARET-GIZLE] taraf EAST ... ELITE isaret 11 | gizlenen 6" (21:08:59) calisiyor; gorsel teyit (S7) kullanicidan
- [ ] `init.sqf` terrain temizligi: hideObjectGlobal + AI navmesh etkisi, `allMissionObjects ""` varsayimi, CUP model adlari (S8)
- [ ] "Bot aractan inmiyor" kok nedeni (S6)
- [ ] Teslim olma (faction bazli CBA) gercek macta (S10) - v8.275: eski formulde ulasilamazdi; yeni cokme terimi + [TESLIM-ADAY] moral < 0.60 logu
- [ ] Recon grubu neden tam binemedi (koltuk / etiketli arac) - v8.275 KISMI BINME logu (S1)
- [ ] IHA seyir hizi / FPV-AT motor bolgesi dalisi (istek, yazilmadi) (S5)

## 2. TEST SENARYO PLANI (10 senaryo, her biri birden cok maddeyi kapatir)
Genel: Server + Zeus client; her senaryo sonunda IKI RPT (sunucu + istemci) kaydet (dosya adinda senaryo no). Ardindan `python3 tools/rpt_ozet.py --karne --tani --form <rpt>`.
Surum kontrolu: RPT'de `[ELITE-BOOT] ... v8.275` gorunmeli.

### S1 - Ele gecir: tank + BTR + recon + zayif/guclu dusman (en cok madde)  [~25 dk]
Ortam: WEST 8 grup (~30 asker), 1 T-72, 3 BTR-80 + 3 Ural (Open), AFOU UAZ recon araci (Gorev Ata RECON ARACI), MEDEVAC gruplu 1 hekim, topcu; EAST hendekli objektif (~25 dusman, 1 tank), objektif 2.5-3 km. HQ kur.
Adim 1: Objektif -> "Dusman sayisi" = 40, guven ORTA, Min. kuvvet orani 2 (guclu dusman): `[PLAN-ORAN] ... ERKEN` BEKLE gormeli, tank durmali (`ORAN BEKLEME`), nakil kalkmamali, 300 sn sonra saldiri iptal + HQ'ya donus.
Adim 2: Yeni plan, Dusman sayisi = 10, guven KESIN, oran 1: `SALDIRI IZINLI`, plan akmali.
Gozlem: `[RECON-ARAC-HAREKET]` (UAZ kalkiyor mu, KURTARMA 3 ilk ~38 sn'den once yok), `[TASIMA] EK ARAC / MEDEVAC REZERVI ATLANDI`, `PIYADE BAGI` (tank piyadeden >400 m once gecmiyor), SENKRON kapisi 420 sn tavana takilmiyor, `[PLAN-ISTIHBARAT]` iddia/gozlenen farki, HQ-DESTEK ozeti, arac carpisma guvenligi / kapasite uyarisi, kinematik surus devreye girerse hasar yok (`ARAC-TERK` tekerlek 1.0 olmamali).
Kapatir: A (nakil/senkron/istihbarat/roller), B (nakil, senkron tavan, yol zinciri, IFV onarim), C 261-265, E (UAZ, guc orani, HQ-DESTEK).

### S2 - Savunma 45-50 dk (hendek + tank + statik + topcu)  [~50 dk]
Ortam: EAST SAVUN plani, hendek alanlari (Trencher), NSV/DShK statik, 1 T-72/T-14 savunma tanki, 5 grup; WEST ele gecir ~1-2 saldiri dalgasi, topcu.
Gozlem: `[HENDEK-DURUM]` 30/90 sn (grubun cogu icinde), `MEVZI-KILIT`/`MEVZI-STATIK`, tank `mevzide: surucu MOVE KAPALI` ve mevziden ilerlememesi, hendek kalicligi (dusman gorunce ayrilmama), karsi saldiri donusu, savunma temassiz sure siniri, `[TOP-TEPKI]`, `PLAN-KAYIP-DONUS`, haritada `P1 ORP` YOK ve `TEHDIT YONU / DESTEK` var, LAMBS Group Suppress/Hide logu (kaynak).
Kapatir: B (hendek/mevzi/savunma/tank mevzi), C 271, E (LAMBS yolu).

### S3 - Tank dueli + hasar + duman  [~15 dk]
Ortam: 2 T-72B + 2 T-14 (RHS) karsi karsiya acik arazide 800-1500 m; WEST AT askeri + RPG.
Adim: bir tankin motorunu vur (hitengine ~0.9): `[TANK-IMMOBIL]`, `HAREKET EDEMIYOR`, murettebat iceride kalirsa sabit atis, 4 geri donus sonra `[TANK-TERK]`; duman: her iki modelde Zeus'tan duman tetikle ya da AT atesi yedirerek `[ARAC-DUMAN]` (T-14 `SmokeLauncher` ates etmezse `[ARAC-DUMAN]` yontem logu nedeni gosterir).
Gozlem: tank hedef dagitimi, AT tepkisi (`aracAtTepki`), zirhtan kacis, murettebat in/bin dongusu 48 degil <=4.
Kapatir: B (zirh kacis, tank ates, murettebat 1-2, duman), C 265, E (T-14 duman, allowCrewInImmobile).

### S4 - Formasyon yuruyusu  [~15 dk]
Ortam: 3 AI grubu (4-8 asker), temassiz; Zeus waypoint ile 3 km: yol, acik arazi, orman, koy. Sonra bir grubun onune dusman.
Gozlem: `[KOMUTAN-FORM] ... | SEYIR | formasyon -> X | tehdit N m` (uzak COLUMN -> yaklasinca WEDGE -> VEE), yolda COLUMN, ormanda/gece COLUMN; formasyon salinimi yok (`--form` [OK]); gorsel dogrulama (kullanici).
Kapatir: C 269, 270.

### S5 - IHA  [~15 dk]
Ortam: Crocus cantali dost asker (O_Crocus_AT_Bag) + yerde bir Crocus AP cantasi; hedefler: dusman tank (zirhli) + piyade kumeleri; Mavic (varsa).
Adim: (a) moduli cantali askerin yanina birak, Tetik=1200: dusman yaklasana kadar dron YOK; (b) firlatma, `canta tuketildi`, dalis `[IHA-DALIS]` (hiz rampasi, havada titreme yok, HEDEFE VURDU); (c) operator oldur -> `KONTROL KAYBI` ya da dalarsa vurur; (d) KALDIR ile bekleyen emir iptali; (e) AP cantasi (yerde) -> FPV-AP; (f) dron yarat listesi + tetik 0.
Gozlem: `Suspending not allowed` hatasi YOK, `[IHA-SORTI]`, `[IHA-BEKLEME]`, canta sinifi esleme (`O_Crocus_AT_Bag -> O_Crocus_AT`).
Kapatir: C 260, 267, 268, 272, 273; E (canta esleme, mod motoru).

### S6 - Oyuncu grubu + arac murettebati  [~10 dk]
Ortam: oyuncu squad lideri, BTR-80/T-72 icinde botlar (surucu, nisanci, yolcu).
Adim: catisma, temas bitti 30+ sn bekle, "Get Out"/in emri, tank icinde botlar.
Gozlem: botlar INMELI; RPT'de bu botlar icin `[MURETTEBAT-KORU] INME EMRI IPTAL` / `koltuguna dondu` OLMAMALI; oyuncusuz AI arac grubunda murettebat korunmaya devam etmeli.
Kapatir: C 266, A (oyuncu komutasi, murettebat koruma), E (bot aractan inmiyor).

### S7 - Isaretler (coklu oyuncu)  [~10 dk]
Ortam: BLUFOR oyuncu, OPFOR oyuncu, Zeus (ayri); BLUFOR icin Objektif/Karakol/HQ koy.
Gozlem: OPFOR haritasinda `ELITE_*` gorunmez (3 sn); BLUFOR'da gorunur; Zeus: CBA gorunum "Hepsi"/"Otomatik"; istemci RPT `[ISARET-GIZLE] taraf ... gizlenen N`.
Kapatir: C 271/274, E (ISARET-GIZLE).

### S8 - init.sqf terrain temizligi (Anizay)  [~20 dk]
Ortam: `init.sqf` (depoda degil, gorev klasorunde); 5 km yol boyunca 3 arac (jeep, BTR, tank) + bot yuruyusu; cimen kapali.
Gozlem: sunucu RPT `[YOL-TEMIZLIK] bitti | ...` + `silinen sus model`, `hacim moduyla silinen model`, `taninmayan model` listeleri (bana gonder), araclar yol kenarinda takilmiyor, botlar yolda rahat, navmesh etkisi, mission objeleri (Eden) gizlenmedi.
Kapatir: E (init.sqf maddeleri).

### S9 - Mini testler (AI, ~5 dk her biri)
(a) Aracli medevac: baygin yarali 40+ sn, hekimsiz grup -> `[ARAC-MEDEVAC]`, `[HQ-MEDEVAC]`.
(b) Ezme korumasi: yaya onunde duran arac `[EZME] FREN`.
(c) Murettebat koruma (AI): kayitli murettebat GET OUT iptali / geri donus.
(d) Taksi: uzak waypointte yaya grup -> `[TAKSI]`.
(e) Kapasite uyarisi: Zeus'ta 15 asker + 2 yer'li arac.
Kapatir: A (medevac, ezme, murettebat, taksi, kapasite), B (surucu yenileme: arac surucusunu oldur, yolcu surucu koltuguna gecmeli)

### S10 - Teslim / moral  [~20 dk]
Ortam: kucuk EAST grubu (6) kusatilmis, WEST 20 asker; CBA moral/teslim: ana anahtar acik, fraksiyon listeleri bos / dolu.
Gozlem: `[TESLIM-ADAY]` fraksiyon=..., teslim olan/olmayan fraksiyon listeye gore; ana anahtar kapaliyken kimse teslim olmaz; esik slider'lari.
Kapatir: B (teslim esikleri + CBA + fraksiyon), E (teslim).

## 3. CIKTI NASIL ISLENIR
1. Her senaryodan IKI RPT (sunucu + istemci) -> bana gonder.
2. `tools/rpt_ozet.py --karne --tani --form <rpt>` ciktisini ekle (yoksa ben calistirir, T'den cikarma onerisi veririm).
3. Dogrulanan maddeleri bu dosyada `[x]`, `OZELLIKLER_LISTESI.md`'de `(T)` -> dogrulandi; basarisizlari DEVIR_LOGU'na kok neden olarak yaz.
Oncelik sirasi (en cok madde / en cok risk): S1 -> S3 -> S5 -> S2 -> S4 -> S6 -> S7 -> S9 -> S10 -> S8.


## 3. TEST SONUCU - 2026-10-20 (RPT: sunucu 20:40 + istemci 20:29; oyun 20:53:02 - 21:49, coopsteril / tem_anizay)
Not: yuklenen iki sunucu RPT'si birebir ayni dosya (ayni md5). **Her iki RPT'de build `v8.274-ISARET-ZEUS`; v8.275 degisiklikleri bu testte YOKTU** (275 maddeleri dogrulanamaz, once v8.275 build'i kopyalanmali).
Senaryo: S1'e yakin (WEST ele gecir, tank + Stryker + Abrams, P2) + EAST savunma (P1); hendek yok, bot oyuncu yok.
Karne: script hatasi 0 (sunucu + istemci), OK:26 KONTROL:5. 45 olum (EAST 16 / WEST 29), sunucu FPS ~57 (son dakikada 32).

### Dogrulanan (yukaridaki [x] satirlari)
Nakil + koltuk kapasitesi, arac-piyade senkronu, PID, ezme korumasi, komutan zihni / arac sinifi, karsi saldiri donusu, Stryker FFV duzeltmesi, zirhtan kacis / tank ates / AT tepkisi / tank koruma / murettebat / duman, motor sesi, tani paketi, guc orani kapisi (SALDIRI IZINLI dali), HQ-DESTEK, tank piyade bagi, IHA firlatma + FPV dalisi, `[ISARET-GIZLE]` istemci logu.

### Yeni bulgular (duzeltilecek)
1. **`[IHA-DALIS]` log seli**: 1437 satir, ~65 sn'de (21:28 = 537, 21:29 = 900) tek bir FPV sortisi icin; kare basina log. Hiz sinirla (ornegin 2 sn'de bir) - RPT sismesi + sunucu yuku.
2. **HQ medevac sonuc vermedi**: hekim 109 m uzaktan atandi, yarali yaklasirken oldu ("IPTAL (yaklasma): yarali oldu"). Atama mantigi calisiyor; mesafe / sure esigi ve baygin yaralinin olum suresi ile iliskisi incelenebilir.
3. **Aracli medevac hic baslamadi**: 3 kez (40 / 40 / 80 sn) `uygun arac YOK` - kosullardan hangisi eliyor loglanmiyor (standoff'tan elenen 0). Elenme nedeni sayaclari eklenmeli.
4. **Siper yapisma**: `[SIPER-YAPISMA] ayarlandi:0 acikta:2507` (karne KONTROL) - siper yapisma hic ayarlamadi, 2507 kez "acikta" gordu.
5. **Anomaliler**: `YURUMUYOR 129`, `TEMAS-YOK-COMBAT 53`, `BOSTA-HAREKET 30`, `KILIT-UZUN 22` (Petrov / Afanasyev 42-43 sn, bayrak EVD+TAK), `AI-KAPALI-SIZINTI 9`. KILIT-UZUN bayrak kombinasyonu (EVADE + TAK) incelenmeli.
6. **Son dakika FPS**: 57 -> 32 (min 31), yerel grup 2 / asker 21 iken; dusuk yukte bile dusus -> IHA log seli (1) ile iliskisi kontrol edilmeli.
7. **Retreat varis orani**: 34/65 (%52).

### Hala test edilmemis / kanitsiz
Hendek + mevzi + statik (S2), tank mevzi kilidi, T-14 duman (T-14 yoktu), `allowCrewInImmobile` / `[TANK-TERK]` (M1A1FEP immobil kaldi, mürettebat icerde, terk 0 - beklenen davranis olabilir), recon araci (`[RECON-ARAC-HAREKET]` yok), kinematik surus, oyuncu grubu muafiyeti (S6), teslim / moral esikleri (S10; kayip %41 < esik), init.sqf temizligi (S8), aracli medevac, taksi, kapasite uyarisi, operator olunce dron dusurme, v8.275 maddelerinin hepsi.
