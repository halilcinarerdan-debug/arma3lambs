#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * OTOMATIK MEVZI / GARNIZON BOLGELERI (v8.327) — kullanici: 'sistem otomatik olarak (opsiyonel operasyon emri ile) arazi analizi ve sistemle uyumlu ORP / CCP uyumlu mevzi + garnizon bolgeleri koysun, askerler oralarda dursun dolassin'.
 * Objektif cevresinde (90-190 m halka, 30 derece adim) arazi analiziyle aday noktalar puanlanir; ORP / CCP / RP isaretlerine >= 70 m (cakisma yok) uzak olanlar secilir:
 *   KARAKOL (garnizon; nobet + devriye): bina yogunlugu x4 + CCP yakinligi (CCP'yi korur, 70-160 m) + tehdide gore GERIDE; yaricap 120 m
 *   MEVZI (en cok 2): tehdit yonune ±35 derece, ortu (agac / kaya / bina) + yukseklik; yaricap 90 m
 *   GOZLETME (1): tehdit yonu + yuksek nokta (fnc_araziAnaliz hakim nokta bonusu); yaricap 70 m
 * Kayitlar mevcut karakol sistemiyle (lambs_danger_karakolIstegi + lambs_danger_garnizonIstegi, fnc_karakolGarnizon bekcisi) kurulur: nobetciler pozisyonda durur, devriye alt gruplari bolgede dolasir; havuz kaynak gruptan en az 3 asker birakir.
 * Operasyon emri: ELITE Objektif 4/4 'Otomatik mevzi / garnizon bolgeleri' (0 Hayir / 1 Evet / 2 Evet guclu); savunma planinda plan kurulunca, saldirida OBJEKTIF ALINDI sonucunda calisir. Kapatma: lambs_danger_otoGarnizonOff = true.  Log: [OTO-GARNIZON]
 *
 * Arguments:
 * 0: Taraf <SIDE>
 * 1: Objektif <ARRAY>
 * 2: Tehdit yonu (derece, -1 = bilinmiyor) <NUMBER>
 * 3: ORP <ARRAY>
 * 4: CCP <ARRAY>
 * 5: RP <ARRAY>
 * 6: Plan kimligi (log) <STRING>
 * 7: Guc 1 / 2 <NUMBER>
 *
 * Return Value: Kurulan bolge sayisi <NUMBER>
 * Public: No
*/

params [["_taraf", sideUnknown, [sideUnknown]], ["_obj", [0, 0, 0], [[]]], ["_tehdit", -1, [0]], ["_orp", [], [[]]], ["_ccp", [], [[]]], ["_rp", [], [[]]], ["_id", "?", [""]], ["_guc", 1, [0]]];
if (!isServer || {missionNamespace getVariable ["lambs_danger_otoGarnizonOff", false]} || {_obj isEqualTo [0, 0, 0]}) exitWith {0};
if (!canSuspend) exitWith { _this spawn FUNC(otoGarnizon); 0 };

private _tehditP = if (_tehdit >= 0) then { _obj getPos [600, _tehdit] } else { [0, 0, 0] };
private _prof = [_obj, 150, _tehditP] call FUNC(araziAnaliz);
private _hakim = _prof getOrDefault ["hakim", []];
private _yasakNokta = [_orp, _ccp, _rp] select {_x isNotEqualTo []};
private _zObj = getTerrainHeightASL _obj;

// ---- adaylar ----
private _adaylar = [];
{
    private _r = _x;
    for "_b" from 0 to 330 step 30 do {
        private _p = _obj getPos [_r, _b];
        if (!surfaceIsWater _p && {(_yasakNokta findIf {(_x distance2D _p) < 70}) < 0}) then {
            private _evler = count ((nearestObjects [_p, ["House"], 45]) select {(count (_x buildingPos -1)) > 0});
            private _ort = count (nearestTerrainObjects [_p, ["TREE", "SMALL TREE", "ROCK", "ROCKS"], 22, false, true]);
            private _h = (getTerrainHeightASL _p) - _zObj;
            private _hiz = if (_tehdit >= 0) then { cos (_b - _tehdit) } else { 0 };
            _adaylar pushBack [_p, _r, _b, _evler, _ort, _h, _hiz];
        };
    };
} forEach [90, 140, 190];
if (_adaylar isEqualTo []) exitWith { diag_log format ["[OTO-GARNIZON] %1 | aday nokta yok (su / ORP-CCP cakismasi)", _id]; 0 };

private _secilen = [];
private _uzak = { params ["_p"]; (_secilen findIf {((_x select 0) distance2D _p) < 60}) < 0 };
private _sec = {
    params ["_puanFn", "_ad", "_yar", "_min"];
    private _en = [];
    private _enS = -1e9;
    {
        private _s = [_x] call _puanFn;
        if (_s > _enS && {(_x select 1) >= _min} && {[_x select 0] call _uzak}) then { _enS = _s; _en = _x; };
    } forEach _adaylar;
    if (_en isNotEqualTo []) then { _secilen pushBack [_en select 0, _ad, _yar, round _enS, _en]; };
};

// KARAKOL: bina + CCP yakinligi + tehdide gore geride
[{
    params ["_a"];
    _a params ["_p", "_r", "_b", "_ev", "_ort", "_h", "_hiz"];
    private _cd = if (_ccp isEqualTo []) then {100} else { _p distance2D _ccp };
    (_ev * 4) + ((160 - ((_cd min 160) max 70)) / 20) + (_ort min 6) - (_hiz * 8) - ((abs (_r - 90)) / 10)
}, "KARAKOL", 120, 90] call _sec;
// MEVZI x2: tehdit yonu ±35 derece, ortu + yukseklik (tehdit yoksa yan yana en iyi ortu)
for "_k" from 1 to 2 do {
    [{
        params ["_a"];
        _a params ["_p", "_r", "_b", "_ev", "_ort", "_h", "_hiz"];
        private _yonOk = if (_tehdit >= 0) then { [-30, 25 * _hiz] select (_hiz > 0.8) } else { 0 };
        _yonOk + ((_ort min 10) * 0.8) + (_ev * 1.5) + ((_h min 12) * 0.5) - ([0, 6] select (isOnRoad _p))
    }, "MEVZI", 90, 90] call _sec;
};
// GOZLETME: tehdit yonu + yuksek nokta (+ hakim nokta bonusu)
[{
    params ["_a"];
    _a params ["_p", "_r", "_b", "_ev", "_ort", "_h", "_hiz"];
    (_hiz * 15) + ((_h min 20) * 3) + ([0, 12] select (_hakim isNotEqualTo [] && {(_p distance2D (_hakim select 0)) < 60}))
}, "GOZLETME", 70, 140] call _sec;

private _say = 0;
{
    _x params ["_p", "_ad", "_yar", "_puan", "_ham"];
    private _adI = ["KARAKOL", "MEVZI", "GOZLETME"] find _ad;
    ["lambs_danger_karakolIstegi", [_taraf, _p, _adI, _yar, 0, false]] call CBA_fnc_serverEvent;
    _say = _say + 1;
    diag_log format ["[OTO-GARNIZON] %1 | %2 %3 | objektife %4 m (%5 derece) | bina %6 ortu %7 yukseklik %8 m | tehdit yonu uyumu %9 | ORP'ye %10 m CCP'ye %11 m | puan %12",
        _id, _ad, mapGridPosition _p, round (_p distance2D _obj), round (_ham select 2), _ham select 3, _ham select 4, round (_ham select 5), (_ham select 6) toFixed 2,
        [-1, round (_p distance2D _orp)] select (_orp isNotEqualTo []), [-1, round (_p distance2D _ccp)] select (_ccp isNotEqualTo []), _puan];
} forEach _secilen;
diag_log format ["[OTO-GARNIZON] %1 | arazi: aciklik %2 | hakim nokta %3 | %4 bolge kuruldu (guc %5)", _id, _prof getOrDefault ["aciklik", "?"], if (_hakim isEqualTo []) then {"yok"} else {mapGridPosition (_hakim select 0)}, _say, _guc];

// garnizon ayari (nobet + devriye) — karakol kaydi olusunca (2 sn)
sleep 2;
private _nobet = [[3, 2, 2], [5, 3, 3]] select ((_guc - 1) max 0 min 1);
private _dev = [[1, 0, 0], [2, 0, 0]] select ((_guc - 1) max 0 min 1);
{
    _x params ["_p", "_ad"];
    private _idx = ["KARAKOL", "MEVZI", "GOZLETME"] find _ad;
    ["lambs_danger_garnizonIstegi", [_p, 0, _nobet select _idx, _dev select _idx, 3, _ad isEqualTo "KARAKOL", false]] call CBA_fnc_serverEvent;
} forEach _secilen;
_say
