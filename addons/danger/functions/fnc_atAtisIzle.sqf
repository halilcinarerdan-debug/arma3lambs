#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * AT ATISI IZLEYICI (v8.251) — atilan AT roketi / fuzesi / tank topu mermisi hangi dusman ARACA dogru gidiyor? Mermi yolu aracin 25 m + %3 mesafe icinden geciyorsa
 * (2500 m'ye kadar) arac fnc_aracAtTepki ile tepki verir (araci yerel olmayan makineye remoteExecCall). firedHub'dan cagrilir: piyade roketatar Fired + LandVehicle Fired (AT sinifi mermi).
 * Geometri: mermi konumu P, hiz yonu u; arac konumu T; t = (T-P).u (20..2500 m), sapma = |(T-P) - u*t|. Fuze egrilebildigi icin esik mesafeyle artar. TEST EDILMEDI (menzil / esik tasarim).
 * Kapatma: lambs_danger_aracAtTepkiOff = true.
 *
 * Arguments:
 * 0: Atici (piyade ya da arac) <OBJECT>
 * 1: Mermi <OBJECT>
 *
 * Return Value: Tepki tetiklenen arac sayisi <NUMBER>
 * Public: No
*/

params [["_atici", objNull, [objNull]], ["_proj", objNull, [objNull]]];
if (isNull _atici || {isNull _proj} || {missionNamespace getVariable ["lambs_danger_aracAtTepkiOff", false]}) exitWith {0};
private _aKmt = effectiveCommander _atici;
if (isNull _aKmt) then { _aKmt = _atici; };
private _taraf = side (group _aKmt);
if (_taraf in [civilian, sideUnknown]) exitWith {0};
private _vel = velocity _proj;
private _vm = vectorMagnitude _vel;
if (_vm < 5) exitWith {0};
private _dir = _vel vectorMultiply (1 / _vm);
private _pp = getPosASL _proj;
private _aPoz = getPosATL _atici;
private _sayi = 0;
{
    private _t = _x;
    if (_t isEqualTo _atici || {!alive _t} || {_t isKindOf "StaticWeapon"}) then { continue };
    private _kmt = effectiveCommander _t;
    if (isNull _kmt || {!alive _kmt} || {(_taraf getFriend (side (group _kmt))) >= 0.6}) then { continue };
    private _rel = (getPosASL _t) vectorDiff _pp;
    private _tt = _rel vectorDotProduct _dir;
    if (_tt < 20 || {_tt > 2500}) then { continue };
    private _sapma = vectorMagnitude (_rel vectorDiff (_dir vectorMultiply _tt));
    if (_sapma > (25 + _tt * 0.03)) then { continue };
    _sayi = _sayi + 1;
    if (local _t) then {
        [_t, _atici, "ROKET", _aPoz] call FUNC(aracAtTepki);
    } else {
        [_t, _atici, "ROKET", _aPoz] remoteExecCall ["lambs_danger_fnc_aracAtTepki", _t];
    };
} forEach (_aPoz nearEntities [["LandVehicle"], 2600]);
_sayi
