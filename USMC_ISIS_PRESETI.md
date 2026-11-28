# USMC (BLUFOR) vs IS / DAESH (OPFOR + INDEPENDENT) preset'i (v8.844)

Dosya: `CBA_LAMBS_Danger_USMC_ISIS_v8.846.txt` (deponun kökünde). Taban: `CBA_LAMBS_Danger_DOKTRIN_KORKU_v8.846.txt` (doktrin + korku, teslimiyet kapalı); üstüne **135 satır** değişiklik. Ana dosyana (`CBA_LAMBS_Danger_v8.846.txt`) dokunulmadı.
Taraf ayarları artık **doktrine** göre uygulanır (aşağıda); `West` sütunu = düzenli ordu (ABD), `East / Ind` sütunu = IS.

## Güven uyarısı (önemli)
Depodaki araştırma (`kaynaklar_doktrin/arastirma_gerceklik/`) **WebSearch özetlerine** dayanıyor, birincil kaynak çoğu yerde okunamadı (güven orta / düşük). **Mutlak sayı kaynakta yok**; kaynaktan yalnızca **oranlar ve yönler** geliyor (ACOG ≈ 2× isabet, IS kayıpta erken kopar, USMC kopmaz...). Mutlak değerler oyun kalibrasyonu (`[T]`). Etiketler: `[K]` depodaki kaynakta var, `[G]` genel askeri bilgi (sayfa doğrulanmadı), `[T]` tasarım tahmini.

## Mod: doktrin bazlı (v8.845, `ayarDoktrinBazli` = açık)
RPT c30f0e7f'de ABD Ranger BLUFOR'da, düzensiz fraksiyon OPFOR'daydı; taraf bazlı ayarlar fraksiyon yerleşimine bağlıydı. Artık `West` ayarları = **düzenli doktrin** (ABD / USMC / RUS...), `East` (+`Ind`) ayarları = **DUZENSIZ doktrin**, **taraf fark etmez**. Doktrin fraksiyondan otomatik (`doktrin* = OTO`; v8.845'te `rhsusaf_ranger` → ABD, `ff_mfas` → DUZENSIZ eklendi). Tanımsız fraksiyonu `doktrinWest/East/Ind = DUZENSIZ` ile işaretle. Beceri **birim oluşurken** uygulanır: ayarı değiştirdikten sonra misyonu yeniden başlat.

## Değişenler (ABD = `West` sütunu, IS = `East / Ind` sütunu)
| Grup | Ayar | ABD | IS | Dayanak |
|---|---|---|---|---|
| **Nişan** | `skillIsabetMin / Max` | 0.34 / 0.52 | 0.14 / 0.30 | `[K]` USMC ilk atış 137-432 m: açık nişangâh %45, ACOG %88 (dosya 1, orta) ≈ 2 : 1; IS'te eğitim farkı eklendi `[T]` |
| | `skillOptiksizCarpan` (herkese) | 0.65 | 0.65 | `[K]` oran 0.51, ACE yumuşatması → 0.65. Etkin: ACOG'lu ABD ≈ 0.43, AK'li IS ≈ 0.14 (**≈ 3 : 1**) |
| | `skillTavanIsabet` | 0.55 | 0.35 | `[T]` |
| | `skillTitremeMin / Max` (**yüksek = az sallanma**) | 0.55 / 0.75 | 0.25 / 0.45 | `[K]` IS atış tekniği zayıf, kalça ateşi / kontrolsüz seri (dosya 3, düşük) |
| | `skillHizMin / Max` (nişan hızı) | 0.75 / 0.92 | 0.45 / 0.70 | `[T]` |
| | `skillFarkMin / Max` (algı) | 0.75 / 0.92 | 0.55 / 0.80 | `[T]` |
| | `skillAcemiOran / Carpan` | 0 / 1 | **0.45 / 0.60** | `[K]` IS kalitesi birimden birime değişken, acemiler (dosya 3, düşük) |
| | `dogrulukMaks` (seri atışta nişan artışı) | 0.15 | 0.06 | `[K]` IS kontrolsüz seri |
| **Tepki / baskı** | `hizliFarkS` (görme süresi, sn) | 0.4 | 0.9 | `[T]` |
| | `baskiEtki` | 0.40 | 0.90 | `[K]` .50 cal altında nişan süresi ≈ %57 düşer (düşük); IS ateş disiplini düşük |
| | `ozguven` | 0.85 | **0.65** | `[T]` özgüven baskı cezasını azaltır: IS baskıda daha çok bozulur |
| **Taktik disiplin** | `durusDisiplinSn` (durgun kalınca çömelme, sn) | 0.8 | **3** | `[T]` IS geç alçalır, ayakta yakalanır |
| | `siperAyniAnda` (aynı anda koşan) | **2** (biri koşar, diğeri örter) | **5** (hep birlikte) | `[K~]` MCWP 3-11.2 ateş ve manevra; IS karşılıklı örtme yok |
| | `siperDostAralik` (siper başına en az dost aralığı, m) | 5.5 | **3** | `[T]` IS yığılır |
| | `siperGorunurCeza`, `siperSafCeza`, `siperKarsilikBonus`, `siperMermiOncelik`, `siperYanAgirlik` | 10 / 20 / 9 / 9 / 3 | 4 / 8 / 4 / 4 / 1 | `[T]` IS görünen / mermi geçiren / karşılık veremeyen siperi kabul eder |
| | `siperYaricap`, `siperOnTaramaM`, `siperGercekCezaM`, `siperYakinM` | 25 / 18 / 70 / 25 | 14 / 10 / 35 / 15 | `[T]` IS daha kısa mesafede siper arar, daha az tarar |
| | `botAdimCarpan` (ayak sesi) | 0.9 | 1.3 | `[T]` |
| **Eğitimsizlik (YENİ)** | `egitimsizlik` (0.7) | – | **ateş altında sabitlenme** | aşağıya bak |
| **Kayıp eşiği** | `erkenKayipHiz / Oran` | 4 / 0.35 | 2 / 0.22 | `[K]` Fallujah II'de ABD > %10 kayıpla kırılmadı (orta); IS %20-30'da kopar **kaynaksız tahmin** |
| **Gerçek dışı hız** | `animHiz`, `cqbAnimEk` | 0 / 0 | aynı | `[T]` doktrin tablosu: hız artışı zorluk düğmesi |
| **Dönüş / düşünme** | `donusHizi` (dönüş animasyonu) | 1.8 | 1.4 | `[T]` v8.846: Arma dönüş animasyonu yavaş, **1 atış yönüne geç bakar** (RPT 236eee40: 'atış yönüne bakamıyor'); eski değerlerin (2.4 / 1.4) altında ama 1'in üstünde |
| | `dusunHizi`, `dusunHiziCqb`, `dusunHiziOnemli` | 2 | 2 | `[T]` v8.846: 1 tepkiyi yavaşlattı ('karşılık veremiyorlar'); doktrin tablosu 1, senin dosyan 3 |
| **Atış yönü (YENİ)** | `atisYonu` | açık | açık | v8.846: mermi geçişi / isabette atıcının yaklaşık konumu grubun yön bilgisine yazılır, asker yöne döner, pusu tepkisi karşılık bastırma ateşi verir |
| **Silahlar** | `rpgMaxM` | 300 (AT4 `[G]`) | 250 | `[K]` RPG-7 hareketli hedef 100 m %96, 200 m %51, 300 m %22, 400 m %9 (dosya 3) |
| | `uglMinM / uglMaxM`, `elBombasiMaxMesafe`, `bombaMinM`, `bombaDostM`, `bastirmaYogunluk` | 25 / 350, 35, 15, 20, 1 | aynı | `[G]` M203A1 350 m ([TDG](https://www.mca-marines.org/wp-content/uploads/TDG-Weapons-Guide.pdf)); el bombası yaralanma yarıçapı ≈ 15 m |
| **IS'e özgü** | `canliBomba*`, `eypKur*`, `eypKomutlu` | **kapalı** | açık | `[K]` Musul: SVBIED + canlı bomba; Fallujah II 653 EYP |
| **Teslim** | `teslim*` | kapalı | kapalı | `[G]` |
| **Komuta** | `doktrin* = OTO`, `komutanKisilik` | `DENGELI` | `SALDIRGAN` | `[K]` MCWP 3-11.1/3-11.2; Musul'da mobil savunma, karşı saldırı |

## "IS eğitimsizliğini hissettirsin" (YENİ, v8.845)
1. **Nişan ve tepki:** yukarıdaki beceri farkı (etkin isabet ≈ 3 : 1, nişan hızı, görme süresi ≈ 2 : 1).
2. **Ateş altında sabitlenme (`egitimsizlik` = 0.7):** yakın mermi korkusu ≥ 0.35 olunca IS askeri (DUZENSIZ doktrin; **acemi** işaretliyse tam, diğerlerinde 0.6, eğitimli doktrinde acemiye 0.3) olasılıkla **yere yatar ve 3-6 sn başını kaldırmaz** (hedef alma / karşılık ateş kapalı), askerde 15 sn'de bir. Olasılık = 0.7 × faktör × (0.5 + korku). ABD'nin ateşi IS'in karşılığını bastırır → manevra mesafesi kapanır.
3. **Kayba yansıması:** görünen siper kabulü, birlikte koşma (aynı anda 5), yığılma (3 m), geç alçalma (3 sn), kısa siper yarıçapı → açıkta daha çok kalır, vurulur; kayıpta erken kopar (%22), koşarak çekilirken bir kısmı vurulur.
4. **Ölçü:** karne `GERCEKCILIK: EGITIMSIZLIK (DUZENSIZ)` (sabitlenme olayı + DUZENSIZ : eğitimli kayıp oranı; kaynaksız tahmin açık arazide 5:1 - 15:1) ve `rpt_ozet.py --kayip`. **Tek oturumdan sonuç çıkarma.**

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
