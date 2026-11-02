# Tüm proje denetimi (v8.364, 2026-11-02)

İstek: "tüm projeyi check et; her şey mantıklı ve deterministik bir sebebe dayansın, tutarlı olsun, neden-sonuç ilişkisi olsun, gerçekçi olsun, kitaba göre check et."
Bu belge **ne kontrol edildiğini, neyin kontrol EDİLEMEDİĞİNİ**, bulunan hataları ve karar bekleyen tutarsızlıkları dürüstçe ayırır. Oyunda hiçbir şey çalıştırılmadı.

## 1. Kapsam ve sınırlar (sayılarla)
| Katman | Kapsam | Güven |
|---|---|---|
| **A. Makine denetimi** | 244 SQF dosyasının TAMAMI (38.8 bin satır), 266 PREP, 24 CBA olayı, 80 CBA ayarı, 1367 `format` çağrısı. Betik: `tools/tutarlilik_denetimi.py` (artık `tools/hemtt_kontrol.sh` sonunda otomatik koşar) + HEMTT | Yüksek: tekrarlanabilir, tam kapsama; **yalnız statik** tutarlılık |
| **B. Elle okuma** | Aşağıdaki §2 hatalarının bulunduğu dosyalar ve her uyarının bağlamı; v8.356–v8.363 dosyaları geçen oturumlarda yazılırken okundu. 244 dosyanın **tamamı satır satır okunmadı** (≈2.4 MB) | Orta: örnekleme |
| **C. Kitaba uygunluk** | Depodaki 8 yayın (`kaynaklar_doktrin/`): TC 3-21.76, MCWP 3-11.1 / 3-11.2, ATP 3-21.8 (alıntı), ATP 4-25.13, ATP 3-01.8, FM 3-34, ATP 7-100.1. v8.206–v8.338 için önceki belge: `KITABA_UYGUNLUK_DENETIMI.md` | Kaynak setiyle sınırlı (tank topçuluğu, FPV, teslimiyet, CQB sayıları kitapta YOK → `[N]`) |
| **D. Oyunda doğrulama** | YAPILMADI | `DOGRULANMAYANLAR.md` |

Makine denetimi şunları tarar: (1) PREP↔dosya↔`FUNC()` referansları, (2) CBA olay emit↔dinleyici↔argüman sayısı, (3) CBA ayar varsayılanı↔koddaki yedek değer↔ipucu metni↔slider aralığı, (4) dosya genelinde bildirilmemiş yerel değişken, (5) `spawn`/CBA/`addEventHandler` kapanışının dışarıdaki yerel değişkeni kullanması (görmez), (6) değer DÖNDÜRMEYEN komutların (`reverse`/`sort`/`append`) değer olarak kullanımı, (7) sürüm tutarlılığı, (8) belgelerdeki `lambs_danger_*` adları, (9) `if-then` içinde dönüş değerli `exitWith`. HEMTT: 0 hata, `L-S12` (geçersiz argüman tipi) 0.

## 2. Bulunan ve DÜZELTİLEN hatalar
| # | Yer | Kök neden | Sonuç (etki) | Düzeltme |
|---|---|---|---|---|
| 1 | `fnc_aracTasima` (4×), `fnc_reconArac` (3×), `fnc_aracSurmeDeney` (1×) | `forEach (reverse (waypoints _vg))`: `reverse` değer **döndürmez** (yerinde çevirir); HEMTT `L-S12` uyarısı yaklaşık 200 uyarı arasında gözden kaçmıştı | Nakil / recon aracının "ELITE NAKIL / RECON-ARAC" waypoint temizliği çalışmaz (script hatası ya da boş döngü): araç iniş sonrası eski waypoint'i izlemeye devam edebilir | `(waypoints _vg) call { reverse _this; _this }`; `hemtt_kontrol.sh` artık `L-S12` sayısını açıkça basar |
| 2 | `fnc_komutanPlan` (v8.175 "çoklu plan engeli") | `if (_cift) exitWith {…false}` bir `then {}` bloğunun İÇİNDEYDİ; `exitWith` yalnız o bloğu terk eder (projenin kendi DEVIR_LOGU satır 171 dersi) → "çift plan engellendi" yazıp **planı yine kuruyordu** | Aynı noktaya (150 m) aynı türden birden fazla plan kurulabiliyordu; dönüş `false` kayboluyordu | Bayrak (`_ciftRed`) + fonksiyon seviyesinde `exitWith {false}`; denetim betiği bu kalıbı artık yakalıyor |
| 3 | `fnc_varsayilanSkill` | v8.309'da CBA varsayılanları değişti (0.97 / 0.90 / 0.05 / 0.90) ama koddaki yedek değerler eski kaldı (0.95 / 0.75 / 0.15 / 0.85) | CBA ayarı yüklenmeden spawn olan birimler farklı beceri alabilirdi (tutarsız neden-sonuç) | Yedekler ayar varsayılanlarıyla eşitlendi |
| 4 | `fnc_tankIzle` | v8.280'in gizli **tank topu hasar çarpanı** (`lambs_danger_tankTopHasar`, HandleDamage): v8.281 "hile sayıldı, kaldırıldı" demişti ama kod duruyordu; CBA/belgeye bağlı değil | Değişken elle ≠ 1 yapılırsa hasarı gizlice çarpar (projenin "hile yok" ilkesine aykırı ölü kod) | Tamamen silindi |
| 5 | `fnc_aracSinif` | `Tank` tabanlı + kargo ≥ 3 ⇒ otomatik IFV/APC: **kargolu ana muharebe tankı (Merkava) IFV sayılır** → `tankAtesKontrol` / zırh destek dışında kalır | Kitaba göre MBT, sistemde taşıyıcı/IFV rolünde | Config'ten güvenilir ayırıcı yok (BMP-3 de 100 mm top + kargo); tahmin yerine `lambs_danger_aracSinifOverride` (sınıf→TANK/IFV/APC…) + RPT ipucu satırı |

## 3. Karar bekleyen tutarsızlıklar / bilinen istisnalar (DOKUNULMADI)
1. ~~**"Bilinen düşman" tanımı sistemler arasında farklı**~~ → **v8.366'da tek tabloya bağlandı** (`fnc_bilgiEsik`, `BILGI_ESIK_TABLOSU.md`). Eski tespit: **"Bilinen düşman" tanımı sistemler arasında farklı**: `knowsAbout` eşikleri 0.2 – 1.2 arası dağılıyor (en sık > 0.5 ×11, ≥ 1.2 ×7, ≥ 1.0 ×7, ≥ 0.8 ×6, ≥ 0.4 ×6, ≥ 0.3 ×6, > 0.2 ×4 …); `reveal` seviyeleri 0.4 – 4 arası (0.4/0.5/0.8, 1.2, 1.5, 2, 2.5, 3, 4). Her biri yerel gerekçeyle yazılmış ama tek bir "sezildi / şüphe / tespit / kesin" tablosu yok. **Öneri:** tek tablo (ör. 0.2 sezildi, 0.5 şüphe, 1.0 tespit, 1.5 kesin) ve her kullanımın bu tabloya bağlanması. Davranışı geniş ölçüde değiştirir → kararınızı bekliyor.
2. **Olasılık kapıları** (rastgele karar; kitapta karşılığı yok `[T]`): İHA gözlem taraması %60 (`ihaGozlem`), UGL %92 (`uglSans`), açıkta tek hedefe bastırma ateşi %60 (`fireSupport`), FPV isabeti 0.45–0.50 × çarpanlar + %8 EW (`ihaSorti`), dron zorla ateş olasılığı (`dronVurusOlasi`: beceri × mesafe × hız — nedensel), HQ rapor kaybı (`hqIstihbarat`: güvenilirlik — nedensel), panik tetik (`panikFelc` — nedensel), ateş-hareket %10 taban (`atesHareket`), tecrübesiz asker oranı %5 (`varsayilanSkill`). **Nedensel olanlar** (parazit, beceri, mesafe) sorun değil; **sabit yüzdeli** olanlar (`ihaGozlem` %60, `uglSans` %92, `fireSupport` %60) "deterministik sebep" ölçütüne uymuyor — istersen her birini ölçülebilir bir nedene (görüş katsayısı, mesafe, hedef kümesi) bağlarım.
3. **Beyan edilmiş hile / istisna**: `fnc_aracKinSurus` (AI sürücü hiç kalkmazsa betikle sürüş; sadece kaynaksız çarpışma hasarı yok sayılır; kodda "HİLEDİR" yazar). Tank mürettebat beceri tabanı 0.95 (`tankEkipSkill`, kullanıcı isteği, `reloadSpeed` dahil) — `[U]`.
4. **Ölü / kanca kod**: ~~`fnc_eliteCover`, `fnc_orphanWatchdog`, `fnc_tacticsPeel`, `fnc_sihaLazer`~~ → **v8.365'te canlandırıldı** (bkz. DEVIR_LOGU v8.365).
5. **Kitap kapsamı dışı (tasarım, `[N]`/`[T]`)**: tank mühimmat seçimi (v8.359–361; gerekçe fiziksel: AP aşırı delme/patlama yok, HE yumuşak/kümeye; kaynak set tank topçuluğu içermiyor), FPV/Mavic davranışları (v8.233–v8.356), teslimiyet animasyon sırası (kaynaklarda yalnız EPW işleme var), UGL zamanlaması, 3DEN katmanı, İHA gözlem devriyesi sayıları (v8.363: irtifa 120/400 m, süre 20 dk — `[T]`).

## 4. v8.339 – v8.363 davranışları: neden → sonuç → etiket
(`[K]` kitapta var, `[K~]` kavram kitapta var / sayı tasarım, `[T]` tasarım, `[N]` kaynak yok, `[U]` kullanıcı kararı. Satır numaraları bugün `grep` ile bakıldı.)

| Davranış | Neden → sonuç | Etiket / dayanak |
|---|---|---|
| Dron zorla ateş olasılığı (v8.340) | Küçük silahla hava hedefi vurma olasılığı düşük; olasılık = beceri(aimingAccuracy) × mesafe × dron hızı → hızlı/uzak dron az, yakın/yavaş çok vurulur | `[K~]` ATP 3-01.8 (olasılık düşük); formül `[T]` |
| Lider hakim noktaya çıkar / yer gözlemcisi (v8.342) | Gözlemci (dron/FO) yokken topçu çağıracak biri hedefi görmeli → görüş hattı açık nokta | `[K~]` gözlem rolü ATP 7-100.1; eşikler `[T]` |
| SIHA keşif sortisi (v8.344) | Tehdit yönü bilinmeden savunma planı kör → çevre halkası + yol taraması + sektör puanı | `[K~]` ATP 7-100.1 (keşif-ateş); sayılar `[T]` |
| İHA görüş katsayısı (`ihaGorus`) | Işık / hava / kamuflaj kamera tespit menzilini düşürür → uzak/gece hedef seçilmez | `[T]` (fiziksel gerekçe) |
| Zayıf iz / salvo (v8.346) | Uzun süre görülen ya da düz giden iz operatör konumunu zayıf tahmin eder → topçu güveni düşer | `[T]` |
| FPV gözcü + vurucu, EW (v8.347) | Gözcü hedef bilgisini artırır (+0.10/+0.20), EW kontrol kaybı | `[N]` açık kaynak analiz |
| Mavic yenileme, zırh aralığı, geçit beklemesi (v8.348–349) | Tekrar kullanım gerçekçi; tanklar birbirini örter | `[N]` (ATP 3-20.15 depoda yok) |
| CQB köşe temkini / yakın siper (v8.351–353) | Köşede açıyı dilimleyerek (pie) temizle; görüş hattı yoksa kendini açma | `[K~]` TC 3-21.76 "Enter and Clear a Room" (bölüm 8, Şekil 8-9/8-10), "Clearing hallway junctions" (Şekil A-15); sayılar `[T]` |
| Mermi paslama (v8.354) | Az mühimmatlı askere gruptan aktarım | `[K~]` MCWP 3-11.1 satır 10691 ("cross-leveling or resupply of ammunition"); eşikler `[T]` |
| Ateş üstünlüğü / baskı (v8.355) | Manevradan önce ateş üstünlüğü | `[K]` TC 3-21.76 satır 5144, 6489, 6723; süreler `[T]` |
| FPV eve dönüş (v8.356) | Hedefsiz dron havada asılı kalmaz; pil/süre → konar → yeniden | `[N]` |
| Teslimiyet sırası (v8.358) | Silah bırak → eller yukarı: animasyonun yarım kalmaması için sıralı | `[N]` mühendislik |
| Hekim yaklaşma iptali bekleme (v8.358/362) | Ateş altında git-gel yapmasın → hekim başına 15–20 sn | `[K~]` ATP 4-25.13 (CCP kavramı); süre `[T]` |
| Tank mühimmat seçimi (v8.359–361) | AP: zırh; HEAT: hafif zırh/IFV; HE: yumuşak/küme/bina → doğru mermiyle hasar | `[N]` fiziksel gerekçe; ölçüm loglanır (`[TANK-MUHIMMAT-ATIS]`) |
| 3DEN modül katmanı (v8.362) | Zeus zorunlu olmasın | işlevsel (doktrin yok) |
| Gözlem İHA'sı, uçak LOITER (v8.363) | Uçak havada asılı kalamaz → daire; quad → rastgele nokta | `[K~]` ATP 3-01.8 satır 276 (küçük insansız sistemler), `[T]` sayılar |

## 5. Önerilen sonraki adımlar (sırayla)
1. §3.1 `knowsAbout` tek tablo (en büyük tutarlılık kazancı).
2. §3.2 sabit yüzdeli üç kapı → nedene bağlama.
3. v8.364 + önceki sürümlerin oyun testi (özellikle düzeltme #1 ve #2: nakil sonrası waypoint temizliği, çift plan engeli).
4. İsteğe bağlı: ölü kod temizliği (§3.4), depoya tank/FPV kaynak yayınları eklenirse `[N]` satırlarını `[K]`'ya çevirme.
