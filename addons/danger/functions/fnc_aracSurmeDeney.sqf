#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * ARAC SURMEME DENEYI (v8.220) — AI surucu "komut MOVE" tutup surmuyor (hedef DoNotPlan; 60 m yakin hedef bile 0 m). Neden bilinmiyor; bu fonksiyon duran aracta ONLEMLER'i sirayla dener ve HANGISI isliyorsa loglar.
 * ONCE: KURTARMA 1 eylemleri tek tek 2 sn arayla (motor, AI ozellik, doMove, itme) — surucu aractan cikarsa SON ADIM [SURME-TANI-CIKTI] logunda gorunur (kim cikartiyor?).
 * SONRA her onlem 4 sn: arac > 6 m gider ve hiz > 3 km/s ise "CALISTI". Calisan onlem lambs_danger_deneyKazanan'a yazilir; sonraki duran aracta ONCE o denenir.
 *   EFEKTIF-KOMUTAN  : arac komutani (baska grup olabilir) hedefe doMove alir
 *   LIDER-SURUCU     : surucu grup lideri yapilir + doMove
 *   WAYPOINT         : grup waypoint'leri silinir, 150 m hedefe MOVE / FULL waypoint
 *   DAVRANIS         : AWARE + FULL + YELLOW + doMove
 *   YOL-DUZ          : setDriveOnPath [konum, hedef] (iki nokta)
 *   PATH-YENILE      : PATH ozelligi kapat/ac + doMove
 *   FSM-KAPAT        : surucu FSM ozelligi kapali + doMove (4 sn sonra tekrar acilir)
 * VARSAYILAN KAPALI (v8.224: kullanici beklemek istemiyor); acmak icin lambs_danger_surmeDeneyOff = false.  Log: [SURME-DENEY]
 *
 * Arguments:
 * 0: Arac <OBJECT>
 * 1: Surucu <OBJECT>
 * 2: Hedef konum (uzak hedef) <ARRAY>
 * 3: Etiket <STRING>
 *
 * Return Value: Calisti mi (script) <SCRIPT>
 * Public: No
*/

params [["_v", objNull, [objNull]], ["_d", objNull, [objNull]], ["_hedefU", [0, 0, 0], [[]]], ["_et", "?", [""]]];
if (isNull _v || {isNull _d} || {_v getVariable [QGVAR(deneyCalisiyor), false]}) exitWith {scriptNull};
_v setVariable [QGVAR(deneyCalisiyor), true];

[_v, _d, _hedefU, _et] spawn {
    params ["_v", "_d", "_hedefU", "_et"];
    private _vg = group _d;
    private _yonlendir = {
        params ["_v", "_hedefU"];
        private _yl = (getPosATL _v) nearRoads 300;
        if (_yl isEqualTo []) exitWith { (getPosATL _v) getPos [150, (getPosATL _v) getDir _hedefU] };
        _yl = [_yl, [], {(_x distance2D _v) + 0.5 * (_x distance2D _hedefU)}, "ASCEND"] call BIS_fnc_sortBy;
        getPosATL (_yl select 0)
    };
    private _h = [_v, _hedefU] call _yonlendir;

    // ---- 1) KURTARMA 1 eylemleri adim adim (surucu cikisi icin son adim) ----
    private _adimlar = [
        ["EngineOn", { params ["_v", "_d", "_h"]; _d action ["EngineOn", _v]; _v engineOn true; }],
        ["AI-OZELLIK", { params ["_v", "_d", "_h"]; _d enableAI "PATH"; _d enableAI "MOVE"; _d forceSpeed 9; }],
        ["doMove-yol", { params ["_v", "_d", "_h"]; _d doMove _h; }],
        ["itme-6ms", { params ["_v", "_d", "_h"]; _v setVelocityModelSpace [0, 6, 0]; }]
    ];
    {
        _x params ["_ad", "_kod"];
        _v setVariable [QGVAR(deneyAdim), _ad];
        [_v, _d, _h] call _kod;
        sleep 2;
    } forEach _adimlar;
    _v setVariable [QGVAR(deneyAdim), "-"];
    waitUntil { sleep 0.5; (speed _v) < 1 || {!alive _v} };

    // ---- 2) onlemler ----
    private _onlemler = [
        ["EFEKTIF-KOMUTAN", { params ["_v", "_d", "_h", "_vg"]; private _ec = effectiveCommander _v; if (!isNull _ec && {_ec isNotEqualTo _d}) then { _ec enableAI "PATH"; _ec doMove _h; }; _d doMove _h; }],
        ["LIDER-SURUCU", { params ["_v", "_d", "_h", "_vg"]; _vg selectLeader _d; _d doMove _h; }],
        ["WAYPOINT", { params ["_v", "_d", "_h", "_vg"]; { deleteWaypoint _x; } forEach (reverse (waypoints _vg)); private _w = _vg addWaypoint [_h, 0]; _w setWaypointType "MOVE"; _w setWaypointSpeed "FULL"; _vg setCurrentWaypoint _w; }],
        ["DAVRANIS", { params ["_v", "_d", "_h", "_vg"]; _vg setBehaviour "AWARE"; _vg setSpeedMode "FULL"; _vg setCombatMode "YELLOW"; _d doMove _h; }],
        ["YOL-DUZ", { params ["_v", "_d", "_h", "_vg"]; _v setDriveOnPath [getPosATL _v, _h]; }],
        ["PATH-YENILE", { params ["_v", "_d", "_h", "_vg"]; _d disableAI "PATH"; sleep 0.3; _d enableAI "PATH"; _d doMove _h; }],
        ["FSM-KAPAT", { params ["_v", "_d", "_h", "_vg"]; _d disableAI "FSM"; _d doMove _h; }]
    ];
    private _kz = missionNamespace getVariable [QGVAR(deneyKazanan), ""];
    if (_kz isNotEqualTo "") then { _onlemler = (_onlemler select {(_x select 0) isEqualTo _kz}) + (_onlemler select {(_x select 0) isNotEqualTo _kz}); };
    private _bulunan = "";
    {
        _x params ["_ad", "_kod"];
        if (_bulunan isEqualTo "" && {alive _v} && {alive _d}) then {
            private _p0 = getPosATL _v;
            [_v, _d, _h, _vg] call _kod;
            sleep 4;
            private _git = (getPosATL _v) distance2D _p0;
            private _ok = _git > 6 && {(speed _v) > 3};
            diag_log format ["[SURME-DENEY] %1 | %2: 4 sn'de %3 m, hiz %4 km/s -> %5", _et, _ad, round _git, round (speed _v), ["calismadi", "CALISTI"] select _ok];
            if (_ad isEqualTo "FSM-KAPAT" && {!_ok}) then { _d enableAI "FSM"; };
            if (_ok) then { _bulunan = _ad; };
        };
    } forEach _onlemler;
    if (_bulunan isNotEqualTo "") then {
        missionNamespace setVariable [QGVAR(deneyKazanan), _bulunan];
        diag_log format ["[SURME-DENEY] %1 | KAZANAN ONLEM: %2 (sonraki duran aracta once denenir)", _et, _bulunan];
    } else {
        diag_log format ["[SURME-DENEY] %1 | HICBIR ONLEM CALISMADI -> kinematik surus", _et];
    };
    _v setVariable [QGVAR(deneyCalisiyor), nil];
};
