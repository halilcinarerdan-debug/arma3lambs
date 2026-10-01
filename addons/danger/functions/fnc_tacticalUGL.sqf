#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * TAKTIK UGL (40mm) KULLANIMI — boost
 *
 * Eskiden UGL sadece LAMBS'in nadir tetiklemesine kaliyordu. Bu fonksiyon, ates ekibinin
 * UGL'li askerlerini DUSMAN PIYADEYE karsi sistemli olarak kullanir:
 *   - hedef 40..320 m arasinda piyade
 *   - dogrudan hat KAPALI (siperde / binada saklanan dusman: tufekle vurulamaz, UGL ust eger)
 *   - hedef BINADA
 *   - 8 m icinde 2+ dusman KUME (alan etkisi)
 *   - yoksa %50 sans (her cagrida degil, dogal gorunsun)
 *   - birim basina 5 sn cooldown
 *
 * Atis mekanigi LAMBS'in doUGL'una birakilir (nisan / muzzle secimi / ates orada).
 *
 * Arguments:
 * 0: unit <OBJECT>
 * 1: dusman piyade <OBJECT>
 * 2: zorla (kontrolleri atla, her zaman at) <BOOL> default false
 *
 * Return Value:
 * Atis denendi mi <BOOL>
 *
 * Example:
 * [bob, angryJoe] call lambs_danger_fnc_tacticalUGL;
 *
 * Public: No
*/

params [
    ["_unit", objNull, [objNull]],
    ["_target", objNull, [objNull]],
    ["_force", false, [false]]
];

if (isNull _unit || {!alive _unit} || {isNull _target} || {!alive _target}) exitWith {false};
if (!isNull objectParent _unit) exitWith {false};
if ((time - (_unit getVariable [QGVAR(uglLast), -999])) < 5) exitWith {false};

// ---------------------------------------------------------------------------
// UGL muzzle (silah basina onbellek) + mermi var mi
// ---------------------------------------------------------------------------
private _w = primaryWeapon _unit;
if (_w isEqualTo "") exitWith {false};

private _onbellek = _unit getVariable [QGVAR(glCache), ["", ""]];
private _gl = "";
if ((_onbellek select 0) isEqualTo _w) then {
    _gl = _onbellek select 1;
} else {
    private _m = (getArray (configFile >> "CfgWeapons" >> _w >> "muzzles")) select {_x isNotEqualTo "this"};
    if (_m isNotEqualTo []) then { _gl = _m select 0; };
    _unit setVariable [QGVAR(glCache), [_w, _gl]];
};
if (_gl isEqualTo "") exitWith {false};
if ((_unit ammo _gl) <= 0) exitWith {false};

// ---------------------------------------------------------------------------
// MENZIL
// ---------------------------------------------------------------------------
private _d = _unit distance2D _target;
if (_d < 40 || {_d > 320}) exitWith {false};

// ---------------------------------------------------------------------------
// UYGUN MU: hat kapali / binada / kume / %50
// ---------------------------------------------------------------------------
private _uygun = _force;
if (!_uygun) then {
    private _engelli = lineIntersects [eyePos _unit, eyePos _target, _unit, _target];
    private _binada = (insideBuilding _target) > 0.5;
    private _kume = (count ((_target nearEntities ["CAManBase", 8]) select {
        alive _x && {(side _x) isEqualTo (side _target)}
    })) >= 2;
    _uygun = _engelli || {_binada} || {_kume} || {(random 1) < 0.5};
};
if (!_uygun) exitWith {false};

// ---------------------------------------------------------------------------
// ATIS — LAMBS doUGL (yoksa sessizce atla)
// ---------------------------------------------------------------------------
private _fn = missionNamespace getVariable ["lambs_main_fnc_doUGL", nil];
if (isNil "_fn") exitWith {false};

_unit setVariable [QGVAR(uglLast), time];
[_unit, _target] call _fn;

true
