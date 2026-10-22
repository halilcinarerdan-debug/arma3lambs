#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * TOPCU ATIS HAZIRLIGI + TANI (v8.287; kullanici: 'topcu ates etmedi'; RPT 22-10 18:47: Zeus test 18:50:25 'ATES EMRI VERILDI (3263 m, 3 mermi, ETA 27 sn)' ama atis olup olmadigi hicbir yerde loglanmiyordu; arac o sirada onceki
 *   yer degistirme emriyle 'komut MOVE | beh SAFE | hiz 0' durumundaydi).
 * doArtilleryFire cagrilmadan ONCE (plan atisi ve Zeus topcu testi):
 *   - arac hareket ediyorsa ya da surucunun hala bir hareket emri (MOVE) varsa iptal edilir (doStop) - yerinde durup atar (hedef menzil icinde zaten kontrol edildi)
 *   - grup davranisi SAFE / CARELESS ise AWARE'e, combatMode BLUE / GREEN ise YELLOW'a alinir (topcu nisancisi 'ates etme' modunda kalmasin)
 *   - nisanci AI parcalari (TARGET / AUTOTARGET / FSM) acilir (baska bir betik kapatmis olabilir)
 * TANI (arac basina bir kez): Fired olayi [TOPCU-ATIS] (mermi, kacinci atis, hedef konumu); atis emrinden 14 sn sonra hic atis olmadiysa [TOPCU-ATIS] ... ATIS YOK + durum dokumu
 *   (davranis, combatMode, komut, hiz, nisanci hazir mi, canFire, mermi, sarj, yerel mi, motor).
 * Kapatma: lambs_danger_topcuHazirlaOff = true.
 *
 * Arguments:
 * 0: Topcu araci <OBJECT>
 * 1: Hedef konumu <ARRAY>
 * 2: Mermi sinifi (magazin) <STRING>
 *
 * Return Value: Hazirlik yapildi mi <BOOL>
 * Public: No
*/

params [["_v", objNull, [objNull]], ["_poz", [], [[]]], ["_mg", "", [""]]];
if (isNull _v || {!alive _v} || {!local _v}) exitWith {false};

private _gn = gunner _v;
private _d = driver _v;
if (isNull _gn) exitWith {false};

// ---- tani: Fired olayi (bir kez) ----
if !(_v getVariable [QGVAR(topcuIzleEH), false]) then {
    _v setVariable [QGVAR(topcuIzleEH), true];
    _v addEventHandler ["Fired", {
        params ["_u", "_w", "_m", "_mode", "_ammo", "_mag"];
        private _n = (_u getVariable [QGVAR(topcuAtisN), 0]) + 1;
        _u setVariable [QGVAR(topcuAtisN), _n];
        if (_n <= 12) then {
            diag_log format ["[TOPCU-ATIS] %1 | ATIS %2 | %3 / %4 | hedef %5", getText (configOf _u >> "displayName"), _n, _mag, _ammo, mapGridPosition (_u getVariable [QGVAR(topcuHedef), getPosATL _u])];
        };
    }];
};
_v setVariable [QGVAR(topcuHedef), _poz];

if !(missionNamespace getVariable ["lambs_danger_topcuHazirlaOff", false]) then {
    private _g = group _gn;
    if (!isNull _d && {!isPlayer _d} && {((speed _v) > 2) || {(currentCommand _d) isEqualTo "MOVE"}}) then {
        doStop _d;
        _d forceSpeed 0;
        [{ params ["_dd"]; if (!isNull _dd) then { _dd forceSpeed -1; }; }, [_d], 4] call CBA_fnc_waitAndExecute;
    };
    if ((behaviour _gn) in ["SAFE", "CARELESS"]) then { _g setBehaviour "AWARE"; };
    if ((combatMode _g) in ["BLUE", "GREEN"]) then { _g setCombatMode "YELLOW"; };
    { _gn enableAI _x; } forEach ["TARGET", "AUTOTARGET", "FSM"];
};

// ---- tani: 14 sn sonra atis yoksa durum dokumu ----
private _n0 = _v getVariable [QGVAR(topcuAtisN), 0];
[{
    params ["_vv", "_n0", "_mg2", "_poz2"];
    if (isNull _vv || {!alive _vv}) exitWith {};
    private _n1 = _vv getVariable [QGVAR(topcuAtisN), 0];
    if (_n1 > _n0) exitWith { diag_log format ["[TOPCU-ATIS] %1 | emirden sonra %2 atis yapildi (hedef %3)", getText (configOf _vv >> "displayName"), _n1 - _n0, mapGridPosition _poz2]; };
    private _gg = gunner _vv;
    private _dd = driver _vv;
    diag_log format ["[TOPCU-ATIS] %1 | 14 sn: ATIS YOK | yerel %2 | canFire %3 | motor %4 | hiz %5 km/sa | davranis %6 | combatMode %7 | nisanci hazir %8 komut '%9' | surucu komut '%10' | mermi %11 (sarjor %12, ammo %13) | menzilde %14 | atis oncesi toplam %15",
        getText (configOf _vv >> "displayName"), local _vv, canFire _vv, isEngineOn _vv, round (speed _vv),
        if (isNull _gg) then {"-"} else {behaviour _gg}, if (isNull _gg) then {"-"} else {combatMode (group _gg)},
        if (isNull _gg) then {"-"} else {unitReady _gg}, if (isNull _gg) then {"-"} else {currentCommand _gg},
        if (isNull _dd) then {"-"} else {currentCommand _dd}, _mg2, count (magazinesAllTurrets _vv), _vv ammo (currentWeapon _vv),
        _poz2 inRangeOfArtillery [[_vv], _mg2], _n1];
}, [_v, _n0, _mg, _poz], 14] call CBA_fnc_waitAndExecute;

true
