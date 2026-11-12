#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * SIPERE ZORLA (v8.510; kullanici: 'botlar ates etmekten cover alamiyor, catisma bitince kazanan taraf yeni cover aliyor; FSM cover istediginde onu sipere forceleyecek bir sistem, raycast destegiyle').
 * Neden: AI hedefi gorup ates ederken doMove / moveTo emrini ertelenir (ates 'dur' gibi davranir): fnc_doCover (LAMBS FSM 'cover') yalniz moveTo + yuruyus animasyonu veriyordu, asker catisma bitene kadar yerinde
 * ates edip siperi sonra aliyordu. Bu fonksiyon kisa (<= 3.5 sn) bir SIPERE ATILIS uygular:
 *   1) RAYCAST DOGRULAMA: (a) siper noktasi dusman gozunden GIZLI olmali (FIRE LOD hatti ya da arazi keser; durus yuksekligi 1.5 / 1.0 / 0.4), (b) askerden siper noktasina 0.6 m yukseklikte hat (GEOM) engelsiz
 *      (duvar / cit icinden gecilmez), (c) siper dusmana ilk konumdan >= 4 m daha yaklasmamali.
 *   2) ATILIS: hedef secimi (AUTOTARGET + TARGET) kapatilir (asker nisan alip durmaz), forceSpeed -1, FULL hiz, ayakta (UP), doMove; varinca ya da 3.5 sn sonra HER DURUMDA geri acilir,
 *      varista durus (MIDDLE / DOWN) + dusmana bakis; ates serbest.
 *   3) KORUMA: dusman <= 8 m (yakin dovus: fnc_yakinAtes ates etsin), asker forceMove / teslim / baygin, LAMBS gorevi / kal-bekle waypoint (fnc_senaryoKapi 'sabit'), 5 sn tekrar siniri.
 * Cagiranlar: fnc_doCover (FSM cover istegi; main), fnc_acikSiper (acikta kalan). Kapatma: lambs_danger_siperZorla = false.  Log: [SIPER-ZORLA] (ilk 40).
 *
 * Arguments:
 * 0: Asker <OBJECT>
 * 1: Siper noktasi (AGL) <ARRAY>
 * 2: Dusman <OBJECT> (opsiyonel; yoksa en yakin bilinen)
 * 3: Varis durusu "UP" / "MIDDLE" / "DOWN" <STRING> (opsiyonel, varsayilan MIDDLE)
 *
 * Return Value: Atilis baslatildi mi <BOOL>
 * Public: No
*/

params [["_u", objNull, [objNull]], ["_pos", [], [[]]], ["_e", objNull, [objNull]], ["_ds", "MIDDLE", [""]]];
if (!(missionNamespace getVariable ["lambs_danger_siperZorla", true])) exitWith {false};
if (isNull _u || {!alive _u} || {_pos isEqualTo []} || {!local _u} || {isPlayer _u} || {!isNull objectParent _u}) exitWith {false};
if ((lifeState _u) in ["INCAPACITATED", "UNCONSCIOUS"] || {captive _u} || {_u getVariable [QGVAR(teslim), false]} || {_u getVariable [QGVAR(forceMove), false]}) exitWith {false};
if (time < (_u getVariable [QGVAR(zorlaT), 0])) exitWith {false};
if ((_u getVariable [QGVAR(zorlaBitis), 0]) > time) exitWith {false};   // atilis suruyor
if ([group _u, "siperZorla", true] call FUNC(senaryoKapi)) exitWith {false};
if (isNull _e || {!alive _e}) then { _e = _u findNearestEnemy _u; };
if (isNull _e || {!alive _e}) exitWith {false};

private _uPos = getPosATL _u;
private _mes = _uPos distance2D _pos;
if (_mes < 1.2 || {_mes > 20}) exitWith {false};
private _ed = _u distance2D _e;
if (_ed <= 8) exitWith {false};   // yakin dovus: kacma, ates et (fnc_yakinAtes)
if ((_pos distance2D _e) < (_ed - 4)) exitWith {false};   // dusmana 4 m'den fazla yaklastirmaz

// RAYCAST (a): siper dusman gozunden gizli mi
private _eASL = eyePos _e;
private _pASL = AGLToASL [_pos select 0, _pos select 1, 0];
private _gizli = ([1.5, 1.0, 0.4] findIf {
    (lineIntersectsSurfaces [_eASL, _pASL vectorAdd [0, 0, _x], _e, _u, true, 1, "FIRE", "NONE"]) isNotEqualTo [] || {terrainIntersectASL [_eASL, _pASL vectorAdd [0, 0, _x]]}
}) > -1;
if (!_gizli) exitWith {false};
// RAYCAST (b): yol engelsiz mi (0.6 m yukseklikte GEOM)
private _uASL = (getPosASL _u) vectorAdd [0, 0, 0.6];
private _pATL = _pASL vectorAdd [0, 0, 0.6];
if ((lineIntersectsSurfaces [_uASL, _pATL, _u, objNull, true, 1, "GEOM", "NONE"]) isNotEqualTo []) exitWith {false};

_u setVariable [QGVAR(zorlaT), time + 5];
_u setVariable [QGVAR(zorlaBitis), time + 3.5];
_u setVariable [QGVAR(taktikKilit), time + 3.5];
private _atVar = _u checkAIFeature "AUTOTARGET";
private _tVar = _u checkAIFeature "TARGET";
if (_atVar) then { _u disableAI "AUTOTARGET"; };
if (_tVar) then { _u disableAI "TARGET"; };
_u forceSpeed -1;
_u setSpeedMode "FULL";
_u setUnitPosWeak "UP";
_u doMove _pos;
if ((missionNamespace getVariable ["lambs_danger_zorlaLogN", 0]) < 40) then {
    missionNamespace setVariable ["lambs_danger_zorlaLogN", (missionNamespace getVariable ["lambs_danger_zorlaLogN", 0]) + 1];
    diag_log format ["[SIPER-ZORLA] %1 | %2 | dusman %3 m | siper %4 m (raycast: gizli + yol acik) | varis durus %5 | hedef secimi 3.5 sn kapali", groupId (group _u), name _u, round _ed, round _mes, _ds];
};
[{
    params ["_uu", "_pp"];
    !alive _uu || {(_uu distance2D _pp) < 1.2}
}, {
    params ["_uu", "_pp", "_dd", "_ee", "_a1", "_t1"];
    if (alive _uu) then {
        if (_a1) then { _uu enableAI "AUTOTARGET"; };
        if (_t1) then { _uu enableAI "TARGET"; };
        _uu setVariable [QGVAR(zorlaBitis), 0];
        _uu setUnitPosWeak _dd;
        if (!isNull _ee && {alive _ee}) then { _uu doWatch _ee; };
    };
}, [_u, _pos, _ds, _e, _atVar, _tVar], 3.5, {
    params ["_uu", "_pp", "_dd", "_ee", "_a1", "_t1"];
    if (alive _uu) then {
        if (_a1) then { _uu enableAI "AUTOTARGET"; };
        if (_t1) then { _uu enableAI "TARGET"; };
        _uu setVariable [QGVAR(zorlaBitis), 0];
    };
}] call CBA_fnc_waitUntilAndExecute;
true
