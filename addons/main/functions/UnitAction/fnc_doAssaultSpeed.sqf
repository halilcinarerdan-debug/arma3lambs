#include "script_component.hpp"
/*
 * Author: nkenny (ELITE fork overlay: Cinar)
 * Sets and reports appropriate CQB speed based on distance
 *
 * ELITE v8.88: ARAC ICINDEKI birimlere forceSpeed UYGULANMAZ. Upstream bu fonksiyon her birime (surucu dahil) forceSpeed 2-4 m/s (lider / moral < 0 / hedefe < 5 m: -1) birakiyordu:
 *   ATTACK komutundaki APC / IFV surucusu 7-14 km/s'e (lider 7 km/s) kisitlaniyordu (RPT a73b486e / 9c82aefa: Stryker ATTACK + COMBAT iken 4-8 km/s). Piyade davranisi AYNEN korunur.
 *
 * Arguments:
 * 0: Unit assaulting <OBJECT>
 * 1: Destination <OBJECT> or <ARRAY>
 *
 * Return Value:
 * appropriate speed
 *
 * Example:
 * [bob, angryJoe] call lambs_main_fnc_doAssaultSpeed;
 *
 * Public: No
*/
params ["_unit", ["_target", objNull]];

// ELITE: aracta ise hizi motor / surucu belirlesin (forceSpeed sifirla, 4 doner = eski donus degeri uyumu)
if (!isNull objectParent _unit) exitWith { _unit forceSpeed -1; 4 };

// speed
if ((behaviour _unit) isEqualTo "STEALTH") exitWith {_unit forceSpeed 1; 1};
private _speed = [3, 4] select (getSuppression _unit isEqualTo 0);
if ((leader _unit) isEqualTo _unit || (morale _unit) < 0) then {_speed = _speed - 1;};
if (_unit distance2D _target < 5) then {_speed = _speed - 1;};
_unit forceSpeed _speed;
_speed
