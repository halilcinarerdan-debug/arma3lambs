#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * ALIVE SAHIBI (v8.561; kullanici: 'ALiVE populasyonu ile uyumlu hale getirme ayari ekle, ALiVE ile cakismasin').
 * Bir birim / arac / grup ALiVE'in mi? ALiVE kaynak kodundan (ALiVEOS/alive.os) okunan isaretler:
 *   - profil ile dogan asker / arac: unit.profileID (+ profileIndex)         [sys_profile/fnc_profileEntity.sqf]
 *   - CQB modulu askeri / grubu:     unit/group.ALIVE_profileIgnore, unit.ALIVE_cqb_instance   [mil_cqb/fnc_CQBSpawnStep.sqf]
 *   - sivil populasyon ajani:        unit.agentID                                [amb_civ_population]
 * Kapali (CBA aliveUyum = 0) ya da ALiVE yuklu degilse hep false.
 *
 * Arguments:
 * 0: Birim / arac / grup <OBJECT / GROUP>
 *
 * Return Value: ALiVE'in mi <BOOL>
 * Public: No
*/

params [["_o", objNull, [objNull, grpNull]]];
if (!(missionNamespace getVariable ["lambs_danger_aliveVar", false])) exitWith {false};
if ((missionNamespace getVariable ["lambs_danger_aliveUyum", 1]) isEqualTo 0) exitWith {false};
private _isaret = {
    params ["_x0"];
    !isNil {_x0 getVariable "profileID"} || {!isNil {_x0 getVariable "ALIVE_profileIgnore"}} || {!isNil {_x0 getVariable "ALIVE_cqb_instance"}} || {!isNil {_x0 getVariable "agentID"}}
};
if (_o isEqualType grpNull) exitWith {
    if (isNull _o || {(_o getVariable ["lambs_danger_aliveSahip", false])}) exitWith {!isNull _o};
    (!isNil {_o getVariable "ALIVE_profileIgnore"}) || {((units _o) findIf {[_x] call _isaret}) >= 0} || {((units _o) findIf {private _v = vehicle _x; _v isNotEqualTo _x && {[_v] call _isaret}}) >= 0}
};
if (isNull _o) exitWith {false};
[_o] call _isaret
