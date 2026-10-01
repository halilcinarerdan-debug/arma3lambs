#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * Askerin GERCEK anti-tank kabiliyeti var mi?
 *
 * Eski kontrol (`secondaryWeapon != "" && ammo > 0`) AA (Titan AA / Stinger), flare ve AP
 * launcher'lari da "AT" sayiyordu -> grup AT'si var sanip tanka saldiriyor, ates edemiyordu.
 * Burada LAMBS'in kendi bayrak kontrolu kullanilir: launcher magazini VEHICLE veya ARMOUR'a
 * karsi kullanilabilir (aiAmmoUsageFlags) olmali; envanterde / yuklu mermi olmali.
 * (tacticsAssess / tacticsHide ile ayni olcut.)
 *
 * Arguments:
 * 0: unit <OBJECT>
 *
 * Return Value:
 * <BOOL>
 *
 * Example:
 * [bob] call lambs_danger_fnc_isATUnit;
 *
 * Public: No
*/

params [["_unit", objNull, [objNull]]];

if (isNull _unit || {!alive _unit}) exitWith {false};
if ((secondaryWeapon _unit) isEqualTo "") exitWith {false};

([[_unit], AI_AMMO_USAGE_FLAG_VEHICLE + AI_AMMO_USAGE_FLAG_ARMOUR] call EFUNC(main,getLauncherUnits)) isNotEqualTo []
