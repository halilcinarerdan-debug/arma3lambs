#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * Keskin nisanci mi? (DMR / nisanci tufegi DEGIL; uzun menzil nisanci tufegi veya sinif adinda "sniper")
 * Sonuc silah basina onbelleklenir.
 *
 * Arguments:
 * 0: unit <OBJECT>
 *
 * Return Value:
 * <BOOL>
 *
 * Public: No
*/

params [["_unit", objNull, [objNull]]];
if (isNull _unit) exitWith {false};

private _w = primaryWeapon _unit;
if (_w isEqualTo "") exitWith {false};

private _c = _unit getVariable [QGVAR(sniperCache), ["", false]];
if ((_c select 0) isEqualTo _w) exitWith {_c select 1};

private _ad = toLower _w;
private _tip = toLower (typeOf _unit);
private _sn = ((_tip find "sniper") >= 0)
    || {(["srifle_lrr", "srifle_gm6", "srifle_m200", "m24", "m40a", "m40_", "sr25", "sr_25", "xm2010", "t5000", "m107", "m82", "as50", "blaser", "mar10", "sv98", "vks", "ksvk", "orsis", "awm", "l115", "l96", "_lrr", "_gm6", "rhs_weap_m24", "rhs_weap_m40", "rhs_weap_sr25"] findIf {(_ad find _x) >= 0}) > -1};

_unit setVariable [QGVAR(sniperCache), [_w, _sn]];
_sn
