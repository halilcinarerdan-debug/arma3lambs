#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * 3DEN: ELITE Canli Bomba (PBIED / VBIED) modulu (v8.777; kullanici: 'zeus destegi ve editor destegi olsun'). Module SYNC ile baglanan her asker / arac canli bomba olur (arac: surucu kosucu). Birden cok birim baglanabilir.
 * Zeus 'ELITE Canli Bomba' ve init satiri [this] call lambs_danger_fnc_eypBombaYap ile AYNI islev (fnc_eypBombaYap). Log: [EDEN] + [EYP-ISARET]
 * Arguments: 0: modul <OBJECT>, 1: baglananlar (kullanilmaz), 2: etkin <BOOL>
 * Return Value: None
 * Public: No
*/

params ["_logic", "", "_activated"];
if (!_activated || {!isServer}) exitWith {};

[_logic] spawn {
    params ["_logic"];
    if !(["BEKLE"] call FUNC(edenOrtak)) exitWith { diag_log "[EDEN] Canli bomba: ELITE hazir olmadi (180 sn)" };
    waitUntil { sleep 0.5; !isNil "lambs_danger_eypSistemStarted" || {time > 120} };
    sleep 2;
    private _bagli = ["BAGLI", [_logic]] call FUNC(edenOrtak);
    if (_bagli isEqualTo []) exitWith { diag_log format ["[EDEN] Canli bomba (3DEN) %1: module bagli birim yok", mapGridPosition _logic] };
    private _tarz = [2, 0, 1] select (((round (["SAYI", [_logic, "lambs_danger_edBmbTarz", 0]] call FUNC(edenOrtak))) max 0) min 2);   // v8.785: 0 agresif (varsayilan) / 1 catisarak / 2 gizli -> eypTarz 2 / 0 / 1
    private _taraf = ((round (["SAYI", [_logic, "lambs_danger_edBmbTaraf", 0]] call FUNC(edenOrtak))) max 0) min 3;
    private _menzil = round (["SAYI", [_logic, "lambs_danger_edBmbMenzil", 400]] call FUNC(edenOrtak));
    private _atilma = round (["SAYI", [_logic, "lambs_danger_edBmbAtilma", 0]] call FUNC(edenOrtak));
    private _tetik = round (["SAYI", [_logic, "lambs_danger_edBmbTetik", 8]] call FUNC(edenOrtak));
    private _tered = (["SAYI", [_logic, "lambs_danger_edBmbTered", 3]] call FUNC(edenOrtak)) max 0;
    private _guc = ((round (["SAYI", [_logic, "lambs_danger_edBmbGuc", 0]] call FUNC(edenOrtak))) max 0) min 3;
    private _olum = ((round (["SAYI", [_logic, "lambs_danger_edBmbOlum", 0]] call FUNC(edenOrtak))) max 0) min 5;
    private _varil = ((round (["SAYI", [_logic, "lambs_danger_edBmbVaril", 0]] call FUNC(edenOrtak))) max 0) min 1;
    private _a = [_menzil, _tarz, [-1, _atilma] select (_atilma > 0), _guc - 1, [-1, 0, 0.25, 0.5, 0.75, 1] select _olum, _taraf, [1, 0] select _varil, [-1, _tetik] select (_tetik > 0), _tered];
    private _n = 0;
    {
        private _o = _x;
        if (_o isKindOf "CAManBase" && {!isNull objectParent _o}) then { _o = vehicle _o; };
        if (alive _o && {!isPlayer _o}) then {
            [_o, _a] call FUNC(eypBombaYap);
            _n = _n + 1;
        };
    } forEach (_bagli arrayIntersect _bagli);
    diag_log format ["[EDEN] Canli bomba (3DEN) | %1 birim | ayar %2", _n, _a];
};
