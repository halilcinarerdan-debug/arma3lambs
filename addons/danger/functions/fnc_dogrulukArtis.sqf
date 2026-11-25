#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * DOGRULUK ARTISI (v8.557; kullanici: 'mermi attikca dogruluk orani artsin, hedef sabitse gittikce artmaya baslasin isabet ihtimali').
 * Ayni SABIT hedefe ARDISIK atis yapan yerel AI askerin nisan dogrulugu (aimingAccuracy) atis basina artar: 3. atistan itibaren her atis +0.03 (CBA dogrulukMaks, varsayilan 0.30'a kadar); ayni zamanda aimingShake +0.5 x bonus.
 * 'Ardisik' = onceki atistan <= 3 sn, ayni hedef (assignedTarget / en yakin dusman) ve hedef SABIT (hiz < 2 km/s, seri baslangicindan <= 2 m). Hedef degisir / kosarsa / 3 sn atis yoksa bonus SIFIRLANIR (beceri eski degerine doner).
 * Uygulanan miktar birim degiskeninde (dogrUyg / dogrUygS) tutulur: baska katmanlarin setSkill degisiklikleri bozulmaz (taban = guncel beceri - uygulanan). Oyuncu atislari etkilenmez. Kapatma: CBA dogrulukArtis.
 * Log: [DOGRULUK] (ilk 25 ornek).
 *
 * Arguments: None
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isNil "lambs_danger_dogrulukStarted") exitWith {false};
lambs_danger_dogrulukStarted = true;
diag_log "[DOGRULUK] sabit hedefe ardisik atista dogruluk artisi baslatildi (v8.557): 3. atistan itibaren +0.03 / atis (CBA dogrulukMaks)";

["CAManBase", "Fired", {
    params ["_u", "_wep"];
    if (!local _u || {isPlayer _u} || {(((units group _u) findIf {isPlayer _x}) > -1) && {!(missionNamespace getVariable ["lambs_danger_oyuncuGrubuBot", false])}} || {[_u] call lambs_danger_fnc_aliveSahip} || {_u getVariable ["lambs_danger_disableAI", false]} || {!(missionNamespace getVariable ["lambs_danger_dogrulukArtis", true])}) exitWith {};
    if (_wep isEqualTo (secondaryWeapon _u) || {_wep isEqualTo (handgunWeapon _u)}) exitWith {};
    private _t = assignedTarget _u;
    if (isNull _t || {!alive _t}) then { _t = _u findNearestEnemy _u; };
    if (isNull _t || {!alive _t}) exitWith {};
    // v8.559: doSuppressiveFire'in 'SuppressTarget' mantiksal nesnesi gercek hedef degil (RPT 1c620d7d: bastirma atesi sabit hedef sayilip +0.30 aldi) -> yalniz gercek piyade / kara araci
    if !(_t isKindOf "CAManBase" || {_t isKindOf "LandVehicle"}) exitWith {};
    private _eski = _u getVariable [QGVAR(dogrHedef), objNull];
    private _poz0 = _u getVariable [QGVAR(dogrPoz), [0, 0, 0]];
    private _n = _u getVariable [QGVAR(dogrN), 0];
    private _sabit = ((speed _t) < 2) && {((getPosATL _t) distance2D _poz0) <= 2};
    if (_t isEqualTo _eski && {(time - (_u getVariable [QGVAR(dogrT), -99])) <= 3} && {_sabit}) then {
        _n = _n + 1;
    } else {
        _n = 1;
        _u setVariable [QGVAR(dogrPoz), getPosATL _t];
        _u setVariable [QGVAR(dogrHedef), _t];
    };
    _u setVariable [QGVAR(dogrN), _n];
    _u setVariable [QGVAR(dogrT), time];
    private _maks = ([_u, "dogrulukMaks", 0.15] call FUNC(ayarTaraf)) max 0 min 1;
    private _bonus = (((_n - 2) max 0) * 0.03) min _maks;
    private _uyg = _u getVariable [QGVAR(dogrUyg), 0];
    if ((abs (_bonus - _uyg)) < 0.005) exitWith {};
    private _uygS = _u getVariable [QGVAR(dogrUygS), 0];
    private _bAcc = (_u skill "aimingAccuracy") - _uyg;
    private _bShk = (_u skill "aimingShake") - _uygS;
    private _yAcc = (_bAcc + _bonus) min 1;
    private _yShk = (_bShk + (_bonus * 0.5)) min 1;
    _u setSkill ["aimingAccuracy", _yAcc];
    _u setSkill ["aimingShake", _yShk];
    _u setVariable [QGVAR(dogrUyg), _yAcc - _bAcc];
    _u setVariable [QGVAR(dogrUygS), _yShk - _bShk];
    if (_n >= 6 && {(missionNamespace getVariable ["lambs_danger_dogrLogN", 0]) < 25}) then {
        missionNamespace setVariable ["lambs_danger_dogrLogN", (missionNamespace getVariable ["lambs_danger_dogrLogN", 0]) + 1];
        diag_log format ["[DOGRULUK] %1 | hedef %2 (sabit) | ardisik atis %3 | nisan %4 -> %5 (bonus +%6)", name _u, (if (_t isKindOf "CAManBase") then {name _t} else {typeOf _t}), _n, _bAcc toFixed 2, _yAcc toFixed 2, (_yAcc - _bAcc) toFixed 2];
    };
}, true, [], true] call CBA_fnc_addClassEventHandler;

// sifirlama: 3 sn atis yoksa bonus kalkar
[] spawn {
    while {true} do {
        sleep 1;
        {
            private _u = _x;
            if ((time - (_u getVariable [QGVAR(dogrT), -99])) > 3 || {!alive _u}) then {
                private _uyg = _u getVariable [QGVAR(dogrUyg), 0];
                private _uygS = _u getVariable [QGVAR(dogrUygS), 0];
                if (alive _u) then {
                    _u setSkill ["aimingAccuracy", ((_u skill "aimingAccuracy") - _uyg) max 0];
                    _u setSkill ["aimingShake", ((_u skill "aimingShake") - _uygS) max 0];
                };
                _u setVariable [QGVAR(dogrUyg), 0];
                _u setVariable [QGVAR(dogrUygS), 0];
                _u setVariable [QGVAR(dogrN), 0];
            };
        } forEach (allUnits select {local _x && {(_x getVariable [QGVAR(dogrUyg), 0]) > 0}});
    };
};
true
