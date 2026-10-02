#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * Bir silahin (ek) muzzle'i icin UYUMLU sarjor listesi: magazines[] + magazineWell[] (CBA / RHS / CUP / vanilla well).
 * Eski kod sadece magazines[] okuyordu; magazineWell kullanan silahlarda (cogu mod + yeni vanilla) liste BOS cikiyor,
 * UGL "yok" sanilip HIC atmiyordu.
 *
 * Arguments:
 * 0: silah <STRING>
 * 1: muzzle <STRING>
 *
 * Return Value:
 * Sarjor siniflari <ARRAY>
 *
 * Public: No
*/

params [["_w", "", [""]], ["_mz", "", [""]]];
if (_w isEqualTo "" || {_mz isEqualTo ""}) exitWith {[]};

private _cfg = configFile >> "CfgWeapons" >> _w >> _mz;
private _mags = (getArray (_cfg >> "magazines")) apply {toLower _x};
{
    private _well = configFile >> "CfgMagazineWells" >> _x;
    if (isClass _well) then {
        {
            if (_x isEqualType []) then { _mags append (_x apply {toLower _x}); };
        } forEach ((configProperties [_well, "isArray _x", true]) apply {getArray _x});
    };
} forEach (getArray (_cfg >> "magazineWell"));
_mags arrayIntersect _mags
