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
    if (((getArray (configFile >> "CfgWeapons" >> _w >> _mz >> "magazines")) findIf {
        (getText (configFile >> "CfgMagazines" >> _x >> "ammo")) isKindOf ["GrenadeBase", configFile >> "CfgAmmo"]
    }) > -1) exitWith { _gl = _mz; };
} forEach _m;
_unit setVariable [QGVAR(glCache), [_w, _gl]];

_gl
