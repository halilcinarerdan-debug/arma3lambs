#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * MG BASTIRMA DESTEGI (v8.732; kullanici: 'CQB'de acikta ates gelince hem MG destegi lazim hem eleman arkasini donmeden sipere gecsin'): fnc_acikSiper acikta kalan askeri sipere gonderirken cagirir.
 * Ayni gruptan en yakin (dusmana) MG: canli, yerel AI, kosucu degil, baski < 0.8, mermi > 8, ates hatti acik (fnc_atesHatiAcik: dost yok) ise dusmana doWatch + doSuppressiveFire (kosan asker bastirma altinda ilerler).
 * Grup basina 5 sn'de bir; dusman 8-300 m. CBA mgDestek (varsayilan ACIK). Log: [MG-DESTEK] (ilk 15) + [ACIK-SIPER-OZET] mg_destek sayaci.
 *
 * Arguments:
 * 0: Siper arayan (acikta) asker <OBJECT>
 * 1: Dusman <OBJECT>
 *
 * Return Value: Destek verildi mi <BOOL>
 * Public: No
*/

params [["_u", objNull, [objNull]], ["_en", objNull, [objNull]]];
if (isNull _u || {isNull _en} || {!alive _en} || {!(missionNamespace getVariable ["lambs_danger_mgDestek", true])}) exitWith {false};
private _g = group _u;
if (time < (_g getVariable [QGVAR(mgDestekT), 0])) exitWith {false};
private _d = _u distance2D _en;
if (_d < 8 || {_d > 300}) exitWith {false};
private _rolFn = missionNamespace getVariable ["lambs_danger_fnc_getUnitRole", {"RIFLE"}];
private _mgs = (units _g) select {
    alive _x && {_x isNotEqualTo _u} && {local _x} && {!isPlayer _x} && {isNull objectParent _x} && {(lifeState _x) in ["HEALTHY", "INJURED"]}
    && {([_x] call _rolFn) isEqualTo "MG"} && {(_x distance2D _en) <= 400} && {(_x getVariable [QGVAR(forceMove), false]) isNotEqualTo true}
    && {([_x] call FUNC(baskiSeviye)) < 4} && {(_x ammo (currentMuzzle _x)) > 8}
};
// v8.736 KAPSAMA ATESI (kullanici: 'cover to cover daha profesyonel'): MG yoksa / uygun degilse ayni gruptan YAKIN (<= 40 m) bosta, siperde, ates hatti acik bir dost (tufek / AT / nisanci) kapsama ateşi acar (siperKapsamaAtesi); koşan asker ates altinda yalniz kalmaz
if (_mgs isEqualTo [] && {missionNamespace getVariable ["lambs_danger_siperKapsamaAtesi", true]}) then {
    _mgs = (units _g) select {
        alive _x && {_x isNotEqualTo _u} && {local _x} && {!isPlayer _x} && {isNull objectParent _x} && {(lifeState _x) in ["HEALTHY", "INJURED"]}
        && {(_x distance2D _u) <= 40} && {(_x distance2D _en) <= 250} && {(speed _x) < 2} && {(_x getVariable [QGVAR(forceMove), false]) isNotEqualTo true} && {(_x getVariable [QGVAR(taktikKilit), 0]) <= time}
        && {([_x] call FUNC(baskiSeviye)) < 4} && {(_x ammo (currentMuzzle _x)) > 8}
    };
};
if (_mgs isEqualTo []) exitWith {false};
_mgs = [_mgs, [], {_x distance2D _en}, "ASCEND"] call BIS_fnc_sortBy;
private _mg = _mgs select 0;
if !([_mg, _en] call FUNC(atesHatiAcik)) exitWith {false};
if !([_mg, _en, "mgDestek"] call FUNC(baskiKapisi)) exitWith {false};   // v8.743: uzak + gozlemci yok = bastirma yok
_g setVariable [QGVAR(mgDestekT), time + 5];
_mg doWatch _en;
_mg doSuppressiveFire _en;
private _s = missionNamespace getVariable ["lambs_danger_acikSiperSay", createHashMap];
_s set [(["kapsama_ates", "mg_destek"] select (([_mg] call _rolFn) isEqualTo "MG")), (_s getOrDefault [(["kapsama_ates", "mg_destek"] select (([_mg] call _rolFn) isEqualTo "MG")), 0]) + 1];
missionNamespace setVariable ["lambs_danger_acikSiperSay", _s];
if ((missionNamespace getVariable ["lambs_danger_mgDestekLogN", 0]) < 15) then {
    missionNamespace setVariable ["lambs_danger_mgDestekLogN", (missionNamespace getVariable ["lambs_danger_mgDestekLogN", 0]) + 1];
    diag_log format ["[MG-DESTEK] %1 | %2 siper arayan (dusman %3 m) <- %4 bastirma atesi (MG dusmana %5 m)", groupId _g, name _u, round _d, name _mg, round (_mg distance2D _en)];
};
true
