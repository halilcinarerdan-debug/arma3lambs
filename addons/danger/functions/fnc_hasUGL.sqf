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
private _m = (getArray (configFile >> "CfgWeapons" >> _w >> "muzzles")) select {_x isNotEqualTo "this"};
if (_m isNotEqualTo []) then { _gl = _m select 0; };
_unit setVariable [QGVAR(glCache), [_w, _gl]];

_gl
