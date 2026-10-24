# ELITE fork — Ayrıntılı Özellik Listesi (birey → buddy → ateş timi → squad → kumanda)

Kaynak: fonksiyon başlıkları (`addons/danger/functions/fnc_*.sqf`) ve `DEVIR_LOGU_v7.0.txt`. Sayılar kod başlıklarından alınmıştır.
Doktrin dayanakları genel ilke / tasarım tahminidir; kaynaklı olanlar `kaynaklar_doktrin/` altında. **(T)** = oyunda henüz doğrulanmadı.
Kapatma anahtarları: `lambs_danger_<ad>Off = true` (yanındaki ada bakın).

---

## A. BİREY (tek asker)

**Rol (`getUnitRole`)** — MG / AT / MARKSMAN / MEDIC / RIFLE; öncelik MG > AT > MARKSMAN > MEDIC.
MG: takılı şarjör kapasitesi ≥ 75 veya bilinen MG adı. Silah başına önbellek. "Gerçek rol" (baskı tüfekçisi ataması yok sayılır) ayrı sorulur.
**Baskı tüfekçisi** (`baskiTufekci`): grupta ≥ 4 asker ve gerçek MG yoksa en uygun tüfekçi (otomatik silah adı +100, şarjör, yedek) MG rolüne atanır.

**Beceri / donanım**
- Zeus / editor ile gelen her piyadeye varsayılan beceri; **optiksiz** birimde doğruluk ×0.75 (gerçekçi kalibrasyon).
- Ortam beceri düşüşü: ışık, NVG / termal, sis, yağmur (spotDistance, aim çarpanı).
- Gece: NVG'li AI NVG + IR lazer açar, NVG'siz fener AUTO; gündüz NVG kapalı.

**Algı (hile yok, yalnızca bilinenler)**
- Ses / muzzle flash / duman farkındalığı; ayak sesi (hız × duruş × zemin, ≤ 45 m) ve el feneri / IR lazer (koni + çizgi görüşü).
- Yaprak arkası görüş kırıcı, ufuk çizgisi, kamuflaj bilinci (ufukta durmaz).
- Tehdit yönüne bakış (boş duvara değil).
- IED farkındalığı (ACE EOD: erken tespit 90 m, EOD imha eder, ikincil cihaz kuralı).
- Hava farkındalığı (dron + helikopter, ateş disiplini).

**Savaş davranışı**
- **Önce siper sonra ateş** (`fieldCraft`): açıkta isen 7 m içindeki siperin arka yüzüne geç, 2.5 sn yerleş, sonra ateş (düşman < 15 m ise yapılmaz).
- **Yer değiştirme (shoot & scoot)**: aynı yerden 12+ atış ve 6+ sn → 6–9 m yana, siperli noktaya. MG / nişancı / bina / tedavi muaf. 25 sn bekleme.
- **Siper yapışma** (`coverHug`): siperin 30–50 cm arkası, dışarıdan görünmeyen en yüksek duruş; yüzeye ray; en fazla 2.2 m yumuşak kayma.
- **CQB refleksi** (`cqbReflex`): bilinen düşman ≤ 28 m → hemen dön / hedef al / ateş; ≤ 15 m diz; nişan hızı tabanı (aimingSpeed ≥ 0.65, accuracy ≥ 0.55); roketatar elindeyse tüfeğe geç. Siper disiplini: baskı ≥ 0.35, açıkta → 12 m içinde siper veya yat.
- **Şarjör değiştirme** (`reloadCover`): mermi ≤ max(3, kapasite×%15) → önce siper (en fazla 8 sn) veya yat; buddy odak ateş + alana baskı verir; şarjör dolunca 2 sn peek.
- **El bombası tepkisi** (`grenadeAwareness`): iniş noktası tahmini, yere atma, fitilli bombadan yarıçap dışına koş (ateşsiz), siperdeysen yat.
- **Atış güvenliği**: RPG / UGL öncesi dost ateşi ve geri patlama kontrolü.
- **Ateş hattı** (`fireLine`): önünde dost varsa (1.6 m) atıcı (MG / nişancıda engelleyen dost) 4.5–7 m yana adım atar; yolda ateş kesik, 4 sn bekleme.
- **Duvar koruması + sıkışma** (`moveAssist`): duvardan geçmeyi geri alır; önünü bloklayan dost varsa 3.5 m yan adım; dönüş animasyon hızı ×1.2–1.38.
- **Panik / felç** (`panikFelc`): stres modeli; DONMA / KÖR ATEŞ / KAÇIŞ (varsayılan 0.35, tavan 0.12); LAMBS doPanic ile bütünleşik.
- **Baygına patlayıcı yasağı (T)** (`firedHub`): baygın hedefe el bombası / roket / 40 mm / pompalı iptal; el bombası hedefsizse iniş noktasından hedef çıkarılır.
- **Rol istasyonu** (`roleStation`): sakinde formasyon sırası role göre (lider, MG, UGL, tüfekçiler, nişancı, AT, sağlıkçı); çatışmada istasyonlar:
  MG lidere 6–28 m (önde değil, overwatch); nişancı 8–35 m geride / yanda; UGL 4–20 m ikinci hat; AT 8–25 m liderin arkası; sağlıkçı 8–20 m arkada.
  Görevler: UGL 40–320 m piyadeye 40 mm; MG 50–450 m hat kapalıysa alana baskı; nişancı 80–600 m launcher'lı / MG'li düşmanı öncelikli vurur.
- **Tek kalan asker**: ≤ 2 asker kalırsa 150 m (telsizle 1500 m) içindeki ≥ 3 kişilik dost gruba katılır; yoksa sert siper (`tacticsBreakContact`), ağır kayıpta bina savunması (`sonDirenis`, ≤ 3 asker, ≤ 240 sn, her asker ayrı iç pozisyon).

**Bireysel özel roller**
- **UGL taşıyıcı** (`tacticalUGL`): yalnız **HE** atar (duman / flare yüklü ise atmaz); hat kapalı, binada, 8 m'de 2+ kümelenme veya %50; asker başına 12 sn bekleme; rezerv 2.
- **AT** (`atFire`, `tacticsATEngage`): hedef araca roket; zırh yoksa sakin. Kendi AT'si olmayan grup zırhtan kaçar (`tacticsEvadeArmor`).
- **Nişancı** (`isSniper`, `sniperTeam`): nişancı + gözlemci takımı, buddy / formasyon dışı.
- **EOD**: buddy olmaz (tek elemanlı çift), cihaza tek kişi yaklaşır, DefusalKit şart.
- **RTO**: ≥ 4 kişilik grupta telsiz sırt çantalı (yoksa ≥ 6 kişide liderin yanındaki nominal RTO); canlıysa grup telsiz gücü 1, ölürse lider telsizi menzil ×0.4.
- **İleri gözcü**: dürbünlü / nişancı rolünde asker; temas yokken 8 sn'de bir tehdit yönünün ±35° ve 150 m ilerisini tarar, spot becerisi ×1.25 (AWARE'de bile).
- **Nokta elemanı** (`noktaEleman`, traveling overwatch): grup ≥ 6, lider hareketli, temas muhtemelse 2 tüfekçi ana gövdenin 55 m önüne gider.
- **Yan koruma + arka emniyet** (`yanGuvenlik`): grup ≥ 5, hareketli; sağ kanat, sol kanat, arka asker dışa doğru 60 m bakar (`lookAt`).
- **Arka güvenlik** (`rearGuard`): CQB / yoğun urbanda ≥ 6 asker ve ≥ 3 sade tüfekçi varsa biri liderin 9 m arkasında 30 m geriye bakar.

---

## B. BUDDY ÇİFTİ (2'li, tek sayıda 3'lü)

**Eşleştirme** (`buddyPairs`): en güçlü + en zayıf (yılan sırası); her çift bir ağır silah / lider + bir tüfekçi.
Öncelik puanı: MG 100 > AT 80 > nişancı 70 > sağlıkçı 50; lider +60. Tek sayıda ortadaki asker son çifte eklenir (üçlü çift). EOD eşleşmez.

**Kalıcı eş + kopmama** (`buddyBond`, 3 sn'de bir):
- Her askere kalıcı `buddy` atanır; üçüncünün eşi çapadır.
- **İzolasyon**: en yakın dost > 40 m (çatışmada 45 m) → en yakın dostun yanına. **Eş kopması**: eşe > 25 m (çatışmada 30 m) → eşin 5–9 m yanına.
- Tikte grup başına en fazla 2 asker, asker başına 10 sn bekleme, `doMove`.
- Atlanır: bounding / retreat / evade / temas kes / AT taarruz, forceMove, binada, baskı ≥ 0.5, düşman < 25 m, rol istasyonuna yeni gönderilen (25 sn), oyuncu, araç. Sakinde lider hareket edince 45 sn bekler.
- 8+ kişilik grupta limit 35 m.

**Buddy'nin yaptıkları**
- **Reload koruması**: eş reload ederken diğeri düşmana odak ateş + alana baskı (3 sn'de bir tazeler).
- **Bounding**: buddy çiftleri 2'li (en güçlü + en zayıf), MG koşmaz; koşucu varınca eş 2–8 m yanına gelir (BND-YAKIN); tek kalan ilerler.
- **Retreat / temas kesme**: 2'li çiftler halinde en yakın sert siper (`findCover SURVIVE`) veya 60 m dik uzaklaşma.
- **Cephane / bomba paslama (T)** (`cephanePaylas`): önce eşler; temasta yalnızca ≤ 6 m eşler arası; sakinde verici alıcıya yürür (≤ 40 m). Fiziksel: verici "PutDown" ile yere bırakır, alıcı gidip alır (50 sn; alınamazsa 120 sn yerde).
  Alıcı eşikleri: tüfek / MG şarjör < 3 (≈ 2.5 × kapasite altı), 40 mm < 3, parçalı bomba 0 (hekim / tüfekçi hariç), duman 0 (lider). Verici: ≥ 5 şarjör (kendinde ≥ 4 kalır), ≥ 3 bomba (≥ 2 kalır). Sınıflar mermi simülasyonundan bulunur.

---

## C. ATEŞ TİMİ (3 takım: FSE / MANEUVER / RESERVE)

**`splitFireTeams`** (≥ 4 asker; boyut tablosu):
| Grup | FSE (ateş desteği) | MANEUVER |
|---|---|---|
| ≥ 12 | 4 | 4 |
| 9–11 | 3 | 3 |
| 7–8 | 3 | 4 |
| 5–6 | 2 | 3 |
| 4 | 2 | 2 |

- **FSE**: MG → nişancı → AT; eksik tüfekçiyle tamamlanır.  **MANEUVER**: lider + tüfekçiler.  **RESERVE**: sağlıkçı + artanlar.
- **Bounding overwatch** (`tacticsBounding`): her döngü 3 faz (ateş 1.5 sn → hareket → ortak ateş 6–9 sn); odak ateş (kapsama ekibi aynı düşmana + alana baskı); her 3. döngüde FSE ileri sıçrar;
  siperden siper (6 aday, yol açıklığı hesabı, düşmanın gördüğü yol cezalı); siper ömrü ≥ 4–5 sn + peek; hücum 40 m'de devredilir; en fazla 10 döngü; combatMode RED (sonra geri yüklenir); hareket sprint, varışta siper duruşu.
  Doktrine göre bitiş mesafesi / döngü sınırı / overwatch kurulum süresi (profil).
- **Kademeli geri çekilme** (`tacticsRetreat`): ALPHA (maneuver + reserve) ve BRAVO (FSE) dönüşümlü: 40 m / 80 m / 120 m / 120 m sıçrama; hareket etmeyen takım `doSuppress` ile ateş eder; her asker kendi varış noktasına (7 m) gider;
  hareket edende forceMove + AUTOCOMBAT / COVER / TARGET kapalı + allowFleeing 0; 45 sn cooldown. Baskı altında önce siper. Retreat bilerek zor başarılır.
- **Kanat / ateş kaydırma** (`tacticsFlank`): ayrı manevra unsuru; kanat ateşi hücum anında kaydırılır.
- **Hücum öncesi bastırma penceresi**, **komutan bekle** (`leaderSync`: takım > 12 m geride → liderin hızı 1.8; > 30 m → PATH en fazla 20 sn kapalı, 25 sn cooldown).
- **Dağılma** (`dispersion`): 2'li çift yığılma sayılmaz; 3+ asker yarıçapta → 7–10 m'ye taşı; düşman launcher'lı piyade / zırh bilinirse yarıçap 5 → 8 m, RPG görüldüğünde 9–16 m; tikte en fazla 2 asker, 10 sn bekleme.

---

## D. SQUAD (grup)

- **Komutan beyni** (`commanderAssess`): rol ağırlıklı güç oranı (düşman / biz), zırh / MG / baskı, kayıp oranı; kararlar BOUNDING, SUPPRESS_ASSAULT, DELAY, PEEL, WITHDRAW, PUSH, HIDE...
  Etkin güç = canlı **ve bayılmamış** (bayılanlar kayıp sayılır).
- **Doktrin profili** (ABD / RUS / GENEL / DUZENSİZ) → bounding bitiş mesafesi, cekilKayip, peelOran / peelKayip, konsolidasyon süresi, küçük ekip eşiği, pusu parametreleri, UGL rezervi, arka güvenlik, kamuflaj eşiği, teslim.
- **Formasyon**: tek yazıcı `formSet` (öncelik 0..2, 25 sn koruma, histerezis), araziye göre seçim; ≥ 4 araçlı açık arazi yaklaşmasında DIAMOND.
  **Halt** (`haltKur`): lider ≥ 8 sn duruyorsa slota ≤ 20 m yürüyen askerlere `doStop` (≥ 6 piyade, temas ≥ 20 sn yok).
- **Pusu / ROE** (`pusu`): bilinen piyade 90–260 m ve yaklaşıyor, ≥ 4 piyade → ateş tutulu (GREEN), siper; ateş ölüm bölgesi çoğunluğu (≥ %60) içindeyse; ≥ 5 kişide yan güvenlik, ≥ 7'de arka güvenlik; düşman > 2× kendimizse iptal; pusu sonrası toparlanma.
- **Sinsi geri çekilme (T)** (`sinsiGeri`): düşman 90–450 m, oran ≥ 1.4 (DUZENSİZ 1.25), grup henüz ateş altında değil (baskı ≤ 0.1, 20 sn ateş yok, kayıp ≤ %15) → ateş kes + STEALTH, öndekiler (medyandan ≥ 8 m yakın, lider dahil) düşman gözünden gizli 50–80 m geri noktaya;
  25 sn sonra / baskı > 0.25 / kayıp / düşman < 70 m / oran < 1.1 / 75 sn iptal; 90 sn cooldown.
- **Yol geçişi (T)** (`tehlikeAlani`): ≥ 5 piyade, açık çevre, 20–70 m'de yol → dur-gözetle 8 sn, A takımı sonra B takımı; 70 sn sınır, temas / retreat'te hemen serbest.
- **Moral + teslimiyet** (`moral`): moral = 1 − 0.5×kayıp − 0.25×baskı − 0.15×düşük cephane − 0.15 (lider ölü) − 0.10 (uzak dost) + 0.10 (temas yok). Teslim: moral < 0.15, ≤ 2 asker, ≥ %70 kayıp, baskı ≥ 0.6, düşman ≤ 50 m (DUZENSİZ teslim etmez).
- **Toparlanma** (`toparlan`): çekilme / pusu sonrası sayım, rapor, güvenlik (TC 3-21.76).
- **Ölüm bölgesi hafızası**, **olay sistemi** (InContact / AllClear / Casualty / RetreatBasla...).
- **Sağlıkçı tasması**: temasta lidere göre arkada (10–16 m), TCCC'deyken muaf.

---

## E. SAĞLIK / MEDEVAC

- **TCCC** (`tccc`): yaralı tespiti (bayılan, hasar > 0.2, kan < 5.3 L). Hekim: önce MEDIC rolü / Medic özelliği (bounding'in forceMove'u yüzünden elenmez), yoksa sargılı herhangi bir asker, yoksa başka gruptan atanan (kumanda medevac).
  Sıra: kanama (sargı → paketleme / elastik → FieldDressing; durmazsa turnike), ateş altında yalnız bu; güvenliyse kalp durmasında CPR + epinefrin, kan < 5.2 L ise en fazla 2 IV, ağrı yüksekse morfin.
  `FirstAidKit` = FieldDressing yedeği; yarasız bölgeye eşya harcanmaz; ACE'nin kendi AI yolu (anim `MedicOther`, bekleme, item sil, bandageLocal / tourniquetLocal / medicationLocal / ivBagLocal / cprLocal olayı, aktivite logu).
- **Triyaj önceliği** (hemşire onaylı): kalp durması (+1000) > kanama hızı (×4000, sınır 0.2) > düşük kan (×25 / L) > bekleme süresi (≤ 240 sn, /4).
- **Ateş altında**: yalnız baygın yaralıya; hekim baskısı > 0.6 → iptal.
- **Hekim durgun tespiti**: 3 sn'de 1 m'den az ilerleme → kademe 1 (MOVE / PATH / ANIM aç, forceMove, hız serbest, `doMove`), kademe 2 (`doStop` + `doMove` + script yürütme: koşu animasyonu + yumuşak hız vektörü, ≤ 14 sn, 2.5 m'ye kadar).
- **Ölü betik kilidi temizliği**: hekim betiği ölürse / hekim bayılırsa `forceMove` ve yaralı kilidi süre sonunda açılır; bayılan hekim hareket ettirilmez.
- **Kumanda medevac** (`hqMedevac`): menzil 600 m, boş hekim varsa talep açılmaz, yoksa açılır (bekleyen < 2 × boş hekim).
- **Araçlı medevac (T)** (`aracMedevac`): yalnız mürettebatlı kara aracı, ≥ 40 sn ilgilenilmeyen yaralıya gider, ≤ 3 yükler. v8.129 doktrin standoff'u: yaralı–düşman mesafesi zırhlı araç için ≥ 300 m, yumuşak araç için ≥ 600 m değilse araç gitmez; yaralıyı düşmandan ≥ 600 m (ya da yaralının mesafesi + 250 m) uzağa / plan CCP'sine taşır (kaynakta araç standoff sayısı yok → tasarım; AK-74 500 m, RPG-7 ~200 m kaynaklı). Zeus "Görev Ata → MEDEVAC" atanmışsa yalnız atananlar kullanılır; atanmış grubun hekimi önce seçilir.
- **AI sürükleme kapalı** (ACE startDrag AI'da çalışmıyor; iptal edildi).
- Baygınlar kayıp sayılır; COD tarzı kaldırma yok.

---

## F. MEKANİZE

- `mekanizeIzle`: dur-kalk tespiti; düşman > 100 m veya yok → COLUMN / FULL / AUTOCOMBAT kapalı; sürücü forceSpeed sıfırlama (-1).
- `doAssaultSpeed` overlay: forceSpeed araç içindekine uygulanmaz.
- Araç mürettebatı roket / duman tehdidine tepki verir (`tehditOlay`).
- DIAMOND yalnız ≥ 4 kara aracı, açık, yol dışı, temas > 60 sn, düşman > 500 m; DÜZENSİZ doktrinde yok.
- **Araç–piyade senkronu** (`aracSenkron`, T): BEKLE > 60 m, YAVAŞLA 20–60 m, SENKRON; temas / baskı / medevac / nakilde serbest.
- **Kara aracı nakli** (`aracTasima`, T): adaylar AI sürücülü, arac grubu tamamen içinde, kargo ≥ 3, yakıt > %10, planda / medevac / karakol görevinde değil. Adımlar: alma noktasına gel (≤ 150 sn) → bin (60 sn; 40 m içindeki gecikenler `moveInCargo`) → iniş noktasına sür (≤ 240 sn; temas / baskı olursa erken in) → in (`doGetOut` → 10 sn sonra `moveOut`) → geri dön, bekle. İniş noktası = hedeften max(500 m, ORP + 150 m) (M16 etkili menzili 460 m + pay; kitapta iniş mesafesi sayısı yok → tasarım). Plan TASIMA fazı 420 sn'de iptal edilir. Kapatma: `lambs_danger_tasimaOff`; otomatik araç seçimi: `lambs_danger_tasimaOtomatik = false` ile kapanır.
- **Taksi** (`taksi`, sunucu, T): yaya AI grubunun aktif waypoint'i > 1200 m ve 600 m içinde boş araç varsa aynı nakil (iniş hedefin 500 m öncesi); ≤ 2 eşzamanlı, grup başına 180 sn bekleme; plan waypoint'leri alınmaz. Kapatma: `lambs_danger_taksiOff`.

---

## G. KUMANDA (HQ) KATMANI — gruplar arası

- `hq`: taraf başına durum tahtası (grup / temasta / meşgul / müsait / toplam asker). Taraf kapalıysa (CBA) atlanır.
- `hqIstihbarat`: SPOTREP ağı, telsiz şartı (lider / RTO), gecikme, belirsizlik, "bilgi sisi" (varsayılan 0.4), kayıp raporu.
- `hqTakviye`, `hqKanat` (iki grup koordineli), `hqFeint` (yanıltıcı sınırlı saldırı), `hqEmir` (emir kanalı; TAKVİYE / KANAT / FEINT bounding'i iptal eder).
- `hqMedevac`: yukarıda. Müsait grup hesabı: bounding grupları (düşman ≥ 250 m) de kullanılır.

---

## G2. KOMUTAN PLANI VE ZEUS MODÜLLERİ (v8.113 – v8.130; devamı G3)

- **ELITE Objektif** (3 panel: görev / düşman / kısıt-destek-mesafe): tip (ele geçir, savun, iptal, onay ver), tempo, H-saati (Zeus onayı), süre, tehdit yönü, düşman bilgisi, ROE kısıtları, topçu, rally (250–900 m, 450), ORP (100–400 m, 300), Baskın (5 / 10 dk).
- **Fazlar** (`komutanPlanDongu`, 3 sn): KUR → TOPLAN → (TASIMA) → ORP → KEŞİF (60 / 90 / 30 sn short halt) → SALDIRI → TOPLANMA / ÇEKİLME; savunma: MEVZİ → BEKLE (1200 sn). Baskın: hedef temiz / süre dolunca ÇEKİLME.
- **Topçu / havan**: RED tablosu (60 mm 145, 81/82 mm 195, 120 mm 430, 105 mm 455 m), danger close ≤ 600 m loglanır; "ATIS YOK" nedenleri sayaçla loglanır. Zeus TOPÇU / TOPÇU_YOK atamasına uyar.
- **Gizlilik önceliği** (gizli tempo veya baskın): toplan / ORP / keşifte temas yoksa GREEN, objektife < 450 m MIDDLE; temas → YELLOW + AUTO; saldırı → AUTO + YELLOW.
- **Görev Ata** (`lambs_danger_gorev`): MANEVRA / DESTEK / YEDEK (plana sınırsız katılır, rol ezilir), HARİÇ, MEDEVAC, TOPÇU, TOPÇU_YOK, TASIMA, KARAKOL_ARAC (sistem atar); LİSTELE.
- **Karakol / HQ**: harita işareti `ELITE_KARAKOL_*`, kayıt `lambs_danger_karakollar`; savunma: yok / hemen (yarıçap × 1.5 içindeki gruplar için savun planı) / alarm (düşman 800 m içinde savunanlarca bilinirse, knowsAbout ≥ 0.5).
- **Karakol Garnizon** (`karakolGarnizon`, sunucu, 15 sn, T): havuz = karakol yarıçapı × 1.5 içindeki AI piyade. Nöbetçi (0–8): üst kat (buildingPos ≥ 2.5 m, skor = yükseklik × 3 + 8 ışın dış cephe görüşü × 4) + arazi halkası (%50 / %80 yarıçap, 30°); en yüksek skor + önceki noktalardan uzaklık, min 18 m. PATH kapatılır, dışa `doWatch`, 120 sn'de varamazsa ışınlanır. Devriye (0–3 grup × 2–6 asker): %60 yarıçap halka, CYCLE, alarmda çevre savunması, 120 sn temassız devam. Araç mevzileri: %75 yarıçap, PATH kapalı, mürettebat içinde. Alt grup değişkeni `lambs_danger_garnizonAlt` (plan / taksi / nakil almaz). Modül tekrar çalıştırılınca yeniden hesaplanır; yeni birimler eksiği tamamlar; kaldırınca birimler orijinal gruplarına döner. Kapatma: `lambs_danger_garnizonOff`.
- **Sunucu devri** (`grupSunucuDevir`, sunucu, 10 sn, tur başına ≤ 4): oyuncu / uzaktan kontrol / HC sahibi / 60 sn içinde devredilmiş olmayan istemci AI grupları `setGroupOwner 2`. Kapatma: `lambs_danger_sunucuDevirOff`.
- **Sunucu kapısı** (`komutanPlanKapi`): CBA sunucu olayları `lambs_danger_planIstegi`, `planNoktaIstegi`, `gorevAta`, `karakolIstegi`, `garnizonIstegi`; yanıtlar `planYanit`, `garnizonYanit` (Zeus sohbetinde + RPT).
- **Telemetri** (`telemetri`): `[TELEMETRI-SUNUCU]` (FPS ort / min, yerel AI, taraf, plan, dönme animasyonu), `[TELEMETRI-GRUP]` (≤ 14 satır / 20 sn), `[HIZ-ANOMALI]` (> 26 km/s yaya), `[DONUS-OZET]`.
- **Dönme animasyon hızı**: `lambs_danger_turnCoef` 1.15 (yalnız "turn" animasyonunda; v8.125).
- Kaynaklı / tasarım eşik ayrımı: `kaynaklar_doktrin/SAYISAL_ESIKLER_KAYNAK_TABLOSU.md`.

---

## G3. v8.131 – v8.168 AYRINTILARI

**Plan / istihbarat**
- `fnc_komutanPlan`: Zeus rol ezmesi (MANEVRA / DESTEK / YEDEK `[PLAN-ATAMA]`), uzak grup devri (`[PLAN-DEVIR]`, yeni grup 60 sn yaşlanır), `secili` (elle grup seçimi, netId listesi, mesafe sınırı yok), RECON seçimi + OP arama (450 / 520 / 600 m, ±45°, LOS, yükseklik, örtü).
- `komutanPlanDongu`: `_gozlemRapor` (düşman / sivil sayısı, iddia ≠ gözlem), `_atisIzni` (PID kapısı), `_topcuAt` (mermi x `topcuMermiCarpan`, ATIS YOK nedenleri), TASIMA fazı (420 sn, en çok 3 sefer), RECON fazı (gözlem 90 / 45 / 20 sn), keşif süresi `kesifCarpan`, AAR `[PLAN-ISTIHBARAT] OZET` + `[PLAN-ZARAR]`.
- Objektif paneli: 1/4 görev (+ Grup seçimi), 2/4 düşman, 3/4 kısıt / mesafe / baskın, 4/4 istihbarat + topçu; Elle seçimde `fnc_objektifGrupSec` (panel başına 8 onay kutusu).

**Nakil / araç** (`aracTasima`, `taksi`, `murettebatKoru`, `ezmeKoruma`)
- Aday süzgeci: kara aracı, hareket edebilir, yakıt > %10, kargo ≥ 3, AI sürücü, araç grubu tamamen içinde, planda / medevac / karakolda değil; `[TASIMA] ATANMIS ARAC UYGUN DEGIL` nedeni.
- Mürettebat tamamlama (150 m içindeki dışarıdaki aynı grup askerleri komutan > nişancı > kargo), yolcu bekçisi (0.25 sn: PATH kapalı, `GET OUT` → `doStop`, hareketli araçtan atlayan 80 m içinde ise geri al), motor zorlaması (yolda kapalıysa `engineOn true` her sn), takılma kurtarma (8 / 18 / 35 sn, sürücü `moveOut` + `moveInDriver`).
- Ezme koruması: 0.25 sn tarama, ileri bakış 10 m + 2.2 x hız, 4 m şerit, 7 m harim (yön fark etmez), 30 sn kesintisiz fren sonrası 5 km/s süzülme; kapatma `lambs_danger_ezmeOff`. Mürettebat koruma: 1 sn, `lambs_danger_murKoruOff`.

**Nakil ve araç rolleri (v8.163 – v8.168)**
- `fnc_aracSinif`: `[sınıf, kargo, top, atgm]`, tip başına önbellek, `[ARAC-SINIF]`. IFV = kargo ≥ 3 + top (mermi hit ≥ 25) ya da ATGM; APC = kargo ≥ 3, topsuz, zırh ≥ 120; sayılar tasarım tahmini.
- `fnc_planZirh`: tank / elle seçilen zırh grubu plan tick'inde ateş pozisyonuna gider (hedeften 380-680 m, görüş hattı, su / bina / sık ağaç dışı), durur + gözetler, temasta COMBAT / RED; IPTAL / BITTI'de serbest. IFV'ler indirdikten sonra `tasimaCtl[5]` ile zırh desteğine eklenir. Hull-down / yer değiştirme YOK (kaynak bekleniyor: ATP 3-20.15 / 3-90.1).
- `fnc_aracTasima` dağıtım: en boş araca yerleştirme (worst-fit), araç başına yumuşak tavan `max(5, ceil(asker/araç))`, sığmazsa 2. tur gerçek kapasite. Öğrenilen kapasite `lambs_danger_tasimaKap_<tip>`; `KAPASITE OGRENILDI`, erken sefer (en çok 3).
- Bekleme: eşleşen asker `doStop` + PATH kapalı + `lambs_danger_tasimaBekle`; bindirme öncesi / iş sonunda / hata temizliğinde açılır. Piyade < 120 m ise araç hareket etmez; daha uzaksa araç gider (8 sn → motor / AI / komut `ALMA TAKILMASI`, 18 sn → sürücü yeniden otur, 30 sn → vazgeç, piyade < 450 m yürür).
- Sunucu devri: elle seçilen taşıma aracı grupları plan devir listesinde (`_tasG`) ve nakil başında `SURUCU GRUBU DEVIR` (≥ 60 sn yaşlı grup); devir bekleme 15 sn.
- Çarpışma güvenliği: ±35°, 40 m, güvenli mesafe 12 m + hız x 1 sn, < 10 m dur; engelleme başına ≤ 20 sn.
- Elle seçim kapasite uyarısı (`fnc_objektifGrupSec`): piyade sayısı ≠ IFV / APC / kamyon kargo koltuk toplamı.

**Doktrin**
- RUS profil anahtarları: `tasimaInisM 300`, `tasimaOrpEk false`, `aracDestekKal true`, `kesifCarpan 0.6`, `topcuMermiCarpan 2`, `kesifAtesHizli true`; ayrıntı `kaynaklar_doktrin/RUS_MUFREZE_MANGA_DOKTRIN_NOTLARI.md`, `NATO_ABD_MUFREZE_MANGA_DOKTRIN_NOTLARI.md`.
- Fraksiyon haritası: `gm_fc_gc` / `gm_fc_pl` → RUS, `gm_fc_ge` / `gm_fc_dk` → ABD, `gm_*_pol` → GENEL.
- Oyuncu komutası: grup değişkeni `lambs_danger_oyuncuKomuta` (true / false / yok = otomatik), `oyuncuKomutaAktif` (yalnız yerel); `tarafSecim` mekanizmasıyla LAMBS FSM + karar izleyicileri kapalı; TCCC / cephane / IED muaf.

**Komutan zihni** (`komutanZihin`, v8.156 – v8.158)
- Gözlem türleri: ATIS (450 m ses), DUMAN (300 m), TOPCU (1500 m), KARSILIK (12 sn içinde karşı ateş + gecikme), TEMAS (grubun bildiği en yakın düşman), GORUS (`nearTargets`, `knowsAbout > 0.5`), KAYIP (x1.5). Gürültü: mesafe ±%6, yön ±8°.
- Hafıza: taraf başına ≤ 160 kayıt, yarı ömür 25 dk, en az 4 gözlem (`lambs_danger_zihinHiz` ile ölçeklenir). Hipotez: YON (8 sektör, pay ≥ %50), MENZIL, DUMAN, ARAZI, KARSILIK, ZIRH, TOPCU, KUVVET. Log `[KOMUTAN-ZIHIN] hipotez / KANIT / OZET`.
- Tavır motoru: YON-HAZIRLIK, KESIF-ATISI, TACIZ-SABITLE, ZIRH-AT-HAZIR, DAGIL-SIPER, DUMAN-IZLE, TEDBIRLI-GOZETLE; kişilik + doktrin bonusu, histerezis 0.12 / 180 sn, log `[KOMUTAN-TAVIR]`. Etki yalnız beklenen yöne gözetleme (güven ≥ 0.45).

**Tanı / A/B anahtarları**
- `[GIYIM-TANI]` (ILK / DEGISTI / SILAH), `[CEPHANE-ENV]`, `lambs_danger_giyimTaniOff`, `silahDegisimOff`, `cephanePaylasOff`, `cephaneAnimAcik`, `sunucuDevirBekleS` (varsayılan 120), `sunucuDevirOff`.
- `tools/rpt_ozet.py` etiketleri: TASIMA, ARAC-SURUCU, PLAN-RECON, PLAN-ISTIHBARAT, PLAN-ZARAR, EZME(-NABIZ / -BAYGIN), MURETTEBAT-KORU, OYUNCU-KOMUTA, GIYIM-TANI, CEPHANE-ENV, KOMUTAN-ZIHIN, KOMUTAN-TAVIR.

---

## G4. v8.169 – v8.225 AYRINTILARI (özet; ayrıntı için `DEVIR_LOGU_v7.0.txt`)
- `fnc_aracKinSurus`: `calculatePath` rotası; yatay dönüş ≤ 2,5°/0,1 sn, hız 7,5 m/s (keskin dönüşte 3), engelde: yaya yana çekilir (`doMove` 12 m), araç +40° sapma; sürücü dışarıdaysa `moveInDriver` (en çok 8 sn); 8 sn'de 3 m'den az ilerlerse boş noktaya taşınır; 700 sn tavan. Çağıranlar: `fnc_aracTasima` (28 sn), `fnc_reconArac` (10 sn).
- `fnc_aracSurmeTani`: nedenleri sınıflar (AI özellik / değişken / hasar / grup / çevre / sürücü çıkışı); `fnc_aracSurmeDeney` (kapalı): 7 önlemi sırayla dener, kazananı hatırlar.
- `fnc_topcuDestek`: `SIS` (duman mermisi varsa), `KARSI` (bilinen düşman topçusu, dost ≥ 200 m, 90 sn'de bir). Plan döngüsü: karşı-batarya 40 sn, ateş kaydırma 60 sn.
- `fnc_gozetleAta` + `fnc_moduleGozetleAta`: nöbet; piyade halkada dağılır (disa bakar), araç gruplarında sürücü noktaya sürer, 45 sn ilerlemezse itme + yola yönlendirme.
- Zincir: `zincir` ayarı → `fnc_komutanPlan` ana planın `zincir` listesine ekler; `BITTI` + "OBJEKTIF ALINDI" ise `fnc_komutanPlanDongu` sıradaki hedefle yeni plan kurar (≥ 2 askerli gruplar `secili` ile devredilir).
- `rpIsaret`, `reconEk`: bkz. `fnc_komutanPlan` (RP geçersiz kılma, ek gözlem noktaları) ve `fnc_komutanPlanDongu` RECON fazı.
- Nakil: devir 15 sn, yükle-ve-bekle (`nakilTutmaS` 60), kapı serbest bırakma koşulları (recon tamam / APC 120 sn / yaya recon 90 sn / 420 sn).
- Geri alınanlar: v8.215 `aracKomutanDuzelt` (kanıtsız hipotez, silindi); v8.223 kapıyı tamamen kapatma (v8.225 ile yükle-ve-bekle).

## G5. v8.276 – v8.338 AYRINTILARI (T = doğrulanmadı; ayrıntı + kök neden `DEVIR_LOGU_v7.0.txt`)
- **`fnc_tankDron` / `fnc_zirhDronIzle`**: tank / IFV / APC (AI sürücülü, oyuncusuz) için dron savunması, plandan bağımsız (2 sn döngü): uyarı, taret MG'si dronun öngörülü noktasına (`fireAtTarget` zorla ateş), duman ≤ 520 m ve (yaklaşma > 0 ya da ≤ 300 m) `fnc_aracDuman` (14 sn bekleme), zikzak kaçış ≤ 380 m (yaklaşma > 4 m/sn), 12 sn bekleme.
- **`fnc_dronTepki`**: piyade dron tepkisi — pervane sesi (700 m) → grup dronu bilir; kaçış / saklanma (`fnc_dronSakla`: bina, ağaç-çalı dibi, siper; taktik kilit 40 sn); yerinde ateş eden 2 nişancı; dik açı (> 40°) kuralı; zorla ateş döngüsü (ana silah, yumuşak dönüş yardımı, bakış dronun kendisinde); **karşı-operatör topçusu** (`fnc_topcuDestek` "OPERATOR"): gözlemler 600 sn, FARKLI dronların geri-yön doğruları ikişer ikişer kesiştirilir (≥ 15°, 100-2500 m), ortanca = operatör bölgesi; kesişim yoksa tek doğruda 380 m; eminlik = dron sayısı: 1 → 110 m yayılım / 1 top, 2 → 70 / 2, 3 → 40 / 3, 4+ → 16 m / tüm toplar (3'er mermi); dost 200 m içindeyse atılmaz. CBA `dronKarsiAtes`, `dronIstiksaf`.
- **`fnc_dronAvi`** (operatör avı): ≥ 2 gözlem (120 sn) → tahmin (kesişim ya da 700 m); kaynak grup: yerel, temassız, taarruz planında olmayan (savunma planındakiler dahil, v8.327), ≥ 5 asker; devriye = 3 (ya da OPORD 4) askerlik alt grup (MG / AT / hekim hariç), ≤ 800 / 1000 m; araç: önce hafif araç (Humvee / Tigr / UAZ sınıfı, sentetik plan `aracHafif` ile `fnc_reconArac` SEC + CALIS), yoksa eldeki uygun araç, yoksa yaya; süre = mesafe / 1,2 + 150 sn; sonunda kaynak gruba döner. OPORD "Dron operatörü avı" (CBA'ya uy / Hayır / 3 / 4 kişi × yaya / araçla). Aday yoksa 60 sn'de bir neden sayaçları.
- **`fnc_dronGozlemTalep` / `fnc_dronGozlemci`** (v8.336): dron izi başına gözlem kaydı (600 sn, dron kimliği); ısrarlı saldırı = 600 sn'de ≥ 2 farklı dron ya da 300 sn'de ≥ 4 gözlem → operatör tahmini (farklı dronların geri-yön doğrularının kesişim ortancası; yoksa tek doğruda 650 m) → sunucu olayı `lambs_danger_dronGozlemIstegi`; gözlemci: (1) hazır GÖZLEM İHA'sı (silahsız, görevde değil; tahmine en yakın), (2) gözlem dronuna dönüşen sırt çantalı asker (≥ 250 m, temassız; çanta tüketilir, asker operatör, öldüğünde dron düşer); görev `fnc_ihaSorti` GÖZLEM (merkez = tahmin, yarıçap 300 / 450 m, 120 m); görülen düşman `fnc_ihaGozlem` ile ortak resme. Taraf başına tek dron, 240 sn bekleme. CBA `dronGozlemAktif`.
- **`fnc_ihaSorti`** (AI IHA): kamikaze FPV-AT / AP, BOMBA, GÖZLEM; v8.327 **duman kilidi** (`fnc_dumanPerde`: `SmokeShell` nesnelerinin 3B parça mesafesi ≤ 14 m): dalış öncesi 1,2 sn temiz hat gerekir, duman varken 220 m'de havada bekler, 22 sn kilit yoksa hedef 45 sn yasaklanır, dalışta hedef dumana girerse 7-12 m kör sapma; v8.329 **FPV-AT gerçek çarpma**: gövde yüzeyi `lineIntersectsSurfaces` ile bulunur, mühimmat yüzeyin 0,5 m önünde 180 m/sn ile yaratılır (0,4 sn'de patlamazsa `triggerAmmo`), 1,7 sn sonra `[IHA-ETKI]`; sapma (ıskalama) ve FPV-AP eski yolda.
- **`fnc_patlayici`** (izleyici 2,5 sn): el bombası (10-60 m, esnek değer: küme 12 m / bina / kapalı hat / alçak duruş / baskı / pusu; asker 20 sn / grup 4 sn / 60 sn ≤ 3), betikle kontrollü balistik atış (yay temizliği, dağılma), omuz roketi 50-300 m (hizalama 6° eşiği, zırh 900 m içindeyse AT rezervi), UGL ek HE mermi (`uglEkMermi`). **`fnc_atesHareket`**: taban ateş + ≤ 5 sn rush (koşarken ateş etmez; `atesHareketOran` 0,10), rol takası. **`fnc_acikSiper`** + **`fnc_coverHug`** hızlı mod.
- **`fnc_pusuTepki`**: pusuya hızlı tepki (1,5 sn izleyici), konum tahmini, çağrı ateşi, kanat; bireysel teslim (`fnc_teslimBirey`).
- **`fnc_sisButce`** (v8.330): taraf 120 sn'de ≤ `sisButceMax` (2) olay, olaylar arası ≥ 25 sn, grup ≥ `sisGrupAralik` (90 sn; temas kesmede × 0,67), grup temasta ya da lider baskı > 0,15; `fnc_tacticalSmoke` (derin perde 2 atış = 1 olay; ekonomi 45 m / 100 sn), `fnc_tacticsAssault` (lider + 40mm) ve `fnc_tacticsFlank` dolaylı bütçeden geçer.
- **`fnc_planZirh`** (v8.325-v8.327): otomatik tank seçimi HQ'ya bağlı tankı 4 km sınırına takmaz; savaşta TAKILDI eşiği 70 sn, ağaç önündeyse 10 sn (geri al + ağaçsız yön); `tankAgresif` (0 temkinli / 1 dengeli / 2 agresif): savunmada gizleme noktası yok, mevzi merkezi tank 110 → 200 m, yer değiştirme süresi × 2, tetik 2500 m; saldırıda ileri sıçrama 150 → 60 sn, 5. kademe 170 m, durma 190 m.
- **`fnc_aracUnstuck`** (v8.328, her makine, 1 sn): AI sürücülü kara aracı MOVE emrinde, hedef > 35 m, hız < 2 km/sa, 10 sn ateş yok, engel (ağaç / kaya / duvar / bina; hafif araçta küçük ağaç da) → eşik: önde 3 sn / yanda 7 sn / görünmüyor 40 sn (plan / nakil yönetimli × 3 / × 2); kademeler 1 geri al (2,5 sn) + 30 m ara nokta, 2 geri 4 sn + 45 m, 3 kaldır (+0,6 m) + 2,5 m kaydır + 65 m, 4+ hedef yönünde 12-30 m engelsiz konuma `setVehiclePosition`. Atlananlar: oyuncu, kinSurus, reconArac, yolcuBırak, mürettebat bekleme, KARAKOL_ARAC, planZirh mevzide. CBA `aracUnstuck`.
- **`fnc_otoGarnizon`** (v8.327): OPORD "Otomatik mevzi / garnizon bölgeleri" (Hayır / Evet / Güçlü) → objektif çevresi 90 / 140 / 190 m × 30° halkası, bina yoğunluğu + örtü + yükseklik + tehdit yönü + `fnc_araziAnaliz` hakim nokta; KARAKOL (bina + CCP yakını 70-160 m + geride), 2 MEVZİ (tehdit ±30°), GÖZLETME (yüksek nokta); ORP / CCP / RP'ye ≥ 70 m, kendi aralarında ≥ 60 m; mevcut `lambs_danger_karakolIstegi` + `garnizonIstegi` olayları (karakolda 3 nöbetçi + 1 devriye alt grubu, güçlü 5 + 2; mevzi / gözletmede 2 / 3 nöbetçi; havuz kaynak gruptan ≥ 3 asker bırakır). Savunma planında plan kurulunca 20 sn sonra, saldırıda OBJEKTİF ALINDI'da. Plan hash'ine `ccp` eklendi.
- **Hedef zinciri TUT** (v8.324): `plan.ayar.tut` (0 / 1 / 2 squad) → en zayıf squad(lar) (komutan, recon hariç, zırh son) ele geçirilen objektifte SAVUNMA planı (`tehditY` sonraki hedefe) + KARAKOL / GÖZLETME / MEVZİ işaretleri + 2. squad için gözetleme nöbeti; `[PLAN-TUT]`.
- **`fnc_dronTopcu`** (v8.338, yalnız sunucu, 5 sn): taraf başına (west / east / independent) AI topçu varsa (`fnc_topcuListe`: artilleryScanner, yerel, AI nişancı, canFire, HE mermisi — duman / ışık / fişek / küme / mayın / lazer / roket hariç) çalışır. Gözlemci = AI mürettebatlı, silahsız GÖZLEM tipi (`fnc_ihaTip`), ≥ 10 m irtifada, son 15 sn'de `fnc_ihaGozlem`'in yazdığı `lambs_danger_ihaGorulen` (gerçek `nearTargets`) en dolu olan dron. Kümeleme `fnc_topcuKume` (60 m; değer: adam 1, hafif araç 2,5, zırhlı 3, statik 2, topçu 4; araçtaki adam ayrıca sayılmaz; esir / sivil / mürettebatsız araç sayılmaz). Küme değeri ≥ `dronTopcuMinDeger` (3), gözlemciden ≥ 150 m, son 240 sn'de atış yapılmış bölge değil, 10 sn aynı yerde (40 m) ise `fnc_dronTopcuMisyon` başlar; taraf kilidi 900 sn (görev sonunda 150 sn / hata 20–90 sn). Uzaktan görünen düşman: gözlemci yoksa yerel AI grup liderlerinin (≤ 10 grup / 20 sn) `nearTargets 1500` + `knowsAbout ≥ 1.2` gördüğü küme, en yakın dosttan ≥ `dronTopcuUzak` (700 m), menzil ve emniyet uygunsa hedefin dost tarafında 380 m geride (yarıçap 130 m) gözlem istasyonu için `lambs_danger_dronGozlemIstegi` (250 sn'de bir; `fnc_dronGozlemci` artık 7. parametre ile yarıçap alır ve görevi biten dronu 'aktif' saymaz). Temas belleği: 20 sn'de bir kümeler 1200 sn tutulur (`lambs_danger_dtBellek_<taraf>`, ≤ 30 kayıt, 100 m birleştirme).
- **`fnc_dronTopcuMisyon`** (v8.338): güvenlik ön kontrolü (`fnc_topcuGuvenlik`, `fnc_topcuRed`, bütçe `fnc_topcuButce`) → `CAGRI` logu (gözlemci, uyarı emri, grid + gözlemciden yön / mesafe, hedef tanımı, yöntem) → ADJUST ≤ 3 mermi (tek top; `fnc_topcuIzle` `Fired` işleyicisi mermiyi izler, son konumu son hız vektörüyle yere taşır → `dtSplash`; hata ≤ max(60 m, mesafe × %1,2) ise düzeltmesiz FFE, değilse düzeltme ≤ 400 m / danger close ≤ 100 m, ilk mermi hedefin dosttan uzak yanına) → FFE (en çok 4 top × 3 mermi, 60/81 mm: 4; danger close: tek top × 2; dağılım 30 / 15 (araç) / 12 (danger close) m; `topcuPartiN` × `topcuAralikS` paceleme) → BDA (gözlemci kalan düşmanı sayar; kalan ≥ 2 ve ≥ %50 ise BİR REPEAT) → `SON (END OF MISSION)`. Gözlemci ölür / görmez, hedef 80 m kayar, NFA / dost / bütçe → iptal.
- **`fnc_topcuTaciz`** (v8.338): bayat temas kaydı (60–900 sn, değer ≥ 3, ≤ 2 kez taciz, son tacizden ≥ 600 sn), puan = değer × tazelik; menzildeki en yakın boşta top (son 20 sn atış yok); RED + 20 m, NFA, sivil, **dost ≥ 600 m** şartı (danger close'ta gözlemsiz atış yok); 2 mermi 18–38 sn arayla, her biri 40 m yarıçapta; mermi bütçesi ortak. Zamanlama `lambs_danger_dtTacizT_<taraf>` (240–480 sn, gece × 0,6).
- **Ortak emniyet** (v8.338): `fnc_topcuGuvenlik` = [uygun, neden, en yakın dost, danger close, dost konumu]; plan atışı yalnız NFA kontrolünü kullanır (dost mesafesini kendi RED mantığıyla denetler). `fnc_topcuDestek` OPERATOR / KARŞI modları topa özel RED + 20 m ve 600 m kapısı (eski: `lambs_danger_topcuEskiMesafe`).
- **Altyapı**: `tools/hemtt_kontrol.sh`, `[PERF-SQF]`, `fnc_perfBisect`, `rpt_ozet.py --tani` yeni bölümleri.

## H. ALTYAPI VE İZLEME

- **Watchdog bekçisi**: her izleyici hata ile ölürse yeniden başlar (`[WATCHDOG-YENIDEN]`).
- **Taraf seçimi**: CBA'dan hangi tarafta aktif; kapalı tarafın grupları atlanır.
- **Log etiketleri**: `[TCCC] [TCCC-TX] [TCCC-DURGUN] [SINSI-GERI] [BAYGIN-ROE] [CEPHANE] [BUDDY] [SAHA] [CQB] [SIPER-YAPIS] [ATES-HATTI] [HAREKET] [ZEKA-*] [HQ-*] [PANIK] [GIZLI] [MEKANIZE] [ARAC-MEDEVAC] [HALT] [GOZCU] [TEHLIKE-ALANI] [DURUM] [DOKTRIN] [ANOMALI] [MORAL]` ...
- **`tools/rpt_ozet.py`**: `--karne / --form / --zeka / --kayip / --grup`; sürüm kontrolü.
- **Dokümanlar**: `DEVIR_LOGU_v7.0.txt`, `DOKTRIN_KAYNAKLARI.md`, `TEST_SENARYOLARI.md`, `kaynaklar_doktrin/arastirma_gerceklik/`, `OZELLIKLER_LISTESI.md` (özet).

---

## Bekleyen
Oda / bina temizleme + el bombası kullanımı yeniden yazımı (en sona); kalıcı senaryo (Bakhmut-lite); helikopter medevac / hava nakli; zırhlı destek (mekanize taktikler); karakolda MG / AT yerleşimi + nöbet rotasyonu; moral → davranış katmanı; hareket halinde formasyon / yol geçişi çakışmasının kök nedeni.
