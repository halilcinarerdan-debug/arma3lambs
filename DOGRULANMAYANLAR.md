# DOGRULANMAYANLAR - cephe simulasyonu HARIC, oyunda dogrulanmamis ozellikler + test senaryo plani (v8.333)

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
- [ ] 275 Recon kismi binme iptali, tank ARAC-SENKRON muaf, moral cokme + teslim esikleri (S1, S10) — v8.275 SUNUCUDA YOKTU (RPT build v8.274-ISARET-ZEUS) -> bu testle dogrulanamaz — 21-10 testi (v8.275): moral COKME terimi calisti (20 [MORAL] satiri, cokme -0.25/-0.10), [TESLIM-ADAY] 18 satir ama teslim 0: sunucuda KAYITLI CBA degerleri eski varsayilanlardi (0.30/60/4/0.40/120) ve baski + 120 m kosullari ulasilamazdi -> v8.276 duzeltti (T). Recon KISMI BINME ve tank senkron muafiyeti tetiklenmedi (recon 6/6 bindi).

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
Karne: script hatasi 0 (sunucu + istemci), OK:26 KONTROL:5. 45 olum (EAST 16 / WEST 29), sunucu FPS ~57 (son dakikadaki 32 alt-tab kaynakli).

### Dogrulanan (yukaridaki [x] satirlari)
Nakil + koltuk kapasitesi, arac-piyade senkronu, PID, ezme korumasi, komutan zihni / arac sinifi, karsi saldiri donusu, Stryker FFV duzeltmesi, zirhtan kacis / tank ates / AT tepkisi / tank koruma / murettebat / duman, motor sesi, tani paketi, guc orani kapisi (SALDIRI IZINLI dali), HQ-DESTEK, tank piyade bagi, IHA firlatma + FPV dalisi, `[ISARET-GIZLE]` istemci logu.

### Yeni bulgular (duzeltilecek)
1. **`[IHA-DALIS]` log seli**: 1437 satir, ~65 sn'de (21:28 = 537, 21:29 = 900) tek bir FPV sortisi icin; kare basina log. Hiz sinirla (ornegin 2 sn'de bir) - RPT sismesi + sunucu yuku.
2. **HQ medevac sonuc vermedi**: hekim 109 m uzaktan atandi, yarali yaklasirken oldu ("IPTAL (yaklasma): yarali oldu"). Atama mantigi calisiyor; mesafe / sure esigi ve baygin yaralinin olum suresi ile iliskisi incelenebilir.
3. **Aracli medevac hic baslamadi**: 3 kez (40 / 40 / 80 sn) `uygun arac YOK` - kosullardan hangisi eliyor loglanmiyor (standoff'tan elenen 0). Elenme nedeni sayaclari eklenmeli.
4. **Siper yapisma**: `[SIPER-YAPISMA] ayarlandi:0 acikta:2507` (karne KONTROL) - siper yapisma hic ayarlamadi, 2507 kez "acikta" gordu.
5. **Anomaliler**: `YURUMUYOR 129`, `TEMAS-YOK-COMBAT 53`, `BOSTA-HAREKET 30`, `KILIT-UZUN 22` (Petrov / Afanasyev 42-43 sn, bayrak EVD+TAK), `AI-KAPALI-SIZINTI 9`. KILIT-UZUN bayrak kombinasyonu (EVADE + TAK) incelenmeli.
6. ~~Son dakika FPS 57 -> 32~~: kullanici teyidi - oyundan alt-tab yapildigi icin (sunucu degil istemci/pencere kaynakli); bulgu degil.
7. **Retreat varis orani**: 34/65 (%52).

### Hala test edilmemis / kanitsiz
Hendek + mevzi + statik (S2), tank mevzi kilidi, T-14 duman (T-14 yoktu), `allowCrewInImmobile` / `[TANK-TERK]` (M1A1FEP immobil kaldi, mürettebat icerde, terk 0 - beklenen davranis olabilir), recon araci (`[RECON-ARAC-HAREKET]` yok), kinematik surus, oyuncu grubu muafiyeti (S6), teslim / moral esikleri (S10; kayip %41 < esik), init.sqf temizligi (S8), aracli medevac, taksi, kapasite uyarisi, operator olunce dron dusurme, v8.275 maddelerinin hepsi.


## 4. TEST SONUCU - 2026-10-21 (v8.275; sunucu 19:57 + istemci 19:55; oyun 19:58 - 20:44, coopsteril / tem_anizay)
Senaryo: P2 WEST ele gecir (45 dost, 1 M1A2 tank + Stryker'lar, recon araci) + P1 EAST savunma (T-72B3, statik silah, hendek YOK). Script hatasi 0. RPT: sunucu 20:44 temiz kapandi.
Kullanici gozlemleri: (1) arac azken squad'lar bolundu - lider cepheye gitti, takimi arkada kaldi; (2) askerler SONUNA KADAR direndi, teslim olmadi (medevac testi bu yuzden yapilamadi); (3) tank taretleri duvara / olu noktaya bakiyor; (4) tanklar pasif.
Log kanitlari:
- `[TASIMA] 2 arac / 12 asker ... takim bazli bolunen: ["squad2 (2/3 takim)","squad1 (1/3 takim)"] | yaya kalan birim: 6` (20:14:14) -> gozlem (1) dogrulandi. 2 arac / 18 asker, SEFER yok (TOPLAN -> ORP 602 sn, sefer kapisi `fazSure < 400`).
- `[TESLIM-ADAY] Alpha 2-3 | moral=0.42 (<0.3) | kayip=67 (>=60) | kalan=2 (<=4) | baski=0.00 (>=0.4) | dusman=254 m (<=120)`: 18 aday satiri, 0 teslim -> gozlem (2). Kayitli CBA = eski varsayilan (boot satiri 0.45 diyordu); moral hedefi baskisiz ~0.33'un altina inmiyor, baski + 120 m zorunluydu.
- `[PLAN-ZIRH] ... ates pozisyonu 041095 (objektife 55 m, gorus hatti false ...)` (T-72B3, 20:12:50): mevzi tehdit noktasina GORUS HATTI OLMAYAN yerde -> gozlem (3). Tank taret hedefi sabit nokta (planZirhBak) idi.
- P2 tank (M1A2) telemetri: 20:21-20:30 034097'de 9 dk (dusman 636-696 m), 20:33-20:41+ 037096'da 8+ dk (dusman 230-320 m) hareketsiz; sicrama yalniz SALDIRI basinda 1 kez -> gozlem (4).
- Dogrulanan (v8.275 bayraklari): moral cokme terimi, recon araci tam binme + yol zinciri (`[RECON-ARAC]` 6/6, `[RECON-ARAC-HAREKET]` 20 satir, 54 km/h'e cikti), kuvvet orani kapisi (`[PLAN-ORAN]` ERKEN SALDIRI IZINLI, tahmin 10.2 = gozlenen 5.0 + iddia 20 x 0.35), HQ-DESTEK, tank piyade bagi (136 sn), tank duman (T-72B3 `rhs_weap_smokegen` ATILDI).
- Yapilmayan: hendek (S2), medevac, teslim (S10), S6.
v8.276 bu dort gozlem icin yazildi (bkz. DEVIR_LOGU v8.276); test icin: ayni senaryoyu tekrarla, `[TESLIM]`, `[TANK-BAKIS]`, `ILERI SICRAMA`, `[TASIMA] ... butun`, `SEFER ERTELENDI` satirlarina bak (`rpt_ozet.py --tani`).

## 5. v8.276 - v8.338 (guncelleme 2026-10-24; kanit = bu oturumdaki RPT / kullanici gozlemi; digerleri T)
### Log kanitiyla DOGRULANAN
- [x] Teslim (v8.276), butun grup nakli, `[TANK-BAKIS]`, ILERI SICRAMA kademe 1 — RPT 2026-10-21 (v8.276 notu).
- [x] Dron zinciri: `[MOTOR-SES]` -> `[DRON-YON]` -> `[DRON-SAKLAN]` calisiyor (RPT 22-10 22:53, v8.294-v8.297); zorla ates `[DRON-ATES]` (132 zorla atis, hepsi kacirdi - isabetsizlik hitbox / hasar suphesi).
- [x] `[TANK-DRON]` tepkisi (YON + ATES + DUMAN + KACINMA, tank GERCEK ATIS 92) ve `[DRON-KARSI-ATES]` (7 olay) — RPT 40d48a79 (v8.324).
- [x] `[SIS-EKONOMI]` (ayni acida / noktada tekrar atmama) — 9 atlanan, RPT 40d48a79.
- [x] Tank mevziye yerlesme + TETIK + `YER DEGISTIRIYOR` (shoot-and-scoot) — RPT 40d48a79; `TAKILDI` 3 kez (tank agaclara takildi, v8.327-v8.328 bunun icin).
### v8.327 - v8.333 (T, hepsi oyunda denenmedi)
- [ ] Tank otomatik secimi HQ'ya bagli tanki mesafe sinirina takmaz (v8.325): `[PLAN-ARAC] ... OTOMATIK alindi` ya da `plana ALINMADI: <neden>`.
- [ ] Tank agresifligi (CBA `tankAgresif` 2): savunmada gizleme noktasi yok, mevzi ~200 m, saldirida 60 sn'de ileri sicrama, 5 kademe.
- [ ] Genel arac unstuck (`[ARAC-UNSTUCK]` kademe 1-4, `[ARAC-UNSTUCK-OZET]`): ag aca / kayaya takilan arac kurtuluyor mu; yanlis pozitif (bekleyen arac) var mi.
- [ ] Dron operatoru avi savunma planindaki gruptan 3-4 kisi cikariyor mu (`[DRON-AVI]`); `devriye cikmadi` nedeni.
- [ ] Dron gozlemcisi (v8.336): israrli saldirida `[DRON-GOZLEM]` talep + hazir IHA / gozlemci asker, gozlem dronu tahmin bolgesine ucuyor mu, operatoru goruyor mu (`[IHA-GOZLEM]`); canta -> dron config'i.
- [ ] Topcu eminligi: 1 dron 110 m / 4+ dron 16 m yayilim (`[DRON-KARSI-ATES] ... dron sayisi`), atis operatore yakin mi.
- [ ] AI IHA duman kilidi (`[IHA-DUMAN]`): duman varken dalis yok / kor sapma; kilit suresi 1,2 sn.
- [ ] FPV-AT gercek carpma (`[IHA-SORTI] ... yontem: govde yuzeyi`, `[IHA-ETKI]`): tank hasari > 0 / parca > 0.3 mi (ACE Vehicle Damage acik / kapali karsilastir).
- [ ] Sis butcesi (`[SIS-BUTCE]` ret nedenleri): taraf 120 sn'de en cok 2 olay; saldirida tek sis.
- [ ] Otomatik mevzi / garnizon (`[OTO-GARNIZON]`): KARAKOL + MEVZI + GOZLETME kuruldu mu, ORP / CCP'den >= 70 m, nobet / devriye kuruldu mu; savunma planinda cakisma.
- [ ] Hedef zinciri TUT (v8.324): `[PLAN-TUT]`, tutan squad'in savunma plani + isaretler.
- [ ] Patlayici (el bombasi / roket / UGL) ve ates-hareket (v8.310-v8.317): son oturumlarda sunucuda temas az, `[PATLAYICI-OZET]` hep 0; yeniden denenmeli.
- [ ] `tools/hemtt_kontrol.sh`: depoda 0 hata (v8.332); lint uyarilari yalniz stil.
### v8.338 (T, hicbiri oyunda denenmedi)
- [ ] AI GOZLEM dronu gercekten hedef goruyor mu: `[IHA-GOZLEM] ... hedef goruldu`; `ihaGorulen` dolu mu (`[DRON-TOPCU-OZET]` 'gozlemci hedef gormuyor' sayaci cok yuksekse HAYIR).
- [ ] Gozlemli atis zinciri: `[DRON-TOPCU] CAGRI` -> `ADJUST n/3: SPLASH ...` -> `ETKI ATESI` -> `BDA` -> `SON (END OF MISSION)`; `Fired` ile dusme noktasi yakalaniyor mu (`adjust mermisi dusmedi` = HAYIR).
- [ ] Adjust gercekten yakinsiyor mu (AI topun kendi dagilimi 60 m esigini asiyor mu: `adjust yakinsamadi`).
- [ ] Danger close: dost <= 600 m (81 mm icin RED 195 m) -> `DANGER CLOSE (creeping <= 100 m)`, tek top 2 mermi; M109 / 155 mm ile dost 455+20 m icindeyse `guvenlik: dost ... < RED`.
- [ ] NFA: `nfa...` adli harita isareti hem gozlemli atisi hem plan atisini (`[PLAN-TOPCU] ... (NFA)`) durduruyor mu; sivil < 120 m.
- [ ] Taciz atisi: `[TACIZ] ... bayat temas`, 18-38 sn arayla 2 mermi, dost >= 600 m, butce.
- [ ] Uzaktan gorunen dusman -> `[DRON-TOPCU] UZAKTAN GORUNEN DUSMAN ... gozlemci talebi` -> `[DRON-GOZLEM]` dron ucuyor -> gozlemli atis.
- [ ] Karsi-batarya / operator atesi kitap emniyeti: `[DRON-KARSI-ATES] ... ATMADI (kitap emniyeti)`; eskisi gibi hic atmiyorsa `lambs_danger_topcuEskiMesafe = true` ile karsilastir.
- [ ] Plan atisinda 122 mm (2S1) icin RED 455 m: `[PLAN-TOPCU] ... ATMADI: en yakin dost ... < RED 455`.
- [ ] v8.339: Zeus IHA modulu Taraf Otomatik (B_ sinif -> BLUFOR); dusman dron secilirse 'IHA gorevi IPTAL' yazisi; bekleyen GOZLEM emri `[DRON-GOZLEM] BEKLEYEN gozlem emri serbest birakildi` -> `[IHA-BEKLEME] ... GOZLEMCI TALEBIYLE serbest`.
- [ ] Operator atesinde Sh_82mm_AMOS mermisi hedeften ~1.6 km uzaga dusuyor mu (`[DRON-KARSI-ATES] ... ATIS EMRI` + `[TANI-TOPCU]` karsilastir).
- [ ] v8.340: dron vurulma suresi uzadi mi (`[DRON-ISABET]` olasiliklari; yakin + yuksek beceri ~1, uzak / hizli dusuk); `dronIsabetOran` 0.5 / 2 ile karsilastir.
- [ ] v8.341: operator / karsi-batarya atisinda `[TOPCU-ATIS] ... YABANCI MERMI temizlendi` / `YANLIS MERMI` gorunuyor mu; tum mermiler hedefe yakin dusuyor mu (`[TANI-TOPCU]`). Karakol nobet / devriye kadrosunda sihhiye yok (komutan / MEDEVAC grubu haric).
- [ ] v8.342: `[FO-HAKIM]` atama (BINA ust kat / cati ya da ARAZI), lider gercekten cikiyor mu (merdiven), varista `gozlem noktasinda`, sonra `[DRON-TOPCU] CAGRI ... (YER GOZLEMCISI ...)`; plandaki grupta yalniz lider gidince grup / LAMBS tepkisi (komutan bekle, buddy).
- [ ] v8.343: gozlem dronu (B_Crocus_AP GOZLEM) tek askeri gorunce `[DRON-TOPCU] CAGRI` baslar mi (esik 1; hedef 10 sn duragan olmali); yer gozlemcisi `[FO-HAKIM]` + `CAGRI ... (YER GOZLEMCISI`; `[DRON-AVI]` ekip sayisi sistemin sectigi; USTKAT dusme: `DUSTU` logu yok.
- [ ] v8.344: farkli iki yonden dron saldirisi -> iki ayri tahmin ([DRON-KARSI-ATES] / [DRON-AVI]); tek dron / tek dogru -> 'ZAYIF TAHMIN' (topcu atilmaz); dron avi 'tuzak olasiligi'.
- [ ] v8.344: AI FPV gece termalsiz / sisli havada hedefi daha gec buluyor mu (`lambs_danger_ihaGorusMenzil`, kilit suresi); TI sinifi gece normal.
- [ ] v8.344: `[SIHA-KESIF]` FAZ 1-3 ve CIKARIM (ucan GOZLEM turu dron ver: Darter / Falcon); plan tehdit yonu guncellendi mi.
- [ ] v8.344: `[MOD-UYUM]` satirlari (RHS tek; CUP yuklenince CUP sayilari).
- [ ] v8.345: sessiz tempoda drona ates yok (`[DRON-ATES] ... ATES YOK (sessizlik`); `dronAtesModu` 0 / 1 / 2; gozlem dronu `[IHA-GOZLEM] N hedef goruldu` artik 1'de takilmiyor; `[DRON-TOPCU-OZET]` periyodik geliyor, hata sonrasi `BEKCI ... yeniden baslatildi` gorunmuyor.
- [ ] v8.346: ayni anda 3 dron cikinca '1 bagimsiz dron' sayiliyor mu (ZAYIF TAHMIN logunda 'N bagimsiz dron'), 5 dk ucan dronun gozlemi 'zayif izli' sayiliyor mu.
