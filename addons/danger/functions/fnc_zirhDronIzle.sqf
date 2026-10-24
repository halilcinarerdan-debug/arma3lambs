#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * ZIRHLI ARAC DRON IZLEYICISI — PLANDAN BAGIMSIZ (v8.319; kullanici: 'tank hicbir sey yapmadi'; RPT 24-10 03:39 v8.318: telemetri plan:0 tum oturum, [TANK-DRON] 0, [TANK-IZLE] 0 - tank dron savunmasi
 * yalnizca fnc_planZirh icinden cagriliyordu; Zeus'la / Eden'de yerlestirilmis ve plana ALINMAMIS tank hic tepki vermiyordu). Motor sesi dinleyicisi dronu duyuyor (knowsAbout 0.93) ama tankDron cagrilmiyordu.
 * 2 sn'de bir: yerel, canli, surucusu oyuncu olmayan TANK / IFV / APC icin fnc_tankDron (uyari, yon, MG, duman, zigzag kacis) cagrilir; tanklara fnc_tankIzle (ekip becerisi + tani) bir kez uygulanir.
 * planZirh de cagirmaya devam eder; fnc_tankDron 3 sn'de bir cagriyi zaten kisitlar (cift cagri zararsiz). Kapatma: lambs_danger_zirhDronIzleOff = true (tum dongu) ya da lambs_danger_tankDronOff (yalniz dron savunmasi). v8.349: her zirhli araca bir kez IncomingMissile olay isleyicisi (fnc_zirhUyari) eklenir (tankDronOff'tan bagimsiz).
 *
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isNil "lambs_danger_zirhDronIzleStarted") exitWith {false};
lambs_danger_zirhDronIzleStarted = true;
diag_log "[TANK-DRON] plandan bagimsiz zirhli arac dron izleyicisi baslatildi (v8.319): her tank / IFV / APC icin tankDron";

[] spawn {
    while {true} do {
        sleep 2;
        if (missionNamespace getVariable ["lambs_danger_zirhDronIzleOff", false]) then { continue };
        private _dronKapali = missionNamespace getVariable ["lambs_danger_tankDronOff", false];
        {
            private _v = _x;
            private _d = driver _v;
            if (isNull _d || {isPlayer _d} || {!alive _d} || {!local _v}) then { continue };
            private _g = group _d;
            if (isNull _g || {(side _g) isEqualTo civilian}) then { continue };
            private _sinif = (([_v] call FUNC(aracSinif)) select 0);
            if (!(_sinif in ["TANK", "IFV", "APC"])) then { continue };
            // v8.349: gudumlu fuze uyarisi (IncomingMissile) — dron savunmasi kapali olsa da eklenir
            if (isNil {_v getVariable QGVAR(zirhUyariEH)}) then { _v setVariable [QGVAR(zirhUyariEH), true]; _v addEventHandler ["IncomingMissile", { _this call FUNC(zirhUyari) }]; };
            if (_dronKapali) then { continue };
            if (_sinif isEqualTo "TANK" && {isNil {_v getVariable QGVAR(tankIzleTamam)}}) then { _v setVariable [QGVAR(tankIzleTamam), true]; [_v] call FUNC(tankIzle); };
            [_g, _v, _d] call FUNC(tankDron);
        } forEach (vehicles select {alive _x && {local _x} && {(_x isKindOf "Tank") || {_x isKindOf "Tracked_APC_F"} || {_x isKindOf "Wheeled_APC_F"}} && {(crew _x) isNotEqualTo []}});
    };
};
true
