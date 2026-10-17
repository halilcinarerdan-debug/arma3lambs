# LAMBS Danger FSM — ELITE fork: Özellik Listesi (v8.237)

LAMBS Danger FSM 2.6.2 üzerine eklenen katmanlar. Her özelliğin yanındaki kapatma değişkeni
`lambs_danger_<ad>Off = true` biçimindedir. **(T)** = oyunda henüz doğrulanmadı / kısmen doğrulandı.
Doktrin iddiaları "tasarım tahmini"dir; kaynaklı olanlar `kaynaklar_doktrin/` altındadır.

---

## 1. Komuta ve karar (komutan beyni)
- **Komutan beyni v2** (`commanderAssess`): rol ağırlıklı güç oranı, zırh / MG / baskı farkındalığı, kayıp oranı;
  kararlar: BOUNDING, SUPPRESS_ASSAULT, DELAY, PEEL, WITHDRAW, PUSH, HIDE...
- **Doktrin çerçevesi** (`doktrin`, `dk`): ordu / grup başına profil (ABD, RUS, GENEL, **DUZENSIZ** isyancı); CBA'dan taraf başına seçim.
- **CBA taraf seçimi**: ELITE'in hangi tarafta (BATI / DOĞU / BAĞIMSIZ / SİVİL) aktif olacağı.
- **KUMANDA (HQ) çekirdeği**: istihbarat ağı (SPOTREP, telsiz şartı, gecikme, belirsizlik, "bilgi sisi" ayarı), takviye,
  kanat manevrası, feint (yanıltıcı saldırı), medevac koordinasyonu, tek emir kanalı (`hqEmir`).
- **Arazi bilinci** (`araziAnaliz`, `ufukMu`): komutan hâkim nokta, ufuk çizgisi, bireysel arazi kıvrımı.
- **Taktik rota planlama** (`rotaPlan`): ortülü yaklaşma, ara nokta zinciri.
- **Karşı pusu kuralı**, **ölüm bölgesi hafızası** (ateşten öğrenme), rota gözcüsü.

## 2. Manevra ve taktikler
- **Bounding Overwatch** (USMC tarzı): 3 ateş timi (Fire Support / Maneuver / Reserve), dönüşümlü sıçrama, mesafeye göre sıçrama boyu.
- **Kademeli geri çekilme** (Retreat / Peel): iki takım, dönüşümlü sıçramalar, baskı altında önce siper; çekilme sonrası **toparlanma**
  (consolidate & reorganize). Çekilme bilerek acımasızdır (kolay başarılmaz).
- **Temas kesme**, **son direniş** (kale savunması), **sinsi geri çekilme** (kullanıcı: çalışıyor görünüyor, loglarla izlenecek) (`sinsiGeri`): düşman ezici üstünse ve grup henüz ateş altında değilse
  ateşi kes, öndekileri (lider dahil) gizli noktaya çek, bekle.
- **Pusu davranışı + ateş emri (ROE)**, **hücum öncesi bastırma penceresi**, **kanat ateş kaydırma**.
- **Zırhtan kaçış**, **AT zırha taarruz + AT escort**, **AT atışı** (`atFire`).
- **Yol geçişi** (`tehlikeAlani`, T): açık çizgisel tehlike alanında dur-gözetle, iki takım dönüşümlü geçer.
- **Tek kalan asker saklan / başka squad'a katıl** (`yetimKatil`, ≤2 asker).
- **Traveling overwatch nokta elemanı**, **yan koruma + arka emniyet**, **ileri gözcü + RTO**.
- **Keskin nişancı takımı**, **baskı tüfekçisi** (gerçek MG yoksa atama).
- **Komutan bekle** (komutan timini geride bırakıp ilerlemez), **buddy bağı** (kalıcı eş, tek başına dolaşma kontrolü), **orphan watchdog**.

## 3. Formasyon
- **Formasyon yazma hakemi** (`formSet`): tek yazıcı, öncelikli (0..2), taktik formasyonu 25 sn korunur, histerezis, osilasyon önleme.
- **Araziye göre formasyon seçimi**; ≥4 araçlı açık arazi yaklaşmasında DIAMOND, aksi COLUMN.
- **Halt / slot kovalama kesici** (`haltKur`): lider durunca slota yakın askerler yürümeyi keser.
- **Dağılma bilinci** (`dispersion`): tek el bombası / RPG hepsini almasın; RPG görülünce 9–16 m dağılma.

## 4. Siper ve saha ustalığı
- **Raycast elit siper seçimi**, **siperin yarım metre uzağında kalma düzeltmesi** (`coverHug`), **önce siper sonra ateş**.
- **Şarjör değiştirme koruması** (açıkta reload yok, buddy korur).
- **Yakın mesafe refleksi (CQB)**, **bina rolü / etaj / peek**, **iç mekân atış pozisyonu**, **bina çevre emniyeti + temizleme** (`buildingClear`).
- **Rol istasyonu** (herkes görev yerini bilir), **ateş hattı kontrolü** (dost ateş hattı yan adımı).
- **Yaprak arkası görüş kırıcı**, **kamuflaj bilinci**, **ortam beceri düşüşü** (ışık / NVG / sis / yağmur).
- **Optiksiz birim doğruluğu ×0.75**, **varsayılan beceri** (Zeus / editor ile gelen her piyadeye).

## 5. Ateş desteği ve patlayıcılar
- **Taktik UGL (40 mm)**: uzak mesafe, rezerv, HE yükleme (duman / flare ile doldurulmaz), salvo.
- **Taktik sis**: düşmanın üstüne değil, geçiş / bastırma için doğru yere.
- **Atış güvenliği** (RPG / UGL öncesi dost ateşi, geri patlama).
- **El bombası farkındalığı**: atılınca iniş noktası tahmini, 0.2 sn tarama, yaklaşan bombadan uzaklaşma.
- **Baygına patlayıcı yasağı** (kullanıcı doğruladı): baygın hedefe el bombası / roket / 40 mm / pompalı iptal; hedef yoksa iniş noktasına göre karar.
- **RPG tepkisi**, **roket / duman izleme** (`tehditIzle`, `tehditOlay`): atıcıyı açığa çıkarır, araç mürettebatı da tepki verir.
- **Ateş merkezi** (`firedHub`): tüm "Fired" olayları tek yerden.
- **Hava farkındalığı**: dron + helikopter, ateş disiplini + toplu ateş.

## 6. Sağlık (TCCC / medevac)
- **TCCC** (ACE Medical + ACM): hekim yaralıya gider, kanama durdurma (sargı / turnike), kalp durmasında CPR + epinefrin, IV, morfin;
  ateş altında yalnız baygına ve yalnız kanama kontrolü.
- **Triyaj önceliği**: kalp durması > kanama hızı > düşük kan hacmi > bekleme süresi (hemşire onayladı).
- **FirstAidKit = FieldDressing yedeği**, eşya yoksa o adım yok, yarasız bölgeye eşya harcanmaz.
- **Hekim durgun tespiti**: kademeli müdahale + pürüzsüz script yürütme (AI komutu işlemezse).
- **Ölü betik kilidi temizliği**, bayılan hekimin hareketi durdurulur.
- **Gerçek hekim bounding'den muaf**, **sağlıkçı tasması** (hekim öne geçmez).
- **HQ medevac**: gruplar arası hekim atama, talep / hekim havuzu kuralı. **Araçlı medevac** (T): kara aracı yaralıları taşır; **doktrin standoff'u** (zırhlı ≥ 300 m, yumuşak araç ≥ 600 m düşmandan; yaralıyı düşmandan ≥ 600 m uzağa / CCP'ye taşır; tasarım değerleri, kitapta sayı yok). Zeus "Görev Ata" ile MEDEVAC ekibi / aracı seçilir.
- **AI sürükleme kapalı** (ACE startDrag AI'da çalışmıyor; kullanıcı kararıyla iptal).
- Baygın asker **kayıp sayılır** (komutan, moral, HQ, son direniş); COD tarzı kaldırma yok.

## 7. İnsan faktörü
- **Moral + teslimiyet** (VBS4 fikri), **yorgunluk duyarlı atılım**.
- **Panik / felç** (`panikFelc`): donma, kör ateş, kaçış; LAMBS doPanic ile bütünleşik; oyuncu karşısında hafifletilmiş (varsayılan 0.35, tavan 0.12).
- **Sivil / dost / esir koruma** (`roeGuard`).
- **Bilgi sisi**: HQ istihbaratı oyuncuya karşı kolaylaşmasın diye varsayılan 0.4.

## 8. Algı (hile yok, yalnızca bildikleri)
- **Gizli algı** (`gizliAlgi`): oyuncunun ayak sesi (hız × duruş × zemin, ≤45 m), el feneri / IR lazer (koni + çizgi görüşü).
- **Ses / muzzle flash / duman farkındalığı**, **IED farkındalığı** (ACE EOD entegrasyonu: EOD imha, güvenlik elemanı, ikincil cihaz kuralı).
- **Tehdit yönüne bakış** (boş duvara değil).

## 9. Mekanize
- **Mekanize dur-kalk izleyici** (`mekanizeIzle`): sürücü forceSpeed sıfırlama, COLUMN / FULL; **doAssaultSpeed overlay** (araç içindekine uygulanmaz).
- Aracın roket / duman tepkisi, ≥4 araçta DIAMOND (DÜZENSİZ doktrinde yok).
- **Araç–piyade senkronu** (T) (`aracSenkron`): araç piyadeyi aşmaz; nakil / medevac görevindeki araç muaf.
- **Kara aracı nakli + taksi** (T) (`aracTasima`, `taksi`): APC / IFV / kamyon grubu alma noktasından alır, hedefin ≥ 500 m öncesinde (M16 menzili + pay) indirir, geri döner. Plan TASIMA fazı + genel "taksi" (aktif waypoint > 1200 m, araç ≤ 600 m). Zeus "Görev Ata → TASIMA".

## 10. Lojistik
- **Cephane + el bombası paslama** (şarjör paslama çalışıyor — kullanıcı; el bombası tarafı henüz görülmedi) (`cephanePaylas`): eşler arası önce; vericinin yere bırakıp alıcının alması; sınıflar mermi simülasyonundan bulunur (RHS).

## 10b. Komutan planı ve Zeus modülleri (v8.113+)
- **ELITE Objektif** (Zeus, 3 küçük panel): görev tipi (ele geçir / savun / iptal / onay ver), tempo (dengeli / sessiz-gizli / hızlı), H-saati + Zeus onayı, süre sınırı, tehdit yönü, düşman bilgisi (piyade / zırh / AT / MG / nişancı / bina), kısıtlar (siviller, ağır silah yasağı), topçu / havan (RED + danger close), rally / ORP mesafesi, **Baskın (vur-çek)**.
- **Planlayıcı** (`komutanPlan`, `komutanPlanDongu`): arazi tanıma → RP → ORP → keşif (kısa durak) → destek (SBF) + manevra + kanat → saldırı → toparlanma / çekilme; savunmada sektörlü mevzi + garrison. Gerçek waypoint'ler ("ELITE PLAN: …", Zeus'ta görünür), harita işaretleri, `[PLAN-OZET]` AAR.
- **Gizlilik önceliği (sızma)**: gizli tempo / baskında temas yoksa ateş yok (GREEN), objektife < 450 m çömelerek; temasta / saldırıda serbest.
- **ELITE Plan Noktası** (manuel RP / ORP / SBF / kanat / CCP, tarihsel canlandırma; komutan hatalı olsa da uygular, `[PLAN-UYARI]`).
- **ELITE Görev Ata**: grup / araca MANEVRA / DESTEK / YEDEK / HARİÇ / MEDEVAC / TOPÇU / TOPÇU_YOK / TASIMA ata; atananlar plana grup sayısı sınırına bakılmadan girer.
- **ELITE Karakol / HQ** (haritadan): karakol / mevzi / HQ / gözetleme noktası; savunma planı hemen / alarm (düşman 800 m içinde gerçekten bilinince).
- **ELITE Karakol Garnizon** (kullanıcı doğruladı): nöbetçiler (üst kat + yüksek arazi pozisyonları, görüş skoru), devriye alt grupları (alarmda çevre savunması), araçlar çevre mevzisinde; tekrar tekrar düzenlenebilir, yeni birimler havuza girer.
- **Sunucu devri** (`grupSunucuDevir`): istemcide kalan AI grupları sunucuya devredilir (Zeus PC yükü); plan da uzak grupları devralır.
- **MP**: Zeus modülleri CBA sunucu olayı gönderir (plan sunucuda kurulur), sonuç `[PLAN-YANIT]` ve Zeus sohbetinde.

## 10c. v8.131 – v8.168 eklemeleri
- **Keşif unsuru (RECON)** (yaya gözlemi çalışıyor — kullanıcı): Gorev Ata → RECON grubu gözlem noktasına (OP) STEALTH + GREEN sızar, ateş gelene kadar ateş etmez, plana rapor verir (gözlenen düşman / sivil sayısı).
- **İstihbarat / PID** (T): "iddia ≠ gerçek" (Irak 2003 örneği). Bilgi güvenilirliği (yetersiz / orta / kesin) + doğrulama disiplini (tam keşif / son doğrulama / yok); topçu yalnız rapor + sivil yoksa atar; sivil gözlenirse atış iptal; atış sonrası sivil / dost zararı `[PLAN-ZARAR]`.
- **Plan nakli** (T): kara aracı (APC / kamyon) plan toplanmasında erken başlar, takım bazlı bölme, sığmayanlar için sefer (en çok 3), medevac varsa 1 araç rezerv, iniş doktrin mesafesinde (RUS 300 m, diğer 500 m), yol üstü inişe sürme.
- **Nakil dayanıklılığı**: dinamik alma noktası, pusu (uzak: geç, yakın: in), takılma tanısı + kurtarma (motor zorlaması, sürücü yeniden oturtma, ara nokta), mürettebat toplama / tamamlama, yolcu bekçisi (hareketli araçtan inme emrini iptal), zırh grubu kalma (RUS).
- **Ezme koruması** (T): hareketli araç AI sürücüsü dost yayaya (yatan dahil) önde / 7 m yakında fren yapar; 30 sn kilitlenme önlemi. Log `[EZME] [EZME-NABIZ] [EZME-BAYGIN]`.
- **Mürettebat koruma** (T): sürücü / komutan / nişancı araçtan inme emrini iptal eder, dışarıda kalan geri döner; yanan araçta ve temasta devre dışı.
- **Rus doktrini** (ATP 7-100.1 + nizamname Bölüm 3): keşif atışı hızlı, topçu x2, 300 m iniş, zırh grubu; GM Doğu Almanya (`gm_fc_gc`) RUS, Batı Almanya / Danimarka ABD. NATO / RUS müfreze-manga notları `kaynaklar_doktrin/`.
- **Oyuncu komutası** (T): oyunculu gruplar ya da Gorev Ata "OYUNCU KOMUTASI" → ELITE taktik katmanı kapalı; TCCC / cephane / IED / ezme / mürettebat açık. "ELITE TAM AÇIK" ile ezilir.
- **Objektif paneli 4 / 4 + elle squad seçimi** (kullanıcı doğruladı): "Grup seçimi: Elle" → squad listesi (en çok 16), yalnız seçilenler plana girer.
- **Komutan zihni + tavır motoru** (T): karşı taraf hakkında yalnız algılananlardan (ateş, duman, topçu, görüş, temas, kayıp) gözlem defteri; alışkanlık hipotezleri (yön, menzil, duman, arazi, karşılık, zırh, topçu); kişilik (temkinli / dengeli / saldırgan) + doktrin ile tavır puanlama (loglu); şimdilik etki: beklenen yöne gözetleme. Oturum hafızası, SQL yok.
- **Araç sınıfı + roller** (T, v8.163-164): `aracSinif` TANK / IFV / APC / KAMYON; APC = savaş taksisi (indirir, geride rezerv), IFV indirdikten sonra zırh ateş desteğine katılır (`planZirh`: ateş pozisyonu 380-680 m, tasarım tahmini), tank elle seçimle zırh desteği olur. Elle seçim listesinde TANK / IFV / APC / KAMYON etiketleri.
- **Nakil iyileştirmeleri** (T, v8.163-168): öğrenilen gerçek koltuk kapasitesi, erken sefer, en boş araca dengeli dağıtım (hiçbir araç boş kalmaz), eşleşen piyade araç gelene kadar BEKLER, piyade 120 m içindeyse araç gitmez piyade biner, alma yolunda takılma kurtarma, araç gelemezse piyade araca yürür, araç grubu sunucuya devri (sürücü yerel değilse hareket etmiyordu), devir bekleme 15 sn.
- **Araç çarpışma güvenliği** (T, v8.167): nakilde önde kara aracı varsa mesafe tutar / frenler (en çok 20 sn). Log `[TASIMA] CARPISMA GUVENLIGI`.
- **Kapasite uyarısı** (T, v8.167): elle seçimde piyade sayısı ≠ taşıma aracı koltuk toplamı ise sohbet + RPT uyarısı.
- **Tanı / düzeltmeler**: sunucu devri yeni gruba 120 sn bekler (çıplak / boş envanter kökü), giyim tanısı `[GIYIM-TANI]`, cephane animasyonu varsayılan kapalı + envanter dolu kontrolü + `[CEPHANE-ENV]`, A/B anahtarları `lambs_danger_silahDegisimOff` / `cephanePaylasOff` / `giyimTaniOff`.

## 10d. v8.169 – v8.225 eklemeleri
Hepsi **(T)** = oyunda tam doğrulanmadı. Sayısal eşikler **tasarım değeridir** (kitapta sayı yok), kaynaklı olanlar `DOKTRIN_KAYNAKLARI.md` içindedir.
- **Komuta ve plan**
  - *Savunma komutanı* (BEKLE fazı): ortak düşman resmi (lider bilgisi), YEDEK grupla karşı saldırı, ağır kayıpta (%60) mevzi kaybı. *FRAGO*: saldırıda toplam kayıp %50 ise CEKILME. Kapatma: `savunmaKomutanOff`, `fragoOff`.
  - *HQ otomatik*: ELITE planı kurulunca Kumanda modülü gerekmeden açılır (`hqPlanOtomatikOff`). *HQ TAMAMI* modu: HQ'ya bağlı tüm squadlar + karakol garnizonları saldırır (güvenlik elemanı bırakma seçeneğiyle).
  - *Ret nedeni*: plan reddedilince gerçek neden Zeus'a gösterilir. *Hedef zinciri*: aktif plana sıradaki hedef eklenir, hedef alınınca hayatta kalan gruplar otomatik ilerler (`[PLAN-ZINCIR]`).
  - *Dost toplanma noktası* (panel 3/4): RP olarak haritadaki dost karakol/mevzi/gözetleme noktası seçilebilir (`[PLAN-RP-ISARET]`). *Recon ek gözlem* (panel 4/4): düşman karakol/mevzi noktaları sırayla gizlice gözlenir (`[PLAN-RECON-EK]`).
- **Keşif (RECON)**: recon için ayrı APC (Görev Ata "RECON ARACI" > MEDEVAC takımı aracı > görevsiz > TASIMA atanmış; v8.226), ana kol recon APC yolun %60'ını geçince kalkar (keşif önde), sessiz sürüş (SAFE/GREEN), geç katılan recon, canlı gözlemle herkes doğrulayabilir, temasta geri dönüş kriteri (FM 3-98), araç yoksa yaya.
- **Topçu**: canlı gözlem doğrulaması, BASIT mod (doğrulamasız), atış paceleme (2'şer mermi/6 sn), Zeus "ELITE Topçu TEST", **duman perdesi**, **karşı-batarya**, **ateş kaydırma** (derinliğe), RED/dost mesafesi kuralları (TC 3-21.76). Ayıklama anahtarları: `topcuPartiN`, `topcuAralikS`.
- **Nakil / mekanize**
  - Yükle-ve-bekle (ATP 4-01.45 ilkesi): binme beklemez, kalkış kapısı en fazla 60 sn (`nakilTutmaS`, tasarım değeri). Sürücü grubu sunucuya 15 sn sonra devredilir. Konvoy takılan aracı beklemez.
  - Takılma kademeleri (tasarım değeri): 8/12/18/20/28/45 sn; **kinematik sürüş** (`fnc_aracKinSurus`, **motor sorununa karşı geçici çözüm, doktrin değil**): AI sürücü sürmüyorsa araç betikle rota boyunca sürülür; sürücüyü koltuğa ışınlar, yayayı yana çeker, aracı dolanır.
  - *Araç kurtarma*: hasarla devre dışı kalan aracın yolcuları boş rezerv araçlarla yeniden nakil ister (`[TASIMA-KURTARMA]`). Su kaçınma (`[ARAC-SU]`), asker su kurtarma (`[SU-KURTAR]`, dalgıç/donanma muaf).
  - Tank: hull-down puanlaması + hasar sonrası yedek mevzi (ATP 3-20.15), savunmada hedef seçimi, SAFE/FULL yol yürüyüşü, `planZirhMax`.
- **Gelen topçu tepkisi (v8.228)**: topçu/havan mermisi izlenir, düşme noktası ~7 sn önce tahmin edilir, piyade uzaklaşıp yere yatar, patlamadan 7 sn sonra kalkar (`[TOP-GELEN]`, `topSiperOff`). Hendek alanı varsa (v8.229) oraya koşup yatar.
- **Hendek alanı (v8.229)**: elle konan dikdörtgen işaret (`elite_hendek*`, Trench Generator'dan bağımsız) — SAVUN planında grup hendek ekseni boyunca dağılıp çömelir (`[HENDEK-YERLES]`), gelen topçuda sığınak olur. Yol bulma/rampa gereksinimi doğrulanmadı.
- **Hendek bilinci (v8.230; v8.238: öncelik artırıldı — topçu altında temassız da hendeğe girer, 22 sn erken uyarı, hendekteyse kalır; kapatma `hendekOncelikOff`)**: plan dışı gruplar temas + baskı/yakın düşman altında ≤ 70 m'deki hendek alanına formasyonsuz girer, temas bitince 45 sn sonra çıkar (`[HENDEK-BILINC]`, `hendekBilincOff`). SAVUN hendekleri gruplar arasında dağıtır. Gelen topçu tespiti Zeus topçu modüllerini de kapsar (ShellBase taraması).
- **Ağaçlık gizlenme + İHA gözlemi (v8.232)**: duran AWARE/SAFE gruplar açıktaysa 150 m içinde ağaç ortülü noktaya geçer (`[AGAC-GIZLEN]`, kullanıcı doğruladı); AI mürettebatlı keşif İHA'ları gördükleri düşmanı ortak resme verir (`[IHA-GOZLEM]`, topçu doğrulaması dahil). FPV/kamikaze: v8.233.
- **İHA görevi (v8.233)**: Zeus "ELITE IHA Görevi" — FPV-AT/AP kamikaze (hedef bilinen zırhlı/personel kümesi, dalış ve patlama), BOMBA (Mavic: 3 el bombası), GÖZLEM devriyesi; `[IHA-ENVANTER]` mod sınıflarını loglar, tür adla tahmin edilir (elle düzeltilebilir). Mod davranışı doğrulanmadı.
- **Karakol / gözetleme**: Zeus modülü "ELITE Gözetleme Ata": squad (tank dahil) seçilen karakol/mevzi/gözetleme noktasında nöbet tutar (`[GOZETLE]`, `[GOZETLE-ARAC]`). Karakol devriye noktaları sudan kaçınır.
- **Sağlık/diğer**: TCCC malzeme toplama (`[TCCC-ESYA]`), buddy bağı garnizon gruplarını atlar, EZME yol açma (`[EZME-YOL-AC]`).
- **Tanı**: `[SURME-TANI-*]` (AI özellikleri, hasar, grup, çevre, sürücü çıkışı), `[SURME-DENEY]` (varsayılan KAPALI; açmak için `surmeDeneyOff = false`), `[TASIMA-KIN]`, `[TASIMA-FIZIK]`. Sunucu donması ayıklama anahtarları (v8.207).
- **Bilinen açık sorun**: RHS Stryker/M113 AI sürücüsü duran araçta "MOVE" tutup sürmüyor (hedef `DoNotPlan`); nedeni bilinmiyor, kinematik sürüş geçici çözüm.

## 10f. v8.238 – v8.239 (T = doğrulanmadı)
- **Hendek önceliği (v8.238, T)**: topçu altında hendek alanı varsa 22 sn erken uyarı + 60 m erişim, hendekteyse kalır; hendek bilinci topçu altındaki grubu temassız da hendeğe sokar (`hendekOncelikOff`).
- **Çoklu mevzi (v8.239, T)**: Zeus Plan Noktası → "MEVZI ekle" (birden çok); SAVUN planı gruplara halka yerine bu mevzileri dağıtır (tehdit yönüne yakın önce; hendek 40 m içindeyse hendeğe). `[PLAN-MEVZI]`.
- **Araç sürüş A/B testi (v8.239, T)**: Zeus "ELITE Arac SURUS A/B Testi" — AI sürücü kök neden tanısı (ELITE kapalı/açık, doMove/waypoint, yolcu, otomatik bisect). `[SURUS-AB-*]`.

- **Stryker FFV kök neden düzeltmesi (v8.240, T)**: yolcu FFV koltuğundayken RHS Stryker sürücü emrini yapmıyordu (A/B testiyle bulundu). Düz koltuk sayımı (`aracDuzBos`), düz koltuğa oturtma (`aracYolcuKoy`) ve FFV yolcusunu düz koltuğa taşıyan/indiren watchdog (`aracFfvDuzelt`, `ffvDuzeltOff`). Stryker nakil kapasitesi 6.

- **Mevzi tutma (v8.243, T)**: hendekteki grup (SAVUN planı ya da hendek bilinci) LAMBS komutan beynine (DELAY→hide, HOLD→`Hide (holding)`, FLANK/ASSAULT), buddy bağına, dağılmaya ve rol istasyonuna tabi değildir; yerinde durup ateş eder. İstisna: grup kaybı ≥ %60 (TASARIM). `[MEVZI-TUT]` (`mevziTutOff`).
- **Karşı saldırı dönüşü (v8.243, T)**: YEDEK grup karşı saldırıdan temas yoksa (varış + 40 sn / 200 sn) mevzisine döner; düşman listesi yalnız gerçek (yaya / mürettebatlı) hedefler. `[PLAN-SAVUNMA] KARSI SALDIRI BITTI`.
- **Savunma süresi uzatma (v8.243, T)**: süre dolunca temas / bilinen düşman varsa savunma planı en çok 2 katına kadar sürer (`savunmaUzatmaOff`).
- **Savunma ateşi (v8.243, T)**: topçu desteği "çağrı" olan SAVUN planı, bilinen düşman ≥ 3 ve düşman dostuna ≥ 480 m iken 120 sn'de bir düşman ağırlık merkezine atış ister (RED kuralları `_topcuAt`'te). `[PLAN-TOPCU] ... SAVUNMA ATESI` (`savunmaTopcuOff`).
- **Araç-piyade senkronu BEKLE tavanı (v8.243, T)**: duran (hendekteki) piyadeyi bekleyen araç 45 sn sonra 90 sn serbest kalır (`senkTavanOff`).
- **Topçu erken kaçış + `[TOP-TEPKI]` (v8.243, T)**: hendek erişimi yoksa ve tehlike yarıçapı içindeyse (uyarı ≥ 10 sn) hemen uzaklaşır (45 m'ye kadar) (`topErkenKacisOff`).
- **IFV sürücü emri onarımı (v8.243, T — kök neden kesin değil)**: planZirh BTR'sinin sürücüsü `GET OUT` / atamasız ise yeniden atanır (`zirhSurucuOnarOff`).

- **Tank / IFV savunma mevzisi (v8.244, T)**: SAVUN planındaki tank/IFV (planZirh) objektifin önünde 650 m değil, piyade hattının içinde/arkasında (objektife 70-260 m) tehdit yönüne bakan hull-down birincil mevziye yerleşir; tehdit gelene kadar 55 m gerideki gizleme noktasında bekler, tetikte (≤1500 m bilinen düşman / piyade teması) birincile çıkar; hasarda alternatif mevziye geçiş (v8.194) korunur. `[PLAN-ZIRH] SAVUNMA MEVZISI / TETIK` (`tankMevziOff`). Kaynak: ATP 3-20.15 4-46..4-49, 4-69..4-78 (mesafeler TASARIM).
- **Sürücü yenileme (v8.244, T)**: sürücü ölürse yaşayan AI yolcu (en düşük rütbe) sürücü koltuğuna geçer; yolcusuz araç (tank) yedek bulamaz, log yazar. `[SURUCU-YENILE]` (`surucuYenileOff`).
- **Gözetleme aracı yönü (v8.244, T)**: karakol gözetleme tankı noktaya vardığında bilinen düşmana, yoksa plan tehdit yönüne bakar (eskiden noktadan dışarı sabit yön).

- **Nakil yol zinciri (v8.245, T)**: inise > 1200 m olan nakilde araç tek uzak `doMove` yerine ~300 m'lik `calculatePath` ara noktalarını izler (60 m kala sıradaki bacak, grup waypoint'i de her bacakta yenilenir). Kök neden hipotezi: uzun tek hedefte AI sürücü 8 sn hareketsiz kalıyordu (5,3 km'de 3/3 BTR-80). `[TASIMA] YOL ZINCIRI` (`nakilZincirOff`).
- **BTR-80 FFV muafiyeti (v8.245, T)**: A/B'de FFV düzeltmesiz bile gittiği için `fnc_aracFfvDuzelt` BTR-80'lerde fazla yolcuyu indirmez (`ffvBtr80MuafOff`).

## 10e. v8.237 — Cephe simülasyonu, Dilim A0 (T = doğrulanmadı)
Tasarım: `CEPHE_SIMULASYONU_TASARIM.md` (§10 ve 11). Sistem **opsiyonel**; kapalıyken eski davranış aynen kalır. Sayısal eşikler **tasarım değeri**.
- **Profil çekirdeği (T)**: squad = veri kaydı (sınıf, canlı, loadout, yara, ACE tıbbi, konum, hedef); fiziksel nesne profilin "cismi". **L0 sanal ↔ L1 fiziksel** geçiş durum taşır (olu beden yerinde kalır). Zeus'la elle konanlar profile girmez.
- **LOD kuralları (T)**: temas / operasyon alanı HER ZAMAN fiziksel (oyuncu olmasa da); cephe şeridi sık; geri hat sanal, **oyuncu yaklaşırsa fiziksel**; tavan (asker) + histerezis; temaslı fiziksel asla sanallanmaz; tavana sığmayan sanal temas **soyut çatışma**. Log `[CEPHE-FIZIKLE/SANALLA/SOYUT/OZET]`, `rpt_ozet.py --cephe`.
- **Faction paneli (T)**: Zeus "ELITE Cephe Paneli" — faction listesi otomatik (RHS/GM/…), **fader** ile asker sayısı / rezerv / yerleşim yarıçapı; mission maker API `lambs_danger_fnc_cepheFaction`. (Gerçek + / − GUI sonraki dilim.)
- **Personnel Replacement (T)**: taraf bazlı panel + CBA varsayılanları — takviye hızı, gecikme, min squad, eşzamanlı paket, beceri, cepheye yakınlık çarpanı, havuz bitince (devam / bitkin / çekil), konvoy zayiatı. Takviye FOB'da doğmaz: **soyut konvoy** varış noktasından squad'a yürür, düşmana ≤ 600 m'de zayiat zarı; A0'da fiziksel araç konvoyu yok.
- **CBA**: "LAMBS Danger > ELITE Cephe Komutani".

## 11. Geliştirici araçları
- **`tools/rpt_ozet.py`**: `--karne / --form / --zeka / --kayip / --grup` RPT özetleri, sürüm kontrolü.
- **Log etiketleri**: `[TCCC] [TCCC-TX] [TCCC-DURGUN] [SINSI-GERI] [BAYGIN-ROE] [CEPHANE] [HQ-*] [PANIK] [GIZLI] [MEKANIZE] [ARAC-MEDEVAC] [HALT] [GOZCU] [TEHLIKE-ALANI] [DURUM] [ANOMALI]` ve plan / Zeus: `[PLAN] [PLAN-KAPI] [PLAN-ISTEK] [PLAN-YANIT] [PLAN-DEVIR] [PLAN-ATAMA] [PLAN-TOPCU] [GOREV-ATAMA] [KARAKOL] [KARAKOL-GARNIZON] [TASIMA] [TAKSI] [SUNUCU-DEVIR]`.
- **Telemetri** (`telemetri`): her 20 sn sunucu FPS + grup durumu (karar, bayraklar, hız, temas, baskı, en yakın düşman), `[HIZ-ANOMALI]`, `[DONUS-OZET]`.
- **Watchdog bekçisi**: her izleyici hata ile ölürse yeniden başlar (`[WATCHDOG-YENIDEN]`).
- **Dokümanlar**: `DEVIR_LOGU_v7.0.txt` (sürüm sürüm değişiklik ve kök neden), `DOKTRIN_KAYNAKLARI.md`, `TEST_SENARYOLARI.md`, `kaynaklar_doktrin/arastirma_gerceklik/`.

## Planlanan / bekleyen
- **CEPHE SİMÜLASYONU (sonraki büyük iş)**: tasarım `CEPHE_SIMULASYONU_TASARIM.md` — kayıt, arazi ajanı (3 parça), istihbarat / TTP öğrenme, harekât / OPORD, lojistik (susuzluk-açlık, ikmal), ateş destek, mühendis (COP/FOB inisiyatifi), rapor iş akışı, cephe komutanı; 6 dilim. **Dilim A0 (profil çekirdeği + faction paneli + Personnel Replacement) v8.237'de yapıldı (10e); sıradaki: Dilim A (kayıt + FOB/COP + susuzluk/açlık).** Drone / İHA işleri askıda.
- **Hat saldırısı / siper hattı planı (Ukrayna benzeri, her şey stabil olduktan SONRA)**: iki noktalı hat (başlangıç / bitiş) → 3–6 hedef kesim, kesim başına squad, dost cephe sınırı HQ'dan hatta, geri çekilme sınırın gerisine; topçu/havan hazırlığı + sızma + siper temizleme. Ön koşul: bina/oda temizleme + el bombası yeniden yazımı, siper temizleme kaynakları (ATP 3-21.8 / MCWP 3-11.2).
- Komutan hamle repertuvarı (taciz / keşif atışı / yem / hileli saldırı / sabitle-kanatla) tavır motorunun üstüne.
- Helikopter medevac / hava nakli (şu an yalnız kara aracı).
- Karakolda MG / AT yerleşimi, nöbet rotasyonu (temel gözetleme ataması v8.214'te var).
- Hedef zinciri: alınan noktada tutucu birlik ve ayrı cephe çizgisi yok; HQ takviyesinde "hangi grup hangi hedefe izinli" kısıtı yok.
- Mühendis / engel (yol haritası 7), HQ güvenlik elemanını role göre seçme.
- AI sürücü kök nedeni (kinematik sürüşü gereksiz kılar).
- Oda / bina temizleme + el bombası kullanımı yeniden yazımı (en sona bırakıldı).
- Kalıcı senaryo ("Bakhmut-lite": kayıt / yükleme, bot kimliği, performans ölçekleme, komutan zekâsı).
- Mekanize taktikleri (araç ateş desteği, ineceği nokta), moral → davranış katmanı.
