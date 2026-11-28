# USMC (BLUFOR) vs IS / DAESH (OPFOR + INDEPENDENT) preset'i (v8.844)

Dosya: `CBA_LAMBS_Danger_USMC_ISIS_v8.844.txt` (deponun kökünde). Taban: `CBA_LAMBS_Danger_DOKTRIN_KORKU_v8.844.txt` (doktrin + korku, teslimiyet kapalı); üstüne **92 satır** değişiklik, kalan 620 satır aynı. Ana dosyana (`CBA_LAMBS_Danger_v8.844.txt`) dokunulmadı.
Taraflar: **USMC = BLUFOR (`West`)**, **IS = OPFOR (`East`) ve INDEPENDENT (`Ind`)** (ikisine aynı değerler; doktrin zaten `ABD` / `DUZENSIZ`).

## Güven uyarısı (önemli)
Depodaki araştırma (`kaynaklar_doktrin/arastirma_gerceklik/`) **WebSearch özetlerine** dayanıyor, birincil kaynak çoğu yerde okunamadı (güven orta / düşük). **Mutlak sayı kaynakta yok**; kaynaktan yalnızca **oranlar ve yönler** geliyor (ACOG ≈ 2× isabet, IS kayıpta erken kopar, USMC kopmaz...). Mutlak değerler oyun kalibrasyonu (`[T]`). Etiketler: `[K]` depodaki kaynakta var, `[G]` genel askeri bilgi (sayfa doğrulanmadı), `[T]` tasarım tahmini.

## Değişenler
| Grup | Ayar | USMC (West) | IS (East / Ind) | Dayanak |
|---|---|---|---|---|
| **Nişan** | `skillIsabetMin / Max` | 0.32 / 0.50 | 0.24 / 0.42 | `[K]` USMC ilk atış 137-432 m: açık nişangâh %45, ACOG %88 (dosya 1, orta) → optikli : optiksiz ≈ 2 : 1 |
| | `skillOptiksizCarpan` | 0.65 | 0.65 | `[K]` oran 0.51; AI'da optik etkisi doğrusal değil, ACE düşük beceride kaybı yumuşatıyor → 0.65 `[T]`. Optiği olmayan herkese uygulanır: ACOG'lu USMC ≈ 0.41, AK'li IS ≈ 0.21 (oran ≈ 2) |
| | `skillTavanIsabet` | 0.55 | 0.45 | `[T]` insan sınırı |
| | `skillTitremeMin / Max` (**yüksek = az sallanma**) | 0.50 / 0.70 | 0.35 / 0.55 | `[K]` IS: toplu eğitim var ama atış tekniği zayıf, kalça ateşi / kontrolsüz seri (dosya 3, düşük) |
| | `skillHizMin / Max`, `skillTavanHiz` | 0.70-0.90, tavan 0.92 | 0.55-0.80, tavan 0.82 | `[T]` |
| | `skillFarkMin / Max` (algı) | 0.70 / 0.90 | 0.65 / 0.88 | `[T]` IS: kentsel yerel bilgi, deneyimli savaşçılar (fark az) |
| | `skillAcemiOran / Carpan` | 0.05 / 0.80 | 0.30 / 0.70 | `[K]` IS kalitesi birimden birime değişken, eski Baas subayları + acemiler (dosya 3, düşük) |
| | `dogrulukMaks` | 0.15 | 0.10 | `[K]` IS yoğun ateşle bastırır, nişanlı seri değil |
| **Baskı / moral** | `baskiEtki` | 0.50 | 0.80 | `[K]` .50 cal altında nişan süresi ≈ %57 düşer (düşük); USMC ateş disiplini yüksek, IS ateş disiplini düşük `[T]` |
| | `ozguven` | 0.85 | 0.90 | `[T]` IS ideolojik direniş; ikisi de donmaz (`panicChance` 0.01 aynı) |
| | `erkenKayipHiz / Oran` (erken geri çekilme eşiği) | 4 / 0.35 | 3 / 0.25 | `[K]` Fallujah II'de ABD kuvveti > %10 kayıpla kırılmadı (orta); IS'nin ilk %20-30 kayıpta temas kesmesi **kaynaksız tahmin** (dosya 2) |
| **Gerçek dışı hız** | `animHiz`, `cqbAnimEk`, `donusHizi`, `botAdimCarpan` | 0 / 0 / 1 / 1 | aynı | `[T]` doktrin tablosu (`DOKTRIN_VARSAYILAN_TABLOSU.md`): hız artışı zorluk düğmesi, doktrin değil |
| | `dusunHizi`, `dusunHiziCqb`, `dusunHiziOnemli` | 1 | 1 | `[T]` aynı tablo. **Karar gecikmesini beğenmezsen 1.25-1.5'e çıkar** (senin dosyanda 3) |
| **Silahlar** | `rpgMaxM` (RPG-7 / AT4) | 300 (AT4 etkili ≈ 300 m `[G]`) | 250 | `[K]` RPG-7 hareketli hedef 100 m %96, 200 m %51, 300 m %22, 400 m %9 (dosya 3, orta) |
| | `uglMinM / uglMaxM` | 25 / 350 | aynı | `[G]` M203: emniyet açılma ≈ 14-28 m, alan hedefi ≈ 350 m |
| | `elBombasiMaxMesafe`, `bombaMinM`, `bombaDostM` | 35 / 15 / 20 | aynı | `[G]` atış ≈ 35-40 m, yaralanma yarıçapı ≈ 15 m + pay (doktrin tablosu) |
| | `bastirmaYogunluk` | 1 | 1 | `[T]` senin 3.2 değerin mermi ekonomisini bozuyordu, taraf ayrımı yok |
| **IS'e özgü** | `canliBomba` + `canliBombaWest/East/Ind` | **kapalı** | açık | `[K]` Musul: damla damla SVBIED + canlı bomba; Irak'ta ~7:1 çatışma (dosya 2/3, orta) |
| | `eypKur` + **yeni** `eypKurWest/East/Ind` | **kapalı** | açık | `[K]` Fallujah II 653 EYP / tuzak (düşük-orta). **v8.844 kodu:** `eypKur` tüm tarafları kapsıyordu, USMC botu da tuzak kuruyordu; taraf anahtarı eklendi |
| | `eypKomutlu` | açık | açık | `[G]` komutla patlayan EYP pususu |
| **Teslim** | `teslim*` | kapalı | kapalı | `[G]` IS ölümüne savaşır; USMC teslim olmaz (isteğin) |
| **Komuta** | `doktrinWest/East/Ind`, `komutanKisilik*` | `ABD`, `DENGELI` | `DUZENSIZ`, `SALDIRGAN` | `[K]` MCWP 3-11.1 / 3-11.2 (USMC); Musul: mobil savunma, karşı saldırı, arkaya sızma, yakın / bina savaşı tercihi (CTC, orta) |

Değişmeyenler (kaynak ya da ihtiyaç yok): `siper*` taraf değerleri, `hizliFark*` (0.5 sn), `korku*`, `durusDisiplin*`, `isabetSeviye / isabetYardim = 0` (aim-assist yok), `isabetUzakSapma / CQB yardımı`.

## Ek kaynaklar (bu oturumda WebSearch; özet düzeyinde, tam metin okunmadı)
- **IS savunması (Musul):** az sayıda piyade + savunma EYP'leri, tüneller, önceden ölçülmüş hedefli havan; mobil savunma, karşı saldırı, arkaya sızma; bütün şehri çevre savunmasıyla tutamaz; engeller yalnız ateşle (keskin nişancı, havan, tanksavar) korunursa işe yarar; liderler yetenekli ama profesyonel ordu değil; bomba taşıyan ticari dron (günde 70'e varan saldırı) + araç bombası eşleşmesi: [CTC Sentinel, Knights & Mello](https://ctc.westpoint.edu/defeat-by-annihilation-mobility-and-attrition-in-the-islamic-states-defense-of-mosul/), [MWI rehberi](https://mwi.westpoint.edu/guide-islamic-states-way-urban-warfare/). → `komutanKisilik* = SALDIRGAN`, `eypKur*`, `canliBomba*` açık; USMC'de kapalı.
- **M203A1 etkili menzil 350 m** (ikincil kaynak): [TDG Weapons Guide](https://www.mca-marines.org/wp-content/uploads/TDG-Weapons-Guide.pdf) → `uglMaxM = 350`. AT4 / SMAW menzili doğrulanamadı (SMAW HEAT 300 m'ye rastlandı, hangi sistem olduğu belirsiz) → `rpgMaxMWest = 300` `[G]`.
- **Tüfek ekibi ateşi:** eğitimde atılan mermilerin yaklaşık 1 / 8'i hedefin kritik bölgesine isabet etmiş (**eğitim, muharebe değil**): [army.mil](https://www.army.mil/article/282397/rate_of_fire_against_men_a_quantitative_assessment_of_fire_team_lethality). Yakınlaştıkça isabetin beklenenden az arttığı (Cranfield, 83 veri noktası): [core.ac.uk](https://core.ac.uk/download/342671927.pdf). Afganistan'da angajmanlar sıklıkla > 300 m (Ehrhart 2009).
- **Marine tüfek manga yapısı** hâlâ değişiyor (13 kişi, 3 ateş ekibi; 4'lü takım düzenlemesi 2025 haberi): [Marine Corps](https://www.marines.mil/Portals/1/Publications/MCWP%203-11.2%20Marine%20Rifle%20Squad.pdf) — grup büyüklüğünü preset değil Zeus / senaryo belirler.

## Gerçekçiliği bozan, bilerek bırakılanlar
- `isabetCqbYardim` (0.45) ve `isabetYakinYardim` (0.15): 25 m altında mermi yönünü düzelten **motor telafisi** (AI yakında neredeyse hiç isabet ettiremiyordu, RPT 5057c18e). Gerçek veri yakın mesafede isabetin beklenenden az arttığını söylüyor, yani bu hâliyle CQB gerçekten biraz **kolay**. Karne `< 50 m` bandı %10-20'de kalıyorsa (en az 10 isabetle) 0.30'a indirebilirsin.
- Dron / havan ayarları taraf bazlı değil: IS'in bomba atan droni ve önceden ölçülmüş havanı gerçek, ama USMC botları da aynı sistemleri kullanabilir. Bu preset onlara dokunmuyor.

## Bilinen sınırlar
- **IS acemi oranı / optik oranı** ve **%20-30'da kopma** kaynaksız; ilk testte kayıp oranına bak (`rpt_ozet.py --kayip`), IS çok erken ya da hiç kopmuyorsa `erkenKayipOranEast` değiştir.
- IS'in iyi ya da kötü olduğu **fraksiyona göre** değişir (Zeus'ta IS sınıfı her zaman optiksiz mi?). Mod IS'inde ACOG / dürbünlü silah varsa `skillOptiksizCarpan` onlara uygulanmaz.
- `dusunHizi = 1` botları senin dosyandakinden yavaş yapar; CPU'yu da rahatlatır.
- ACE hasar eşikleri senin ayarındır, preset'e dokunmaz (araştırma notları `4_arma_ace_kalibrasyon.md`).
- Hiçbiri oyunda denenmedi.

## Test
1. Boot `v8.844`, karne `SURUM` GEÇTİ.
2. Açık arazi 200-300 m, ~20 IS (AK + RPG) vs ~28 USMC (ACOG, M203, MG): `rpt_ozet.py --kayip`; kaynaksız tahmin 5:1 - 15:1 (IS ölü : USMC ölü). IS açık arazide yenilir ama pusuda (< 100 m, ilk ateş IS'in) 1:1 - 2:1 olabilir.
3. IS geri çekilirken `[EYP-...]` tuzak, ağır kayıpta `[CANLI-BOMBA]` görülmeli; USMC tarafında **hiç** tuzak / canlı bomba olmamalı.
4. Kısa mesafe bina çatışması: IS RPG 100 m altında ağırlıkta, USMC 200 m üstünde optikle öne geçmeli.
