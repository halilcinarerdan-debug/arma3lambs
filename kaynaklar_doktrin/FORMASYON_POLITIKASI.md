# FORMASYON POLITIKASI (v8.270) - kitap / tasarim ayrimi

Kullanici karari: "tamamen kitaba uygun; kitapta yeterli bilgi yoksa kendi kararini ver ama mantikli". [K] = kitapta var, [T] = TASARIM (kitapta yok / uyarlama).
Kaynaklar: TC 3-21.76 (Ranger, 2017), ATP 3-21.8 (2024 alintilar), MCWP 3-11.2 (Marine Rifle Squad, 2002), MCWP 3-11.1 (2014).
Kod: `fnc_selectFormation` (baglamlar), `fnc_commanderFormation` (secim zamani, tehdit mesafesi), `fnc_formSet` (yazma hakemi).

| Durum | Formasyon | Kaynak |
|---|---|---|
| Temas beklenmiyor (tehdit > 1200 m), acik arazi | COLUMN (manga kolonu) | [K] ATP 3-53 intikalin ana formasyonu; TC 6-7a traveling; esik 1200 m [T] |
| Yol | COLUMN | [K] MCWP 3102b(1)(c) dar ortulu rota |
| Gece / sinirli gorus (temas olasi) | COLUMN | [K] MCWP 3102b(1)(e) gece harekati |
| Temas olasi (250-1200 m), acik | WEDGE | [K] TC 6-7b gozetimli seyir (en cok kullanilan), ATP 3-46; esikler [T] |
| Temas olasi, meskun mahal | STAG COLUMN | [T] sokak kenari; formasyon MCWP 3-11.1 listesinde |
| Temas bekleniyor (< 250 m) | WEDGE | [K] TC 6-13 sicramada ekipler kamada |
| Temas bekleniyor + yeri bilinen dusman onde | VEE | [K] MCWP 3102b(3) |
| Temas sonrasi 120 sn | WEDGE | [T] her yone guvenlik (ATP 3-46 mantigi) |
| Sicrama (bounding), acik | WEDGE (8+ ve kucuk grup; eski LINE kaldirildi) | [K] TC 6-13 / 5616 |
| Sicrama, orman / meskun | VEE / STAG COLUMN | [T] |
| Temasta: kayip >= %40 ya da ustun dusman | WEDGE | [K] esnek, her yone guvenlik (ATP 3-42, 3-46) |
| Temasta: yakin (< 50 m) acik | LINE | [K] MCWP 3102a(3) yeri / gucu bilinen dusman, hucum |
| Temasta: orta mesafe | LINE / ECH (kanat tehdidi) | [K] LINE ayni; ECH = acik kanat (MCWP, ATP 3-42) |
| Temasta: uzak | WEDGE / ECH | [K] |
| Temasta: zirh < 300 m ya da MG | VEE (dagilma) | [T] kitapta zirh / MG'ye gore formasyon hukmu yok; V ates + kanat (MCWP 3102b(3)) |
| Temasta: meskun mahal | WEDGE | [K] temasta kolon YOK (ATP 3-42, MCWP); [T] meskunda kama |
| Hucum, acik | LINE (manga hatti) | [K] ATP 3-54, MCWP 3102a(3); NOT: TC 3-21.76 ekipleri kamada tutar (ekip duzeyi) |
| Hucum, meskun mahal | WEDGE | [T] sokakta hat uygulanamaz |
| Kanat hareketi | COLUMN (eski FILE) | [K] MCWP 3102b(1)(c); TC 6-13 dosya yalniz olaganustu |
| Saklanma / bekleme (hide) | WEDGE (eski LINE) | [K] ATP 3-42 hat yanlardan zayif; ATP 3-46 kama |
| Geri cekilme / peel / kesin nisanci | FILE | [K] TC 6-13 'olaganustu durumda' dosya |
| Garnizon (bina girisi) | FILE | [T] bina giris istifi |
| Savunma (yon biliniyor / bilinmiyor) | VEE / WEDGE | [K] MCWP 3102b(3) V: dusman onde biliniyor; WEDGE belirsiz |

Aralik (kisi arasi 10 m seyir, 20 m gozetimli seyir, ekipler arasi 50 m) kitapta teknige bagli; Arma formasyon motoru aralik belirler (SAYISAL_ESIKLER_KAYNAK_TABLOSU.md) - bu surumde degismedi.
Elmas (diamond): kitapta var, kullanici karariyla (v8.83) kullanilmiyor.
