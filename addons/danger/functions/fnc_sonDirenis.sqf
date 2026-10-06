#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * SON DIRENIS (KALE SAVUNMASI) — kalan <= 3 asker, kacis imkansiz / son care ise EN UYGUN BINAYA yerlesir ve orada SAVUNUR (kullanici: "tek kalan askerler garrison atsin,
 * son care ise kaleyi savunsun, max 3, asiri zor durum = gercek CQB").
 *
 * TETIK (fnc_tacticsBreakContact'ten cagrilir): 1-3 canli piyade; dusman 25-250 m; (kayip >= %50 ve dusman <= 150 m) ya da kayip >= %60;
 *   <= 70 m'de bina: >= 2 ic pozisyon, dusmana YAKLASTIRMAYAN (bina dusmana <= 15 m'den fazla yaklasmaz), dusman bina onunde < 25 m degil.
 * ATAMA: her asker icin AYRI ic pozisyon: dusmani GOREN pozisyon +25 (ates edebilir), zemin / 1. kat (z < 4 m) +8, uzaklik -0.4 / m, ayni pozisyonlara 6 m yakin -15.
 * SAVUNMA: LAMBS bu grupta kapali (grup + birim bayragi); combatMode RED; varista doStop + COMBAT + comelme (MIDDLE), dusmana bakar; 240 sn'ye kadar ya da dusman 45 sn bilinmiyor / yok olunca biter.
 * Bitince bayraklar eski haline doner. Kapatma: lambs_danger_sonDirenisV1 = false ya da doktrin sonDirenis = false.
 * Log: [SON-DIRENIS] BASLADI / ATAMA / BITTI. Olay: SonDirenis.
 *
 * Arguments:
 * 0: Grup <GROUP>
 * 1: Tehdit pozisyonu <ARRAY AGL>
 *
 * Return Value:
 * Baslatildi mi <BOOL>
 *
 * Public: No
*/

params [["_group", grpNull, [grpNull]], ["_tehditPos", [0, 0, 0], [[]]]];

if (isNull _group || {!(missionNamespace getVariable ["lambs_danger_sonDirenisV1", true])}) exitWith {false};
if (!([_group, "sonDirenis", true] call FUNC(dk))) exitWith {false};
if (_group getVariable [QGVAR(isSonDirenis), false] || {(time - (_group getVariable [QGVAR(sonDirenisT), -999])) < 120}) exitWith {false};

private _us = (units _group) select {alive _x && {isNull objectParent _x} && {!((lifeState _x) in ["INCAPACITATED", "UNCONSCIOUS"])}};   // v8.91
private _n = count _us;
if (_n < 1 || {_n > 3}) exitWith {false};
private _lider = if (alive (leader _group)) then {leader _group} else {_us select 0};
private _eMes = _lider distance2D _tehditPos;
if (_eMes < 25 || {_eMes > 250}) exitWith {false};
private _init = _group getVariable [QGVAR(cmdInitialCount), _n];
if (!(_init isEqualType 0)) then { _init = _n; };
private _kayip = if (_init > 0) then {(_init - _n) / _init} else {0};
if (!((_kayip >= 0.5 && {_eMes <= 150}) || {_kayip >= 0.6})) exitWith {false};

// --- bina secimi ---
private _eEz = AGLToASL (_tehditPos vectorAdd [0, 0, 1.6]);
private _enIyiB = objNull;
private _enIyiBS = -9999;
{
    private _b = _x;
    private _pozlar = _b buildingPos -1;
    if ((count _pozlar) >= 2) then {
        private _bE = (getPosATL _b) distance2D _tehditPos;
        if (_bE >= 25 && {_bE >= (_eMes - 15)}) then {
            private _s = (-0.5 * (_lider distance2D _b)) + (((count _pozlar) min 8) * 1.0) + ([0, 10] select (_bE > _eMes));
            if (_s > _enIyiBS) then { _enIyiBS = _s; _enIyiB = _b; };
        };
    };
} forEach (nearestTerrainObjects [getPosATL _lider, ["BUILDING", "HOUSE"], 70, true, true]);
if (isNull _enIyiB) exitWith {false};

// --- pozisyon atamasi ---
private _pozlar = _enIyiB buildingPos -1;
private _atanan = [];
private _atamalar = [];
{
    private _u = _x;
    private _enP = [];
    private _enPS = -9999;
    {
        private _p = _x;
        private _pA = AGLToASL (_p vectorAdd [0, 0, 1.4]);
        private _gorur = !(terrainIntersectASL [_eEz, _pA] || {lineIntersects [_eEz, _pA, objNull, objNull]});
        private _s = (-0.4 * (_u distance2D _p)) + ([0, 25] select _gorur) + ([0, 8] select ((_p select 2) < 4));
        if ((_atanan findIf {(_x distance2D _p) < 6}) > -1) then { _s = _s - 15; };
        if (_s > _enPS) then { _enPS = _s; _enP = _p; };
    } forEach _pozlar;
    if (_enP isNotEqualTo []) then {
        _atanan pushBack _enP;
        _atamalar pushBack [_u, _enP];
        diag_log format ["[SON-DIRENIS] %1 | ATAMA %2 -> kat z:%3 m | dusmani goruyor:%4 | uzaklik %5 m", groupId _group, name _u, (_enP select 2) toFixed 1, !(terrainIntersectASL [_eEz, AGLToASL (_enP vectorAdd [0, 0, 1.4])] || {lineIntersects [_eEz, AGLToASL (_enP vectorAdd [0, 0, 1.4]), objNull, objNull]}), round (_u distance2D _enP)];
    };
} forEach _us;
if (_atamalar isEqualTo []) exitWith {false};

// --- bayraklar ---
private _eskiDGA = _group getVariable [QGVAR(disableGroupAI), false];
private _eskiCM = combatMode _group;
_group setVariable [QGVAR(isSonDirenis), true];
_group setVariable [QGVAR(isExecutingTactic), true];
_group setVariable [QGVAR(disableGroupAI), true];
_group setVariable [QGVAR(sonDirenisT), time];
_group setCombatMode "RED";
_group setBehaviour "COMBAT";
{
    private _u = _x select 0;
    _u setVariable [QGVAR(sdEskiDAI), _u getVariable [QGVAR(disableAI), false]];
    _u setVariable [QGVAR(disableAI), true];
    _u allowFleeing 0;
    _u enableAI "PATH"; _u enableAI "MOVE"; _u enableAI "TARGET"; _u enableAI "AUTOTARGET"; _u enableAI "AUTOCOMBAT"; _u enableAI "COVER";
    _u setVariable [QGVAR(forceMove), true];
    _u setUnitPos "UP";
    _u forceSpeed -1;
    _u doMove (_x select 1);
} forEach _atamalar;

diag_log format ["[SON-DIRENIS] %1 | BASLADI | %2 asker | kayip %3%% | dusman %4 m | bina:%5 (%6 ic pozisyon) | son care: kale savunmasi", groupId _group, count _atamalar, round (_kayip * 100), round _eMes, typeOf _enIyiB, count _pozlar];
[_group, "SonDirenis", count _atamalar] call FUNC(olayGonder);

[_group, _atamalar, _tehditPos, _eskiDGA, _eskiCM] spawn {
    params ["_g", "_atamalar", "_tp", "_eskiDGA", "_eskiCM"];
    private _t0 = time;
    private _sonDusman = time;
    private _neden = "sure";
    while {time < (_t0 + 240)} do {
        sleep 2;
        if (isNull _g) exitWith {};
        private _canli = _atamalar select {alive (_x select 0)};
        if (_canli isEqualTo []) exitWith { _neden = "grup yok oldu"; };
        {
            _x params ["_u", "_p"];
            _u setVariable [QGVAR(taktikKilit), time + 6];
            if ((_u distance2D _p) < 2.5 && {_u getVariable [QGVAR(forceMove), false]}) then {
                _u setVariable [QGVAR(forceMove), nil];
                doStop _u;
                _u setUnitPos "MIDDLE";
                _u doWatch _tp;
            };
        } forEach _canli;
        private _l = (_canli select 0) select 0;
        private _en = _l findNearestEnemy _l;
        if (!isNull _en && {alive _en} && {(_l distance2D _en) < 250}) then { _sonDusman = time; _tp = getPosATL _en; };
        if ((time - _sonDusman) > 45) exitWith { _neden = "dusman 45 sn yok / uzak"; };
    };
    if (!isNull _g) then {
        _g setVariable [QGVAR(isSonDirenis), nil];
        _g setVariable [QGVAR(isExecutingTactic), nil];
        _g setVariable [QGVAR(disableGroupAI), [nil, true] select _eskiDGA];
        _g setCombatMode _eskiCM;
        _g setVariable [QGVAR(bcEndTime), time];
        _g setVariable [QGVAR(sonDirenisT), time];
        {
            private _u = _x select 0;
            if (alive _u) then {
                _u setVariable [QGVAR(disableAI), [nil, true] select (_u getVariable [QGVAR(sdEskiDAI), false])];
                _u setVariable [QGVAR(sdEskiDAI), nil];
                _u setVariable [QGVAR(taktikKilit), nil];
                _u setVariable [QGVAR(forceMove), nil];
                _u setUnitPos "AUTO";
                _u doWatch objNull;
                _u doFollow (leader _u);
            };
        } forEach _atamalar;
        diag_log format ["[SON-DIRENIS] %1 | BITTI | neden:%2 | sure:%3 sn | kalan:%4", groupId _g, _neden, round (time - _t0), count ((units _g) select {alive _x})];
    };
};

true
