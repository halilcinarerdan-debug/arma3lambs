# ELITE Yürünebilir Alan — kullanım rehberi (v8.335)

**Ne işe yarar:** AI'nın yol bulması çok sayıda nesneyle (kum torbası, tahta, kaya kümesi, siper parçası) dolu hendeğe / banda yol bulamaz; asker kenarda ya da içinde dakikalarca takılır. Bu modülün alanı içinde takılan asker, nesnelerin ÜSTÜNDEN betikle yürütülür (kayanın içine girmez, üstüne çıkar). Alan dışında hiçbir şey yapmaz.

## 1. Nereye koyulur
- **Nesne yoğun, askerin geçmesi gereken yere:** hendek hattı, kaya / çalı bandı, kum torbası yığını, tahta-palet siperleri. Merkez bandın **ortası**, alanın `b` (boy) ekseni bandın uzun yönünde olsun.
- Koyma: Eden → Systems → Modules → **ELITE Yürünebilir Alan (yoğun objeli hendek)** (LAMBS Danger kategorisi). Zeus → aynı modül; bırakınca ayar paneli açılır.
- **Eden:** alan boyutu / yönü / şekli modülün kendi tutamaçlarıyla (varsayılan 12 x 4 m dikdörtgen). **Zeus:** panelde şekil (dikdörtgen / elips), yarı genişlik `a`, yarı boy `b`, yön. Panel kapatılırsa 12 x 4 m varsayılan geçerli; değiştirmek için modülü silip yeniden bırak.
- **Kıvrımlı / uzun bant:** tek dikdörtgen yetmez. Bandın boyunca **birkaç alanı ≥ 8 m birbirine bindirerek** diz; üst üste alanlar tek bölge sayılır, asker alan içinde kaldıkça yürür.

## 2. Ne koyulabilir (nesne kuralları)
| Nesne | Durum |
|---|---|
| Kaya, kum torbası, tahta, çit, alçak duvar, siper parçası, çalı (üst yüzeyi **ayaktan ≤ 3 m**) | ✔ üstünden yürünür |
| 3 m'den yüksek kaya / duvar / yığın | ✘ tırmanılamaz: asker ±25 / 50 / 80° yan açı dener; hiçbiri geçilemezse yürüme bırakılır (`gecilemez engel`) |
| Bina (House) | ✘ alan bina içini kapsamaz; AI binaya kendi yoluyla girer (tarama uyarı verir) |
| Araç / asker | yok sayılır |
| Su | ✘ alanın %30'undan fazlası su ise HATA |

## 3. Renkler (Zeus / önizleme; her alan otomatik taranır)
- **YEŞİL — TAMAM:** nesneli ve geçilebilir. Alan boyutu, nesne örneği ve en yüksek nesne yazar.
- **TURUNCU — UYARI:** bazı noktalar > 3 m (yan geçiş denenir) ya da alanda bina var.
- **KIRMIZI — HATA:** noktaların > %25'i tırmanılamaz, > %30 su ya da alan çok küçük → alanı küçült / kaydır / böl.
- **SARI — BOŞ:** alanda neredeyse hiç nesne yok → AI zaten yürür; alanı nesneli hendeğin üstüne taşı.
- Durum değişince Zeus'a sohbet raporu gelir (`[ELITE] Yürünebilir alan 090043: UYARI - ...`); aynı satır `[YURUYUS-ALANI] tarama` olarak RPT'ye yazılır. Harita işareti + 3D çerçeve + etiket aynı renktedir. Alanı diğer oyuncular **görmez** (CBA "Yürünebilir alanları HERKES görsün" açılırsa görürler).

## 4. Ne zaman devreye girer (tetik)
Asker alanın **içinde ya da en çok 12 m yanında**, **hareket emrinde**, hedefi **alanın içinde** (≤ 3 m) **ya da hedefe giden doğru alandan geçiyor** ve **2,5 sn boyunca 0,4 m'den az ilerlemişse** "takıldı" sayılır. Hedef: hendek yerleştirme / garnizon nöbeti / gözetleme emrinin **gerçek noktası** (90 sn içinde) varsa o, yoksa AI'nın hedefi. Hızlı AI geçişlerini bozmaz: yürüyebilen asker hiç devralınmaz.

## 5. Sorun giderme
| Belirti | Bak / yap |
|---|---|
| Alan oyunda görünmüyor | Zeus'ta mısın (curator atanmış)? Değilsen CBA "Yürünebilir alanları HERKES görsün" aç. Alan listesi 10 sn'de yenilenir. |
| Hiçbir `[YURUYUS]` satırı yok | asker alanın 12 m dışında / MOVE emrinde değil / takılmadı; modülü bandın ortasına al; `[YURUYUS-ALANI] tarama` satırı HATA / BOŞ mu? |
| `bitti: gecilemez engel` | bantta > 3 m nesne: alanı yüksek kısmın dışına al ya da yan geçişe izin ver (alan genişlet) |
| Asker kayanın içinden / havada geçiyor | `[YURUYUS] ... en yüksek yüzey N m` logunu bildir (GEOM ışını bazı kayalarda nesne döndürmeyebilir) |
| Kıvrımlı bantta ortada kalıyor | alanları ≥ 8 m bindir |

## 6. Ayar / log
- CBA: ELITE siper → **Yürünebilir alan (Eden modülü) AKTİF** (varsayılan açık), **Yürünebilir alanları HERKES görsün** (varsayılan kapalı). Kapatma: `lambs_danger_yuruyusOff = true`, görsel: `lambs_danger_yuruGorselOff = true`.
- Log: `[YURUYUS-ALANI]` (modül kaydı + tarama), `[YURUYUS]` (takılma + bitiş nedeni, süre, en yüksek yüzey). `python tools/rpt_ozet.py --tani <rpt>` "Yürünebilir alan" bölümü.
- Doğrulanmadı (T): GEOM ışını terrain kayalarında nesne döndürüyor mu, 3 m tırmanma sınırı, Eden `objectArea` değişken adı — ayrıntı `DOGRULANMAYANLAR.md`.
