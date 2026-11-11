# Yol haritası: fazlı birleşik harekât (Fırat Kalkanı tarzı) — v8.407 sonrası

Durum notu: v8.406–v8.407 değişiklikleri (tank piyade bağı sahipliği, harekât objektifi "başka planda" beklemesi, oyuncu yolcu araç, binme beklemesi, sade Saldırı/Savunma Objektifi, Objektif'e İHA desteği) oyunda DOĞRULANMADI. Her aşama kendi "kabul ölçütü" ile RPT üzerinden doğrulanır; doğrulanmayan aşama bir sonrakine geçmez.

İlkeler: (1) kontrol kaybolmaz: yeni davranış varsayılanla kapalı/uyumlu, gelişmiş ayar saklı kalır; (2) eski sahneler bozulmaz (eski modüller durur); (3) her davranış log etiketiyle izlenir; (4) sayılar TASARIM değeridir, kitapta sayı yoksa öyle yazılır.

---

## Aşama 0 — Doğrulama ve temizlik (v8.408)
Amaç: v8.406/407 düzeltmelerinin gerçekten çalıştığını görmek.

| İş | Kabul ölçütü (RPT) |
|---|---|
| Sade Saldırı/Savunma Objektifi 3DEN'de açılıyor, ayarlar görünüyor | `[EDEN] Objektif (3DEN) ... plan istegi gonderildi`; config hatası yok |
| Görev Ata `RECON` / `RECON ARACI` okunuyor | `[GOREV-ATAMA] recon -> RECON`, `[PLAN-RECON]`, `[RECON-ARAC]` |
| Tank dur-kalk bitti | `PIYADE BAGI` satırı 3 sn'de bir tekrar etmiyor; `KAPI-ACILDI` makul sürede |
| Harekât fazı sırası | `FAZ 1 basladi (1 objektif)` → Faz 1 BITTI → `FAZ 2 basladi` |
| Objektif "baska planda" bekleme | `gruplar baska planda mesgul - bekleniyor` sonra `plan KURULDU` |
| Oyuncu yolcu araç kalkıyor | `[TASIMA] ... BINDI`, oyuncunun aracı `YOL ZINCIRI` |
| İHA desteği | `[PLAN-IHA]` satırı, dron görev alıyor |
| Binmeyen asker seferi | `[TASIMA] ... sefer` ve geride asker kalmıyor |

Ek işler: Zeus panelindeki zincir alanlarını kaldır; Görev Ata `Otomatik` hâlâ etiket okumuyorsa `edGorKod` okuma yolunu incele (kök neden açık madde).

## Aşama 1 — Koordinasyon omurgası (v8.409–v8.411) ★ öncelik
Log'larda görülen asıl sorun: planlar arası koordinasyon yok.

1. **Grup/araç sahipliği (v8.409).** Bir grup/araç aynı anda tek planda. Çakışma tespitinde log + nedenli ret (`[PLAN-SAHIP]`). Tank gibi paylaşılan destek unsurları için "hangi plana hizmet ediyor" açık kayıt. Kabul: iki plan aynı grubu almıyor.
2. **Faz hattı / sınır çizgisi (v8.410).** Faza opsiyonel hareket hattı (LD / LOA / ileri sınır). Hattı geçmeden bekleme, komşuyla hizalanma. Harekât modülüne "hat" ayarı; Objektif'e yaklaşma ekseni var, onu kullan.
3. **Sektör ve komşu koordinasyonu (v8.411).** Paralel planlara sektör sınırı; birbirinin önüne geçme ve dost ateşi azaltma. Kabul: iki paralel planda zırh/piyade birbirine yetişiyor, `[PLAN-HAT]` logları tutarlı.

Bağımlılık: `fnc_komutanPlan`, `fnc_komutanPlanDongu`, `fnc_planZirh`. Risk: plan döngüsü büyük; küçük adımlarla, her adımdan sonra RPT.

## Aşama 2 — Ağırlık merkezi ve yedek (v8.412–v8.413)
1. **Ana çaba / yardımcı çaba.** Harekât modülünde faza "ana çaba" objektifi. Zırh, topçu ve İHA önceliği ana çabada.
2. **Yedek komutanı.** `YEDEK` rolünün serbest bırakılması: ana çabada tıkanma (temas + ilerleme yok) ya da kayıp eşiği → yedek devreye. Savunmada karşı saldırı.
3. **Kayıp devri.** Etkisiz grubun görevi komşu/yedek gruba (kayıp eşiği mevcut: %50).
Kabul: tıkanan planda yedek serbest kalıyor (`[PLAN-YEDEK]`).

## Aşama 3 — Ele geçir → güvence → sömürü (v8.414–v8.415)
1. **Güvence aşaması.** Saldırı Objektifi alındıktan sonra otomatik: çevre güvenliği/mevzilenme (mevcut Karakol/Savunma mantığını yeniden kullan), sonra faz geçişi. Eski "zincirde tut" davranışının faz tabanlı karşılığı.
2. **Sömürü.** Düşman kırılınca öncü (mekanize/zırh) sıradaki objektife; ana kol arkadan. Sınır: hat kuralları (Aşama 1) çiğnenmez.
Kabul: Faz geçişinde bırakılan güvence grubu mevzide, ana kol ilerlemiş.

## Aşama 4 — Ateş ve istihbarat entegrasyonu (v8.416–v8.418)
1. **Topçu hedef planı.** Faza bağlı hedef listesi; hazırlık/kaydırma; **FSCL** (dost yaklaşınca ateş durur/kayar). Mevcut dost mesafesi kontrolünü genişlet.
2. **Durum resmi (COP).** Recon + İHA raporlarını tek yapıda topla; faz başlamadan OPORD düşman paragrafını güncelle.
3. **Recon çeşitleri.** Birden çok OP, İHA keşfi + yaya recon birleşik rapor.
Kabul: topçu dost yakınında durur; OPORD güncellemesi oyuncuya düşer.

## Aşama 5 — Çevre ve engeller (v8.419–v8.421)
1. **Engel/mayın/IED modülü + istihkâm rolü.** Konvoy yavaşlar/rota değiştirir; engel temizleme.
2. **Şehir muharebesi.** Kenarda zırh destek, piyade sokak temizleme; bina temizleme yeniden yazımı (mevcut bekleyen iş).
3. **Gece/hava.** NVG/tempo/İHA kısıtı davranış bağlantısı; sivil davranışı.
Kabul: şehir kenarında zırh bekliyor, piyade bina temizliyor; engelde konvoy davranışı log'lu.

## Aşama 6 — Lojistik ve devamlılık (v8.422+)
Faz arası toparlanma içinde yaralı toplama, cephane dağıtımı, yakıt; plan komutanı kaybında devir bildirimi; helikopter medevac/hava nakli (bekleyen).

## Modül sadeleştirmenin devamı (paralel, küçük adımlar)
- Karakol + Garnizon birleşimi → Savunma Objektifi içinde "garnizon" ayarı (eski modüller kalır).
- İHA: türe göre grup (FPV / silahlı-gözlem) ayarlarını Objektif'e taşıma; bağımsız İHA modülü kalır.
- Görev Ata: iki kademeli seçim (Plan rolü / Özel rol) — şimdilik yalnız etiket gruplaması yapıldı.
- Sahne şablonu: örnek "Fırat Kalkanı" görev dosyası + `TEST_SENARYOLARI.md` güncellemesi.

## Aşama 7 — AAR ve eğitimsel tekrarlanabilirlik (eklendi; kararlar henüz uygulanmadı, hepsi "T" = doğrulanmadı)
Hedef: bit düzeyinde determinizm DEĞİL (motor: AI / fizik / yol bulma deterministik değil). Eğitim için üç şey: kontrollü değişkenlik, açıklanabilirlik, incelenebilirlik (AAR). Mevcut durum (kod taraması): `random` 171 + `selectRandom` 20 çağrı, tohum yok; ~422 `sleep`, 148 dosyada betik; tekrarlanabilirlik yaklaşık 3/10 (kendi katmanlarımıza göre kaba yargı, dış yazılımla karşılaştırma YOK; VBS4 / Titan IM Vanguard determinizmi doğrulanamadı).
Sıra (her adım: CBA bayrağı + RPT kabul ölçütü + test turu):
0. **RNG envanteri** (`RNG_ENVANTERI.md`, v8.500x: 171 `random` mikro / karar / egitim degiskenligi / teknik olarak etiketlendi; kod degismedi). Karar-duzeyi ~30-35 cagri; mikro (konum / zaman sapmasi, 106 + 35) BIRAKILIR.
1. **Tohumlu rastgelelik** (`fnc_rastgele`): tek global akış DEĞİL; sayı = f(tohum, grup kimliği, sistem etiketi, sayaç) (betik sırası farklı olsa da aynı kalsın). Tohum `[ONUCUS] RUN` satırına yazılır; eğitmen sabitleyebilir / değiştirebilir. `random` / `selectRandom` çağrıları kademeli taşınır (önce siper seçimi, varış noktası dağıtımı, rush / ateş olasılıkları, topçu dağılımı).
2. **Karar defteri `[KARAR]`**: zaman, kim, sistem, girdi özeti, tetiklenen kural, reddedilen seçenekler. Önce 4–5 sistem: plan kapısı, nakil, geri çekilme, topçu, bastırma. Mevcut dağınık etiketler (`[PLAN-KAPI]`, `[PLAN-TOPCU]`, `[GERI-CEKILME]`...) tek biçime çekilir.
3. **AAR üreticisi** (çevrimdışı, `tools/rpt_ozet.py` genişler): zaman çizelgesi + harita üzerinde konum (1 Hz, seyreltilmiş) + olaylar + karar defteri → HTML. Sınır: Arma içinden dosya yazamaz (RPT tabanlı); log hacmi sınırlanmalı. Açık soru: AAR oyun içinde (Zeus / brifing) mi, çevrimdışı rapor mu?
4. **Doktrin puanlaması**: mevcut doktrin tablolarını ölçüt yapıp tim bazlı AAR puanı (siper, ateş-hareket, kayıp, süre, dost ateşi). Ölçütlerin kitap kaynağı tek tek belgelenmeli; "tasarım değeri" işaretli olanlar puan temeli olmamalı.
5. **Tekrar-doğrulama düzeneği**: aynı senaryo + tohum, N koşu; olay sayıları ve temel göstergelerin dağılımı kıyaslanır (aynı sayı değil, aynı aralık).
6. **Karar katmanının saflaştırılması** (uzun vadeli): algı → karar → uygulama; karar "durum özeti → niyet" saf fonksiyonları (birim testlenebilir). Niyet / uygulayıcı katmanı ve hakem (uzuv) çalışmasıyla birleşik.
7. **Tohum tasarimi (karar bekliyor: varsayilan otomatik, sabitleme egitmende).** Oncelik: senaryo degiskeni (`lambs_danger_tohum`, 3DEN Harekat / Kumanda niteligi) > CBA sunucu ayari (0 = otomatik, > 0 sabit) > otomatik (UTC + `diag_tickTime`). Tohum yalniz `[ONUCUS] RUN` satirina yazilir (+ senaryo adi, harita, paket surumu, onemli CBA ozeti: karsilastirilabilirlik). Turetme: DURUMSUZ f(tohum, grup kimligi, sistem etiketi, karar baglami) tercih; ayni birim ve sistem birden fazla cekim yapiyorsa sayac. Iki cekim sinifi: **BASLANGIC** (senaryo duzeyi, bir kez, tohuma bagli: komutan kisiligi, beceriler, devriye rotalari; herkese ayni karsilasma karakteri) ve **TEPKI** (baglama bagli, oyuncuya gore degisir). Sinirlar: SQF 32-bit float (24-bit karistirici); tohumlu `random` sozdizimi (`seed random max`) bu surumde DENENMELI; editor disi (Zeus / arac) kimlikler kararsiz; kalici dosya yazimi yok (loga yaz, ayara elle gir); `profileNamespace` "son tohum" secenegi denenmeli.
8. **Opsiyonel ogrenme katmani (uc mod)**: KAPALI (varsayilan, degerlendirme: dusman ogrenmez) / HAFIZA (bugunku `fnc_komutanZihin`, oturum ici, etkisi kucuk) / UYARLAMALI (hipotezden sinirli karsi taktik). Kurallar: senaryo duzeyi cekimler (BASLANGIC) uyarlanmaz; etki sinirli (dinamik zorluk gibi sinirsiz odul / ceza YOK); uyarlama `[KARAR] ... uyarlama` etiketiyle AAR'da gorunur; oturum sonunda hafiza sifirlanir; hile yok kurali korunur. Cevrimdisi ogrenme (AAR verisinden insan onayli parametre ayari) tekrarlanabilirligi bozmadigi icin daha guvenli alternatif. Egitime etkisi: karsilastirilabilirligi zedeler (degerlendirmede KAPALI), serbest egitimde ezberi onler; kullanici testiyle dogrulanmali (T).
9. **Oyuncu profili (oturumlar arasi; opt-in; dosya tabanli)**: testlerin sonunda oyuncunun egilimi OZET olarak toplanir (250 m kare sayaclari: ilk temas yeri, yaklasma yonu 8 sektor, ana rotalar, mesafe bandi; ham iz DEGIL); en az N gozlem (ornek 3) olusunca etki eder; eski gozlemler agirlik yitirir. Dusman komutan zihnine ON BILGI (prior) olarak yuklenir (tohum zarlari ayni, profil "dusman neyi bekliyor" kismini ekler). Modlar (CBA): PROFIL KAPALI (varsayilan) / SADECE BU OTURUM / PROFIL YUKLU. Veri: cevrimdisi arac AAR / RPT'den `profil.sqf` uretir ve senaryoya konur (seffaf, surumlenebilir, tek komutla sifirlanir); profil hash'i loga yazilir. `profileNamespace` ile otomatik yazim 2. asamada, opt-in. Dikkat: gizlilik / riza (UID yerine takma ad, egitmen gorur ve siler, oyunculara bildirilir); somuru riski (degerlendirmede KAPALI); esik ve agirliklar TASARIM degeri, testle dogrulanmali.
Not: "ciddi oyun" kullanımı için gerçek doğrulama (V&V: ölçüt kaynağı, senaryo geçerliliği, kullanıcı testi) teknik katmanlardan ayrı gerekir.

## Aşama 8 — Çevre algısı ve RHS / ACE uyumu (bekleyen, "test ede ede" ilerlenecek)
1. Açık-yön servisini birleştir: `fnc_sektorBakis` kendi kopyası yerine `fnc_bakisAcikYon` kullansın (+ ACE hendek / tahkimata ek siper değeri; tür-bağımsız yedek zaten var).
2. Bina / nesne sınıflandırma tablosu (ateş geçirir mi, siper değeri: duvar, çit, kaya, ağaç, araç, ACE nesneleri); önce `fnc_atesHatiAcik` ve `fnc_bakisAcikYon` kullanır.
3. ACE tıbbi bilgi: hangi karar için okunacağı belirlenecek (komutan raporu / nakil önceliği / medevac); `fnc_tccc` zaten ACE tıbbını kullanıyor.
4. Arazi / görüş haritası önbelleği (en büyük iş, regresyon riski yüksek; 1–3 doğrulandıktan sonra).
5. RHS / ACE: hasar uyumu eklendi (`fnc_aracHasar`, CBA `lambs_danger_rhsAceUyum`, varsayılan kapalı; RHS / ACE ile DENENMEDİ). Bekleyenler: RHS koltuk düzeni / FFV kalibrasyonu, aktif koruma (Trophy vb.) sınıf tanıma, RHS MANPADS sınıflandırması.

## Açık maddeler (son testlerden)
- Şoförlerin park halinde tekrar tekrar araçtan inmesinin kaynağı (komut `GET OUT`, motor kapalı, temas yok; `MURETTEBAT-KORU` 19 kez geri döndürüyor).
- Oyuncu ve ekibinin araçlardan çok uzakta olması (8–50 km): manifest araca atıyor; bekleme kısaltıldı, atama mantığı değişmedi.
- Faz 2'de araçların başlangıçta 5 km uzakta olması (faz 1 sonrası yedekte bekleyen araçlar): tasarım kararı bekliyor.
- Duvara ateşin kaynağı doğrulanamadı (motorun otomatik atışı mı, başka bir modül mü); `tacticsSuppress` hat kontrolü eklendi, gözlem bekleniyor.
- 3DEN niteliklerinin tüm senaryolarda sağlam okunduğunun doğrulanması (kök neden düzeltildi: `%s` sınıf adını veriyor; ön uçuş `--onucus` ile kontrol edilir).

## Aşama 9 — Tasarımcı güdümlü makro katman (dal: `claude/tasarimci-makro`; hibrit: otomatik varsayılan, tasarımcı geçersiz kılar)
Gerekçe (kullanıcı + oturum verisi): makro kararları sistemin tahmin etmesi her testte yeni varsayım hatası üretti (medevac aracı recon aracı seçildi, 6 km uzak araç 11 dk beklendi, oyuncu / ekibi araçlardan 8-50 km uzakta ama manifeste girdi, kuvvet oranı kapısı yolcuları saymadı, faz 2'de araçlar 5 km uzakta). Makroyu senaryo tasarımcısı (3DEN + Trigger + modüller) verir, FSM mikroyu yürütür. Tohum / "neden binmedi" sorunları küçülür. Mikro güvenilirlik (araç takılması, yol bulma, koltuk) yine bizim işimiz. Hepsi "T" (denenmedi).
1. **Modüller tetikle başlatılabilir** (Objektif x3 + Harekât: `isTriggerActivated = 1`; Trigger SYNC'liyse tetik tetiklenince, yoksa mission başında; tek seferlik koruma; log `[EDEN] ... baslatildi | bagli tetik`). Sınır: Harekât'a bağlı objektiflerde tetiği HAREKÂT modülüne bağla; Trigger davranışı (`_activated`, `EmptyDetector`) oyunda DOĞRULANMALI.
2. **Nakil modu**: Otomatik (bugünkü) / Tasarımcı atamalı (SYNC ile araç grubu <-> hizmet edeceği gruplar; "Nakil Emri" modülü mü SYNC mi: karar bekliyor).
3. **Kapı koşulları tasarımcıya açılır**: recon önce / hemen / tetikle, kuvvet oranı kapısı, nakil bekleme tavanı, faz arası.
4. **Plan A / B**: iki objektif + tetik + başarısızlık çıktısı; seçici ve her seçim `[KARAR]` defterine (neden A / neden B).
5. **Öncelik ağacı**: modül bazlı yapılandırılabilir (1-4 kullanımından sonra gerekenler belirlenir).
0. **Tasarımcı araçları (ilk iki hazır, "T" = denenmedi):** (a) `tools/senaryo_denetimi.py <mission.sqm>`: oyunsuz senaryo denetimi (HQ bağlantısı, rol grupları, objektif / Harekât / faz, nakil koltuğu ve mesafe, sürücüsüz araç, oyuncu, İHA / topçu mesafesi); sentetik `tools/ornek_mission.sqm` ile sınandı, GERÇEK mission.sqm ile doğrulanmadı (grup adı, araç / asker ayrımı, SYNC hedefi için yedek yollar var, ikili SQM okunamaz). (b) Oyun içi ön uçuş özeti: uyarılar ana bilgisayar + Zeus'a sohbet olarak da gösterilir (`lambs_danger_onUcusSohbetOff`). Sırada: mikro-senaryo test seti, Nakil Emri modülü, tetikli olay modülü, plan görselleştirme, AAR.
0b. **SENARYO MODU (v8.502, CBA `lambs_danger_senaryoModu`, varsayılan KAPALI; hazır senaryoları, örn. Blackfox, gözlemlemek için):** tasarımcı waypoint'i olan gruplarda ELITE hareket / taktik kararları yok sayılır; GERİ ÇEKİLME (WITHDRAW / PEEL / EVADE_ARMOR + <4 asker temas kes), panik, teslim, tıbbi, ateş disiplini ve araç güvenlik freni AÇIK kalır. Kapsam CBA `senaryoKapsam`: 0 = yalnız aktif waypoint'i olan gruplar, 1 = tüm AI grupları (waypoint yerine scripted `doMove` kullanan senaryolar için). Kapı: `fnc_senaryoKapi` (log `[SENARYO-MODU]` + 120 sn özeti). SERBEST (v8.502b): bounding / overwatch (HOLD), arka + yan emniyet, nokta elemanı, ileri gözcü (lidere göre konumlanır, rota değiştirmez); bounding rotadan saparsa (`fnc_senaryoRota`: lider başlangıç→waypoint doğrusundan >120 m yana sapar ya da waypoint'ten >60 m uzaklaşırsa) iptal edilip waypoint'e döndürülür, bounding sonu hücum devri kapalı. Yok sayılan: DELAY (hide), SUPPRESS_ASSAULT, FLANK, ASSAULT, AT_ENGAGE, ateş-hareket (rush), CQB çevik, formasyon yazımı (geri çekilme hariç), rol istasyonu, buddy, dağılma, yetim, araç senkronu, mekanize, tank aralığı, açıkta bekleme, HQ emirleri (`fnc_tactics`, `formSet`, ilgili izleyiciler). DENENMEDİ (T); Blackfox'un waypoint mı script mi kullandığı doğrulanmadı.
6. **Oyuncu eğilimleri + öğrenen seçici**: en sonda; Aşama 7 madde 8-9 (karar defteri + oyuncu profili) ile birleşir.

## Aşama 10 — SADE WAYPOINT (dal: `claude/sade-waypoint`, v8.503) — Aşama 7-9'un plan / nakil / objektif kısımlarını İPTAL eder
Karar (kullanıcı): botlara senkron combined arms yaptırmak sürdürülemez; **tasarımcı waypoint + tetik** yeter. Makro (manga) koordinasyon kalır, Objektif kalmaz; FPV + UAV kalır; yetenekler hem araç hem piyade için korunur.
- **Kaldırıldı:** komutan planı, Objektif (Saldırı / Savunma / eski), Harekât, nakil (V2 dahil), recon aracı, HQ / US, hendek-mevzi kurulumu, tank düellosu / bakışı / yol zinciri, SurusAB testi, 17 plan CBA ayarı. Eski hâller: `claude/nakil-v2`, `claude/tasarimci-makro`.
- **Kalır:** Kumanda / Koordinasyon (istihbarat paylaşımı, takviye, kanat, destek, medevac), Karakol / Garnizon / Gözetleme / Görev Ata / Çatışma Pozisyonu, FPV + İHA (ihaSorti, ihaBekle, İHA Görevi, dronTopcu, dronAvi yaya devriye), taktik tepkiler (bounding, ileri gözcü, arka emniyet, CQB ...), tank / araç tepkileri (tankIzle, tankKoru, tankHedefSec, tankAtesKontrol, mekanizeIzle, aracZirhKac ...), senaryo modu, tohum, ön uçuş.
- **Açık / sonraki:** (1) oyunda doğrulama (hiçbir şey denenmedi: boş mission + Kumanda / Karakol / İHA modülü + ön uçuş çıktısı); (2) tank düellosunun waypoint-dostu yeniden yazımı (mevcut tankIzle üstüne) — istenirse; (3) Karakol "savunma" davranışı artık yalnız garnizon; (4) rpt_ozet `--karne` eski plan satırları YOK / KONTROL gösterebilir (bilinen).

## Sürüm disiplini
- Her aşama: değişiklik → RPT ile kabul ölçütü → `DEVIR_LOGU` ve `OZELLIKLER_LISTESI` güncelleme.
- Doğrulanmayan davranış belgede "T" (doğrulanmadı) işaretlenir.
- Büyük aşama başlamadan önce kod incelemesi ve küçük prototip; geri alma için bayrak (CBA ayarı ile kapatma) bırakılır.

## Açık sorular (karar bekleyen)
1. Faz hattı: çizgi 3DEN'de elle (modül/işaret) mi çizilsin, yoksa Objektif yaklaşma ekseninden otomatik mi türetilsin?
2. Ana çaba seçimi: Harekât modülünde faz başına tek Objektif mi, yoksa Objektif'te "ana çaba" onay kutusu mu?
3. Güvence aşaması varsayılan açık mı kapalı mı? (öneri: açık, süre 5 dk)
