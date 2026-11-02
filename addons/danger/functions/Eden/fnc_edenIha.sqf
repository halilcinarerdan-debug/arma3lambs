#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * 3DEN: ELITE IHA Gorevi modulu (v8.362). Module SYNC ile baglanan IHA (dron; ya da muretttebat askeri) ve istege bagli operator asker. Modul konumu gozlem merkezidir.
 * Zeus 'ELITE IHA Gorevi' ile ayni sunucu olayi (lambs_danger_ihaGorev): sorti / gozlem devriyesi / kaldir. 'Dron yarat' ve cantadan kurma Zeus'a ozgudur (3DEN'de dronu yerlestirin).
 * Arguments: 0: modul <OBJECT>, 1: baglananlar (kullanilmaz), 2: etkin <BOOL>
 * Return Value: None
 * Public: No
*/

params ["_logic", "", "_activated"];
if (!_activated || {!isServer}) exitWith {};

[_logic] spawn {
    params ["_logic"];
    if !(["BEKLE"] call FUNC(edenOrtak)) exitWith { diag_log "[EDEN] IHA: ELITE hazir olmadi (180 sn)" };
    sleep 3;
    private _bagli = ["BAGLI", [_logic]] call FUNC(edenOrtak);
    private _uav = objNull;
    private _op = objNull;
    {
        private _o = _x;
        if (unitIsUAV _o) then {
            if (isNull _uav) then { _uav = _o; };
        } else {
            if (_o isKindOf "CAManBase") then {
                private _p = objectParent _o;
                if (!isNull _p && {unitIsUAV _p}) then {
                    if (isNull _uav) then { _uav = _p; };
                } else {
                    if (isNull _op && {alive _o}) then { _op = _o; };
                };
            };
        };
    } forEach _bagli;
    if (isNull _uav) exitWith { ["MESAJ", [format ["IHA (3DEN) %1: module bagli IHA (dron) yok - dronu module SYNC edin", mapGridPosition _logic]]] call FUNC(edenOrtak) };
    private _gorev = ((round (["SAYI", [_logic, "lambs_danger_edIhaGorev", 0]] call FUNC(edenOrtak))) max 0) min 2;
    private _tur = ((round (["SAYI", [_logic, "lambs_danger_edIhaTur", 0]] call FUNC(edenOrtak))) max 0) min 4;
    private _tarafA = round (["SAYI", [_logic, "lambs_danger_edIhaTaraf", 0]] call FUNC(edenOrtak));
    private _men = round (["SAYI", [_logic, "lambs_danger_edIhaMenzil", 3000]] call FUNC(edenOrtak));
    private _yar = round (["SAYI", [_logic, "lambs_danger_edIhaYar", 300]] call FUNC(edenOrtak));
    private _opMod = ((round (["SAYI", [_logic, "lambs_danger_edIhaOp", 0]] call FUNC(edenOrtak))) max 0) min 2;
    if (isNull _op) then { _opMod = 0; };
    private _tarafI = _tarafA - 1;
    if (_tarafA <= 0) then {
        _tarafI = -1;
        if (!isNull _op) then { _tarafI = [west, east, independent] find (side (group _op)); };
        if (_tarafI < 0) then {
            private _cs = getNumber (configOf _uav >> "side");
            if (_cs in [0, 1, 2]) then { _tarafI = [1, 0, 2] select _cs; };
        };
        if (_tarafI < 0) then { _tarafI = 1; };
    };
    _tarafI = _tarafI max 0 min 2;
    private _mod = ["SORTI", "GOZLEM", "KALDIR"] select _gorev;
    private _turKod = ["", "FPV-AT", "FPV-AP", "BOMBA", "GOZLEM"] select _tur;
    ["lambs_danger_ihaGorev", [netId _uav, _mod, _turKod, _tarafI, getPosATL _logic, _yar, _men, "", 0, ["", netId _op] select (!isNull _op), _opMod, ""]] call CBA_fnc_serverEvent;
    diag_log format ["[EDEN] IHA (3DEN) | %1 | %2 | tur %3 | taraf %4 | operator %5 | menzil %6 m", typeOf _uav, _mod, [_turKod, "otomatik"] select (_turKod isEqualTo ""), ["BLUFOR", "OPFOR", "INDEP"] select _tarafI, ["yok", name _op] select (!isNull _op), _men];
};
