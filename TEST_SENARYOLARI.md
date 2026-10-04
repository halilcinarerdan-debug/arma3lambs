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
