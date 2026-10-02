#include "script_component.hpp"
/*
 * Author: nkenny
 * Plays a gesture picked from an array
 *
 * Arguments:
 * 0: Unit doing gesture <OBJECT>
 * 1: Array of possible gestures, default freeze gesture <ARRAY> or <STRING>
 * 2: Force Gesture <BOOL> (Default: false)
 *
 * Return Value:
 * boolean
 *
 * Example:
 * [bob] call lambs_main_fnc_doGesture;
 *
 * Public: Yes
*/
params [
    ["_unit", objNull, [objNull]],
    ["_gesture", "gestureFreeze", [[], ""]],
    ["_force", false, [false]]
];

// check global settings
if (GVAR(disableAIGestures) && {!_force}) exitWith {false};

// not for players
if (isPlayer _unit) exitWith {false};

// ELITE: jest spami onleme — birim basina 6 sn, grup basina 2.5 sn (zorunlu degilse)
private _grp = group _unit;
if (
    !_force
    && {
        ((_unit getVariable ["lambs_main_gestureZaman", 0]) > time)
        || {(_grp getVariable ["lambs_main_gestureGrupZaman", 0]) > time}
    }
) exitWith {false};
if (!_force) then {
    _unit setVariable ["lambs_main_gestureZaman", time + 6];
    _grp setVariable ["lambs_main_gestureGrupZaman", time + 2.5];
};

// sort gestures
if (_gesture isEqualType []) then {
    _gesture = selectRandom _gesture;
};

// tani (ELITE): jest kaydi (ilk 200 satir)
if (isNil "lambs_main_jestLogN") then { lambs_main_jestLogN = 0; };
if (lambs_main_jestLogN < 200) then {
    lambs_main_jestLogN = lambs_main_jestLogN + 1;
    diag_log format ["[JEST] %1 | %2 | %3 | zorla:%4", groupId _grp, name _unit, _gesture, _force];
};

// do it
if (_force) then {_unit playActionNow _gesture;} else {_unit playAction _gesture;};

// end
true
