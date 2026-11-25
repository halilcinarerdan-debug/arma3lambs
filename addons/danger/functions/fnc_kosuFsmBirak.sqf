#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * KOSU FSM BIRAK (v8.811): fnc_kosuFsm ile kapatilan FSM'i hemen geri acar (sicrama sonu / varis / geri cekilme bitisi). Token temizlenir; zamanli geri acma bos kalir.
 * Arguments: 0: Asker <OBJECT>
 * Return Value: Yok
 * Public: No
*/

params [["_u", objNull, [objNull]]];
if (isNull _u || {!alive _u}) exitWith {};
if ((_u getVariable [QGVAR(kosuFsmTok), 0]) isNotEqualTo 0) then {
    _u setVariable [QGVAR(kosuFsmTok), 0];
    _u enableAI "FSM";
    private _say = missionNamespace getVariable ["lambs_danger_kosuFsmSay", createHashMap];
    _say set ["birakildi", (_say getOrDefault ["birakildi", 0]) + 1];
    missionNamespace setVariable ["lambs_danger_kosuFsmSay", _say];
};
