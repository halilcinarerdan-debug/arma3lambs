#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * BAYGIN ASKER OLUMU (v8.524; kullanici: 'baygin adam yerdeyken olmuyor, sunger gibi' + 'cba ayari ver').
 * Neden: ACE / ACM'de bayilan (INCAPACITATED / ACE_isUnconscious) AI asker, kanamasi pihtilasip durdugunda (ACM coagulationClotting) ya da yalniz bayilma esigini asan hasarla dusmusse
 * yerde SONSUZA kadar yasayabiliyor; ek mermiyi emip olmuyor ('sunger'). Ayrica v8.384 BAYGIN-KORU (setCaptive) dusman AI'nin bayilmislara ates etmesini engelledigi icin kimse bitirmiyor.
 * Bu modul iki kural ekler (yalniz AI; oyuncu bayilmasina DOKUNMAZ):
 *   1) EK ISABET: bayilmis AI, ace_medical_injured olayi (yerel; her hasar isleminden sonra) ile 'N' ek isabet alirsa (CBA lambs_danger_bayginVurus, varsayilan 2) ölür (ace_medical_status_fnc_setDead).
 *      Isabet sayaci 30 sn icinde sifirlanir. Yarali baygin icin tek isabetle (varsayilan 2 -> 1 yapilabilir).
 *   2) YERDE KALMA SURESI: bayilma suresi > lambs_danger_bayginOlmeSure (varsayilan 300 sn; 0 = kapali) ve tedavi gormuyorsa (ace_medical_medicalActivity yok, TCCC meşgul degil) olur (kan kaybi / hipoksi).
 * CBA: lambs_danger_bayginOlum (ana anahtar, varsayilan ACIK), lambs_danger_bayginVurus, lambs_danger_bayginOlmeSure.  Log: [BAYGIN-OLUM] (ilk 30).
 *
 * Arguments: None
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isNil "lambs_danger_bayginOlumStarted") exitWith {false};
lambs_danger_bayginOlumStarted = true;
diag_log "[BAYGIN-OLUM] baygin AI olum kurallari baslatildi (v8.524): ek isabet + yerde kalma suresi (ACE / ACM)";

if (!isNil "CBA_fnc_addEventHandler") then {
    ["ace_medical_injured", {
        params ["_u", ["_agri", 0]];
        if (!(missionNamespace getVariable ["lambs_danger_bayginOlum", true])) exitWith {};
        if (isNull _u || {!alive _u} || {isPlayer _u} || {!local _u}) exitWith {};
        private _bay = ((lifeState _u) in ["INCAPACITATED", "UNCONSCIOUS"]) || {_u getVariable ["ACE_isUnconscious", false]};
        if (!_bay) exitWith {};
        // yalniz gercek hasar (cok kucuk dolayli etkiler sayilmaz): ayni anda gelen isabetleri 0.4 sn'de topla
        if ((time - (_u getVariable [QGVAR(bayginIsabetT), -9])) < 0.4) exitWith {};
        private _n = ((time - (_u getVariable [QGVAR(bayginIsabetT), -999])) < 30);
        private _sayi = [1, (_u getVariable [QGVAR(bayginIsabet), 0]) + 1] select _n;
        _u setVariable [QGVAR(bayginIsabet), _sayi];
        _u setVariable [QGVAR(bayginIsabetT), time];
        if (_sayi >= (missionNamespace getVariable ["lambs_danger_bayginVurus", 2])) then {
            private _oldur = missionNamespace getVariable ["ace_medical_status_fnc_setDead", {}];
            if (!(_oldur isEqualTo {})) then {
                [_u, "ELITE-BAYGIN-EK-ISABET"] call _oldur;
            } else {
                _u setDamage 1;
            };
            if ((missionNamespace getVariable ["lambs_danger_bayginOlumLogN", 0]) < 30) then {
                missionNamespace setVariable ["lambs_danger_bayginOlumLogN", (missionNamespace getVariable ["lambs_danger_bayginOlumLogN", 0]) + 1];
                diag_log format ["[BAYGIN-OLUM] %1 | %2 | bayilmisken %3 ek isabet -> OLDU", groupId (group _u), name _u, _sayi];
            };
        };
    }] call CBA_fnc_addEventHandler;
};

[] spawn {
    while {true} do {
        sleep 5;
        if (!(missionNamespace getVariable ["lambs_danger_bayginOlum", true])) then { continue };
        private _sure = missionNamespace getVariable ["lambs_danger_bayginOlmeSure", 300];
        if (_sure <= 0) then { continue };
        {
            private _u = _x;
            if (!local _u || {!alive _u} || {isPlayer _u}) then { continue };
            private _bay = ((lifeState _u) in ["INCAPACITATED", "UNCONSCIOUS"]) || {_u getVariable ["ACE_isUnconscious", false]};
            if (!_bay) then { _u setVariable [QGVAR(bayginT0), nil]; continue };
            private _t0 = _u getVariable [QGVAR(bayginT0), -1];
            if (_t0 < 0) then { _u setVariable [QGVAR(bayginT0), time]; continue };
            // tedavi goruyorsa sayac ileri sarilir (sure dolmasin)
            if ((_u getVariable ["ace_medical_medicalActivity", false]) || {time < (_u getVariable [QGVAR(tcccBusy), 0])}) then { _u setVariable [QGVAR(bayginT0), (_t0 + 5) min time]; continue };
            if ((time - _t0) >= _sure) then {
                private _oldur = missionNamespace getVariable ["ace_medical_status_fnc_setDead", {}];
                if (!(_oldur isEqualTo {})) then { [_u, "ELITE-BAYGIN-SURE"] call _oldur; } else { _u setDamage 1; };
                if ((missionNamespace getVariable ["lambs_danger_bayginOlumLogN", 0]) < 30) then {
                    missionNamespace setVariable ["lambs_danger_bayginOlumLogN", (missionNamespace getVariable ["lambs_danger_bayginOlumLogN", 0]) + 1];
                    diag_log format ["[BAYGIN-OLUM] %1 | %2 | bayilmis %3 sn tedavi gormedi -> OLDU (kan kaybi / hipoksi)", groupId (group _u), name _u, round (time - _t0)];
                };
            };
        } forEach (allUnits select {!isPlayer _x && {(side group _x) in [west, east, resistance]}});
    };
};
true
