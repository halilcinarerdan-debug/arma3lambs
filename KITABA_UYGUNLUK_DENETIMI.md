# Kitaba uygunluk denetimi (v8.338, 2026-10-24)

Kullanici istegi: "herseyin kitaba uygun olup olmadigini check et". Bu belge, **v8.206 - v8.338** arasinda eklenen davranislari `kaynaklar_doktrin/` altindaki kaynak metinlere karsi
tartar. Eski ozelliklerin (formasyon, ORP, bounding, retreat, feint, mekanize inis vb.) sayisal denetimi zaten
`kaynaklar_doktrin/SAYISAL_ESIKLER_KAYNAK_TABLOSU.md`, `kaynaklar_doktrin/FORMASYON_POLITIKASI.md` ve `DOKTRIN_KAYNAKLARI.md` icindedir; burada tekrar edilmedi.

## Yontem ve sinirlar
- **Etiketler:** `[K]` kitapta var (dosya + satir, bugun `grep` / `sed` ile elle dogrulandi) | `[K~]` kavram kitapta var, kodun uygulamasi (sayi / ayrinti) tasarim | `[T]` tasarim tahmini, kitapta karsiligi YOK |
  `[N]` kaynak setinde konu hic yok | `[X]` kitapla CELISIYORDU (bu surumde duzeltildi) | `[U]` kullanici karari kitaptan bilerek sapiyor.
- **Kaynak seti sinirli:** TC 3-21.76, MCWP 3-11.1 / 3-11.2, ATP 3-21.8 (alinti), ATP 4-25.13, ATP 3-01.8, FM 3-34 (icinde FM 3-90 eki var), ATP 7-100.1. Dolayli atesin asil kitaplari
  (FM 3-09, ATP 3-09.32, TC 3-09.81 vb.) depoda **yok**; topcu kavramlari yalniz yukaridaki kitaplarin icindeki ozetlerden alindi. Kitapta olmayan hicbir sayi "kitapta" diye sunulmadi.
- **Oyunda dogrulama ayri:** Bu belge "kitaba uygun mu"yu soyler, "oyunda calisiyor mu"yu degil (o liste `DOGRULANMAYANLAR.md` ve `TEST_SENARYOLARI.md`).

## 1. Dolayli ates (topcu / havan) — en cok sapma burada cikti
| Davranis | Kitap karsiligi | Etiket | Durum |
|---|---|---|---|
| Risk estimate distance (RED): 60 mm ~145, 81/82 ~195, 120 ~430, 105 ~455 m | TC 3-21.76 3-4 / 3-5 + Tablo 3-3 (satir 2720-2745) | `[K]` | Plan atisi (v8.183) ve yeni sistemler kullaniyor |
| Kitapta olmayan kalibre (122 / 152 / 155 mm) icin RED | Tabloda yok; en buyuk tablo degeri 455 m | `[T]` | **`[X]` -> duzeltildi:** plan atisinda varsayilan 300 m idi (2S1 gibi 122 mm icin tablodakinden KUCUK); 455 m yapildi. Geri almak: `lambs_danger_topcuEskiMesafe = true` |
| Karsi-batarya ve operator (dron) atesinde dost mesafesi | RED (kitap) | `[X]` | **Duzeltildi:** `fnc_topcuDestek` OPERATOR / KARSI modlari tek tip 200 m kullaniyordu (120 mm RED 430, 155 mm RED 455 > 200). Artik topa ozel RED + 20 m |
| Duzeltmesiz (gozlemsiz) atis dost birligine <= 600 m | DANGER CLOSE: hedef dosta <= 600 m ise yalniz gozlemli, **creeping** (<= 100 m duzeltme), bracketing yasak (TC 3-21.76 satir 2733-2741; cagri adimi f (satir 2951)) | `[K]` | Karsi-batarya, operator atesi ve taciz atisi artik dost <= 600 m ise ATMAZ. (Plan atisi onceden planlanmis hazirlik atisi oldugu icin 600 m kisitina bagli degil; asagida 'Acik' 1) |
| Ates yasak alani (NFA) | "Bir alan; icine ates / etkisi yasak. Ileri gozlemci, dost kuvvet, sivil yogunlugu, hassas yer korunur" — FM 3-34 eki (FM 3-90) A-96 / A-97 (satir 19262-19281); ayrica satir 10664 | `[K]` kavram, `[T]` isim kurali | Yeni: haritada adi `nfa` ile baslayan isaret (+100 m tampon) icinde HICBIR dolayli ates (plan, gozlemli, taciz, karsi-batarya, operator) yok |
| Sivil yakininda atis | NFA'nin amaci "dislocated civilian concentrations" (ayni satirlar) | `[K~]` | Yeni: hedefe < 120 m'de canli sivil varsa gozlemli / taciz / karsi / operator ateslerinde atis yok (120 m `[T]`). Plan atisi icin sivil kontrolu yok (senaryo yazari isaretle `nfa` kullanir) |
| Cagri (call for fire) adimlari: gozlemci kimligi, uyari emri (ADJUST / FFE), hedef yeri, hedef tanimi, uygulama yontemi, kontrol | TC 3-21.76 3-10 / 3-11 (satir 2916-2985), Tablo 3-6 (satir 2999) | `[K]` | `fnc_dronTopcuMisyon` ayni sirayi logluyor (`CAGRI`) |
| ADJUST FIRE: tek top, tek mermi, SPLASH, duzeltme, sonra FFE | TC 3-21.76 satir 2970 ('Normally adjust fire: one gun is used with a five second interval between rounds'), Tablo 3-6 (SHOT / SPLASH) | `[K]` | Uygulandi (en cok 3 mermi); **dusme noktasi gercekten izleniyor** (mermi nesnesi), tahmin degil |
| Duzeltme siniri: normal 400 m, danger close 100 m; yeterli esik max(60 m, mesafenin %1.2'si) | 100 m creeping `[K]`; 400 m ve esik `[T]` | `[K~]` | |
| FFE: menzildeki toplar, top basina 3-4 mermi, 12-30 m dagilim; danger close'ta tek top x 2 mermi | Kitap "size of element to fire for effect" der, sayi yok | `[T]` | |
| END OF MISSION + BDA + REPEAT | Tablo 3-6 'END OF MISSION ... casualties'; REPEAT (kontrol yontemi listesi) | `[K]` | Bir REPEAT; kalan >= 2 ve >= %50 ise |
| Dron = ileri gozlemci (hedef tespiti, atis duzeltme, vurus sonrasi hasar degerlendirme) | ATP 7-100.1 6-66 (satir 5055-5060: 'UAV company ... identifying targets, adjusting artillery fire, post-strike damage assessments'); C-13 (satir 7380-7385: UAS + dolayli ates = reconnaissance-fire complex); gozlem ekipleri 'support adjustment of direct and indirect fires' (satir 3030-3033) | `[K]` | Rol dogru. Rus kaynaginin 4 dk / 12-15 dk sensor-to-shooter sureleri (satir 5056, 2403-2404) koda alinmadi (bizde tepki suresi 10 sn durağanlik + ucus) |
| Taciz atesi (harassing fire): dusmanin dinlenmesini bozma, hareketi kisitlama, moral dusurme; kucuk / duzensiz / gozlemsiz | Etki turleri 'harassing, interdiction, suppressive, destruction, deception' — FM 3-34 1-138 (satir 5429); MCWP 3-11.1 (satir 11021: 'harassing fire to disrupt the activities of insurgents'); FM 3-34 4-33 (satir 7678: 'non-observed harassing and interdiction fires') | `[K]` tanim | **Sayisal kural kitapta YOK:** 60-900 sn bayat temas, 240 sn aralik, 2 mermi, 40 m dagilim, gece x0.6, 30 mermi / 600 sn butce hep `[T]`. Yalniz gozlemsiz ve danger close disi (kitap emniyeti) |
| Interdiction (I of H&I) | Etki turu olarak kitapta (ayni satir 5429) | `[K]` kavram | **Uygulanmadi** — yalniz 'H' var; yol / gecit ablukasi eklenmedi |
| Karsi-batarya: bilinen dusman topcusuna atis | ATP 7-100.1 (Rus): karsi-ates, 'sensor-to-shooter 4-6 dk' (satir 2403-2404), 'RSC' (3783) | `[K~]` | Kavram var; bizde 90 sn'de bir, 3 mermi, 3 top `[T]`. 4-6 dk gecikmesi uygulanmiyor (daha hizli, kitaptan 'sert') |
| Duman perdesi (SIS): dusman gozetlemesini kor et, dostu perdele; dusman mevzisine yakin | MCWP 3-11.1 satir 7922-7930 ('Obscure enemy observation or screen friendly maneuver'), 8012-8016 ('smoke effects are close to or on enemy positions') | `[K]` | Hedefin 60 m onune, yaklasma yonune; mermi sayisi (2) `[T]` |
| Dron operatorune tahmini nokta atesi | Kitapta YOK (operator avi icin dolayli ates onerilmez / yasaklanmaz) | `[T]` | Artik kitap emniyetine (RED, 600 m, NFA) tabi |
| Mermi paceleme (2'serli parti, 6 sn arayla) | Kitapta yok; ACE frag / sunucu donmasi dersi (v8.206) | `[T]` | Muhendislik onlemi, doktrin iddiasi degil |

**Acik (duzeltilmedi, bilincli):**
1. Plan hazirlik atisi (`fnc_komutanPlanDongu`) RED'e uyuyor ama dost 600 m icindeyse 'DANGER CLOSE + creeping' uygulamiyor; kitaptaki danger close gozlemli atis icindir, hazirlik atisi onceden planli hedeftir. Dost RED ile 600 m arasinda ise atilir. Istenirse ayni 600 m kapisi eklenebilir (davranisi sertlestirir).
2. Gozlemci yalniz dron. Kitaptaki asil gozlemci olan ileri gozlemci (yer, FO) yok; bir yer grubunun 'gorup' topcu cagirmasi yapilmadi.
3. Cagri / telsiz gecikmesi (FDC islem suresi) yok; mermi hazirlik gecikmesi yalniz topun kendi hazirligi.

## 2. Piyade duman / sis
| Davranis | Kitap | Etiket |
|---|---|---|
| Temas kesmede duman, saldirida perde | TC 3-21.76 Break contact drill (H1 notu, `DOKTRIN_KAYNAKLARI.md`); MCWP 3-11.1 satir 7922, 10014 ('screen friendly displacement') | `[K]` |
| Taraf basina 120 sn'de en cok 2 sis olayi, grup basina 90 sn, olaylar arasi 25 sn | Kitapta yok (kitap sis YETERSIZLIGINI de belirtmez) | `[T]` — kullanici istegi (cok sis) |
| Kisi basi sis yuku (HC 6 / kirmizi 2 / sari 4) | TC 3-21.76 satir 1352-1370 (SAYISAL_ESIKLER tablosu) | `[K]` yukleme, butce `[T]` |

## 3. Dron / hava tehdidi
| Davranis | Kitap | Etiket |
|---|---|---|
| Dron gorunce dagil, gizlen, siper al | ATP 3-01.8 pasif onlemler 'What can be seen can be hit', dagilma, siper (satir 1385-1480) | `[K]` |
| Kucuk silahla dron atesi komutanin karari; yalniz alcak ucan hedef; toplu ates komutla; olasilik dusuk | ATP 3-01.8 satir 2386-2397, 2399-2425, 2435 | `[K~]`: sistemde 'zorla ates' var (v8.293, kullanici istegi); 'komutla toplu ates / hassas nisan onemsiz' tam uygulanmiyor -> `[U]` |
| Dron operatorunu avlayan devriye (3-4 kisi) | Kitapta devriye sayisi yok; ATP 3-01.8 'C-UAS TTP gelistir' (satir 2348-2356) | `[T]` |
| Gozlem dronu gonderme (gelis yonune) | ATP 3-01.8 1-2 (satir 276: kucuk insansiz sistemler); gozlem rolu ATP 7-100.1 6-66 | `[K~]` rol, tetik `[T]` |
| FPV kamikaze / bomba dronu davranisi (kendi tarafimiz) | Kaynak setinde FPV / loitering munition kullanimi YOK (yalniz Rus 'loitering munitions' anilir: ATP 7-100.1 satir 3216, 7384) | `[N]` — acik kaynak analizlerine dayali tasarim |

## 4. Zirh (tank)
| Davranis | Kitap | Etiket |
|---|---|---|
| Hull-down mevzi, birincil / yedek mevzi, sektorler | ATP 3-20.15 3-76 (kullanici gonderdi; `DOKTRIN_KAYNAKLARI.md` 'Recon karari, tank mevzisi'); FM 3-34 satir 20065 | `[K]` |
| Saldirgan varsayilan (`tankAgresif` 2): gizleme noktasi yok, mevzi ~200 m, 60 sn'de ileri sicrama | Kitap tersine: savunmada defilade / gizlenme ve **kesin cati engagement'tan kacinma** | `[U]` kullanici karari ('cok savunmaci'); `tankAgresif` 0-1 = kitaba yakin |
| Sicrama / tetik / mesafe sayilari | Kitapta yok | `[T]` |
| Bina: acikta kalan asker ve bina icinde dusmani goremeyen asker, dusmana pencere hatti acik ama ust ortulu ATIS pozisyonu secer; pasif gizlenme son care (`fnc_acikSiper`, `fnc_binaPencere`) | MCWP 3-11.2 satir 2598 (savunmada pencere pozisyonu golgede, pencerenin hemen onunde degil); TC 3-21.76 A-9 / 11-12 (kat / girisleri tek yone yigilmadan guvenceye al) | `[K~]` ilke (bina atis pozisyonu olarak kullanilir); skorlar, mesafeler, kat siniri `[T]`; 'ic mekan ust ortu' = pencerenin gerisinde durma yaklasimi |
| Cephane paslama: yedek sarjoru azalan oyuncuya manga arkadaslari sarjor verir (`fnc_cephanePaylas` oyuncu kolu) | Genel ilke 'ammunition cross-leveling' (catisma arasi cephanenin yeniden dagitimi); kaynak setinde sayisal esik YOK | `[T]` (esik 3 sarjor, 4'e tamamlama, vericide >= 2) |
| CQB: kor kosede (bina ucu, sokak agzi, kapi pervazi) durup bilinmeyen sektoru dilimler, arkadakiler sirada bekler, yigilma yok (`fnc_koseTemkin`) | TC 3-21.76 A-7..A-8 (koridor kavsagi tehlike alani; #1 alcak / #2 yuksek, kenetlenen sektorler; temizlik ekip gidince gecersiz), A-9 (fatal funnel), 11-24 not ('flagging' yasak), 11-12 (girislerde yigilma yok); MCWP 3-11.2 9107d (sokakta siperi onceden sec, duvara yapis, ortadan gitme, birlikte gec + dagil) | `[K]` ilke; isin yelpazesi, esikler, 1.0 / 0.8 sn, 60 sn hafiza `[T]`; AI'nin 'egilerek kose bakma' animasyonu yok: forceSpeed 0 + doWatch yaklasimi, birebir kitap tekniği DEGIL |
| CQB: dusman < 70 m iken siper alt siniri dusman mesafesinin %30'u; bina / duvar kose adaylari; 28 m icinde acikta kalan asker 6 m icindeki siper / koseye atilir (`fnc_findCover`, `fnc_cqbReflex`) | MCWP 3-11.2 9107d (siperi onceden sec, duvara yapis); TC 3-21.76 11-12 (korunma + gizlenme analizi) | `[K~]`; %30 / 5 m / 6 m `[T]` (eski sabit 25 m alt sinir bir muhendislik hatasiydi, kitap iddiasi degil) |
| Zirh, rotadaki gorus engeli cizgisini (tepe sirti) ve bogazi (kopru, orman yolu, koy ici, yarma) piyade temizlemeden gecmez (`fnc_zirhGecit` + `fnc_zirhBekle`, engel basina <= 120 sn) | MCWP 3-11.1 satir 8751-8766 (gorus engeli cizgileri / bogazlar once piyade tarafindan temizlenir) | `[K]` ilke; 30 m ornekleme, 28 m yan mesafe, 150 m durus, 120 sn `[T]` |
| Sicramali gozetleme: temas olasi bolgede esler arasi biri ilerlerken digeri yerinde gozetler (`fnc_zirhBekle` ES SICRAMA, `fnc_planZirh` grup ici) | MCWP 3-11.1 satir 8742-8766 (arac araligi: birbirini gorecek kadar yakin) + s. 6-36 (zirh piyade temizledikce ileri sicrar) | `[K~]` ilke (bounding overwatch kavrami); 1400 m, 150 sn, esleme 0-1 / 2-3 `[T]` |
| Gudumlu fuze uyarisi: duman + karsi ates + yer degistirme + komsu zirhliya bildirim (`fnc_zirhUyari`) | ATP 3-20.15 3-81..3-98 (temasta eylemler), 3-136 (duman) | `[K]`; 500 m `[T]` |

## 5. Savunma / garnizon / saglik
| Davranis | Kitap | Etiket |
|---|---|---|
| Otomatik garnizon: karakol (gozcu), mevzi, gozletme (OP) sektorun onunde | TC 3-21.76 satir 812, 1820 (LP/OP); MCWP 3-11.1 satir 780 (OP) | `[K~]` |
| Nobet / devriye zamanlamasini degistirme | MCWP 3-11.1 satir 11013 ('Varying the timing and methods of patrolling, changing guards') | `[K]` ilke, sayilar `[T]` |
| CCP konumu (ORP / RP yakininda, korunakli) | ATP 4-25.13 satir 1205 (CCP'ler dikkatle secilir), 1265-1266, 1308 | `[K~]`; 70-160 m `[T]` |
| ORP 200-400 m, ses / gorus disinda | TC 3-21.76 4678 (SAYISAL tablo) | `[K]` |
| Garnizon halkalari 90 / 140 / 190 m, birbirinden >= 60 m, ORP / CCP / RP'den >= 70 m | Kitapta yok | `[T]` |
| TCCC / triyaj / CCP'ye tasima | ATP 4-25.13 (SAYISAL tablo CE satirlari) | `[K]` (onceki denetimle ayni) |

## 6. Kitapla ilgisiz (muhendislik)
Arac unstuck (`fnc_aracUnstuck`), tank ve piyade agac / kaya takilma cozumleri, HEMTT kontrolu, pacing, FPS onlemleri, ACE uyumu `[N]` — motor / mod sorunlarinin cozumudur, doktrin iddiasi tasimaz.

## 7. Sonuc
- **Kitapla celisen 2 gercek sapma bulundu ve duzeltildi:** (a) karsi-batarya / operator atesinde 200 m sabit dost mesafesi (RED'den ve 600 m danger close kuralindan kucuk), (b) kitapta olmayan kalibrelerde RED 300 m (tablodaki en buyuk degerden kucuk). Ek olarak **NFA** (kitaptaki ates yasak alani) hic yoktu, eklendi.
- **Kitapla uyumlu ve yeni:** gozlemli atis (cagri -> adjust -> FFE -> BDA -> REPEAT), dron = ileri gozlemci (ATP 7-100.1 6-66), taciz atesi (tanim kitapta; sayilar tasarim).
- **Bilincli sapmalar:** tank agresifligi (kullanici), dron zorla atesi (kullanici).
- **Kitapta karsiligi olmayan, tasarim sayisi olan** cok sayida esik var; hicbiri "kitapta" diye sunulmadi (her ozelligin ust bilgisinde `[T]` / "tasarim" yazar).
- **Dogrulanamayan:** AI dronun gercekten hedef gorup gormedigi (`ihaGorulen` dolu mu), `Fired` ile dusme noktasi yakalama, `getArtilleryETA` / `doArtilleryFire` tek mermi davranisi. Bkz. `TEST_SENARYOLARI.md` -> TOPLU TEST PLANI v8.338.
