# Arastirma 1: Piyade Tufegi Atisi - Gercek Savas Verisi (Arma 3 AI kalibrasyonu)

**ONEMLI SINIRLAMA:** Ortamda WebFetch tum alanlara (apps.dtic.mil, military.com, gwern, taskandpurpose, historynet...) `EGRESS_BLOCKED` verdi. Orijinal PDF'ler OKUNAMADI. Tum degerler WebSearch ozet metinlerinden alinmistir; bu yuzden GUVEN en fazla "orta"dir ve her deger orijinal PDF'ten dogrulanmalidir. Hicbir sayi uydurulmamistir; bulunamayanlar BULUNAMADI diye isaretlidir.

Format: DEGER | BIRIM / MESAFE | KAYNAK | GUVEN | NOT

## 1) Gercek catisma ates mesafesi dagilimi

| DEGER | BIRIM / MESAFE | KAYNAK | GUVEN | NOT |
|---|---|---|---|---|
| Piyade muharebesinin %70'i | < 100 yd (~91 m), WW2 + Kore | https://archive.org/details/DTIC_AD0000346 (Hitchman, ORO 1952) ; ikincil: https://www.everydaymarksman.co/?p=2275 | orta | Rakam ikincil ozetten; Kore'de 602 gazi roportaji. Birincil metinde dogrulanmali |
| %90'i | < 300 yd (~274 m) | ayni (Hitchman) ; https://www.thefirearmblog.com/blog/2014/07/08/weekly-dtic-hitchman-gustafson-reports | orta | Tufek atesinin neredeyse tamami <= 500 yd |
| Kore'de isabetlerin ortalama mesafesi ~100 yd, hemen hepsi < 300 yd | yd | https://www.cfspress.com/sharpshooters/battle-ranges.html ; https://archive.org/stream/DTIC_AD0000346/DTIC_AD0000346_djvu.txt | orta | ORO verisi |
| M1 tufek isabeti "tatmin edici" sadece <= 100 yd, 300 yd'de "dusuk mertebe" | yd | https://archive.org/details/DTIC_AD0000346 | orta | Uzman nisanci icin bile |
| Irak: ortalama angajman < 100 m, cogu 20-30 m; catismalarin cogu < 300 m | m | https://www.strategypage.com/htmw/htinf/articles/20030514.aspx ; https://www.military.com/defensetech/2010/03/01/taking-back-the-infantry-half-kilometer | dusuk-orta | Anekdotik/subay ifadesi, olcum degil |
| Afganistan: angajmanlarin ~%50'si > 300 m | m | Ehrhart 2009 monografisi: https://ntrl.ntis.gov/NTRL/dashboard/searchResults/titleDetail/ADA512732.xhtml ; http://council.smallwarsjournal.com/archive/index.php/t-9942.html | dusuk-orta | Gazi anketi/hikayeleri, sistematik olcum degil |
| "Afganistan'da catismalarin %52'si 500 m'de baslar" | m | https://army.ca/forums/threads/the-500m-war.96668 (SSG Wall alintisi) | dusuk | Forum alintisi |
| "Savasin yarisindan fazlasi > 500 m" | m | https://www.Strategypage.Com/htmw/htinf/articles/20030514.aspx (arama ozeti) | dusuk | Ehrhart ile celisiyor (300 vs 500); abartili olabilir |
| %80 / %95 yuzdelikleri | m | BULUNAMADI (birincil kaynakta tablo okunamadi) | - | Asagida kaynaksiz tahmin var |

**S.L.A. Marshall tartismasi:** Marshall (Men Against Fire, 1947) "WW2'de askerlerin sadece ~%15'i (en saldirgan birliklerde nadiren >%25) silah ateslemis" dedi. Spiller (1988) sistematik veri toplama iddiasinin dayanaksiz oldugunu savundu. Sonuc: Marshall'in oranini AI "ates etme olasiligi" icin KULLANMA.
Kaynak: https://historynewsnetwork.org/article/1356 ; https://www.hnn.us/article/1356 ; https://www.Gwern.net/doc/history/s-l-a-marshall/1988-spiller.pdf ; https://www.military-history.us/2011/09/s-l-a-marshall-men-against-fire-and-whether-men-are-conditioned-to-kill-in-combat-or-not/ | GUVEN: orta (tartisma gercek; rakamlar tartismali).

## 2) Isabet olasiligi / mermi-kayip orani

| DEGER | BIRIM / MESAFE | KAYNAK | GUVEN | NOT |
|---|---|---|---|---|
| ~250.000 mermi / oldurulen isyanci | Irak+Afganistan | https://jonathanturley.org/2011/01/10/gao-u-s-has-fired-250000-rounds-for-every-insurgent-killed/ | dusuk | GAO'ya atfedilen ama hesap yontemi tartismali (toplam harcama / tahmini olu; egitim dahil). AI icin dogrudan kullanilamaz |
| ~50.000 mermi / dogrulanmis dusman kaybi | Vietnam | https://thegunzone.com/?p=1176860 | dusuk | Ikincil blog; tum mermi turleri dahil |
| ~25.000 mermi / oldurulen | WW2 | https://thegunzone.com/?p=1176860 | dusuk | Ayni; eski ORO tahmini, birincil dogrulanmadi |
| M16A1 yari-otomatik: %50 isabet olasiligi hareketli insan hedefte 200 m, sabit hedefte 250 m | m | https://generalstaff.org/BBOW/Weapons/Hist_PHitsPKills.htm | dusuk-orta | Arama ozeti; hareketin ~%20 menzil kaybina denk geldigini gosterir |
| Akut fiziksel stres altinda isabet olasiligi degismedi (%92, yakin menzil atis poligonu), ama dagilim (ozellikle dikey) arti | poligon | https://pmc.ncbi.nlm.nih.gov/articles/PMC9200070 (arama ozeti) | orta | Savas stresi degil, laboratuvar/egzersiz stresi; tek calisma |
| Savas stresi altinda ates basina isabet (menzile gore) | - | BULUNAMADI | - | Hitchman: isabet 100 yd'den sonra keskin duser (nitel) |
| Egitim vs savas isabet orani | - | BULUNAMADI (sayisal) | - | Nitel: savas dagilimi poligondan cok kotu |

## 3) Optik vs acik nisangah

| DEGER | BIRIM / MESAFE | KAYNAK | GUVEN | NOT |
|---|---|---|---|---|
| 100 m: tum nisangahlarda ~%90+ isabet | m | https://apps.dtic.mil/sti/pdfs/AD1064518.pdf (ARL, "Effects of Sight Type, Zero Methodology, and Target Distance...") | orta | Poligon, birincil PDF okunamadi, ozetten |
| 200 m: acik nisangah ~%71; buyutmeli optik > %90 | m | AD1064518 (ayni) | orta | " |
| 300 m: acik nisangah ~%55; buyutmeli optik ~%87 | m | AD1064518 (ayni) | orta | 400 m'ye kadar veri var ama rakam okunamadi: 400 m BULUNAMADI |
| CCO/reflex icin 200-300 m'de ayri rakam | m | BULUNAMADI (calismada var ama ozetten cikmadi) | - | Arma icin: CCO ~ acik ile ACOG arasi varsayilabilir (TAHMIN) |
| Ilk-atis isabeti: M16A2 acik nisangah %45 vs SAM-R (ACOG) %88 | 137-432 m | https://www.globalsecurity.org/military/systems/ground/samr.htm ; https://www.defenseindustrydaily.com/?p=1021 | orta | USMC hedefleri; ACOG + agir namlu + bipod dahil (SAM-R) karisik etki |
| Mattis: ACOG "M1 Garand'dan beri piyade ölümcüllüğünde en buyuk gelisme" | - | https://www.defenseindustrydaily.com/?p=1021 | orta | Nitel |

## 4) M4 / M27 / M249 vs AK-74 / AKM / RPK dagilim

| DEGER | BIRIM / MESAFE | KAYNAK | GUVEN | NOT |
|---|---|---|---|---|
| M855A1 (1:7 namlu): 1.6 MOA 100 yd ve 300 yd | MOA | https://www.thefirearmblog.com/blog/2012/09/05/m855a1-enhanced-performance-round-accuracy | orta | Match-benzeri test namlusu; hizmet silahi bundan kotudur |
| Ordu sartnamesi M16/M4 M855: 3 MOA @ 300 yd | MOA | https://shadowspear.com/threads/accuracy.1864 | dusuk | Forum; "raf tufegi ~2 MOA en iyi ihtimalle" |
| Hizmet tufegiyle "uzman" icin ~6 MOA yeterli | MOA | https://www.usar.army.mil/Portals/98/Documents/Marksmanship/ARM_FY20-4.pdf (arama ozeti) | dusuk | Yeterlilik esigi, silah kapasitesi degil |
| M27 IAR M16A4'ten ~2x isabetli olabilir; M249 acik-surgulu (open bolt) = daha az isabetli | - | https://www.military.com/dodbuzz/2011/06/14/marines-ditch-saw-for-new-auto-rifle ; https://www.globalsecurity.org/military/systems/ground/m27-iar.htm | dusuk | Nitel, sayisal MOA yok |
| AK-74: AK-47'ye gore tek atista ~%50, otomatikte ~2x daha isabetli; 100 yd 2-3 inc grup (tek test, ~2-3 MOA) | yd | https://www.gun-tests.com/uncategorized/interarms-bulgarian-style-ak-74-5-45x39mm/ ; https://en.wikipedia.org/wiki/AK-74 | dusuk | Tek sivil test; Wikipedia ikincil |
| M16 skorlari AKM'den %13 yuksek (145 asker) | skor | https://www.usar.army.mil/Portals/98/Documents/Marksmanship/ARM_FY20-4.pdf | dusuk-orta | Silah farki + nisangah farki karisik |
| AKM / AK-74 / RPK icin 300 m MOA | MOA | BULUNAMADI (guvenilir kaynak) | - | Asagida tahmin |

## 5) Baski (suppression)

| DEGER | BIRIM / MESAFE | KAYNAK | GUVEN | NOT |
|---|---|---|---|---|
| Simule .50 cal ates altinda uretken (izleme/nisan) sure ortalama ~%57 dustu | CDEC deneyi | https://apps.dtic.mil/sti/pdfs/AD0519874.pdf ve ARI TR-79-A19: https://apps.dtic.mil/sti/pdfs/ADA071116.pdf (arama ozeti) | orta | Saha deneyi; dogrudan "isabet" degil, "uretken zaman" |
| Baski operasyonel tanimi: 2 mermi, hedefin 2 m icinden, 0.04 dk (~2.4 sn) icinde | m / sn | https://apps.dtic.mil/sti/pdfs/AD0519874.pdf | orta | Esik tanimi |
| Baski, yanal ıskalama mesafesi arttikca dogrusal azalir; ates hacmi ve gurultu ile dogrusal artar; isitsel+gorsel (isabet izi) > yalniz isitsel | - | AD0519874 | orta | Nitel dogrusal iliskiler |
| Baski altindaki askerin isabet dususu (yuzde olarak) | - | BULUNAMADI | - | |
| Hedef boyutu / hareket etkisi (sayisal) | - | Yalniz: hareketli hedef ~%20 menzil kaybi (bkz. Bolum 2, dusuk guven) | dusuk | |

## TAHMIN (kaynaksiz) - Arma 3 icin baslangic degerleri, dogrulanmamistir

- Angajman mesafesi dagilimi (orman/sehir): %50 < 50-100 m, %80 < ~200-250 m, %95 < ~300-350 m. Acik arazi (Afganistan-benzeri): medyan ~200-300 m, %80 < ~500 m. (Hitchman: %90 < 300 yd ve Ehrhart: ~%50 > 300 m arasinda interpolasyon.)
- Gercek savas isabeti: poligon degerinin ~0.3-0.5x'i (stres, hareket, kismi hedef). Dayanak: Hitchman nitel + hareket ~%20 menzil kaybi.
- Dagilim (hizmet silahi, tipik asker, MOA): M4 optikli ~3-4, M4 acik ~4-5; M27 ~2.5-3; M249 ~5-6 (kisa patlak) ; AKM ~5-6; AK-74 ~4-5; RPK ~4-5. Hepsi kaynaksiz, yalniz oransal rehber.
- Baski: yakin gecen mermi sonrasi dagilim carpani 1.5-2.5x, nisan suresi uzamasi ~%50 (CDEC %57 dususu baz alinarak).

## En onemli 8 bulgu

1. Hitchman/ORO 1952: muharebenin %70'i < 100 yd, %90'i < 300 yd; 100 yd sonrasi isabet keskin duser (orta guven).
2. Afganistan angajmanlarinin ~%50'si > 300 m (Ehrhart; dusuk-orta guven); Irak < 100 m, cogu 20-30 m.
3. ARL: acik nisangah 200 m ~%71, 300 m ~%55; buyutmeli optik 200 m > %90, 300 m ~%87; 100 m'de fark yok (~%90+).
4. USMC: ilk atis isabeti acik nisangah %45 vs ACOG %88 (137-432 m).
5. M16A1: %50 isabet 250 m sabit / 200 m hareketli hedef (dusuk-orta).
6. Mermi/kayip: WW2 ~25.000, Vietnam ~50.000, Irak-Afg ~250.000 (hepsi dusuk guven, hesap tartismali).
7. Baski: simule .50 cal altinda uretken sure ~%57 dustu; 2 mermi/2 m/~2.4 sn baski esigi (orta).
8. Marshall %15 orani Spiller tarafindan itibarsizlastirildi; AI'da kullanma. 300 m'de M855A1 ~1.6 MOA (laboratuvar), hizmet esigi ~3 MOA; AK/RPK MOA BULUNAMADI.

Erisilemeyen/atlanan: apps.dtic.mil PDF'leri, military.com, gwern.net, taskandpurpose.com, historynet.com, americanheritage.com (hepsi egress engelli; yalniz arama ozetleri kullanildi).
