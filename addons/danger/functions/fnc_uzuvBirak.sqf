#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * UZUV BIRAK (v8.500) - sahip uzvu serbest birakir (yalniz kiralayan sahip birakabilir). Bkz. fnc_uzuvKirala.
 *
 * Arguments: 0: Birim <OBJECT>, 1: Uzuv <STRING>, 2: Sahip adi <STRING>
 * Return Value: birakildi mi <BOOL>
 * Public: No
*/

params [["_u", objNull, [objNull]], ["_uzuv", "HIZ", [""]], ["_sahip", "", [""]]];
if (isNull _u) exitWith {false};
private _k = format ["lambs_danger_uzuv_%1", _uzuv];
private _m = _u getVariable [_k, []];
if (_m isNotEqualTo [] && {(_m select 0) isEqualTo _sahip}) exitWith { _u setVariable [_k, nil]; true };
false
