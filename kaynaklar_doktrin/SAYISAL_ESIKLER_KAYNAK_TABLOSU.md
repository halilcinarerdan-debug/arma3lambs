# Sayısal eşikler: kaynaklı olanlar ve tasarım tahminleri (v8.118)

Taranan kaynaklar: `kaynaklar_doktrin/` altındaki TC 3-21.76 (RH), MCWP 3-11.1 (M111), MCWP 3-11.2 Ch1 (M112, OCR bozuk), ATP 3-21.8 alıntıları (A21), ATP 4-25.13 (CE), ATP 3-01.8 (AD), FM 3-34, araştırma notları.
Tarama bir alt ajanla yapıldı; **satır numaraları ajan raporundandır**. Ben şunları kaynaktan elle doğruladım: RH 4266-4281 (hareket aralıkları), RH 4457-4459 (halt), RH 4545 (farside 250 m), M111 8708-8710 (bound ≤ ⅔ etkili menzil), A21 31-33 (kama 10 m), CE 287 (taşıma 50-300 m), RH 4678 / 5253 (ORP). Diğerleri ajan raporuna dayanır, kullanmadan önce kaynağa bakın.

## 1. Kaynaklı sayılar (kodda kullanılanlar işaretli)
| Konu | Kitapta yazan | Kaynak | Kodda |
|---|---|---|---|
| ORP mesafesi | Objektiften tipik 200-400 m (veya en az bir büyük arazi ögesi); sınırlı görüşte 100-200 m; ses ve görüş dışı | RH 4678, 5253 | **Kullanıldı** (v8.117): ORP varsayılanı 300 m, uyarı eşikleri |
| Rally point nitelikleri | Örtülü/gizli, akın yollarından uzak, kısa süre savunulabilir | RH 4668-4672 | **Kullanıldı** (konum seçimi) |
| Danger close | Hedef dost birliğe ≤ 600 m (havan/sahra); düzeltme ≤ 100 m creeping | RH 2734-2741 | **Kullanıldı** (v8.117) |
| RED (%0.1 Pi) | 60 mm ~145, 81/82 mm ~195, 120 mm ~430, 105 mm ~455 m (azami şarj, ayakta). OCR bozuk: RH 2748-2860'ı elle doğrulayın | RH Tablo 3-3 | **Kullanıldı** (topçu min. dost mesafesi) |
| Security halt | Short halt 1-2 dk; long halt > 2 dk | RH 4457-4459 | **Kullanıldı** (v8.118): keşif 60 / 90 / 30 sn |
| M16 etkili menzil | 460 m (tüfek ateşi açma sınırı) | M112 409 | **Kullanıldı** (SBF uyarı eşiği 460 m) |
| Bound uzunluğu | Gözetleyen silahın etkili menzilinin ⅔'ünü geçmemeli | M111 8708-8710 | Kodda henüz yok (öneri) |
| Hareket aralıkları | Traveling 10 m (kişi) / 20 m (manga); traveling overwatch 20 m / 50 m (takım); öndeki manga 50-100 m önde; bounding ~20 m | RH 4266-4305 | Arma formasyon motoru belirler |
| Dağılma | 3-5 m gündüz, 1-3 m gece | RH 4378 | `dispersion` yığılma eşiği 2.5 m, RPG yarıçapı 9-16 m (tasarım) |
| Ateş timi kaması | Normalde 10 m aralık | A21 31-33 | Formasyon motoru |
| Tehlikeli alan | Karşı taraf ≤ 250 m ise gözetleme + öncü manga temizler | RH 4545 | `tehlikeAlani` gözetleme 8 sn (tasarım) |
| Yerel güvenlik | 2-4 kişilik karakollar, tüfek etkili menziline (460 m) kadar ileride | M112 1669 | `yanGuvenlik` 60 m (tasarım) |
| Yakın pusu | Düşman ≤ 50 m = yakın pusu; 50 m = baskın saldırı sınırı | M112 2262 | Pusu kill-zone 55-70 m (tasarım) |
| Yaralı taşıma | 1-2 kişi 50-300 m; > 300 m öne-arkadan; sürükleme ≤ 50 m | CE 287, 357-435 | Araçlı medevac 350 m taşır (tasarım) |
| Tahliye öncelikleri | Urgent ≤ 1 saat, Priority ≤ 4 saat (CE) / 6 saat (M111), Routine 24 saat | CE 1062-1081 | Kodda yok |
| Temas sonrası | 25 dk içinde harekete hazır (görev standardı); rush ≤ 3-5 sn | RH 5448, 5707 | Bounding sıçramaları (tasarım) |
| Silah menzilleri | M249 bipod/nokta 600, alan 800; M240B tripod/alan 1100, bastırma 1800; M2 1500/1830; AK-47 300, AK-74 500, RPG-7 ~200 m | RH 6524-6541, M111 21241-21274 | Rol istasyonu MG 450 m (tasarım) |
| Silah yükü | M4 210 mermi, M67 24 bomba (kişi başı 2), duman: HC 6 / kırmızı 2 / sarı 4 | RH 1352-1370 | Cephane paslama eşikleri (tasarım) |
| 1/3-2/3 kuralı | Lider planlama süresinin 1/3'ünü kullanır | RH 958-960 | Kodda yok |
| Dört işaret | Aç / kes-kaydır / saldır / çekil | M112 2371 | Destek ateşi kaydırması |

## 2. Kitapta SAYI YOK (kodda değerler TASARIM tahminidir)
- Rally point bekleme süresi (kitap "OPORD'da belirt" der): kodda 300 sn.
- Destek noktası (SBF) objektife mesafesi ve açısı: kodda 160-300 m, eksenden ±35..105°.
- Kanat noktası mesafesi/açısı: kodda 110 m, ±75°.
- Saldırı hattı / assault position: kitapta yalnızca örnek emirde "objektife ~50 m kala çukur"; kodda ORP sonrası doğrudan saldırı.
- Pusu kill zone boyutu, güvenlik elemanı mesafesi: kodda 35 m / 22 m.
- **Duman**: genişlik, derinlik, süre, el bombası adedi, rüzgâr = YOK (yalnızca nitel). Düşman 82 mm havan dumanı 20-25 yd genişlik (M111 21414). `sisEkonomisi` 10°/22 m/75 sn = tasarım.
- Temas kesme mesafesi (RH'de yok; M112'de "saat yönü + 200 m"), geri çekilme süreleri: kodda 40 m sıçramalar, 150 sn bekleme.
- Ammo durum eşiği yüzdesi (LACE yeşil/sarı/kırmızı): kodda `mermiDisiplin` 2.0 / 0.8 şarjör.
- "Platinum 10 dakika", TCCC evreleri (kitapta yok; yalnızca "tactical combat casualty care" ve DA Form 7656).
- Moral/panik/teslimiyet eşikleri.

## 3. Kodda kitaba çekilebilecek (öneri; test etmedim)
1. Bounding sıçrama uzunluğu ≤ ⅔ gözetleyen silah etkili menzili (tüfek 460 m → ~300 m; MG 600+ → ~400+ m).
2. Tehlikeli alan karşı tarafı ≤ 250 m ise "overwatch + öncü manga" kuralı.
3. Saldırı pozisyonu: objektife ~50 m kala örtülü nokta (örnek emirde var).
4. Dağılma: gündüz 3-5 m, gece 1-3 m aralık.
5. Yaralı tahliyesi: > 300 m taşıma için dört kişilik sedye ekibi (CE).

## 4. RUS DOKTRINI — ATP 7-100.1 "Russian Tactics" (v8.143)
Kaynak dosya: ATP 7-100.1 (tabur / tugay duzeyinde; manga / takim sayisi yok). Satir numaralari alt ajan raporundandir; ben su maddeleri elle dogruladim: dismount line (5486-5496), ast inisiyatifi (5554-5557), ATGM %70 / %30 (4062-4063), hava emniyet mesafeleri (4466-4470), bolum / takim bosluklari (5134), sehir muharebesinde tank / BMP (5993-6003).
Telif / kisitli metin kopyalanmadi; yalniz davranis ozetleri ve sayilar.

| Konu | Kitapta | Satir | Kodda |
|---|---|---|---|
| Inis hatti (dismount line) | Dusmana en yakin SON ORTULU ve GIZLI mevzi; mesafe sayisi YOK; yuksek hassasiyetli silah tehdidinde daha uzakta | 5486-5496 | RUS `tasimaInisM` 300 m (TASARIM), `tasimaOrpEk` false (NATO: >= 500 m ve ORP + 150) |
| Inis sonrasi arac | "Bronegruppa": piyadeyi ates destegiyle izler ya da zirhli manevra yedegi | 1579-1583, 4863-4868, 5993-6003 | `aracDestekKal` true: arac inis noktasinda kalir, COMBAT |
| Ast inisiyatifi | Merkezilestirilmis degil; "decentralized execution", ast firsat degerlendirir | 5554-5557 | Inisiyatif KISILMADI (onceki "RUS merkezi" varsayimim kitapla ortusmuyor; NATO ile ayni) |
| Marstan taarruz | Hiz kritik; sayi yok | 5621, 6438 | `kesifCarpan` 0.6 (TASARIM) |
| Kesif-ates kompleksi | Hedef tespit - atis < 4 dk ("Strelets"); kara hedefi 12-15 dk | 5056, 2404 | `kesifAtesHizli`: kesif raporu gelince hazirlik atisi |
| Ek topcu | Ana yonde tugaya 2-4 ek topcu taburu | 5458-5460 | `topcuMermiCarpan` 2 (oran TASARIM) |
| Ates hasar normlari | Imha 70-90 %, tahrip 50-60 %, bastirma 30 % etki azalmasi | 3586-3594 | Kodda yok |
| Yuruyen baraj | Ilk hat 2-4 km, sonraki 700-1000 m, son 400-600 m; hat araligi 100-300 m | 3902-3912, 3883-3886 | Kodda yok (topcu takvimi yok) |
| Hava destegi emniyet mesafesi | Serbest roket 1000 m, helikopter topu 500 m, helikopter MG 300 m | 4466-4470 | Kodda yok (CAS yok) |
| Savunma | Tabur 5 x 3 km; hendek hatlari 400-600 / 600-1000 m geride; bolukler arasi ~1000 m, takimlar arasi 300 m; bolugun 3 takimi; en az bir takim yedek; ATGM cepheden 2 km | 5070-5072, 4921, 5134, 5083-5086, 4950-4957 | Kodda yok (squad olcegine uymuyor) |
| Sehir muharebesi | Tanklar sokaga girmez; BMP / BTR iki yan bina guvene alininca arkadan, hedeften ~200 m geride; ustten asagiya temizleme, bodrum son; temizledikten sonra hemen cekilir | 5993-6015 | Oda temizleme ertelenmisti |
| ATGM hedef orani | Saldirida %70 tanklara, %30 digerlerine | 4062-4063 | Kodda yok |
| Eselon | Birinci eselon 1/2-2/3, ikinci 1/2-1/3 (yedek degil, gorevli, firsat somurur) | 5443-5454 | Kodda yok |
| **Kitapta SAYI YOK** | Inis mesafesi, hucum hizi, takim / manga cephesi, ates hazirligi suresi, MLRS dozaji, duman mesafesi, kayip esikleri, kademeli cekilme, savunma yedek orani, arac-piyade senkron mesafesi, gozlem suresi, oda temizleme | — | Tasarim tahmini (NATO ile uyumlu) |
