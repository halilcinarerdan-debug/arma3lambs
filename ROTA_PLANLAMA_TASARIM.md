# Taktik rota planlama (gizli yaklasma) — tasarim taslagi

Amac: dusmana yaklasirken motorun "en kisa yol"u yerine ORTULU hatlari (agac sirasi, cali, duvar, cukur) kullanan ara noktalar secmek.
VBS4 gorselindeki beyaz rota agac siralarini izliyordu; Arma 3'te navmesh yok, yalniz ARA NOKTA verebiliriz.

## Girdi / cikti
`fnc_rotaPlan`: [grup, hedefPos, mod] -> [[nokta1, nokta2, ...], rapor]
- mod: "YAKLAS" (ates-manevra oncesi), "KANAT" (flank), "GERI" (retreat'in ileri versiyonu degil, ayri kalir)
- cikti: en fazla 4-5 ara nokta; her biri tehdit gorusunden gizli / ortulu

## Aday uretimi
1. Ana dogru: grup merkezinden hedefe. Koridor: dogrunun +-40 m (doktrin profili: `rotaGenislik`).
2. Orneklem: koridorda ~12 m aralikli izgara; veya nearestTerrainObjects ["TREE","BUSH","HIDE","WALL","FENCE","ROCK"] kumelerinin yan tarafi
   (agac SIRASI = ard arda >= 3 agac, aralik < 25 m -> hat; hat boyunca noktalar).
3. Cukur / gizli alan: terrainIntersectASL (dusman goz -> aday) ile ortulu mu.

## Puanlama (kucuk = iyi)
- maruziyet: dusman bilinen konumundan (ve diger tehditlerden) aday + yurume hatti ornekleri (5 m) gorulen oran  x 40
- acik mesafe: ortusuz (en yakin ortu > 15 m) segment uzunlugu  x 0.5
- uzunluk: toplam rota / dogru mesafe oraninin asimi x 10
- hedefe yaklasma odulu: her nokta oncekinden >= 15 m hedefe yakin olmali
- bina / duvar icine dusme cezasi (duvar korumasi + navmesh)

## Entegrasyon
- bounding: `_kosanHareket` bugun siper adaylarini yol aciklik orneklemesiyle (acik:[..]) puanliyor -> rota noktalarini ONCELIKLI aday olarak ekle
- komutan ilerleme emri: BOUNDING baslarken rota ara noktalari grup degiskenine (lambs_danger_rota) yazilir; sonraki atilim bu listeden
- pahali: bütce (tick basina max 40 isin), sadece lider/ilk bound icin, 20 sn onbellek; kapatma: lambs_danger_rotaV1 = false

## Log ve olcut
- [ROTA] grup | hedef m | nokta sayisi | maruziyet % (planli) | acik mesafe m | sure ms
- Olcut (`rota_hedgerow`): planli rota maruziyeti < dogru hat maruziyetinin %60'i; rota uzunlugu <= 1.4 x dogru
- rpt_ozet: ROTA bolumu (maruziyet ortalamasi)

## Riskler
- Isin maliyeti (dusman goz yuksekligi + 12 m izgara): bütce ve onbellek zorunlu
- Motor, ara noktalar arasinda yine kendi yolunu secer: noktalari birbirine yakin tut (<= 40 m)
- Mod haritalarinda agac sinifi farklari: nearestTerrainObjects tip adlari ("TREE", "SMALL TREE", "BUSH") test edilecek
