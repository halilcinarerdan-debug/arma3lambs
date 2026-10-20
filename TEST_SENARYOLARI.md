# Test senaryolari (lambs_danger ELITE)

Her senaryo icin: kurulum -> beklenen log -> `python tools/rpt_ozet.py <rpt>` ile hizli kontrol.
Yuklenen surum `[ELITE-BOOT] ... build vX` satirindan dogrulanir.

| # | Senaryo | Kurulum | Beklenen (RPT) | Gecme olcutu |
|---|---------|---------|----------------|--------------|
| 1 | **Uzak bounding** | Iki grup (>= 8 kisi) birbirinden 250-350 m | `[CMD] BOUNDING`, `[BND-BASLA]`, `[OVERWATCH]`, `[BND] ... hareket:A kapsama:B` | A <= toplamin yarisi, cycle'lar `buddy` / `FSE-sicrama` donusumlu, `[BND-BITTI]` mesafe 40-45 m |
| 2 | **Yakin bounding / hucum** | 80-100 m | BOUNDING -> 45 m'de `ASSAULT` | Bounding en az 2 cycle |
| 3 | **Retreat** | 5-8 kisilik grup, %40 kayip, dusman 100-150 m | `[CMD] WITHDRAW/PEEL`, `[GERI-CEKILME-BASLA]`, `sicrama N sonuc | vardi:a/b` | Toplam vardi orani >= %50, retreat sirasinda `TACTICS ASSAULT` yok |
| 4 | **Kucuk ekip / yakin temas** | <= 3 kisi veya dusman < 60 m, agir kayip | `[CMD] ... -> DELAY` (kacmak yerine siper + sis), `[SIS]` | `GERI-CEKILME-BASLA` yok |
| 5 | **Acikta baski** | Grup acikta (15 m'de siper yok) + baski >= 0.6 | `[CMD] DELAY (baski altinda, ACIKTA ...)` | HOLD degil DELAY |
| 6 | **El bombasi tepkisi** | Bir askere dusman bombasi attir (Zeus: AI'ya el bombasi emri) | `[GRENADE-ATIS]`, `[EL-BOMBASI-GORDU]`, `[EL-BOMBASI] ... fitil kalan X` | Tepki <= 1 sn, `fitil kalan` ort. >= 2.5 sn |
| 7 | **UGL** | Bombaaatarli grup, dusman 40-200 m | `[ATES-DESTEK] UGL salvo` veya `[ROL-GOREV] UGL` | > 200 m'de 25 sn'den sik degil, rezerv < 3 mermi iken uzak atis yok |
| 8 | **RPG guvenligi** | AT askerin onunda dost / cali | `[ATIS-GUVENLIK] RPG atilmadi: ...` | Dost yakininda RPG atilmaz |
| 9 | **Formasyon** | 5 dk temaslı yuruyus | `[KOMUTAN-FORM]` / `[FORMASYON]` | Ayni grupta 90 sn icinde formasyon degisimi yok (zirh/agir kayip haric 20 sn) |
| 10 | **Felc / spam** | Herhangi uzun catisma | `rpt_ozet` -> SPAM TESPITI | "yok"; `[KOMUT]` gecisleri asker basina >= 3 sn aralikli; `[CAGRI]` ayni cagri 40 sn'de bir |
| 11 | **Arka guvenlik** | Kent (>= 8 bina), grup >= 6 kisi, >= 3 sade tufekli | `[ARKA-GUVENLIK] ... arkayi kollamaya atandi` | MG/AT/nisanci/saglikci/UGL secilmez |
| 13 | **Grup olaylari** | Herhangi catisma + retreat | `[OLAY] ... InContact / AllClear / Casualty / RetreatBasla / RetreatBitti / BoundingBasla / BoundingBitti / GrenadeAlgilandi` | Her temasin InContact + AllClear cifti var; `AllClear guvenlik agi` satiri YOK (varsa bir taktik anormal bitiyor) |
| 12 | **Doktrin puani** | Her senaryo | `[DOKTRIN]` | Ortalama >= 70; `komutan_onde:true` orani <= %30 |

## Bilinen sinirlar
- LAMBS taban FSM'i (Dodge, sympathetic assault, Checking bodies) derlenmis pbo'da; sadece `disableGroupAI` ve `forceMove` ile bastirilabilir.
- El bombasi ATISI (AI'nin bomba atmasi) LAMBS tabanindadir; bu fork yalnizca tepkiyi ve tanilari yonetir.
- Mod hatalari (`setHitPointDamage`, `fnc_throwWeapon`, `Bone ...`) bu fork'a ait degildir; `rpt_ozet` bunlari ayiklar.


## VBS4 ilhamli ozellik senaryolari (test ortami adlari)
Her senaryo 3-5 dk; RPT kaydederken senaryo adini ve saatini not et. **Retreat her turda en az bir senaryoda ayrica dogrulanir (hibrit duzen).**

| Ad | Ozellik | Kurulum | Beklenen / bakilacak |
|----|---------|---------|----------------------|
| `cover_acik_alan` | Siper ve atis analizi v2 | Agac / duvar / kaya olan acik alan, 8-10 kisi, dusman 150-250 m | `[SIPER-ANALIZ]` faz2 degisim orani %5-50; askerler gercek (mermi durduran) siperde, hedefi gorebiliyor; pasiflesme yok (hareket orani) |
| `rota_hedgerow` | Taktik rota planlama (gizli yaklasma) | Tarlalar + agac sirasi (hedgerow), dusman karsi uc | Grup agac hattini kullaniyor mu / acik tarla maruziyeti (`[ROTA]` loglari, yazildiginda) |
| `pusu_yol` | Pusu davranisi + ates emri (ROE) | Yol kenari, grup gizli, dusman devriye / konvoy | Ilk ates zamani (emir / ates altinda), killbox yonu, lider gozlem |
| `kapi_oda` | Kapi yigilma + oda temizleme | Tek kat bina, kapi + 2 oda, icinde 2 dusman, 4 kisilik ekip | Kapida iki yana yigilma, giris sirasi |
| `hendek_hatti` | Mevzi / hendek | Hendek hatti (mod nesneleri), savunma + hucum | Mevzilere yerlesme, mevzi arasi geri cekilme |
| `yorgunluk_yaklasma` | Yorgunluk duyarli bound | ACE fatigue acik, uzun yaklasma (> 500 m) | Atilim boylari / bekleme yuke gore degisiyor |
| `teslimiyet_kusatma` | Teslimiyet / moral | Kayipli, kusatilmis kucuk grup | Teslim karari (esikler profile gore) |
| `retreat_kayipli` | Retreat dogrulamasi (sabit) | 5-8 kisi, %40 kayip, dusman 100-150 m | `vardi:` toplam >= %50, retreat'te `TACTICS FLANK` / `Group Suppress` yok, `RetreatBasla/Bitti` cifti |
| `olay_temas` | Grup olaylari | Herhangi catisma | `[OLAY] InContact/AllClear` cifti, `Casualty` = olu sayisi, `AllClear guvenlik agi` YOK |


## TOPLU TEST PLANI (v8.16)
Tek oturumda tum yeni ozellikler; sonuc: `python tools/rpt_ozet.py <rpt> --karne` (OK / KONTROL / YOK karnesi), ayrintilar icin `--anomali`, `--grup "Alpha 1-1" --aralik HH:MM:SS-HH:MM:SS`.

| Blok | Kurulum | Karnede beklenen |
|------|---------|------------------|
| A. Acik arazi 8v8, 250-300 m, engebeli | Ayni oturumun ilk 6 dk | ROTA (maruziyet dusus), ARAZI BILINCI, KAMUFLAJ (ufukta artis), OLAY, DOKTRIN >= 70 |
| B. Yaklasan devriye (pusu) | Bir grup yol kenari, digeri yola dogru yuruyor (90-260 m, temas yok) | PUSU basladi > 0 ve ates > 0 (kill-box) |
| C. Kayipli retreat | 5-8 kisi, %40 kayip, dusman 100-150 m (acikta + baskili bir tur daha) | RETREAT varis >= %50, ek sicrama > 0, baski-kirma > 0 (baskili turda) |
| D. Cali / cimen | Dusman yatik cali arkasinda, 60-150 m; ayrica uzun cimende yatik | YAPRAK KIRICI kontrol > 0, gizli orani <= %70, tick ort < 12 ms; `lambs_danger_yaprakTest = true` ile tek tek karar |
| E. Ortam | Gece + sis + yagmur; NVG'li, termalli ve gozluksuz askerler | ORTAM SKILL degisim > 0; `[ORTAM-SKILL]` satirlarinda cihaz farkli (normal / NVG / termal) ve carpan spotD farkli |
| F. Saglik | Tum oturum | SAGLIK / ANOMALI: anomali yok; varsa kod + grup + detay (`--anomali`) |

Yaprak testi icin konsol: `lambs_danger_yaprakTest = true;` (ilk 400 degerlendirme `[YAPRAK-TEST]`), kapatma `lambs_danger_yaprakV1 = false;`, esikler `lambs_danger_yaprakEsikAyakta` / `lambs_danger_yaprakEsikYatik`.

## v8.32 KUMANDA (HQ) testi
1. Ayni taraftan 3+ grup (2 grup birbirinden 100-600 m, biri temasa girsin). Log: `[HQ] kumanda cekirdegi baslatildi`, `[HQ-TAHTA]` (90 sn'de bir), temas + kayip %25 / guc oraninda `[HQ-TAKVIYE] ... -> destek ...` ve `[HQ-EMIR] ... TAKVIYE`. Destek grubu dusmanin kanadina yaklasmali (dusman noktasina duz kosmamali). Beklenen: bir turda en cok 1-2 grup, yardim isteyene 90 sn'de bir.
2. Hekimsiz grup + baygin yarali (hekimi oldur), yakinda (< 350 m) baska musait grup + hekimi. Beklenen: `[HQ-MEDEVAC] ... <- hekim ...`, sonra `[TCCC] ... hekim ... -> yarali ...`; hekim tedaviden sonra kendi grubuna donmeli.
3. Kontrol: Zeus'ta grup `lambs_danger_hqTakviyeKatilim=false` ise destek vermemeli; `lambs_danger_hqV1=false` tum HQ'yu kapatir.

## v8.33 KOMUTAN (Zeus modulu) testi
0. Zeus > 'LAMBS Danger' kategorisi > 'ELITE Kumanda (HQ)' modulunu herhangi bir yere yerlestir; pencerede 'Kumanda aktif' acik, 'LAMBS dynamic reinforcement'i kapat' acik birak; Tamam. RPT'de `[HQ-MODUL] kumanda AKTIF | ...`. Modul yerlestirmeden HICBIR `[HQ-...]` takviye / kanat / istihbarat satiri olmamali.
1. ISTIHBARAT: 3+ grup (birbirine < 1500 m). Biri dusmani gorsun. Beklenen: `[HQ-ISTIHBARAT] muhbir G1 -> alici G2 | hedef ...` ve diger gruplarin dusman yonune donmesi / mesafe kapatmasi. Oyuncu ekibi hedefse `OYUNCU` yazar.
2. KANAT: 3 grup, biri sabit temasta (ayakta mesafeli atis), ikisi 100-900 m'de musait. Beklenen: `[HQ-KANAT] EMIR ... cift kusatma` ardindan yaklasik 40-150 sn sonra `[HQ-KANAT] SALDIRI`; gruplar dusmanin yanlarindan gelmeli.
3. Dostca ates: sabitleyen grup kanattan hucum eden dostuna ates etmemeli (kanat noktasi sabitleyenin ates hattina dik); gorulurse nerede oldugunu yaz.

## v8.34 DOKTRIN testi (retreat + toparlanma)
1. Kayipli bir grubu retreat ettir. Log sirasi: `[GERI-CEKILME-BASLA]` ... `[GERI-CEKILME-BITIS] neden:gozlem yok | temas kesildi | guvenli mesafe`; temas koptuysa `[GERI-CEKILME-YON]` (tek sicrama, eksenden +-55 derece sapma); `[GERI-CEKILME-TAMAM]`; hemen ardindan `[TOPLAN] BASLA` (halka, OP, silah sektorleri), `[TOPLAN-RAPOR]`, `[TOPLAN] BITTI neden:...`.
2. Gorsel: retreat bittikten sonra askerler lider etrafinda halka olup DISA bakmali (tehdit yonune MG / AT), bir kisi 30-45 m onde gizli gozetleme noktasinda; dusman cikarsa toparlanma bitmeli ve komutan yeni karar vermeli. 90 sn icinde otomatik hucum olmamali.
3. Kanat: hucum baslayinca (`[HQ-KANAT] SALDIRI`) sabitleyen grubun atesi dusmanin otesine kaymali (yakin kanatta dost atesi olursa yaz).
4. Sorun isaretleri: retreat cok erken bitiyor mu ('gozlem yok' ile 20-30 sn'de), halkada askerlerin binanin / duvarin icine dusmesi, toparlanma sonrasi askerlerin kaybolmasi (doFollow).

## v8.35 PUSU DOKTRIN v2 testi
Kurulum: bir grup (>= 6 kisi) yol kenari, digeri (>= 4 kisi) yola dogru yuruyor (90-260 m, temas yok).
1. Beklenen log: `[PUSU] BASLADI`, `[PUSU-GUVENLIK] ... SOL / SAG (ARKA >= 7 kisi)`, `[PUSU-KZ] bilinen:N | kill zone icinde:K` (5 sn'de bir). Gorsel: iki asker kanatlara gidip disa bakmali.
2. Ates `ATES:cogunluk kill zone'da (K / N)` ile baslamali (ilk adam 70 m'ye girince degil); az dusmanda (<= 2) `ATES:kill-box`.
3. Cok kalabalik dusman (> kendi sayinin 2 kati): `IPTAL:dusman cok buyuk` ve pusu ateş acmamali.
4. Ates sonrasi temas kopunca `[TOPLAN] BASLA` (halka + rapor) gorulmeli.
5. Sorun isaretleri: guvenlik askeri pusuyu ele veriyor (dusman erken doner), cogunluk kriteri cok gec ates (dusman gecip gidiyor).

## v8.36 ROTA ZINCIRI + KAPI / ODA testi
1. Rota: dusmana 150-400 m, ortulu hat (agac sirasi / cali) olan arazide bounding. Log: `[ROTA] ... sapma:..`, `[ROTA-ZINCIR] ... N bacak ... noktalar:[...]`. Gorsel: grup tek yone dogru ilerlemeli, 20 sn'de bir sag / sol degistirmemeli.
2. Kapi / oda: catisma sonrasi (28 sn sakin) yakinda bina (>= 2 pozisyon). Log: `[BINA-TEMIZLE] BASLA`, `[ODA] ... kapi:... (Door_N_trigger | bina pozisyonu) | yigilma yani:...`, ardindan `[ODA] ... oda i/N CLEAR`.
3. Gorsel: giris timi kapinin YANINDA duvara yigilmali (onunde degil); iki asker odaya ayni anda girip zit koselere gitmeli ve oda icine bakmali.
4. Sorun isaretleri: askerlerin ayni noktaya gitmesi (kose = oda noktasi), kapi disinda duvara takilma, bina disina yigilma.

## v8.37 FEINT testi (Zeus modulu acik, Feint secili)
Kurulum: ayni tarafin 4 grubu: biri dusmanla sabit temasta (>= 3 dusman), uc grup 100-900 m'de musait (>= 4 kisi).
1. Beklenen: `[HQ-KANAT] EMIR` (kanat grubu), ardindan `[HQ-FEINT] EMIR: ana cabasi = kanat manevrasi ... feint G -> on cephe ...`. Feint grubu dusmana ON'den (sabitleyen eksenine yakin) 150 m'ye yaklasmali, kanat grubu yandan gelmeli.
2. `[HQ-FEINT] BIRAK ... neden:` kayip / bastirma / 100 sn / ana saldiri. Kayip ya da bastirmada feint grubu retreat etmeli (`[GERI-CEKILME-BASLA]`).
3. Zeus modul penceresinde 7 secenek gorunmeli (Feint dahil).
4. Sorun isaretleri: feint grubunun dogrudan sabitleyenin yanina yigilmasi, feint'in hic birakilmamasi (sure kriteri), kayipli feint'in ayrilmamasi.

## v8.47 testleri
- Retreat: 8+ kisilik grubu 100 m'den baskiya sokup cekilmeyi izle; beklenen: 300 sn'ye kadar / dusman >=450 m veya gozlem yok >=280 m; sonra 90 sn toparlanma, hemen geri hucum yok. Log: [GERI-CEKILME-EK], [GERI-CEKILME-BITIS].
- Formasyon: dusman yandan (45-120 derece) acik arazide -> ECH LEFT/RIGHT; gece intikal -> COLUMN; temas sonrasi 2 dk intikal -> DIAMOND. Kanat yonu dogru mu bak.
- Tehdit bakisi: temas disi grup durunca askerler duvara degil son dusman yonune bakmali. Log: [TEHDIT-BAKIS] baslangic.
- Hava: dusman silahli heli/dron gonder; grup binaya girmeli veya dagilip gizlenmeli, AA'li asker ates etmeli. Log: [HAVA-FARK].
- IED: yol kenarina IED (vanilla IEDLandSmall_F) koy, grubu yurut; ~25 m'de durup 55 m'ye acilmali, EOD varsa 'Deactivate'. Log: [IED-FARK].

## v8.51 HAVA ATES DISIPLINI testi
1. Saldirmayan silahli heli (UH-60M vb.), grubun 400-1200 m'sinde ucsun, ates ETMESIN. Beklenen: `[HAVA-FARK-TANI]` (ates:... sn once buyuk), grup gizlenir / bina (`tepki:HIDE` veya `GARRISON`), bounding grup `BOUNDING-DEVAM`. Askerler heliye ates ETMEMELI (forgetTarget).
2. Saldiran heli (door gunner / roket ile gruba ates), mesafe <= 600 m, yukseklik <= 300 m. Beklenen: `tepki:TOPLU-ATES`, `ates eden:N`, 20 sn'den sonra durmali, 60 sn sonra tekrar. Askerler helinin ONUNE ates etmeli (tracer onde).
3. Saldiran heli > 600 m: ates yok, gizlenme (`tepki:HIDE`).
4. Hover eden silahli heli: `hover:true`, `[HAVA-FARK-TANI]`'da `hover` alani true.
5. Hata testi: RPT'de `Error` olmamali; olursa `[WATCHDOG-YENIDEN]` gorulmeli ve davranis devam etmeli.
## v8.51 IED yaricap testi
`[IED-FARK] ... (yaricap X m [config:Y], temas:...)`: Y > 0 olmali; yaricap = Y x 3 (20-80 m).

## v8.60 TAKTIK ZEKA testleri (RPT: python tools/rpt_ozet.py --zeka <rpt>)
1. Baslangic: `[ZEKA-OLUM] ... baslatildi (v8.60)`; 90 sn'de bir `[ZEKA-NABIZ]`.
2. Karsi pusu (yakin): gruba 25+ sn sakinlikten sonra 30-50 m'den pusu kur (>= 4 kisilik saglikli grup). Beklenen: `[ZEKA-TEMAS] ... onceki sakin sure >= 25`, `[ZEKA-PUSU] ... TEPKI:ASSAULT`, `[CMD] ... ASSAULT (karsi pusu ...)`; grup siper almak yerine pusuya yuklenmeli.
3. Karsi pusu (uzak + zayif): 100+ m'den pusu, grup 3 kisi ya da cok kayipli: `TEPKI:DELAY` (siper al, temas kes).
4. Olum bolgesi: gruptan 1-2 kisiyi bir pozisyondan vur (kayip), ardindan baska bir grubu AYNI taraf, o bolgeden gorulen hat uzerinden dusmana yaklastir: `[ZEKA-OLUM] ... kayip | katil konumu:` ve `[ROTA] ... olum bolgesi gozcusu:1+` (rota o gorus hattindan kacinmali).
5. HQ otomatik: `lambs_danger_hqOtomatik = true` -> `[HQ-MODUL] kumanda OTOMATIK acildi`, `[HQ-ISTIHBARAT]`, `[HQ-KANAT]` loglari (Zeus modulu gerekmeden).
Kapatma anahtarlari: lambs_danger_olumBOff, lambs_danger_pusuKarsiOff, lambs_danger_hqOtomatik (acma).

## v8.63-v8.66 SQUAD TAKTIK ZEKASI testleri (RPT: python tools/rpt_ozet.py --zeka <rpt>)
1. HAZIRLIK (v8.63): >= 4 kisilik grup, dusman 60-200 m, kararin ASSAULT olmasi: `[ZEKA-HAZIRLIK] ... BASTIRMA PENCERESI 5-8 sn | ates eden:N | UGL:M | sonra hucum`; 5-8 sn sonra hucum baslamali. Baskidaki grupta `ATLANDI`.
2. BASKI TUFEKCISI (v8.64): MG'siz squad: `[ZEKA-BASKI] ... BASKI TUFEKCISI: <ad> | silah ...`; [ROL-SIRA] satirinda MG:1 gorunmeli; o asker MG istasyonuna gecmeli (overwatch), hat kapaliyken `[ROL-GOREV] ... MG alana baski`.
3. YAN / ARKA (v8.65): >= 5 kisilik grup yuruyus halinde (temassiz): `[ZEKA-YAN] ... SAG:ad | SOL:ad | ARKA:ad`; o askerler yuruyuste kanatlara / arkaya BAKMALI (govde donmeden). Durunca / temasta `SERBEST`.
4. NOKTA ELEMANI (v8.66): >= 6 kisi, temas yakin zamanda olmus (< 240 sn) ya da 700 m icinde bilinen dusman, yuruyus: `[ZEKA-NOKTA] ... NOKTA ELEMANI: ad1, ad2 | ana govdenin 55 m onunde`; 2 asker ~55 m ONDE ilerlemeli. Temasta / durunca `SERBEST`.
Kapatma anahtarlari: lambs_danger_hazirlikOff, lambs_danger_baskiTufekciOff, lambs_danger_yanGuvenlikOff, lambs_danger_noktaOff.

## v8.67 — Tek kalan katilimi / formasyon hakemi / HQ takviye
- Bir squad'i <= 2 kisiye dusur (Zeus ile oldur), 150 m icinde baska dost squad (>= 3) birak -> `[ZEKA-YETIM] KATILDI` beklenir.
- Ayni test, 600 m uzakta + ikisinde telsiz (ItemRadio) -> `YOLDA` loglari sonra `KATILDI`; telsizsiz iken `uygun dost grup YOK`.
- Saldiri / bastirma sirasinda `--form` salinim tespiti: WEDGE<->LINE gidip gelme olmamali.
- Bir squad temasta + kayip >= %25, ikinci squad 300 m+ uzakta bounding'de -> `[HQ-EMIR] ... bounding iptal edildi` ve TAKVIYE.

## T-HENDEK / T-TOP (v8.228 – v8.229): gelen topçu tepkisi + hendek alanı
Ortam: kısa harita bölgesi, düz arazi, sunucuda ELITE + RHS (US/RUS). Zaman: ~6 dk. Her adımdan sonra RPT'de `[TOP-GELEN]`, `[HENDEK-YERLES]`, `[ANOMALI]`.
1. **Düz arazide tepki (hendek yok)**: Batı 1 squad (8 AI), 400 m uzağa 1 havan (RHS 82 mm) + Zeus "ELITE Topçu TEST". Squad'ı 150 m içine bırak. Beklenen: atıştan önce `[TOP-GELEN] ... kalan 6.x sn`, askerler düşme noktasından uzaklaşıp yatar, patlamadan ~7 sn sonra kalkar. Ölçüt: kaç asker yaralandı/öldü (aynı senaryoyu `lambs_danger_topSiperOff = true` ile tekrarla ve karşılaştır).
2. **Hendek tek başına yürüme**: Eden'de 20-30 m hendek (1,4 m derin, 4 m geniş) + iki ucuna rampa. Üstüne dikdörtgen işaret koy: ad `elite_hendek_1`, boyut hendeğin YARI uzunluk/genişliği, yön hendeğin yönü. Bir squad'a Zeus'tan hendek içine `doMove`. Beklenen: giriyor, rampadan çıkıyor; takılırsa `[ANOMALI] YURUMUYOR`.
3. **SAVUN + hendek**: aynı hendeğin 150 m yakınına ELITE Objektif → SAVUN (objektif hendeğe ≤ 350 m). Beklenen: `[PLAN] ... SAVUN: <grup> hendek alanına yerleşecek` ve `[HENDEK-YERLES]`; askerler hendek ekseninde dağılıp çömelir, dışa bakar.
4. **Topçu + hendek**: 3'teki squad'a topçu ateşi (1'deki gibi). Beklenen: hendek ≥ 8 m uzaktaysa hendeğe koşup yatar (aynı log, sonuç: hendek içinde kalan sayısı).
5. **Olumsuz durum**: hendek işaretini sil/yanlış adla (ör. `hendek_1`) → eski davranış (düz arazide yat) — hata/log kirliliği olmamalı.
Başarı ölçütü: 1'de açık farkla daha az kayıp; 2'de ≥ %80 asker hendeğe girip çıkabiliyor; 3-4'te `[HENDEK-YERLES]` ve çömelen asker sayısı ≥ %70. Not: hepsi doğrulanmamış (T).

## T-CEPHE-A0 (v8.237): cephe simulasyonu — profil cekirdegi, faction paneli, Personnel Replacement
Ortam: sunucu (dedicated ya da host) + RHS US / RUS (ya da GM), Zeus'lu bir oyuncu. CBA > LAMBS Danger > ELITE Cephe Komutani: kisa test icin tavan 60, oyuncu yaricapi 1000, sanallama beklemesi 20, min fiziksel kalis 30 yapin (varsayilanlar uzun test icin).
RPT yardimcisi: `python tools/rpt_ozet.py --cephe <sunucu.rpt>`. Zaman cizelgesi [CEPHE-*] t+sn satirlaridir.
1. **Acilis**: boot satirinda `v8.237-CEPHE-A0`, `[CEPHE] olaylar kaydedildi`, `[CEPHE] cephe dongusu baslatildi`, `[ELITE-CBA] cephe ayarlari kaydedildi`. Zeus'ta "ELITE Cephe Paneli" modulu gorunmeli.
2. **Faction ekle**: modulu 3 km uzaga birak -> "Faction asker ekle" -> BLUFOR bir faction, asker 120, rezerv 40, yaricap 500, varis noktasi isaretli. Beklenen: `[CEPHE-FACTION] ... +120 asker`, ardindan `~15 sanal squad profili olusturuldu`; sistem kendiliginden acilir. Ayni islemi karsi taraf icin 2 km yanina yap (120 asker). Faction listesi gelmiyorsa `[CEPHE-FACTION-TARAMA]` satirina bak.
3. **Sanal kal**: oyuncu 3 km'den uzaktayken `[CEPHE-OZET]`: L0 ~30, L1 0, fiziksel asker 0. Hicbir asker gorunmemeli (harita/Zeus'ta yok).
4. **Oyuncu yakinligi (tier 1)**: oyuncu bir squad'in 900 m'sine yurusun: `[CEPHE-FIZIKLE] ... OYUNCU-YAKIN`, 8 askerlik grup belirir (`Zeus`ta gorulur), AI normal davranir. 1.3x yaricap disina cikip bekleyince (>= 20 + 30 sn) `[CEPHE-SANALLA] ... tetik yok (bekleme doldu)`; askerler silinir, olu varsa bedeni yerinde kalir.
5. **Oyuncusuz temas (tier 3)**: oyuncu 5 km uzakta/Zeus kamerasinda: iki tarafin profillerini 1 km icine yaklastirmak icin Zeus'tan bir tarafin squad'ina (once fiziksel yap: oyuncu yakinligi) hedef ver YA DA iki modul konumunu 1 km arayla birak. Beklenen: `[CEPHE-FIZIKLE] ... TEMAS | oyuncu ... m | dusman ... m` iki tarafta da, oyuncu uzakta olsa da; askerler gercekten catisir. Temastaki fiziksel squad temas bitene kadar `[CEPHE-SANALLA]` almaz.
6. **Tavan**: tavani 16 yap, 5'teki catismayi tekrarla. Beklenen: `tavan-blok` sayisi OZET'te artar, tavana sigmayan sanal temas icin `[CEPHE-SOYUT]` (30 sn'de bir, kayip <= %15), `--cephe` ciktisinda "TAVANA DAYANDI".
7. **Personnel Replacement**: panel > PR ayarlari: hiz 120/saat, gecikme 30 sn, min squad 6, es zamanli 2. 5'teki catismada bir squad'in canli sayisi 6'nin altina duserse: `[CEPHE-TAKVIYE] TALEP` (hemen), 30 sn sonra `YOLDA | n asker -> squad | varis noktasi ..., ETA` , sanal yuruyus, `VARDI | ... squad simdi X/Y`. Rezerv `[CEPHE-DURUM]` ile (panel > Durum raporu) dusmeli. Dusmana yakin gecen paket icin `[CEPHE-KONVOY] KONVOY-SANAL` zaiyat.
8. **Havuz bitti**: rezervi kucuk tut (10), "Havuz bitince = Cekil": `HAVUZ BITTI | ... CEKILIYOR`.
9. **Saglik/yara tasima**: bir fiziksel askeri yarala (ACE), sanalla, tekrar fizikselle: yaralanma/tibbi durum korunmali (ACE yoksa hitpoint). Loadout (silah/mermi) ayni kalmali.
10. **Kapatma**: CBA > Aktif kapat: `[CEPHE-OZET]` durur, hicbir profil silinmez; Zeus elle yerlestirilmis birimler hic etkilenmez.
Basari olcutu: gecis nedenleri mantikli (`--cephe`), 120 sn icinde sanal->fiziksel salinim 0, tavan asilmiyor (temasli haric), RPT'de `Error` / `[WATCHDOG-YENIDEN] cephe` yok. Hepsi (T) = dogrulanmadi.

## T-MEVZI (v8.239): coklu mevzi ile SAVUN
1. Zeus: ELITE Plan Noktasi (manuel) -> taraf, tip "MEVZI ekle", "Mevzi yonu = modul yonu" isaretli; modulu 150-400 m cevreye 3 farkli yere birak (her birinde modulu dusmana dogru dondur). Haritada ucgen "MEVZI 1..3".
2. Objektif -> SAVUN (en az 3 grup, objektif 3 mevzinin ortasi, tehdit yonu verilirse tehdit yonune en yakin mevzi once dolar). Beklenen log: `[PLAN-MEVZI] ... 3 manuel mevzi plana alindi`, her grup icin `[PLAN-MEVZI] ... -> mevzi N (grid, sira, yon, hendek)`; gruplar 3 ayri mevziye gider, 4. grup varsa 1. mevzide 18 m yaninda.
3. Bir mevzinin 40 m icine elite_hendek alani koy: o mevzideki grup hendege girer ([HENDEK-YERLES]).
4. "MEVZI sil (en yakin)" ve "hepsini sil" sonrasi yeni SAVUN eski halka sektoruyle kurulmali (`[PLAN-MEVZI]` satiri gelmez).

## T-SURUS-AB (v8.239): AI surucu A/B testi
Ortam: acik, DUZ arazi, sunucu + RHS. Zeus > "ELITE Arac SURUS A/B Testi" > sinif 1 = bir RHS tekerlekli APC (Stryker / BTR), sinif 2 = bir paletli (M113 / BMP), "ELITE acik" + "yolcu" isaretli, sure 15, bisect KAPALI ilk kosuda.
Beklenen: ~25 sn sonra Zeus sohbetinde `[SURUS-AB-OZET]` satirlari (sinif basina A B C D E : G/X + yorum); tum satirlar sunucu RPT'sinde `[SURUS-AB]`. Satirlari `[SURUS-AB]` etiketiyle arayin.
Sonuca gore: ELITE acikken gitmiyorsa ikinci kosuda "Otomatik bisect" isaretli tekrar edin ([SURUS-AB-BISECT] suclu aday). Hepsi gidiyorsa sorun Zeus'ta yerel yaratma / sunucu devri / plan kosulundadir (bir sonraki adim: o kosulu test).

## T-MEVZI-TUT (v8.243): savunmada hendekten ayrilmama
Ortam: P1 gibi EAST SAVUN (4 grup, hendek alani var), karsi taraf WEST ELE GECIR; topcu destegi 'cagri'.
1. Temas ve topcu olsun; savunma gruplarinin hendekte KALMASI beklenir. Loglar: `[MEVZI-TUT] ... hendekte: komutan beyni / taktik atlandi` (grup basina 60 sn'de bir), `[TASIMA]` vb. degil. LAMBS `TACTICS HIDE/HOLD/FLANK` satiri hendekteki gruplar icin ARTIK gelmemeli (kayip >= %60 sonrasi gelebilir).
2. YEDEK karsi saldiri: `[PLAN-SAVUNMA] KARSI SALDIRI: ... dusmanlar: <tip/taraf listesi>` — listede GERCEK dusman tipleri olmali; sonrasinda `KARSI SALDIRI BITTI: ... mevziye donuyor` ve `[HENDEK-YERLES]` tekrar gelmeli. Acikta 5 dk+ kalan grup olmamali.
3. Savunma suresi: `lambs_danger_planSavunmaS` kisa verip (ornegin 120) temasta `SURE DOLDU ... temas kesilene kadar surer` satiri gelmeli; temas kesilince BITTI.
4. Savunma atesi: topcu aracina menzil icinde ol; dusman >= 3 ve dostundan >= 480 m: `[PLAN-TOPCU] ... SAVUNMA ATESI` (RED / izin kurallari ayni). Atmazsa `ATIS YAPILMADI` nedeni yazar.
5. Topcu tepkisi: `[TOP-TEPKI]` satirlari (ilk 30): her asker icin karar (HENDEGE kosuyor / ZATEN HENDEKTE / HENDEK YOK: hemen uzaklasiyor ...). Acikta olup 'tehlike disinda' diyenleri not al.
6. Senkron tavani: hendekte duran piyadenin onunde GOZETLEME gorevli tank: `[ARAC-SENKRON] ... SERBEST (eskort piyade durdu: BEKLE tavani ...)`.
7. IFV 'bekliyor' vakasi: `[PLAN-ZIRH] ... SURUCU EMRI ONARILDI` (ilk 3) ve `TAKILDI` satirinda surucu komut / motor / canMove bilgisi.
Hepsi (T) = dogrulanmadi; kapatma anahtarlari: mevziTutOff, savunmaUzatmaOff, savunmaTopcuOff, senkTavanOff, topErkenKacisOff, zirhSurucuOnarOff.

## T-TANK-MEVZI (v8.244): savunmada tank / IFV mevzisi + surucu yenileme
Ortam: SAVUN plani (Zeus elle secimde TANK grubu da secili; tehdit yonu verilirse daha iyi), RHS tank (T-72/T-80/T-90 veya M1A1) + BTR/BMP/Bradley.
1. `[PLAN-ZIRH] ... SAVUNMA MEVZISI: birincil .. (objektife 70-260 m, tehdit yonu ..), gizleme noktasi .. (55 m geride), alternatif ..` satiri; tank objektifin onunde 650 m'de OLMAMALI.
2. Dusman >1500 m iken tank gizleme noktasinda durur (`mevzide (GIZLEME NOKTASI)`); dusman <=1500 m bilinince `TETIK: gizleme noktasindan birincil mevziye cikiyor` ve tank tehdit yonune bakar.
3. Hasar >= 0.08: `YER DEGISTIRIYOR` (alternatif). Gorus hatti yoksa (hull-down aday yok) mevzi yine secilir; log 'gorus hatti false'.
4. Surucu yenileme: dolu BTR/IFV'nin suruculusunu Zeus'ta oldur: 3-6 sn icinde `[SURUCU-YENILE] ... yolcu .. surucu koltuguna gecti`; arac devam etmeli (planZirh yeni surucuye doMove verir). Tankta yolcu yoksa `yedek surucu YOK` bir kez yazar.
5. Gozetleme tanki (Zeus gozetleme gorevi): vardiginda `[GOZETLE-ARAC] ... derece gozetliyor` yonu dusmana / tehdit yonune bakmali.
Kapatma: tankMevziOff, surucuYenileOff. Hepsi (T) = dogrulanmadi.

## T-NAKIL-ZINCIR (v8.245): uzak nakil (BTR-80 hareket sorunu)
Ortam: ELITE Objektif / OPORD, inis noktasi 3-5 km uzakta, 3-4 BTR-80 (yt_btr80 / old_btr80 karisik), her biri 6-8 yolcu, araclari birbirine YAKIN (10-15 m) park et (onceki sorunlu kosuda 10-13 m komsu vardi).
1. `[TASIMA] ... YOL ZINCIRI: N ara nokta (inise X m)` her arac icin; sonra araclar `yolda: inise ..` ile ILERLEMELI; `TAKILMA TANISI (8 sn hareketsiz ...)` gelmemeli ya da gelirse `[TASIMA-TAKILMA]` satiri kopyala.
2. Ara nokta gecisi sirasinda hiz dususu / durma olmamali (60 m kala sonraki bacak). `kinematik surus` (TASIMA-KIN) gerekmemeli.
3. Kapat: lambs_danger_nakilZincirOff = true ile ayni sahneyi tekrarla (eski davranis karsilastirmasi).
4. A/B ile dogrulama (300 m mesafe, 3 BTR-80 sinifi): DEGISMEDI, hepsi gitti (RPT b5530abe).
Hepsi (T) = dogrulanmadi.

## T-NAKIL-TEMAS + T-OTO-TANK (v8.246)
1. Nakil sirasinda yolda dusman cikar (yol kenarina 60-150 m'de EAST piyade yerlestir). Beklenen: `[TASIMA] ... YAKIN PUSU: dusman X m -> HEMEN IN` (X <= 150) ya da dusman >= 150 m ise `PUSU / TEMAS: dusman X m -> HIZLI GECIS` (X artik bilinen mesafe, 'bilinmiyor' degil); `YOLCU GERI ALINDI` ardi ardina (>5) satir OLMAMALI.
2. Otomatik tank: Objektif modulu ELLE SECIM YAPMADAN kur; haritada senin tarafindan tank grubu (Zeus gozetleme atamasi YOK) objektife <= 4000 m. Beklenen: `[PLAN-ARAC] ... [TANK] ZIRH DESTEK unsuru olarak OTOMATIK alindi`, sonra `[PLAN-ZIRH] ... ates pozisyonu` (SAVUN ise `SAVUNMA MEVZISI`). Tank Zeus gozetleme atamasiyla HARIC ise alinmaz (beklenen).
Kapatma: nakilTehditGenisOff, planOtoTankOff. Hepsi (T) = dogrulanmadi.

## T-MOTOR-SES (v8.247): arac / heli / ucak motorunu duyma
Ortam: sakin gunduz, duz arazi, EAST piyade grubu (4-6 kisi, SAFE/AWARE, mevzide) ve karsi tarafta (WEST) yaklasan araclar (hepsi motoru calisir halde).
1. Tank 900 m'den yaklasirken: `[MOTOR-SES] TANK (...) duyuldu -> <grup> | X m (menzil ~900 m ...) | yon ...`; grup AWARE'e gecer, 3 asker yone bakar. AT'li grupta AT askerleri de bakar. Ayni grup icin 20 sn'de bir.
2. Kamyon ~500 m, rolantide (hiz < 3 km/s) arac ~200 m'de duyulmali. Gece menzil x1.3, yagmur x0.7, ruzgar > 6 m/sn x0.75 (Zeus'ta hava ayarla).
3. Dinleyici temastayken (son 15 sn) menzil x0.4; tepe arkasinda (arazi engeli) x0.6.
4. Helikopter alcak ucus ~2.5 km, jet ~4 km, kucuk IHA ~400 m: `HELI` / `UCAK` / `IHA` satirlari. NOT: bu surumde hava araci icin hide / AA ateşi karari [HAVA-FARK]'ta kalir (ses yalniz uyari + bakis).
5. Grup araci zaten biliyorsa (gorduyse) [MOTOR-SES] satiri gelmez.
Kapatma: motorSesOff. Hepsi (T) = dogrulanmadi.

## T-GERCEK-HEDEF (v8.247)
Trencher modulu (ya da herhangi bir Logic) dusman tarafli olsa bile tank `HEDEF: trencher_main_Module_TrenchController` secmemeli; savunma planinda 'dusman 6, objektife 19 m' hayalet sayilmamali. gercekHedefOff = true ile eski davranis (karsilastirma).

## T-ARKA-DESTEK (v8.248): ORP gerisinde pusuya dusen ekibe destek
Ortam: WEST ELE GECIR (6+ grup, BTR nakil), ORP'nin 400-800 m gerisinde, yol kenarinda (tercihen ORMANLIK) EAST pusu (3-6 asker). 
1. Pusu atesi acilinca ve ekip >= 6 sn temastayken: `[PLAN-ARKA-DESTEK] P.. | <ekip> temasta (ORP'den X m geride, ..) -> <grup> (YEDEK/MANEVRA) DESTEGE gidiyor | dusman N bilinen | ORMANLIK: ...`. En fazla 2 destek grubu.
2. Destek gruplari 25 sn sonra ORP'ye DONMEMELI (eski hata); ORP fazi destek gruplarini beklemeden ilerler.
3. Gorevden alma: `destekten ALINDI (bulustu (X m), Y sn temassiz ...)`; ormanlikta Y >= 90 sn, acikta >= 45 sn; 300 sn tavan.
4. Destek grubu tehlike altindaysa (kayip >= %60) mevzi mantigi / FRAGO ayri calisir.
Kapatma: arkaDestekOff. Hepsi (T) = dogrulanmadi.

## T-SAVUNMA-SURE + T-DRON-YARAT (v8.249)
1. Savunma suresi: Objektif > SAVUN, "Sure siniri" = 10 dk. Temas OLMADAN 10 dk sonra `[PLAN-SAVUNMA] ... 600 sn TEMASSIZ gecti` + `BITTI (savunma: 600 sn temassiz)`. Temas surerken (ya da objektif 400 m cevresinde bilinen dusman varken) sayac sifirlanir, plan BITMEZ. "Sinirsiz" secilirse 30+ dk temassiz beklese bile bitmemeli (eski surum 1200 sn'de bitiyordu).
2. Dron yarat: Zeus > ELITE IHA Gorevi > bos bir yere birak (40 m icinde dron yok), "Dron yarat" = Crocus AT; beklenen: sohbette `... yaratildi (B_Crocus_AT)` ve `IHA gorevi gonderildi`; sunucuda `[IHA-SORTI]`. Yakinda dron varsa yaratilmaz.
Hepsi (T) = dogrulanmadi.

## T-ARAC-ZIRH-KAC (v8.250)
Ortam: WEST BTR-80 (veya APC/IFV, ATGM'siz) yolcusuz / yolcuyla ELE GECIR planinda; EAST tarafinda ATGM'siz piyade degil bir TANK (T-72/T-14) acik arazide.
1. Tank BTR'yi gorunce (bilinen, <= 1200 m): `[ARAC-ZIRH-KAC] BTR-80 (<grup>, sinif IFV) | bilinen dusman tanki T-14 (zirh 500) X m -> gorus hattini kiran konuma cekiliyor <grid> (N m, engel true) | savas modu GREEN`. BTR planZirh ates pozisyonuna gitmeye CALISMAMALI, tankla duello yapmamali.
2. `[PLAN-ZIRH] ... HEDEF: rhs_t14_tv` satiri ATGM'siz IFV icin ARTIK gelmemeli (tank / ATGM'li araclar icin gelir).
3. Tank gorus disina cikinca 25 sn sonra `tehdit gecti ... savas modu ...'e geri`.
4. Ayni sahneyi `aracZirhKacOff = true` ile tekrarla (karsilastirma).
Sinirlar: duman yok; AT'li piyade (RPG / NLAW) kendi mantigiyla (AT_ENGAGE) calisir; kayip orani karsilastirmasi icin plan sonu [PLAN-OZET].
Hepsi (T) = dogrulanmadi.

## T-TANK-ATES (v8.251)
Ortam A (AT tepkisi): WEST tank (veya BTR/IFV) acik arazide; EAST'ten 300-800 m'de roketatarli piyade (RPG-7 / PCML) ya da ATGM'li arac, tanka dogru ates etsin.
1. Ates aninda: `[ARAC-AT-TEPKI] <arac> (<grup>, sinif TANK) | sebep ROKET | atici ... | duman true | yer degistirme NN m -> grid (engelli true) | ... koruyan piyade grubu N`. Arac korunakli konuma gider.
2. `[ARAC-DUMAN] ... fireAtTarget <silah> -> true | kalan N` ve oyunda tankin onunde duman gorunmeli. (`false` / silah YOK ise duman atici bulunamadi: silah adini rapor et.)
3. Isabet (hasar >= 0.05): `sebep ISABET` satiri.
4. 25 sn icinde ikinci roket ayni araca tepki tetiklemez (bekleme).
Ortam B (hedef dagitimi): 2 tank (ayni grup ya da yan yana) + karsida dusman tank + AT'li piyade + MG'li piyade + BTR: `[PLAN-ZIRH] ... HEDEF ... dagitim puani N` / `[TANK-ATES] ... HEDEF ... dagitim: yakinda dost tank true`; iki tank ayni anda ayni hedefe KILITLENMEMELI (tank hedefi haric: ortak ates serbest).
Ortam C (koru): tank + yakin dost piyade grubu (<= 400 m) + 450 m'de dusman roketatarci: `[TANK-KORU] ... N piyade grubu / M asker tehdide ates / bakis`. Piyade roketatarciya ates etmeli. Tank temasta ve piyade yoksa `[TANK-YALNIZ]` (teshis).
Karsilastirma: `tankAtesOff = true` ya da `aracAtTepkiOff = true` / `aracDumanOff = true` / `tankKoruOff = true` ile ayni sahneyi tekrarla.
Sinirlar: piyade tank yanina KONUMLANDIRILMAZ (yalniz ates / bakis); duman atici API'si (fireAtTarget) ve esikler (25 m + %3 sapma, 45/75/110 m, 0.05 hasar) TASARIM; yer degistirme sonrasi planli grup davranisi izlenmeli.
Hepsi (T) = dogrulanmadi.

## T-SAVUNMA-YARICAP (v8.252)
Ortam: SAVUN objektifi (OPFOR); haritada 6+ `elite_hendek*` alani (bazilari 14-30 m), 1-2 ELITE Karakol/Mevzi/Gozetleme kaydi (ayni taraf), 4 savunma grubu (8-9 kisilik). Objektif 3/4 panelinde "Mevzi arama yaricapi" = 500.
1. `[PLAN-MEVZI] ... N karakol / mevzi / gozetleme kaydi mevzi olarak plana alindi (objektife <= 500 m)`; `[PLAN] ... SAVUN: <grup> N asker, alan X kapasitesi K -> ek alanlar [[idx,say],...]`; bos alan kaldiysa `bos hendek alani ... -> <grup> grubundan N kisilik ekip`.
2. `[HENDEK-YERLES] <grup> | N asker hendege (alan X, N nokta, kapasite K)` birden cok satir (grup bolundu); `KAPASITE ASILDI` yalniz ek alan yoksa.
3. 92 sn sonra `[HENDEK-VARIS] <grup> | N asker: V noktada, Z zaman asimi (en uzak kalan M m)`. Zaman asimi > 0 ise hendegin yaninda bekleyenler var: o gruptan DURUM satirlari + hendek isareti boyutu/yonu rapor edilsin.
4. Karakol/gozetleme noktasina giden grup: `[PLAN-MEVZI] ... mevzi N` ve `[MEVZI] ... mevzi kuruldu: bina ...`.
5. Slider'i 100 yap: yalnizca 100 m icindeki alanlar kullanilir. `hendekEkOff = true` / `karakolMevziOff = true` ile karsilastir.
Sinirlar: hendek isareti kutu (dikdortgen); Trencher modunun gercek siperine uyum gorulmedi; AI'nin siperin icine girmesi motorun yol bulmasina bagli. Hepsi (T) = dogrulanmadi.

## T-TANK-MURETTEBAT (v8.252)
Ortam: tek tank (T-14/T-72), karsida AT atesi; tank murettebatindan nisanci/surucuyu oldur ya da Zeus'tan tankin disina cikar.
1. Nisanci olurse: `[TANK-MURETTEBAT] ... koltuk degistirdi: komutan -> gunner` ve tank yine ates eder.
2. Disari inen murettebat (150 m icinde, saglikli): `... yayaydi (N m) -> <rol> koltuguna donuyor`.
3. Duman: `[ARAC-DUMAN] <arac> duman silahlari: [...]` ve `... fireAtTarget true | cephane A -> B | ATILDI`. `ATILMADI -> YEDEK forceWeaponFire` satiri gelirse yedek yol calisiyor mu oyunda bak.
Karsilastirma: `tankMurettebatOff = true`, `aracDumanOff = true`. Hepsi (T) = dogrulanmadi.

## T-TANK-MURETTEBAT-2 (v8.253)
Ortam: grubun lideri tank murettebatindan; tank vurulup (surucusuz / canMove false) murettebat insin, temas surerken.
1. `[ARAC-UZAK] ... dost arac (temas)` satiri murettebat icin ARTIK gelmemeli (baska piyade icin gelir).
2. Nisanci/surucu yayaysa tank `[TANK-MURETTEBAT] ... BEKLIYOR: N murettebat yayada` ile en cok 25 sn durur; murettebat binince `... koltuguna donuyor`.
3. Lider yayaysa `[PLAN-ZIRH]` satirlari tank icin devam eder (eskiden sessizdi).
Karsilastirma: `aracUzakMurOff = true`, `tankMurettebatOff = true`. Hepsi (T) = dogrulanmadi.

## T-KAYIP-HQ-DONUS (v8.254)
A) Savunma: HQ'ya bagli SAVUN plani (ya da HQ'suz), 8+ askerli gruplar; karsi tarafi guclu yap (topcu / tank). Kayip %50'ye varinca:
 1. `[PLAN-SAVUNMA] ... KAYIP yuzde N (esik 50) ve dusman M: mevzi tutulamiyor, HQ'ya donus`, `[PLAN-KAYIP-DONUS] ... N grup cekiliyor -> <HQ id | rally point> (grid)`.
 2. `[PLAN] ... FAZ BEKLE -> CEKILME`, 150 sn sonra `FAZ CEKILME -> DONUS`, gruplar HQ/RP'ye yurur (hendekten cikarlar, `[TACTICS-CAGRI]`/retreat satirlari), sonunda `HQ'ya donuldu`.
B) Ele gecir: ORP/KESIF/SALDIRI sirasinda pusu/topcuyla %50 kayip: `[PLAN-KAYIP-DONUS] ... fazinda kayip yuzde N` -> CEKILME -> DONUS. (SALDIRI'da eski FRAGO satiri `saldiri kaybi yuzde N` + simdi cekilme emri de verir.)
Karsilastirma: `kayipDonusOff = true` (savunma eski %60/BITTI davranisi), `fragoOff = true`.
Sinirlar: yalniz PLAN gruplari; plansiz gruplar ve tek tek moral/teslimiyet mantigi degismedi; esikler TASARIM; geri cekilirken topcu/tank atesi altinda kayip surebilir. Hepsi (T) = dogrulanmadi.

## T-TANI (v8.255)
Ortam: onceki testlerdeki gibi (savunma hendekleri + topcu + tank + piyade). Test sonrasi `python tools/rpt_ozet.py --tani <server.rpt>` (ve istemci RPT'si) calistir.
1. ELITE-BOOT satiri `v8.255-TANI`, `[TANI] tani paketi kuruldu` gorunmeli.
2. `[OLUM-TANI]` her olumde; `--tani` ozeti: hendek grubundan kac olu hendek DISINDA, kaci topcu dususune denk (<=35 m, <=3 sn).
3. `[HENDEK-DURUM] ... t=30sn / t=90sn`: atanan / icinde / yolda / disinda. `atanan > kapasite` CIKARIM satiri hendek kapasitesi sorununu gosterir; `nesneler=` alanda Trencher / hendek nesnesi var mi.
4. `[ARAC-TERK]`: murettebat inince neden (hasarli parca, canMove, birim komutu, son hasar yasi).
5. `[ARAC-HAREKET]`: tank durduktan sonra neden kalkti (surucu komutu, beklenen hedef, planZirh / hide / vardi bayraklari).
6. `[KAYIP-DEGERLENDIRME]` 30 sn'de bir; esik %50.
Sinirlar: HC varsa HC'nin RPT'si de gerekir; 'topcu_olasi' bir ESTIRIM (zaman + mesafe eslesmesi), kesin neden degil. Hepsi (T) = dogrulanmadi.

## T-HENDEK-KILIT (v8.256)
Ortam: v8.255 sahnesi (savunma hendekleri + hendek yaninda dost tank + yaklasan dusman tanklari + AT'li piyade) + 1-2 bos DShK / MG statik silah hendeklerin yaninda (<= 250 m).
1. `[MEVZI-STATIK] <grup> | <asker> (MG) -> <statik> (N m, grup liderine M m)`; statik silahta nisanci gorunur. Atanmazsa `[MEVZI-STATIK] ... yaricapta ... baska statik var: [...]` (RHS statik sinifi beklenen tur degil; sinif adini rapor et).
2. Dusman gorunce hendek grubundan kimse alan disina cikmamali: `[ARAC-UZAK] ... dost arac (temas)` hendek grubu icin GELMEMELI; `[MEVZI-KILIT]` satiri gelirse kimin hangi komutla ciktigi yazar (ayni saniyedeki [KOMUT] satirlarina bak) ve geri cagrilir.
3. `[MEVZI-TUT] ... tehdit_gecerli false` gorulurse eski bosluk (hedef gecersiz) yakalanmis demektir.
4. Tank: motoru vurulunca `[ARAC-TERK]` GELMEMELI (allowCrewInImmobile); gelirse parca / komut yazar. `[TANK-MURETTEBAT] DONGU KESILDI` gelirse in-bin dongusu var.
5. Duman: `[ARAC-DUMAN] ... | ATILDI (FAT|FWF|ACT)` ya da `HICBIRI CALISMADI` (taret_birimi ve yol bilgisiyle). Calisan yontem sonraki atislarda once denenir.
6. `python tools/rpt_ozet.py --tani <rpt>`: OLUM TANISI artik tum olumleri sayar (OLUM-TANI hata duzeltmesi).
Karsilastirma: `mevziKilitOff`, `mevziStatikOff`, `crewImmobileOff`, `aracUzakMurOff`. Hepsi (T) = dogrulanmadi.

## T-TANK-KILIT (v8.257)
Ortam: savunma planinda dost T-14 (hendek yakininda) + yaklasan dusman tanklari / AT'li piyade.
1. Tank mevziye varinca `[PLAN-ZIRH] ... mevzide: surucu MOVE KAPALI`; ardindan `[ARAC-HAREKET]` ile `surucu_komut=ATTACK` + hizlanma GELMEMELI (gelirse: tankKilitOff acik mi, hangi kod doMove vermis?).
2. AT tepkisi sonrasi yeni yer ilk mevziye <= 150 m: `[ARAC-AT-TEPKI] ... yer degistirme N m -> grid` gridleri zincirleme uzaklasmamali.
3. `[PLAN-ZIRH] ... TAKILDI` hareket edemeyen tankta ve murettebat beklerken GELMEMELI; gelirse ara nokta <= kalan mesafenin %60'i.
4. Hendek: ek alan ekiplerinin sagliklari `[MEDIC-TASMA]` ile geri yurumemeli; `[KOMUT] ... Group Suppress (Move)` / `Hide (holding)` hendek gruplari icin GELMEMELI; gelirse `[MEVZI-KILIT]` geri gonderir.
Karsilastirma: `tankKilitOff = true`, `mevziTutOff = true`. Hepsi (T) = dogrulanmadi.

## T-GUC-ORANI (v8.258)
Ortam: ELE GECIR (WEST) ~24-32 asker + 3 tank; savunan (EAST) ~30 asker + hendek + T-14 (esit / yakin sayi). Objektif panelinde 'Min. kuvvet orani' = 2.
1. KESIF sonunda `[PLAN-ORAN] ... kuvvet orani dost N : dusman M = x < esik 3.00 (hazirlanmis savunma true) -> SALDIRI ERTELENDI (t / 300)`; 30 sn'de bir tekrar.
2. 300 sn sonra `[PLAN-KAYIP-DONUS] ... kuvvet orani yetersiz ... saldiri iptal` -> CEKILME -> DONUS (HQ). Oran duzelirse (topcu / takviye) `SALDIRI IZINLI`.
3. Slider 0: kapi yok, esit sayiya saldirir (eski davranis). Dusman bilinmiyorsa (recon yok, tahmin 0) kapi gecilir - bu bir bilgi sinirlamasi.
4. Panik: dusman tankina karsi AT'siz askerde `[PANIK] ... neden: zirh korkusu (tank N m)` ve KACIS; kacis yonu sag / sola daginik.
5. Tank yaklasma: `[PLAN-ZIRH] ... TAKILDI` ve 'pozisyona N m' duzenli azalmali (eskiden her 25 sn'de 25 m); WEST tank 650 m'yi ~2 dk'da gecmeli.
Karsilastirma: `oranKapisiOff`, `panikSans`, `lambs_danger_tankKilitOff`. Hepsi (T) = dogrulanmadi.

## T-TESLIM (v8.259)
Ortam: yogun catisma; bir tarafin grubu %60+ kayip verip dusmana <= 120 m. CBA > LAMBS Danger > ELITE moral / teslim.
1. Varsayilan: kayip >= %60, kalan <= 4, baski >= 0.4, moral < 0.30 -> `[TESLIM] ... asker teslim oldu`. Olmuyorsa `[TESLIM-ADAY] ... izin=... moral=... kalan=... baski=... dusman=...` satiri hangi kosulun tutmadigini gosterir.
2. Fraksiyon: 'Asla teslim olmayan' kutusuna fraksiyon adinin parcasini yaz (RPT [DOKTRIN-PROFIL] / TESLIM-ADAY satirindaki fraksiyon=...): o fraksiyon `izin=false` olmali. 'Her zaman' listesi ve taraf kutulari ayni sekilde dene.
3. Ana anahtar kapali -> hicbir taraf teslim olmaz. Esik slider'lari degisince davranis degisir.
Not: ACE esir mekanigi / teslim olanlarin esir alinmasi bu surumde degismedi. Hepsi (T) = dogrulanmadi.


## T-IHA-SUNUCU (v8.260)
1. Zeus > ELITE IHA Gorevi > 'Dron yarat' = O_Crocus_AT, Gorev = Sorti, Tur = FPV-AT; yakinda bilinen dusman zirh olsun.
2. RPT: `[IHA-SORTI] O_Crocus_AT sunucuda yaratildi (40 m, FLY)` sonra `[IHA-SORTI] ... | mod SORTI | tur FPV-AT` ve `hedef ...` satirlari beklenir; 'Suspending not allowed' hatasi OLMAMALI.
3. Dron patlarsa `[IHA-SORTI] ... YOK OLDU | yukseklik .. m | hiz .. | olduren ..` satiri nedeni verir (hedefe vurma `HEDEFE VURDU` satiri ayridir).
4. Dron yerde/yakinda hazir yerlestirilmisse (yaratma = Yok) eski yol: mod yerel degilse setOwner 2 denenir.
Hepsi (T) = dogrulanmadi.

## T-ORAN-ERKEN (v8.261)
Ortam: ELE GECIR plani, objektifte ~30 dusman (hendek / bina), plan 8 grup (~32 asker) + 1 tank + 2 BTR, objektif 3 km uzakta; Zeus 'Dusman sayisi' = 30, guven = ORTA; recon grubu ata. Min. kuvvet orani 2.
1. Recon OP'ye gider, rapor gelir (`[PLAN-ISTIHBARAT] RAPOR`). Hemen ardindan beklenen: `[PLAN-ORAN] ... ERKEN (recon raporu) | dost X : dusman TAHMIN Y (gozlenen G + OPORD iddia C x agirlik W | guven ORTA | gozlem kalitesi Q) ... BEKLE`.
2. Piyade RP'de, BTR'ler piyadeyi almiyor / kalkmiyor, tank mevziye varmadiysa durur: `[PLAN-ZIRH] ... ORAN BEKLEME`. 300 sn sonra `[PLAN-KAYIP-DONUS]` / saldiri iptal.
3. Iddia 30 ama recon 10 dusman gordu, tam gozlem: tahmin ~ 10 + 20x0.35 = 17 (iddia tek basina 30 sayilmaz). Iddia 10 ama gozlenen 25: tahmin 25 (gercek gozlem iddiaya ustun).
4. Dost sayisini artir (ya da esigi 1'e indir): `... SALDIRI IZINLI`, tank ilerler, nakil kalkar.
5. Eski (KESIF sonu) kapi ayni `_oranKontrol` ile calismaya devam eder (`KESIF` etiketi).
`python3 tools/rpt_ozet.py --tani <rpt>` KUVVET ORANI KAPISI bolumu. Hepsi (T) = dogrulanmadi.

## T-TASIMA-EK-ARAC (v8.262)
1. ~28 asker (7 grup), Zeus TASIMA: 2-3 BTR-80 + 3 Ural (Flat), ayrica bir medevac grubu (MEDEVAC atamasi) ve atanmamis bir APC (or. Namer, AI suruculu) 600 m icinde.
2. Beklenen RPT: `[TASIMA] ATANMIS ARAC UYGUN DEGIL: Ural-4320 (Flat) | bos kargo yeri 2`; koltuk yetmiyorsa `[TASIMA] ... EK ARAC: <apc> atanmamis ama uygun`; `MEDEVAC REZERVI ATLANDI` (rezerv ayrilirsa kalan koltuk yetmiyor demektir). `yaya kalan birim` sayisi 0'a yakin.
3. Ural (Open / Covered) ata: 16+ koltuk, nakilde kullanilir.
Hepsi (T) = dogrulanmadi.

## T-KIN-KORUMA (v8.263)
1. Recon aracini agaclik / duvar yanina park et (AI surmesin diye yola cikis yolunu kapat) ya da AI'yi surmeyecek bicimde engelle; KURTARMA 3 -> `[TASIMA-KIN] kinematik surus basladi`.
2. Beklenen: arac nesneye itilmez (dur / sap), `canMove` true kalir, 8 sn ilerleme yoksa `arac bos noktaya tasindi`; araci Hit ile elle vurursan (mermi) hasar normal islenir.
3. `[ARAC-TERK]` satirinda tekerler / camlar 1.0 gorulmemeli.
Hepsi (T) = dogrulanmadi.

## T-RECON-SABIR (v8.264)
1. Zeus RECON ARACI = UAZ-469 (ya da onceki sorunlu arac), recon 3 asker, hedef 2 km+.
2. RPT: `[RECON-ARAC-HAREKET] ... t+3 ... hiz ... yon farki ...` satirlari AI'nin ne yaptigini gosterir (geri vites mi, donuyor mu). `KURTARMA 3 ... kinematik` ilk ~38 sn'den once GORULMEMELI; AI 38 sn icinde gittiyse kinematik hic baslamaz.
3. `python3 tools/rpt_ozet.py --tani <rpt>`: RECON ARACI AI SURUSU bolumu.
Hepsi (T) = dogrulanmadi.

## T-TANK-PIYADE-BAG (v8.265)
1. ELE GECIR plani, objektif 2.5+ km, 1 tank + piyade (yaya + BTR). Tank piyadeden hizli.
2. Beklenen RPT: tank piyadenin 400 m'den fazla onune gecince `[PLAN-ZIRH] ... PIYADE BAGI: tank piyadenin X m onunde ... BEKLIYOR`; piyade yetisince `PIYADE BAGI bitti ... tank ilerliyor`. SENKRON kapisi tankin beklemesi yuzunden 420 sn tavana takilmamali (`[PLAN] SENKRON: nakil serbest birakildi` makul surede). 300 sn dolarsa `ZAMAN ASIMI`.
3. CBA: Tank piyade bagi AKTIF kapali -> tank eskisi gibi tek basina ilerler.
## T-TANK-TERK (v8.265)
1. Tank motorunu vur (hitengine ~0.9): `[TANK-IMMOBIL] ... canMove false | canFire ... | parcalar >0.5: [...]`, `[PLAN-ZIRH] ... HAREKET EDEMIYOR`.
2. Murettebat 4 kez geri donup ejekte edilirse (ya da 3 / 60 sn) `[TANK-TERK] ... terk eden murettebat N -> <grup> grubuna katildi`; murettebat yakindaki piyade grubuyla birlikte hareket eder, tanka tekrar kosmaz.
3. Tanki onar (ACE): `[TANK-TERK] tekrar hareket edebiliyor: terk kalkti`, planZirh pozisyonu yeniden secer.
`python3 tools/rpt_ozet.py --tani <rpt>`: TANK PIYADE BAGI / HAREKET EDEMEYEN TANK bolumu. Hepsi (T) = dogrulanmadi.

## T-OYUNCU-GRUBU-ARAC (v8.266)
1. Oyuncu squad lideri; botlar BTR / tank murettebati (surucu, nisanci, komutan) ve yolcu. Catisma, temas bitince 30+ sn bekle.
2. Oyuncu aractan inip (ya da arac icinde 'Get Out' emriyle) botlari indirir: botlar INMELI, ELITE koltuga geri sokmamali. RPT'de bu botlar icin `[MURETTEBAT-KORU] ... INME EMRI IPTAL` / `koltuguna dondu` satiri OLMAMALI.
3. Oyuncu olmayan (AI) arac grubunda eski davranis (murettebat korunur) degismez.
Hepsi (T) = dogrulanmadi.

## T-IHA-BILINCLI (v8.267)
1. Zeus > ELITE IHA Gorevi > Dron yarat = O_Crocus_AT, Gorev = Sorti, Tetik = 1200: sahnede dron GORUNMEZ; RPT `[IHA-BEKLEME] ... firlatma emri kaydedildi ... tetik 1200 m`; 60 sn'de bir `bekliyor ... bilinen dusman yok`.
2. Firlatma noktasinin 1200 m icine, IHA tarafinin gorebildigi bir dusman TANKI getir (FPV-AT icin zirhli sart): `[IHA-BEKLEME] ... FIRLATMA: <grid> | tetik hedefi <sinif> (<m>)` ardindan `[IHA-SORTI] ... hedef ...` satirlari; dron o anda 40 m'de yaratilir.
3. Tetik 0: dron hemen yaratilir. Gorev = KALDIR + modulu firlatma noktasina birak: `Zeus KALDIR: 1 bekleyen firlatma emri iptal edildi`.
4. Dusman hic gelmezse 30 dk sonra `emir bitti: omur doldu (dron yaratilmadi)`.
Hepsi (T) = dogrulanmadi.

## T-IHA-OPERATOR (v8.268)
1. Dost bir askerin yanina (<= 40 m) 'ELITE IHA Gorevi' birak: Operator bagi = 'olunce dron DUSER', Dron yarat = O_Crocus_AT, Tetik = 0 (ya da dusman yakinda), Sorti. systemChat `IHA operatoru: <isim>`.
2. Sorti sirasinda operatoru oldur (Zeus / ates): RPT `[IHA-SORTI] ... OPERATOR OLDU (...) -> KONTROL KAYBI`, dron alcalir, `kontrolsuz dron yere carpti / imha edildi`.
3. Mod 'DALAR': dron hedefe dalis yaparken operator olursa `HEDEFE VURDU`; hedef secme asamasindayken olursa `operator olu: hedef kilitli degil -> yeni hedef secilmiyor` + dusme.
4. Firlatma emri bekliyorken operator olurse `[IHA-BEKLEME] ... OPERATOR OLDU: firlatma emri iptal`.
5. 40 m icinde dost asker yoksa `operator BAGSIZ` uyarisi; Bagsiz seciliyse operator olumunun dronu etkilemedigi eski davranis.
Hepsi (T) = dogrulanmadi.

## T-FORM-SEYIR (v8.269)
1. Temas etmemis bir AI grubunu (4+ asker) acik arazide uzak bir noktaya yuru (Zeus waypoint ya da ELE GECIR plani; yakinda dusman yok).
2. Beklenen: hareket baslayinca ~25 sn icinde `[KOMUTAN-FORM] <grup> | SEYIR | formasyon -> COLUMN | tehdit 9999 m` (ya da plan objektifine mesafe); yol uzerinde COLUMN, orman / meskun STAG COLUMN, yaklasinca (<1200 / <600 / <250 m) STAG COLUMN > WEDGE > VEE. Gruplar goruntude farkli formasyonda ilerlemeli.
3. Duran / mevzideki / recon grubu formasyonu degismemeli. `python3 tools/rpt_ozet.py --form <rpt>` SEYIR FORMASYONU satiri.
4. Salinim kontrolu: ayni grupta 60 sn'den kisa aralikla ardisik degisim OLMAMALI (`--form` [SORUN] vermemeli).
Hepsi (T) = dogrulanmadi.
