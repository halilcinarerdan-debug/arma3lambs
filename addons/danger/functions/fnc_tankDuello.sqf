#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * TANK DUELLOSU (v8.278; kullanici: 'tanklari dusman tankina karsi daha agresif yap, karsi karsiya gelmiyorlar / risk almiyorlar').
 * Mevzideki tankin bildigi (knowsAbout > 0.5, canli, gercek) EN YAKIN dusman tanki varsa:
 *   - dusman tankina GORUS HATTI var ve <= 1300 m: yerinde kalir, ates eder (hedef dagitimi zaten tank onceligi verir) -> hamle yok.
 *   - gorus hatti YOK ya da > 1300 m: dusman tankina 500-900 m kala GORUS HATTI olan, mumkunse govde-asagi (hull-down) yeni bir ates pozisyonu aranir ve tank oraya sicrar (en cok 350 m atilim;
 *     savunmada birincil mevziden en cok 150 m). 45 sn bekleme, grup basina en cok 8 hamle. Yakin zirhli dusman + hasar > 0.45'te hamle yapilmaz.
 * Mevzi seciminin ayni degiskenlerini kullanir (planZirhPoz / Vardi): fnc_planZirh yeni noktaya surer ve varinca yeniden kilitler. Log: [TANK-DUELLO]
 * Kapatma: lambs_danger_tankDuelloOff = true.
 *
 * Arguments:
 * 0: Grup <GROUP>
 * 1: Arac <OBJECT>
 * 2: Surucu <OBJECT>
 * 3: Savunma mi <BOOL>
 * 4: Objektif <ARRAY>
 * 5: Plan kimligi <STRING>
 *
 * Return Value: Hamle baslatildi mi <BOOL>
 * Public: No
*/

params ["_g", "_v", "_d", "_savunma", "_obj", "_id", ["_plan", createHashMap, [createHashMap]]];
private _l = leader _g;
if (isNull _l || {!local _l} || {!canMove _v} || {(damage _v) > 0.45}) exitWith {false};
if ((time - (_g getVariable ["lambs_danger_tankDuelloT", -999])) < 45) exitWith {false};
if ((_g getVariable ["lambs_danger_tankDuelloN", 0]) >= 8) exitWith {false};
// v8.280 KOORDINASYON (birbirini ortme): ayni planda baska bir tank grubu son 45 sn icinde hamle yaptiysa bu tank yerinde kalip ortu ates verir
private _hk = _plan getOrDefault ["tankHareketK", [grpNull, -999]];
if (!isNull (_hk select 0) && {(_hk select 0) isNotEqualTo _g} && {(time - (_hk select 1)) < 45} && {({alive _x} count (units (_hk select 0))) > 0}) exitWith {false};

private _taraf = side _g;
private _ets = (_l nearTargets 1600) select {
    (_taraf getFriend (_x select 2)) < 0.6
    && {alive (_x select 4)}
    && {(_x select 4) isKindOf "Tank"}
    && {(_l knowsAbout (_x select 4)) > 0.5}
    && {[_x select 4] call FUNC(gercekHedef)}
};
if (_ets isEqualTo []) exitWith {false};
_ets = [_ets, [], {(_x select 0) distance2D _v}, "ASCEND"] call BIS_fnc_sortBy;
private _et = (_ets select 0) select 4;
private _etP = (getPosASL _et) vectorAdd [0, 0, 1.8];
private _dist = _v distance2D _et;

private _gozV = (AGLToASL (getPosATL _v)) vectorAdd [0, 0, 2.4];
private _gorunur = (lineIntersectsSurfaces [_gozV, _etP, _v, _et, true, 1, "VIEW", "FIRE"]) isEqualTo [];
if (_gorunur && {_dist <= 1300}) exitWith {
    // v8.279: gorus hattinda dusman tanki varken tam savas modu (RPT 21-10: grup 'AWARE / YELLOW / FULL / COLUMN' iken 180-290 m'de dusman tanki vardi)
    if ((behaviour _l) isNotEqualTo "COMBAT") then { _g setBehaviour "COMBAT"; };
    if ((combatMode _g) isNotEqualTo "RED") then { _g setCombatMode "RED"; };
    false
};

// ---- yeni ates pozisyonu: dusman tankina 500-900 m, gorus hatti var, govde-asagi tercih ----
private _merkezP = if (_savunma) then { _g getVariable ["lambs_danger_planZirhAsil", getPosATL _v] } else { getPosATL _v };
private _maxAt = [350, 150] select _savunma;
private _brg = _et getDir _v;
private _en = [];
private _enS = -1e9;
{
    private _dd = _x;
    {
        private _a = _x;
        private _p = _et getPos [_dd, _brg + _a];
        if (!surfaceIsWater _p && {(_p distance2D _merkezP) <= _maxAt} && {(nearestObjects [_p, ["House"], 8]) isEqualTo []} && {(count (nearestTerrainObjects [_p, ["TREE"], 10])) < 4}) then {
            private _zemin = AGLToASL [_p select 0, _p select 1, 0];
            private _pe = _zemin vectorAdd [0, 0, 2.4];
            if ((lineIntersectsSurfaces [_pe, _etP, objNull, _et, true, 1, "VIEW", "FIRE"]) isEqualTo []) then {
                private _s = 100 - ((_p distance2D _v) / 8) - ((abs _a) * 0.3);
                // govde-asagi: taret yuksekliginden gorunur ama govdeden (1.0 m) gorunmez
                if ((lineIntersectsSurfaces [_zemin vectorAdd [0, 0, 1.0], _etP, objNull, _et, true, 1, "VIEW", "FIRE"]) isNotEqualTo []) then { _s = _s + 25; };
                if (isOnRoad _p) then { _s = _s - 5; };
                if (_s > _enS) then { _enS = _s; _en = _p; };
            };
        };
    } forEach [0, 20, -20, 40, -40, 60, -60];
} forEach [700, 600, 800, 500, 900];

_g setVariable ["lambs_danger_tankDuelloT", time];
if (_en isEqualTo [] || {(_en distance2D _v) < 40}) exitWith {false};

_g setVariable ["lambs_danger_tankDuelloN", (_g getVariable ["lambs_danger_tankDuelloN", 0]) + 1];
_g setVariable ["lambs_danger_planZirhPoz", _en];
_g setVariable ["lambs_danger_planZirhVardi", nil];
_g setVariable ["lambs_danger_planZirhVardiT", -1];
_g setVariable ["lambs_danger_planZirhKilit", nil];
_g setVariable ["lambs_danger_planZirhHide", false];
_g setVariable ["lambs_danger_planZirhUzatN", 0];
_g setVariable ["lambs_danger_planZirhT", time];
_g setVariable ["lambs_danger_planZirhMax", 100 max (((_v distance2D _en) / 2.2) min 300)];
_g setVariable ["lambs_danger_planZirhYerT", time];
_plan set ["tankHareketK", [_g, time]];
_d enableAI "PATH"; _d enableAI "MOVE"; _d forceSpeed -1;
_d doMove _en;
diag_log format ["[TANK-DUELLO] %1 | %2 %3 | dusman tanki %4 (%5 m, gorus hatti %6) -> yeni ates pozisyonu %7 (%8 m atilim, dusmana %9 m, puan %10) | hamle %11/8",
    _id, groupId _g, getText (configOf _v >> "displayName"), typeOf _et, round _dist, _gorunur, mapGridPosition _en, round (_v distance2D _en), round (_en distance2D _et), round _enS, _g getVariable ["lambs_danger_tankDuelloN", 0]];
true
