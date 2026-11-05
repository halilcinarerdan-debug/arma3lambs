# UYUM DENETIMI (statik; kod degistirmez)

Cakisma adayi = ayni uzva birden fazla ALAN yaziyor. Gercek cakisma RPT ile dogrulanir (`[UYUM]` etiketi hakem eklenince).

## 1. Uzuv ozeti

| Uzuv | Dosya | Cagri | Alan dagilimi (dosya) |
|---|---|---|---|
| HIZ | 54 | 178 | ARAC:20, PIYADE-MIKRO:18, TAKTIK:10, DIGER:4, PLAN:2 |
| HAREKET | 95 | 421 | DIGER:40, ARAC:21, PIYADE-MIKRO:18, TAKTIK:11, PLAN:5 |
| DAVRANIS | 67 | 299 | DIGER:24, PIYADE-MIKRO:13, ARAC:13, TAKTIK:12, PLAN:5 |
| BINIS | 15 | 69 | ARAC:11, DIGER:3, PLAN:1 |
| FORMASYON/TAKIP | 43 | 62 | DIGER:18, TAKTIK:13, ARAC:6, PIYADE-MIKRO:4, PLAN:2 |

## 2. ARAC SURUCUSU cakisma kumesi (HIZ + HAREKET + BINIS; ARAC ve PLAN alanlari)

Bu bolum oturumdaki RPT sorunlarinin (konvoy gecme, kalkmayan arac, ping-pong) bulundugu yer.

**HIZ** (22 dosya): fnc_aracAtTepki(1), fnc_aracKinSurus(1), fnc_aracMedevac(2), fnc_aracSenkron(2), fnc_aracSurmeDeney(2), fnc_aracSurmeTani(1), fnc_aracTasima(21), fnc_aracUnstuck(3), fnc_aracZirhKac(1), fnc_ezmeKoruma(4), fnc_komutanPlanDongu(10), fnc_mekanizeIzle(4), fnc_nakilV2(13), fnc_orphanWatchdog(1), fnc_planZirh(10), fnc_reconArac(11), fnc_surusAB(6), fnc_tankAralik(3), fnc_tankDron(1), fnc_tankDuello(1), fnc_tehlikeAlani(4), fnc_zirhBekle(1)

**HAREKET** (26 dosya): fnc_aracAtTepki(2), fnc_aracKinSurus(2), fnc_aracMedevac(4), fnc_aracSurmeDeney(8), fnc_aracSurmeTani(3), fnc_aracTasima(52), fnc_aracUnstuck(8), fnc_aracUzak(1), fnc_aracZirhKac(2), fnc_ezmeKoruma(2), fnc_hqDestek(1), fnc_hqEmir(1), fnc_karakolGarnizon(16), fnc_komutanPlanDongu(8), fnc_murettebatKoru(2), fnc_nakilV2(21), fnc_planZirh(21), fnc_reconArac(25), fnc_surusAB(25), fnc_taksi(2), fnc_tankAralik(2), fnc_tankDron(4), fnc_tankDuello(2), fnc_tankMurettebat(3), fnc_tehlikeAlani(7), fnc_zirhBekle(2)

**BINIS** (12 dosya): fnc_aracFfvDuzelt(4), fnc_aracKinSurus(2), fnc_aracMedevac(2), fnc_aracTasima(12), fnc_aracYolcuKoy(1), fnc_murettebatKoru(4), fnc_nakilV2(10), fnc_planZirh(1), fnc_reconArac(7), fnc_surusAB(11), fnc_taksi(5), fnc_tankMurettebat(6)


## 3. Birakma disiplini (forceSpeed): deger koyan ama -1 ile BIRAKMAYAN dosyalar

| Dosya | Alan | forceSpeed koy | forceSpeed -1 |
|---|---|---|---|
| fnc_surusAB | ARAC | 4 | 0 |
| fnc_aracSurmeDeney | ARAC | 1 | 0 |
| fnc_moduleSurusAB | DIGER | 1 | 0 |

## 4. Cakisma adaylari: ayni uzva en cok farkli alan yazan uzuvlar

- HIZ: 5 alan ['ARAC', 'DIGER', 'PIYADE-MIKRO', 'PLAN', 'TAKTIK']
- HAREKET: 5 alan ['ARAC', 'DIGER', 'PIYADE-MIKRO', 'PLAN', 'TAKTIK']
- DAVRANIS: 5 alan ['ARAC', 'DIGER', 'PIYADE-MIKRO', 'PLAN', 'TAKTIK']
- FORMASYON/TAKIP: 5 alan ['ARAC', 'DIGER', 'PIYADE-MIKRO', 'PLAN', 'TAKTIK']
- BINIS: 3 alan ['ARAC', 'DIGER', 'PLAN']

## 5. Ayrinti: HIZ yazan ARAC / PLAN dosyalari ve satirlar (ilk 3)

### fnc_aracAtTepki (ARAC)
- `83`: `_d enableAI "PATH"; _d enableAI "MOVE"; _d forceSpeed -1;`
### fnc_aracKinSurus (ARAC)
- `76`: `_uk enableAI "PATH"; _uk enableAI "MOVE"; _uk forceSpeed -1;`
### fnc_aracMedevac (ARAC)
- `38`: `_vg setSpeedMode "FULL";`
- `117`: `_vg setSpeedMode _eskiHiz;`
### fnc_aracSenkron (ARAC)
- `49`: `_d forceSpeed -1;`
- `121`: `_d forceSpeed _hiz;`
### fnc_aracSurmeDeney (ARAC)
- `45`: `["AI-OZELLIK", { params ["_v", "_d", "_h"]; _d enableAI "PATH"; _d enableAI "MOVE"; _d forceSpeed 9; }],`
- `63`: `["DAVRANIS", { params ["_v", "_d", "_h", "_vg"]; _vg setBehaviour "AWARE"; _vg setSpeedMode "FULL"; _vg setCom`
### fnc_aracSurmeTani (ARAC)
- `67`: `_d2 enableAI "PATH"; _d2 enableAI "MOVE"; _d2 forceSpeed -1;`
### fnc_aracTasima (ARAC)
- `474`: `_vg setSpeedMode "NORMAL";`
- `549`: `_v engineOn true; _d forceSpeed -1; doStop _d; _d doMove _pk; _sonMove = time;`
- `740`: `_d forceSpeed -1;`
### fnc_aracUnstuck (ARAC)
- `142`: `_d enableAI "PATH"; _d enableAI "MOVE"; _d forceSpeed -1;`
- `181`: `_d enableAI "PATH"; _d enableAI "MOVE"; _d forceSpeed -1;`
- `188`: `_d enableAI "PATH"; _d enableAI "MOVE"; _d forceSpeed -1;`
### fnc_aracZirhKac (ARAC)
- `86`: `_d enableAI "PATH"; _d enableAI "MOVE"; _d forceSpeed -1;`
### fnc_ezmeKoruma (ARAC)
- `49`: `if (_frenli && {!isNull _d} && {local _d}) then { _d forceSpeed -1; [_d, "HIZ", "ezme"] call FUNC(uzuvBirak); `
- `93`: `_d forceSpeed (if (_surekli > 30) then {1.4} else { if (_enYakin > 14) then { (((_enYakin - 6) / 2.2) max 1.4)`
- `102`: `_uk enableAI "PATH"; _uk enableAI "MOVE"; _uk forceSpeed -1;`
### fnc_komutanPlanDongu (PLAN)
- `525`: `_rg2 setSpeedMode "NORMAL";`
- `604`: `(group _d) setSpeedMode "FULL";`
- `605`: `_d enableAI "PATH"; _d enableAI "MOVE"; _d forceSpeed -1;`
### fnc_mekanizeIzle (ARAC)
- `53`: `_d forceSpeed -1;`
- `55`: `_say set ["forceSpeed-kaldirildi", (_say getOrDefault ["forceSpeed-kaldirildi", 0]) + 1];`
- `56`: `if (_logN < 40) then { _logN = _logN + 1; diag_log format ["[MEKANIZE-YAVAS] %1 | arac %2 | surucu forceSpeed `
### fnc_nakilV2 (ARAC)
- `233`: `_d enableAI "PATH"; _d enableAI "MOVE"; _d forceSpeed -1; _vg setBehaviour "SAFE"; _vg setSpeedMode "FULL";`
- `359`: `_d enableAI "PATH"; _d enableAI "MOVE"; _d forceSpeed -1;`
- `360`: `_vg setBehaviour "SAFE"; _vg setSpeedMode "FULL";`
### fnc_orphanWatchdog (ARAC)
- `89`: `_u forceSpeed -1;`
### fnc_planZirh (PLAN)
- `206`: `_g setBehaviour "COMBAT"; _g setCombatMode "RED"; _g setSpeedMode "FULL";`
- `207`: `_d enableAI "PATH"; _d enableAI "MOVE"; _d forceSpeed -1;`
- `297`: `_g setSpeedMode "NORMAL";`
### fnc_reconArac (ARAC)
- `91`: `if (alive _d) then { _d forceSpeed -1; _d setVariable [QGVAR(forceMove), nil]; _d enableAI "AUTOCOMBAT"; };`
- `111`: `_vg setBehaviour "SAFE"; _vg setSpeedMode "NORMAL";`
- `112`: `_d enableAI "PATH"; _d enableAI "MOVE"; _d forceSpeed -1;`
### fnc_surusAB (ARAC)
- `100`: `["L", "forceSpeed 9 + doMove", true, "FS9+DOMOVE", 0, "CARGO"],`
- `231`: `_g setSpeedMode "NORMAL";`
- `240`: `_d forceSpeed 9;`
### fnc_tankAralik (ARAC)
- `78`: `_dr forceSpeed ([((_onHiz * 0.8) max 1.5), 0] select _sert);`
- `79`: `[{ params ["_dd"]; if (!isNull _dd) then { _dd forceSpeed -1; [_dd, "HIZ", "tankAralik"] call lambs_danger_fnc`
- `107`: `_dr enableAI "PATH"; _dr enableAI "MOVE"; _dr forceSpeed -1;`
### fnc_tankDron (ARAC)
- `137`: `_d enableAI "PATH"; _d enableAI "MOVE"; _d forceSpeed -1; _d setSpeedMode "FULL";`
### fnc_tankDuello (ARAC)
- `95`: `_d enableAI "PATH"; _d enableAI "MOVE"; _d forceSpeed -1;`
### fnc_tehlikeAlani (ARAC)
- `85`: `{ _x setUnitPos "UP"; _x forceSpeed -1; _x setSpeedMode "FULL"; _x doMove (_hedefNokta getPos [random 4, rando`
- `92`: `{ _x setUnitPos "UP"; _x forceSpeed -1; _x setSpeedMode "FULL"; _x doMove (_hedefNokta getPos [random 5, rando`
- `136`: `_x forceSpeed -1;`
### fnc_zirhBekle (ARAC)
- `132`: `_d enableAI "PATH"; _d enableAI "MOVE"; _d forceSpeed -1;`
