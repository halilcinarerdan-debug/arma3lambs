# LAMBS Danger FSM — ELITE fork: Özellik Listesi (v8.103)

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
- **Temas kesme**, **son direniş** (kale savunması), **sinsi geri çekilme (T)** (`sinsiGeri`): düşman ezici üstünse ve grup henüz ateş altında değilse
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
- **Baygına patlayıcı yasağı (T)**: baygın hedefe el bombası / roket / 40 mm / pompalı iptal; hedef yoksa iniş noktasına göre karar.
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
- **HQ medevac**: gruplar arası hekim atama, talep / hekim havuzu kuralı. **Araçlı medevac** (T): APC / araç yaralıları toplama noktasına taşır.
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
- Aracın roket / duman tepkisi, ≥4 araçta DIAMOND.

## 10. Lojistik
- **Cephane + el bombası paslama (T)** (`cephanePaylas`): eşler arası önce; vericinin yere bırakıp alıcının alması; sınıflar mermi simülasyonundan bulunur (RHS).

## 11. Geliştirici araçları
- **`tools/rpt_ozet.py`**: `--karne / --form / --zeka / --kayip / --grup` RPT özetleri, sürüm kontrolü.
- **Log etiketleri**: `[TCCC] [TCCC-TX] [TCCC-DURGUN] [SINSI-GERI] [BAYGIN-ROE] [CEPHANE] [HQ-*] [PANIK] [GIZLI] [MEKANIZE] [ARAC-MEDEVAC] [HALT] [GOZCU] [TEHLIKE-ALANI] [DURUM] [ANOMALI]` ...
- **Watchdog bekçisi**: her izleyici hata ile ölürse yeniden başlar (`[WATCHDOG-YENIDEN]`).
- **Dokümanlar**: `DEVIR_LOGU_v7.0.txt` (sürüm sürüm değişiklik ve kök neden), `DOKTRIN_KAYNAKLARI.md`, `TEST_SENARYOLARI.md`, `kaynaklar_doktrin/arastirma_gerceklik/`.

## Planlanan / bekleyen
- Oda / bina temizleme + el bombası kullanımı yeniden yazımı (en sona bırakıldı).
- Kalıcı senaryo ("Bakhmut-lite": kayıt / yükleme, bot kimliği, performans ölçekleme, komutan zekâsı).
- Mekanize taktikleri (araç ateş desteği, ineceği nokta), moral → davranış katmanı.
