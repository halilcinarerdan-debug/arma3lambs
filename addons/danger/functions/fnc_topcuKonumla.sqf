#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * TOPCU YER DEGISTIRME (v8.181) — hedef topun minimum menzilinin icindeyse (ya da azami menzilin disindaysa) AI murettebatli top, hedefi menzile alan bir konuma yer degistirir.
 * Neden: RPT 3c7286a5 / ce7738ae: M109G'nin menzil ici mesafeleri 3500 m ve uzeri; hedef daha yakinsa (2402 m) ya da top plan sirasinda yer degistirdiyse atis "hedef menzil disi" ile hic yapilmiyordu.
 * Yontem: topun hedef yonunde 500 m adimlarla inRangeOfArtillery taranir (min / maks menzil); menzil disindaysa hedeften (min + 700 m) [ya da maks - 600 m] uzaga,
 *   hedefin ters yonune (topun mevcut yonu korunur) bos bir konum secilir, surucu oraya gider. Ayni top icin 300 sn'de bir emir verilir.
 *
 * Arguments:
 * 0: Top araci <OBJECT>
 * 1: Hedef <ARRAY>
 * 2: Plan kimligi (log) <STRING>
 *
 * Return Value:
 * Yer degistirme emri verildi mi <BOOL>
 * Public: No
*/

params [["_v", objNull, [objNull]], ["_obj", [0, 0, 0], [[]]], ["_id", "?", [""]]];
if (isNull _v || {!alive _v}) exitWith {false};
private _m = (getArtilleryAmmo [_v]) param [0, ""];
if (_m isEqualTo "") exitWith {false};
if (_obj inRangeOfArtillery [[_v], _m]) exitWith {false};
private _dr = driver _v;
if (isNull _dr || {isPlayer _dr} || {!local _v} || {(time - (_v getVariable ["lambs_danger_topcuKonumT", -999])) < 300}) exitWith {false};

private _yonT = (getPosATL _v) getDir _obj;
private _ici = [];
for "_d" from 500 to 20000 step 500 do { if (((getPosATL _v) getPos [_d, _yonT]) inRangeOfArtillery [[_v], _m]) then { _ici pushBack _d; }; };
if (_ici isEqualTo []) exitWith {
    diag_log format ["[PLAN-TOPCU] %1 | MENZIL TANISI: %2 hicbir mesafede menzil ici degil (ammo %3)", _id, typeOf _v, _m];
    false
};
private _dist = _v distance2D _obj;
private _min = _ici select 0;
private _max = _ici select (count _ici - 1);
private _hedefD = if (_dist < _min) then { _min + 700 } else { (_max - 600) max _min };
// hedefe gore konum: min ihlalinde hedefin ters yonune (topun bulundugu taraf), maks asiminda hedefe dogru
private _a = if (_dist < _min) then { _obj getDir _v } else { _obj getDir _v };
private _hP = _obj getPos [_hedefD, _a];
private _bos = _hP findEmptyPosition [0, 150, typeOf _v];
if (_bos isNotEqualTo []) then { _hP = _bos; };
if (surfaceIsWater _hP) then { _hP = _obj getPos [_hedefD, _a + 40]; };
if (surfaceIsWater _hP) exitWith { false };
_v setVariable ["lambs_danger_topcuKonumT", time];
(group _dr) setBehaviour "SAFE";
(group _dr) setSpeedMode "NORMAL";
_dr enableAI "PATH"; _dr enableAI "MOVE"; _dr forceSpeed -1;
_dr action ["EngineOn", _v];
_v engineOn true;
_dr doMove _hP;
private _wp = (group _dr) addWaypoint [_hP, 0];
_wp setWaypointType "MOVE";
_wp setWaypointName "ELITE TOPCU KONUM";
(group _dr) setCurrentWaypoint _wp;
diag_log format ["[PLAN-TOPCU] %1 | TOPCU YER DEGISTIRIYOR: %2 | hedef %3 m; menzil ici %4..%5 m -> yeni konum %6 (hedeften %7 m)", _id, typeOf _v, round _dist, _min, _max, mapGridPosition _hP, round (_hP distance2D _obj)];
true
