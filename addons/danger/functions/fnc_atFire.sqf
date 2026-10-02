#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * AT askeri hedef araca ROKET atar — LAMBS tacticsHide'in kanitlanmis yontemiyle.
 *
 * LAMBS: setCombatMode RED -> doTarget -> CBA_fnc_selectWeapon(launcher) -> setUnitPos MIDDLE
 *        -> 5-8 sn SONRA doFire.
 * Eski kodum her cagrida selectWeapon + doFire yapiyordu: silah gecisi (animasyon ~2-3 sn)
 * surekli sifirlaniyor, AT hic ates edemiyordu.
 *
 * Simdi:
 *   - launcher secili DEGILSE: secim bir kez (6 sn'de bir) baslatilir, doFire 4 sn sonra
 *   - launcher secili ise: dogrudan doFire
 *
 * Arguments:
 * 0: AT asker <OBJECT>
 * 1: hedef arac <OBJECT>
 *
 * Return Value:
 * Dogrudan doFire verildi mi <BOOL>
 *
 * Example:
 * [bob, tank] call lambs_danger_fnc_atFire;
 *
 * Public: No
*/

params [
    ["_unit", objNull, [objNull]],
    ["_target", objNull, [objNull]]
];

if (isNull _unit || {!alive _unit} || {isNull _target} || {!alive _target}) exitWith {false};

private _launcher = secondaryWeapon _unit;
if (_launcher isEqualTo "") exitWith {false};
// Mermi yok / menzil disi: bos ya da cok uzak hedefe doFire spam'i yapma
if ((_unit ammo _launcher) <= 0 && {(currentWeapon _unit) isEqualTo _launcher}) exitWith {false};
if ((_unit distance2D _target) > 400) exitWith {false};

// GUVENLIK: dost / geri patlama / engel (cali, dal) kontrolu — guvenli degilse ATMA
if (!([_unit, _target, "RPG"] call (missionNamespace getVariable ["lambs_danger_fnc_atisGuvenli", {true}]))) exitWith {false};

_unit setUnitPosWeak "UP";   // roket icin ayakta gorus (MIDDLE'da siperin arkasindan zirhi goremeyebilir)
_unit doTarget _target;

if ((currentWeapon _unit) isNotEqualTo _launcher) then {
    if ((time - (_unit getVariable [QGVAR(atSelectTime), -999])) > 6) then {
        _unit setVariable [QGVAR(atSelectTime), time];
        [_unit, _launcher] call CBA_fnc_selectWeapon;
        [{
            params ["_u", "_t"];
            if (alive _u && {alive _t} && {[_u, _t, "RPG"] call (missionNamespace getVariable ["lambs_danger_fnc_atisGuvenli", {true}])}) then {
                _u doFire _t;
            };
        }, [_unit, _target], 4] call CBA_fnc_waitAndExecute;
    };
    false
} else {
    _unit doFire _target;
    true
}
