#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * 3DEN: ELITE HQ / US Kur modulu (v8.362). Modul konumu komuta noktasi; modulle SYNC edilen gruplar bu HQ ya atanir (Zeus hqIstegi + hqAtama olaylari). HQ kimligi modulde 'lambs_danger_edenHqId' olarak saklanir (Objektif modulu okur).
 * Arguments: 0: modul <OBJECT>, 1: baglananlar (kullanilmaz), 2: etkin <BOOL>
 * Return Value: None
 * Public: No
*/

params ["_logic", "", "_activated"];
if (!_activated || {!isServer}) exitWith {};

[_logic] spawn {
    params ["_logic"];
    if !(["BEKLE"] call FUNC(edenOrtak)) exitWith { diag_log "[EDEN] HQ: ELITE hazir olmadi (180 sn)" };
    private _gruplar = ["GRUPLAR", [_logic]] call FUNC(edenOrtak);
    private _taraf = ["TARAF", [_logic, "lambs_danger_edHqTaraf", _gruplar]] call FUNC(edenOrtak);
    private _katI = (round (["SAYI", [_logic, "lambs_danger_edHqKat", 0]] call FUNC(edenOrtak))) max 0 min 3;
    private _yar = ["SAYI", [_logic, "lambs_danger_edHqYar", 100]] call FUNC(edenOrtak);
    private _poz = getPosATL _logic;
    ["lambs_danger_hqIstegi", [_taraf, _poz, _katI, round _yar]] call CBA_fnc_serverEvent;
    private _id = format ["%1_%2", ["HQ1", "HQ2", "HQ3", "US"] select _katI, _taraf];
    _logic setVariable ["lambs_danger_edenHqId", _id];
    if (_gruplar isNotEqualTo []) then {
        ["lambs_danger_hqAtama", [_id, _gruplar apply {netId _x}]] call CBA_fnc_serverEvent;
    };
    diag_log format ["[EDEN] HQ (3DEN) | %1 | %2 | yaricap %3 m | atanan grup %4: %5", _id, mapGridPosition _poz, round _yar, count _gruplar, _gruplar apply {groupId _x}];
};
