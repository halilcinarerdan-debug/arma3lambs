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
