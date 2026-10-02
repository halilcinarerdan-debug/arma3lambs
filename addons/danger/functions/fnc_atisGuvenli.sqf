#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * ATIS GUVENLIGI — RPG / UGL (40mm) atmadan once: dost atesi, geri patlama (backblast) ve ENGEL (calı / dal / duvar) kontrolu.
 *
 * Kontroller:
 *   1) minimum guvenli mesafe (hedefe): RPG 35 m, UGL 30 m
 *   2) DOST: hedef etrafinda patlama yaricapi (RPG 10 / UGL 12 m) icinde dost var mi; atis hatti koridorunda (4 m) dost var mi
 *   3) YAKIN ENGEL: namlunun ilk 12 m'sinde (gogus yuksekligi, 3 yonlu: duz + 0.7 m sag/sol) gorus/ates geometrisi (cali, dal, duvar, cit)
 *      varsa mermi seker / erken patlar -> ATMA
 *   4) HAT ENGELI: hedefe giden hat (hedef etrafi haric) kapaliysa ATMA (RPG icin sadece ilk engel hedef degilse)
 *   5) GERI PATLAMA (sadece RPG): atanin 8 m arkasi 60 derece konide dost / duvar var mi
 *
 * Arguments:
 * 0: Atici <OBJECT>
 * 1: Hedef <OBJECT | ARRAY (pos)>
 * 2: Tur <STRING> "RPG" | "UGL"
 *
 * Return Value:
 * Guvenli mi <BOOL>
 *
 * Public: No
*/

params [["_unit", objNull, [objNull]], ["_hedef", objNull, [objNull, []]], ["_tur", "RPG", [""]]];

if (isNull _unit) exitWith {false};
private _tPos = if (_hedef isEqualType objNull) then { getPosATL _hedef } else { +_hedef };
if (_tPos isEqualTo []) exitWith {false};

private _rpg = (_tur isEqualTo "RPG");
private _minMes = [30, 35] select _rpg;
private _yaricap = [12, 10] select _rpg;
private _uPos = getPosATL _unit;
private _d = _uPos distance2D _tPos;
private _gorev = {
    params ["_neden"];
    _unit setVariable [QGVAR(atisRet), [time, _neden]];
    if ((time - (_unit getVariable [QGVAR(atisRetLog), -999])) > 20) then {
        _unit setVariable [QGVAR(atisRetLog), time];
        diag_log format ["[ATIS-GUVENLIK] %1 | %2 atilmadi: %3 (%4 m)", name _unit, _tur, _neden, round _d];
    };
    false
};

if (_d < _minMes) exitWith {["hedef cok yakin"] call _gorev};

private _side = side group _unit;
private _dostlar = (allUnits select {
    alive _x && {_x isNotEqualTo _unit} && {(_side getFriend (side _x)) >= 0.6} && {(_x distance2D _unit) < 450}
});

// 2) hedef etrafinda dost
if ((_dostlar findIf {(_x distance2D _tPos) < _yaricap}) > -1) exitWith {["hedef cevresinde dost"] call _gorev};

// atis hatti koridoru (4 m): hatta (unit -> hedef) dik uzaklik
private _dir = _unit getDir _tPos;
private _hat = _dostlar findIf {
    private _dx = (_x distance2D _unit);
    private _a = (_unit getDir _x) - _dir;
    _dx > 1.5 && {_dx < (_d + 5)} && {(abs (sin _a)) * _dx < 4} && {(cos _a) > 0}
};
if (_hat > -1) exitWith {["hatta dost"] call _gorev};

// 3) yakin engel: ilk 12 m, gogus yuksekliginde 3 serit
private _bas = AGLToASL (_uPos vectorAdd [0, 0, 1.4]);
private _yaku = false;
{
    private _basS = AGLToASL ((_unit getPos [0.7, _dir + (_x select 1)]) vectorAdd [0, 0, 1.4]);
    private _son = AGLToASL (_unit getPos [([8, 12] select _rpg), _dir + (_x select 2)]);
    _son set [2, (_basS select 2) + ((((AGLToASL _tPos) select 2) + 1.2 - (_basS select 2)) * (12 / (_d max 12)))];
    if (terrainIntersectASL [_basS, _son] || {(lineIntersectsSurfaces [_basS, _son, _unit, objNull, true, 1, "FIRE", "VIEW"]) isNotEqualTo []}) exitWith { _yaku = true; };
} forEach [[12, 0, 0], [12, 90, 0], [12, -90, 0]];
if (_yaku) exitWith {["onunde cali/dal/engel (sekme)"] call _gorev};

// 4) hat engeli (SADECE RPG: duz giden roket). UGL yayli atar — hat kapali olsa bile (siperin / duvarin arkasi) atmasi tam da amaci;
//    UGL icin sadece yakin engel (3) ve dost (2) kontrolu yapilir
if (!_rpg) exitWith {true};
private _hedefASL = AGLToASL (_tPos vectorAdd [0, 0, 1.2]);
private _bitis = _bas vectorAdd (((_hedefASL vectorDiff _bas) vectorMultiply (((_d - 8) max 1) / (_d max 1))));
if ((lineIntersectsSurfaces [_bas, _bitis, _unit, objNull, true, 1, "FIRE", "VIEW"]) isNotEqualTo []) exitWith {["hat kapali (engel)"] call _gorev};

// 5) geri patlama (RPG): arkada 8 m, 60 derece kon
if (_rpg) then {
    private _arka = _dir + 180;
    private _bb = false;
    if ((_dostlar findIf {
        (_x distance2D _unit) < 8 && {(abs (((_unit getDir _x) - _arka + 540) % 360 - 180)) < 30}
    }) > -1) then { _bb = true; };
    if (!_bb) then {
        {
            private _p = AGLToASL ((_unit getPos [7, _arka + _x]) vectorAdd [0, 0, 1.2]);
            if ((lineIntersectsSurfaces [_bas, _p, _unit, objNull, true, 1, "FIRE", "VIEW"]) isNotEqualTo []) exitWith { _bb = true; };
        } forEach [0, 30, -30];
    };
    if (_bb) then { ["geri patlama (arkada dost/duvar)"] call _gorev } else { true }
} else { true }
