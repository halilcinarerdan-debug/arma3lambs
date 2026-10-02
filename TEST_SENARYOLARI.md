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
| 12 | **Doktrin puani** | Her senaryo | `[DOKTRIN]` | Ortalama >= 70; `komutan_onde:true` orani <= %30 |

## Bilinen sinirlar
- LAMBS taban FSM'i (Dodge, sympathetic assault, Checking bodies) derlenmis pbo'da; sadece `disableGroupAI` ve `forceMove` ile bastirilabilir.
- El bombasi ATISI (AI'nin bomba atmasi) LAMBS tabanindadir; bu fork yalnizca tepkiyi ve tanilari yonetir.
- Mod hatalari (`setHitPointDamage`, `fnc_throwWeapon`, `Bone ...`) bu fork'a ait degildir; `rpt_ozet` bunlari ayiklar.
