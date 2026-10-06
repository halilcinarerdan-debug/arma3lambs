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
- **Araçlı medevac (T)** (`aracMedevac`): yalnız mürettebatlı kara aracı, ≥ 40 sn ilgilenilmeyen yaralıya gider, ≤ 3 yükler, 350 m taşır.
- **AI sürükleme kapalı** (ACE startDrag AI'da çalışmıyor; iptal edildi).
- Baygınlar kayıp sayılır; COD tarzı kaldırma yok.

---

## F. MEKANİZE

- `mekanizeIzle`: dur-kalk tespiti; düşman > 100 m veya yok → COLUMN / FULL / AUTOCOMBAT kapalı; sürücü forceSpeed sıfırlama (-1).
- `doAssaultSpeed` overlay: forceSpeed araç içindekine uygulanmaz.
- Araç mürettebatı roket / duman tehdidine tepki verir (`tehditOlay`).
- DIAMOND yalnız ≥ 4 kara aracı, açık, yol dışı, temas > 60 sn, düşman > 500 m.

---

## G. KUMANDA (HQ) KATMANI — gruplar arası

- `hq`: taraf başına durum tahtası (grup / temasta / meşgul / müsait / toplam asker). Taraf kapalıysa (CBA) atlanır.
- `hqIstihbarat`: SPOTREP ağı, telsiz şartı (lider / RTO), gecikme, belirsizlik, "bilgi sisi" (varsayılan 0.4), kayıp raporu.
- `hqTakviye`, `hqKanat` (iki grup koordineli), `hqFeint` (yanıltıcı sınırlı saldırı), `hqEmir` (emir kanalı; TAKVİYE / KANAT / FEINT bounding'i iptal eder).
- `hqMedevac`: yukarıda. Müsait grup hesabı: bounding grupları (düşman ≥ 250 m) de kullanılır.

---

## H. ALTYAPI VE İZLEME

- **Watchdog bekçisi**: her izleyici hata ile ölürse yeniden başlar (`[WATCHDOG-YENIDEN]`).
- **Taraf seçimi**: CBA'dan hangi tarafta aktif; kapalı tarafın grupları atlanır.
- **Log etiketleri**: `[TCCC] [TCCC-TX] [TCCC-DURGUN] [SINSI-GERI] [BAYGIN-ROE] [CEPHANE] [BUDDY] [SAHA] [CQB] [SIPER-YAPIS] [ATES-HATTI] [HAREKET] [ZEKA-*] [HQ-*] [PANIK] [GIZLI] [MEKANIZE] [ARAC-MEDEVAC] [HALT] [GOZCU] [TEHLIKE-ALANI] [DURUM] [DOKTRIN] [ANOMALI] [MORAL]` ...
- **`tools/rpt_ozet.py`**: `--karne / --form / --zeka / --kayip / --grup`; sürüm kontrolü.
- **Dokümanlar**: `DEVIR_LOGU_v7.0.txt`, `DOKTRIN_KAYNAKLARI.md`, `TEST_SENARYOLARI.md`, `kaynaklar_doktrin/arastirma_gerceklik/`, `OZELLIKLER_LISTESI.md` (özet).

---

## Bekleyen
Oda / bina temizleme + el bombası kullanımı yeniden yazımı (en sona); kalıcı senaryo (Bakhmut-lite); mekanize taktikleri; moral → davranış katmanı.
