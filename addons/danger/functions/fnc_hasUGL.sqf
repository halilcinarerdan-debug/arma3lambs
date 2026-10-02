#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * Askerin 40mm UGL (el bombasi atar) muzzle'ini doner.
 * Sonuc silah basina onbelleklenir (fnc_tacticalUGL ile ayni onbellek: QGVAR(glCache)).
 *
 * Arguments:
 * 0: unit <OBJECT>
 *
 * Return Value:
 * UGL muzzle adi <STRING> ("" = UGL yok)
 *
 * Example:
 * [bob] call lambs_danger_fnc_hasUGL;
 *
 * Public: No
*/

params [["_unit", objNull, [objNull]]];
if (isNull _unit) exitWith {""};

private _w = primaryWeapon _unit;
if (_w isEqualTo "") exitWith {""};

private _onbellek = _unit getVariable [QGVAR(glCache), ["", ""]];
if ((_onbellek select 0) isEqualTo _w) exitWith {_onbellek select 1};

private _gl = "";
// GL muzzle = magazinleri bombali (GrenadeBase) olan ilk ek muzzle (ek muzzle'in her zaman GL olduguna guvenme)
private _m = (getArray (configFile >> "CfgWeapons" >> _w >> "muzzles")) select {_x isNotEqualTo "this"};
{
    private _mz = _x;
    if ((([_w, _mz] call FUNC(uglMags)) findIf {
        (getText (configFile >> "CfgMagazines" >> _x >> "ammo")) isKindOf ["GrenadeBase", configFile >> "CfgAmmo"]
    }) > -1) exitWith { _gl = _mz; };
} forEach _m;
_unit setVariable [QGVAR(glCache), [_w, _gl]];
// Tani: silah basina bir kez RPT'ye (RHS / mod UGL tespiti dogru mu?)
if (isNil "lambs_danger_uglLogSet") then { lambs_danger_uglLogSet = []; };
if (!(_w in lambs_danger_uglLogSet)) then {
    lambs_danger_uglLogSet pushBack _w;
    diag_log format ["[UGL-TESPIT] %1 | muzzle'lar: %2 | UGL: '%3' | uyumlu sarjor: %4", _w, _m, _gl, if (_gl isEqualTo "") then {[]} else {[_w, _gl] call FUNC(uglMags)}];
};

_gl
