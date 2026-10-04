#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * ROKET / FUZE / DUMAN IZLEYICI (v8.83) — atilan roket / fuze ve duman mermisinin DUSTUGU yeri bulur, fnc_tehditOlay'i (herkese) calistirir.
 *
 * Arguments:
 * 0: Mod <STRING> "ROKET" | "DUMAN"
 * 1: Mermi / nesne <OBJECT>
 * 2: Atici <OBJECT>
 *
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

params [["_mod", "", [""]], ["_proj", objNull, [objNull]], ["_atici", objNull, [objNull]]];
if (isNull _proj || {_mod isEqualTo ""}) exitWith {false};
if (missionNamespace getVariable ["lambs_danger_tehditOlayOff", false]) exitWith {false};
private _taraf = if (isNull _atici) then { sideUnknown } else { side (group _atici) };

[_mod, _proj, _atici, _taraf] spawn {
    params ["_mod", "_proj", "_atici", "_taraf"];
    private _p = getPosATL _proj;
    private _bitis = time + ([20, 8] select (_mod isEqualTo "DUMAN"));
    waitUntil {
        sleep 0.1;
        if (!isNull _proj) then { _p = getPosATL _proj; };
        isNull _proj || {time > _bitis} || {_mod isEqualTo "DUMAN" && {(vectorMagnitude (velocity _proj)) < 1} && {(_p select 2) < 3}}
    };
    if (_p isEqualTo [0,0,0]) exitWith {};
    [_mod, _p, _taraf, _atici] call FUNC(tehditOlay);
    if (isMultiplayer) then {
        [_mod, _p, _taraf, _atici] remoteExecCall ["lambs_danger_fnc_tehditOlay", -clientOwner];
    };
};
true
