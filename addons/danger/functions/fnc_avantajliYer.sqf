#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * AVANTAJLI YER ANALIZI (v8.674; kullanici: 'araziye gore avantajli yer analiz edilsin, koy / ev barindiran bolgeler avantajli sayilsin'; RPT 8f8a8871: 'retreat cok kotu, avantajli pozisyonu ele gecirmiyorlar').
 * [merkez, tehdit, (yaricap), (mod)] -> [nokta (AGL), skor, ozet metin] YA DA []
 *
 * ESKI: geri cekilme noktalari yalnizca 'dusmandan uzaga 20-50 m, siperli / gorusu kesen' puanliyordu; arazi (yukseklik, sirt, cukur), KOY / EV kumesi ve gidis yolunun dusman gozunden gizliligi hic degerlendirilmiyordu,
 *   bina yakini ise CEZALIYDI (-25 / bina: duvar korumasi / navmesh sorunu icin).
 * SIMDI: merkezin 'tehdidin TERSI' yonundeki +-80 derecelik konisinde 4 halka (yaricap x 0.35 / 0.55 / 0.8 / 1.0) x 9 yon aday puanlanir (yuksek = iyi):
 *   + YUKSEKLIK: adayin tehdit konumuna gore yuksekligi (en cok +15 m) x 1.5 (alcak yer -0.7 / m)
 *   + GIZLILIK (dusman gozunden, arazi + nesne): ayakta (1.6 m) gizli +14; comelik (1.0 m) gizli +10; yatik (0.4 m) gizli +8
 *   + KOY / EV: 40 m icindeki bina (BUILDING / HOUSE / CHURCH / FUELSTATION) >= 3: +26 (koy), 1-2: +12; ek olarak kume icinde bina ile dusman arasinda KALAN nokta (hat binayla kesilir) +10; 6 m'den yakin bina -8 (icine dusmesin)
 *   + SERT NESNE (kaya / duvar / agac, 4 m): +6
 *   + GIDIS YOLU: merkez -> aday hattinin orta noktasi dusman gozunden gizliyse +10
 *   + MESAFE KAZANCI: adayin tehdide uzakligi - merkezin tehdide uzakligi (en cok +60 m) x 0.15; tehdide merkezden YAKIN aday -40
 *   - su / egim (yuzey normali z < 0.7): elenir
 *   KABUL: en iyi skor >= minSkor (22; mod GERI) ve merkezin kendi skorundan en az 8 iyi.
 * CBA: lambs_danger_avantajliYer (acik / kapali), lambs_danger_avantajYaricap (150 m). Log: [AVANTAJLI-YER] (ilk 20).
 *
 * Arguments:
 * 0: Merkez <ARRAY AGL>
 * 1: Tehdit pozisyonu <ARRAY AGL>
 * 2: Yaricap m (varsayilan CBA 150) <NUMBER>
 * 3: Mod "GERI" (varsayilan) <STRING>
 *
 * Return Value: [nokta, skor, ozet] ya da [] <ARRAY>
 *
 * Public: No
*/

params [["_c", [], [[]]], ["_t", [], [[]]], ["_yar", -1, [0]], ["_mod", "GERI", [""]], ["_minS", -1, [0]], ["_mar", -1, [0]]];   // v8.677: 5. / 6. parametre: kabul esigi / merkezden fazla puan (varsayilan kipe gore)
// v8.675 KIPLAR: "GERI" (geri cekilme: tehdidin tersi konide, GIZLILIK oncelikli, esik 22), "SAVUNMA" / "BND" (savunma mevzii / bounding ates ussu: TAM halka, ATIS ALANI KAPSAMI zorunlu (yatik gozden hedef gorulmeli),
//   gizlilik yerine ufuk cizgisi cezasi, dusmana 60 m'den yakin / merkezden 10 m'den fazla yaklasan elenir, esik 45 = 'mis gibi yer', merkezden >= 15 iyi)
private _savun = _mod in ["SAVUNMA", "BND", "YAKIN"];
if ((count _c) < 2 || {(count _t) < 2} || {!(missionNamespace getVariable ["lambs_danger_avantajliYer", true])}) exitWith {[]};

private _R = if (_yar > 0) then { _yar } else { ((missionNamespace getVariable ["lambs_danger_avantajYaricap", 150]) max 60) min 300 };
private _eASL = AGLToASL [_t select 0, _t select 1, ((_t param [2, 0]) max 0) + 1.6];
private _tH = getTerrainHeightASL _t;
private _d0 = _c distance2D _t;
private _geri = _t getDir _c;   // tehdidin TERSI yon (merkezden uzaklasma)

private _bSinif = ["BUILDING", "HOUSE", "CHURCH", "FUELSTATION"];
private _sertSinif = ["ROCK", "ROCKS", "WALL", "TREE", "HIDE"];

// atis alani ornekleri (SAVUNMA / BND): tehdit merkezi + yanal +-18 + derinlik +-12 m, gogus yuksekligi
private _dirT = _c getDir _t;
private _tz = (_t param [2, 0]) max 0;
private _ornek = [
    [_t select 0, _t select 1, _tz],
    (_t getPos [18, _dirT + 90]) vectorAdd [0, 0, _tz],
    (_t getPos [18, _dirT - 90]) vectorAdd [0, 0, _tz],
    (_t getPos [12, _dirT]) vectorAdd [0, 0, _tz],
    (_t getPos [12, _dirT + 180]) vectorAdd [0, 0, _tz]
] apply { AGLToASL (_x vectorAdd [0, 0, 1.0]) };

private _skor = {
    params ["_pt"];
    private _s = 0;
    private _h = ((getTerrainHeightASL _pt) - _tH) max -10 min 15;
    _s = _s + (if (_h >= 0) then { _h * 1.5 } else { _h * 0.7 });
    if (_savun) then {
        // ATIS ALANI: yatik goz (0.45 m) tehdit merkezi + yanal +-18 + derinlik +-12 m'den (5 ornek) kaci goruyor; merkez gorunmuyorsa aday elenir
        private _pA = AGLToASL [_pt select 0, _pt select 1, 0.45];
        private _gor = 0;
        {
            if (!(terrainIntersectASL [_pA, _x]) && {!(lineIntersects [_pA, _x, objNull, objNull])}) then { _gor = _gor + 1; };
        } forEach _ornek;
        if (_gor < 2 || {(terrainIntersectASL [_pA, _ornek select 0])}) then {
            _s = _s - 1000;   // atis alani yok: aday ELENIR (< -900)
        } else {
            _s = _s + (25 * (_gor / 5));
            private _dd = vectorNormalized (_pA vectorDiff _eASL);
            private _ileri = _pA vectorAdd (_dd vectorMultiply 300);
            if (!(terrainIntersectASL [_pA, _ileri]) && {!(lineIntersects [_pA, _ileri, objNull, objNull])}) then { _s = _s - 15; };
        };
    } else {
        private _g = [1.6, 1.0, 0.4] apply { (terrainIntersectASL [_eASL, AGLToASL [_pt select 0, _pt select 1, _x]]) || {lineIntersects [_eASL, AGLToASL [_pt select 0, _pt select 1, _x], objNull, objNull]} };
        if (_g select 0) then { _s = _s + 14; } else { if (_g select 1) then { _s = _s + 10; } else { if (_g select 2) then { _s = _s + 8; }; }; };
    };
    private _bin = nearestTerrainObjects [_pt, _bSinif, 40, false, true];
    private _nb = count _bin;
    if (_nb >= 3) then { _s = _s + 26; } else { if (_nb >= 1) then { _s = _s + 12; }; };
    if (_nb >= 1) then {
        // bina ile dusman arasinda kalan nokta: hat binayla kesiliyorsa (kume icinde) +10
        if (lineIntersects [_eASL, AGLToASL [_pt select 0, _pt select 1, 1.2], objNull, objNull]) then { _s = _s + 10; };
        if (((_pt distance2D (_bin select 0)) < 6)) then { _s = _s - 8; };
    };
    if ((nearestTerrainObjects [_pt, _sertSinif, 4, false, true]) isNotEqualTo []) then { _s = _s + 6; };
    _s
};

private _s0 = [_c] call _skor;
if (_s0 < -900) then { _s0 = -60; };
private _en = [];
private _enS = -1e9;
{
    private _r = _R * _x;
    for "_k" from 0 to ([8, 11] select _savun) do {
        private _pt = _c getPos [_r, if (_savun) then { _k * 30 } else { _geri + ((_k - 4) * 20) }];
        if (surfaceIsWater _pt) then { continue };
        if (((surfaceNormal _pt) select 2) < 0.7) then { continue };
        private _dT = _pt distance2D _t;
        if (_dT < (_d0 - ([5, 10] select _savun)) || {_savun && {_dT < ([60, 40] select (_mod isEqualTo "YAKIN"))}}) then { continue };
        private _s = [_pt] call _skor;
        if (_s < -900) then { continue };
        private _mid = _c getPos [(_c distance2D _pt) / 2, _c getDir _pt];
        if ((terrainIntersectASL [_eASL, AGLToASL [_mid select 0, _mid select 1, 1.0]]) || {lineIntersects [_eASL, AGLToASL [_mid select 0, _mid select 1, 1.0], objNull, objNull]}) then { _s = _s + 10; };
        if (!_savun) then { _s = _s + (((_dT - _d0) min 60) * 0.15); };   // mesafe kazanci yalniz geri cekilmede
        if (_s > _enS) then { _enS = _s; _en = _pt; };
    };
} forEach [0.35, 0.55, 0.8, 1.0];

if (_en isEqualTo []) exitWith {[]};
if (_enS < ([[22, 45] select _savun, _minS] select (_minS >= 0)) || {_enS < (_s0 + ([[8, 15] select _savun, _mar] select (_mar >= 0)))}) exitWith {[]};

private _nb = count (nearestTerrainObjects [_en, _bSinif, 40, false, true]);
private _ozet = format ["skor %1 (merkez %2) | yukseklik %3 m | bina %4 (40 m) | %5 m uzakta | tehdide %6 m", round _enS, round _s0, ((getTerrainHeightASL _en) - _tH) toFixed 1, _nb, round (_c distance2D _en), round (_en distance2D _t)];
if ((missionNamespace getVariable ["lambs_danger_avantajLogN", 0]) < 20) then {
    missionNamespace setVariable ["lambs_danger_avantajLogN", (missionNamespace getVariable ["lambs_danger_avantajLogN", 0]) + 1];
    diag_log format ["[AVANTAJLI-YER] %1 | %2 | koy / ev kumesi %3", _mod, _ozet, ["YOK", "VAR"] select (_nb >= 3)];
};
[_en, _enS, _ozet]
