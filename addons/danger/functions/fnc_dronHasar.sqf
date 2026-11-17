#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * FPV / BOMBA DRON DAYANIKLILIGI (v8.564; kullanici: 'dronu feci vuruyorlar'). RPT dc3334c3'te zorla ates olasiligi 0.00 (dronIsabetOran = 0) ve DRON-ATES emri yoktu: oyuncu FPV'lerini VANILLA AI atesi (tank murettebati beceri 0.98) dusuruyordu;
 * dronVurusOlasi / reaksiyon ayarlari o yolu kisamaz. Bu fonksiyon DOGRUDAN hasari kisar: saldiri tipi FPV / bomba dronlarina (fnc_ihaTip: FPV-AT / FPV-AP / BOMBA) HandleDamage olay isleyicisi eklenir;
 * MERMI (BulletBase) + TOP MERMISI (ShellBase; tank ana topu / HE) kaynakli hasar artisi CBA 'dronHasarKatsayi' (0.4 = %60 daha az hasar; 1 = eski) ile carpilir. Carpisma, patlama, kendi imha / kamikaze (mermi disi) hasarina DOKUNULMAZ (mod'un dalis / patlama mantigi bozulmasin).
 * Yalniz drona YEREL makinede calisir (HandleDamage yerel). Zaten eklenmis dronlara bir kez (bayrak QGVAR(dronHasarEH)).
 * Log: [DRON-HASAR] (ilk 10: dron, kaynak, ham -> kisilmis hasar).
 *
 * Arguments: None
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isNil "lambs_danger_dronHasarStarted") exitWith {false};
lambs_danger_dronHasarStarted = true;
diag_log "[DRON-HASAR] FPV / bomba dron mermi hasari kisici baslatildi (v8.564; CBA dronHasarKatsayi)";

["Air", "init", {
    params ["_d"];
    [{
        params ["_d"];
        if (isNull _d || {!local _d} || {_d getVariable [QGVAR(dronHasarEH), false]}) exitWith {};
        if !(([_d] call lambs_danger_fnc_ihaTip) in ["FPV-AT", "FPV-AP", "BOMBA"]) exitWith {};
        _d setVariable [QGVAR(dronHasarEH), true];
        _d addEventHandler ["HandleDamage", {
            params ["_u", "_sel", "_dmg", "_src", "_proj"];
            private _k = ((missionNamespace getVariable ["lambs_danger_dronHasarKatsayi", 0.4]) max 0.02) min 1;
            if (_k >= 1 || {!(_proj isEqualType "")} || {_proj isEqualTo ""} || {!((_proj isKindOf ["BulletBase", configFile >> "CfgAmmo"]) || {_proj isKindOf ["ShellBase", configFile >> "CfgAmmo"]})}) exitWith { _dmg };
            private _cur = if (_sel isEqualTo "") then { damage _u } else { _u getHit _sel };
            if (isNil "_cur" || {!(_cur isEqualType 0)}) then { _cur = 0; };
            private _yeni = _cur + ((_dmg - _cur) * _k);
            if ((missionNamespace getVariable ["lambs_danger_dronHasarLogN", 0]) < 10 && {_sel isEqualTo ""}) then {
                missionNamespace setVariable ["lambs_danger_dronHasarLogN", (missionNamespace getVariable ["lambs_danger_dronHasarLogN", 0]) + 1];
                diag_log format ["[DRON-HASAR] %1 | mermi %2 | kaynak %3 | hasar %4 -> %5 (katsayi %6)", typeOf _u, _proj, typeOf _src, _dmg toFixed 3, _yeni toFixed 3, _k toFixed 2];
            };
            _yeni
        }];
    }, [_d], 1] call CBA_fnc_waitAndExecute;
}, true, [], true] call CBA_fnc_addClassEventHandler;
true
