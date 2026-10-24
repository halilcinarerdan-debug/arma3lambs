# RHS / CUP / vanilla uyumluluk (v8.344)

Kullanici: "rhs cup kullaniyorum, sistemin tamamini bu iki moda ne olur ne olmaz uyumlu hale getir; test ortaminda tek RHS var".
**Durum:** yalniz RHS (+ ACE, Crocus FPV, CBA, Zeus Enhanced) ile OYUNDA test edildi (RPT'ler). **CUP ile hic denenmedi**; asagidaki CUP maddeleri koddan / sinif ailesi mantigindan cikarimdir (T).

## Tasarim ilkesi
ELITE sinif ADINA degil **config ailesine** dayanir; bu yuzden RHS, CUP ve vanilla ayni yolu kullanir:
| Konu | Nasil bulunur | RHS | CUP | Notlar |
|---|---|---|---|---|
| Topcu / havan | `artilleryScanner > 0`, `getArtilleryAmmo` | calisiyor (M252, M109; RPT) | beklenen: calisir (M252, M109, D-30) | Kalibre RED'i mermi + arac adindaki '60mm / 81mm / 82mm / 120mm' alt dizesinden; baska kalibre (122 / 152 / 155) 455 m |
| Roketatar (MLRS / Grad / Smerch) | mermi adi haric listesi (`rocket`, `mlrs`, `9m22`, `9m28`, `bm21`, `grad`, `m270`, `tos1`...) | RHS 9M22 / 9M28 haric | CUP MLRS / BM21 haric | RED tablosu yok; dolayli atis sistemleri bunlari KULLANMAZ |
| Yanlis mermi | `fnc_topcuAtisHazirla` yabanci magazin temizligi | RHS M252'de vanilla 82 mm magazini bulundu (RPT) -> temizleniyor | ayni durum olasi (CUP + vanilla namlu uyumu) | `lambs_danger_topcuYabanciMermiOff` ile kapat |
| Tank / APC | `isKindOf "Tank"`, `Wheeled_APC_F`, `APC_Tracked_01_base_F`, config `armor` | calisiyor | CUP tankler `Tank`'tan turer; bazi CUP APC'ler farkli taban sinifta olabilir -> `armor >= 100` yolu da var | Tank secimi kacirilirsa `[PLAN-ARAC] ... plana ALINMADI` nedeni yazar |
| IHA / SIHA | `unitIsUAV`, `isKindOf "Air"` | vanilla UAV + Crocus (Zeus) | CUP MQ-9 / Raven benzeri `unitIsUAV` ise bulunur | Termal tahmini: sinif / ad icinde `_ti`, `thermal`, `flir`, `uav_0`, `mq9`, `predator`, `reaper`, `pchela`, `orlan`, `raven`; elle: arac degiskeni `lambs_danger_ihaTermal` |
| Dron turu | `fnc_ihaTip` (crocus / fpv / mavic / dji -> FPV / BOMBA, digerleri GOZLEM); gorev turu `ihaGorevTur` | calisiyor | CUP'ta FPV yok -> hepsi GOZLEM | FPV yalniz Crocus (workshop) |
| Doktrin profili | fraksiyon adi alt dizesi (`fnc_doktrin` haritasi) | `rhs_faction_usmc / usarmy / msv / vdv / rva / tv / socom / insurgents`, `rhsgref_*`, `rhssaf` -> eslesmeyen GENEL | `cup_b_us*`, `cup_b_baf / gb / ger / cz`, `cup_o_ru`, `cup_o_sla`, `cup_i_tk_gue`, `cup_o_chdkz`, `cup_i_napa`, `cup_i_pmc` | Bilinmeyen fraksiyon GENEL profile duser; kendi haritan: `lambs_danger_doktrinHaritasi` |
| Rol (MG / AT / sniper / UGL / sihhiye) | `CfgWeapons` turu + `attendant` + silah adi alt dizeleri | calisiyor | silah adlari alt dize listesinde (m24, m107, as50...) CUP'ta da genelde var | Rol yanlis cikarsa `[ROL-*]` loglarina bak |
| Sihhiye / TCCC | ACE Medical (`ace_medical`) varsa | calisiyor (RPT) | ACE ile ayni | ACE yoksa TCCC adimlari atlanir |
| Telsiz | `lambs_main_radioDisabled`, ACRE / TFAR / ItemRadio | ItemRadio | ayni | |
| FPV mod motoru | `FPV_AI_Drones_fnc_fpvLogic` varsa | yok/var, istege bagli | - | yoksa betik motoru |

## Acilista tani
`[MOD-UYUM]` (fnc_modUyum, 10 sn sonra): yuklu / yok mod listesi + mod basina `artilleryScanner` / `isUav` / `Tank` / `APC` sinif sayilari + lazer gudumlu magazin sayisi. CUP kurunca bu satirda `CUP topcu=N, CUP UAV=N` GORUNMELI; gorunmuyorsa CUP yuklenmemis ya da config yamasi adi farkli.

## CUP'ta ilk denemede bakilacaklar
1. `[MOD-UYUM] yuklu:` satirinda CUP; `CUP topcu` sayisi > 0.
2. CUP M109 / M252 ile `[DRON-KARSI-ATES] ... ATIS EMRI` + `[TANI-TOPCU] dusme` hedefe yakin mi; degilse `YANLIS MERMI` / `YABANCI MERMI` satirlari.
3. CUP tank / APC `[PLAN-ARAC] ... [TANK]` ile plana aliniyor mu.
4. CUP piyade `[ROL-SIRA]` rol dagilimi mantikli mi (MG:/AT:/saglikci:).
5. CUP UAV (Raven / MQ-9) `[SIHA-KESIF]` sortiye aliniyor mu (ucuyor olmali; ucak tipi yerden kalkmaz).

## Bilinen riskler
- CUP + RHS birlikte: ayni namlu icin birden cok magazin ailesi (yabanci mermi temizligi bunu kapsar ama CUP'ta test edilmedi).
- Bazi CUP / RHS araclari `scope=1` ya da gizli siniflar; Zeus'ta gorunmeyen araclar `[MOD-UYUM]` sayimina girmez.
- Termal / gorus katsayisi (`fnc_ihaGorus`) mod UAV'lerinin gercek kamera ozelliklerini OKUMAZ; ad ile tahmin eder.
