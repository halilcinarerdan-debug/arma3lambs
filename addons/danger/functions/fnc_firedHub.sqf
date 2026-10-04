#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * ATES MERKEZI — tum piyadelerin "Fired" olayini tek yerden dinler (her makinede, atici o makinede yerelse).
 *
 *   1) EL BOMBASI LISTESI: atilan GrenadeCore mermileri lambs_danger_grenadeList'e girer
 *      (fnc_grenadeAwareness nearObjects taramasina EK olarak bu listeyi de izler).
 *   2) SES / PARLAMA FARKINDALIGI: her atis fnc_soundAwareness'a gider (1.2 sn kisitlamali; roketatar hemen).
 *   3) MG FLAS GIZLEYICI: yerel AI MG'lerin namlusunda susturucu / flas gizleyici yoksa, uyumlu en iyi
 *      flas gizleyici (visibleFire katsayisi < 1, audibleFire >= 0.9) otomatik takilir. 20 sn'de bir tarar.
 *
 * Arguments:
 * None
 *
 * Return Value:
 * Baslatildi mi <BOOL>
 *
 * Public: No
*/

if (!isNil "lambs_danger_firedHubStarted") exitWith {false};
lambs_danger_firedHubStarted = true;
lambs_danger_grenadeList = [];

diag_log "[SES] ates merkezi baslatildi (el bombasi listesi + ses/parlama farkindaligi + MG flas gizleyici)";

[
    "CAManBase",
    "Fired",
    {
        params ["_unit", "_weapon", "_muzzle", "_mode", "_ammo", "_mag", "_proj"];
        _unit setVariable [QGVAR(sonAtisT), time];   // v8.16: yaprak gorus kirici (hedef son 4 sn ates ettiyse unutturulmaz)

        // 0) GENIS TANI: patlayici / firlatilan her mermi (simulation: shotGrenade, shotShell, shotMine, shotSmoke, shotSubmunitions...) bir kez / sinif
        private _simTani = toLower (getText (configFile >> "CfgAmmo" >> _ammo >> "simulation"));
        if ((_simTani in ["shotgrenade", "shotshell", "shotmine", "shotdirectionalbomb", "shotsmoke", "shotilluminating", "shotrocket", "shotmissile"]) || {_ammo isKindOf ["GrenadeCore", configFile >> "CfgAmmo"]}) then {
            if (isNil "lambs_danger_atisTani") then { lambs_danger_atisTani = []; };
            private _anahtar = _weapon + "|" + _ammo;
            if (!(_anahtar in lambs_danger_atisTani) && {(count lambs_danger_atisTani) < 80}) then {
                lambs_danger_atisTani pushBack _anahtar;
                diag_log format ["[ATIS-TANI] %1 | oyuncu:%2 | silah:%3 | muzzle:%4 | mermi:%5 | sim:%6 | GrenadeCore:%7", name _unit, isPlayer _unit, _weapon, _muzzle, _ammo, _simTani, _ammo isKindOf ["GrenadeCore", configFile >> "CfgAmmo"]];
            };
        };

        // 1) El bombasi listesi
        // RHS el bombalari (rhs_ammo_rgd5 / m67...) GrenadeCore'un ALTINDA DEGIL (RPT: GrenadeCore:false, sim:shotgrenade) -> simulation ile de yakala
        if (!isNull _proj && {(_ammo isKindOf ["GrenadeCore", configFile >> "CfgAmmo"]) || {_simTani isEqualTo "shotgrenade"}}) then {
            // tani: el bombasi / 40mm atisi (ilk 60). Zeus uzaktan kontrol / oyuncu atislari da (isPlayer filtresi kaldirildi)
            if (true) then {
                if (isNil "lambs_danger_grLogN") then { lambs_danger_grLogN = 0; };
                if (lambs_danger_grLogN < 60) then {
                    lambs_danger_grLogN = lambs_danger_grLogN + 1;
                    private _grEn = _unit findNearestEnemy _unit;
                    diag_log format ["[GRENADE-ATIS] %1 | %2 | %3 | dusman %4 m", name _unit, _weapon, _ammo, if (isNull _grEn) then {"?"} else {round (_unit distance2D _grEn)}];
                };
            };
            lambs_danger_grenadeList = lambs_danger_grenadeList select {!isNull _x};
            if ((count lambs_danger_grenadeList) < 60) then {
                lambs_danger_grenadeList pushBack _proj;
                _proj setVariable [QGVAR(grSeen), time];
            };
        };

        // 1b) RPG / roketatar tepkisi: karsi taraf gruplari oncelikli ates + dagilma (formasyon korunur)
        if (
            (getNumber (configFile >> "CfgWeapons" >> _weapon >> "type")) isEqualTo 4
            && {_ammo isKindOf ["RocketBase", configFile >> "CfgAmmo"] || {_ammo isKindOf ["MissileBase", configFile >> "CfgAmmo"]}}
        ) then {
            [_unit] call (missionNamespace getVariable ["lambs_danger_fnc_rpgReaction", {0}]);
            // v8.83: dustugu yerde arac murettebati dahil herkese tepki (rpgReaction yalniz piyade)
            if (!isNull _proj) then { ["ROKET", _proj, _unit] call (missionNamespace getVariable ["lambs_danger_fnc_tehditIzle", {false}]); };
            if (isMultiplayer) then {
                [_unit] remoteExecCall ["lambs_danger_fnc_rpgReaction", -clientOwner];
            };
        };

        // 1b2) v8.83 DUMAN: dusman taraf duman bombasi / 40mm duman = tehdit isareti
        if (!isNull _proj && {_simTani isEqualTo "shotsmoke" || {(toLower _ammo) find "smoke" >= 0}}) then {
            ["DUMAN", _proj, _unit] call (missionNamespace getVariable ["lambs_danger_fnc_tehditIzle", {false}]);
        };

        // 2) Ses / parlama (roketatar ve 40mm hemen, digerleri 1.2 sn'de bir)
        private _glMuzzle = [_unit] call (missionNamespace getVariable ["lambs_danger_fnc_hasUGL", {""}]);
        private _agir = ((getNumber (configFile >> "CfgWeapons" >> _weapon >> "type")) isEqualTo 4)
            || {_glMuzzle isNotEqualTo "" && {_muzzle isEqualTo _glMuzzle}};
        if (_agir || {time > (_unit getVariable [QGVAR(sesSon), 0])}) then {
            _unit setVariable [QGVAR(sesSon), time + 1.2];
            [_unit, _weapon, _muzzle, _ammo, _agir] call (missionNamespace getVariable ["lambs_danger_fnc_soundAwareness", {false}]);
            // Oyuncu atisi: baska makinelerdeki (sunucu / HC / diger istemci) YEREL AI'lar da duysun
            if (isMultiplayer && {isPlayer _unit}) then {
                [_unit, _weapon, _muzzle, _ammo, _agir] remoteExecCall ["lambs_danger_fnc_soundAwareness", -clientOwner];
            };
        };
    },
    true,
    [],
    true
] call CBA_fnc_addClassEventHandler;

// 1c) ACE Advanced Throwing: atilan bomba Fired mermisi DEGIL, ace_throwableThrown olayiyla gelir (listeye ekle)
{
    [_x, {
        params ["_unit", "_thr"];
        if (!isNull _thr && {(typeOf _thr) isKindOf "SmokeShell" || {((toLower (typeOf _thr)) find "smoke") >= 0}}) then {
            ["DUMAN", _thr, _unit] call (missionNamespace getVariable ["lambs_danger_fnc_tehditIzle", {false}]);
        };
        if (!isNull _thr) then {
            lambs_danger_grenadeList = lambs_danger_grenadeList select {!isNull _x};
            if ((count lambs_danger_grenadeList) < 60) then {
                lambs_danger_grenadeList pushBack _thr;
                _thr setVariable [QGVAR(grSeen), time];
            };
        };
    }] call CBA_fnc_addEventHandler;
} forEach ["ace_throwableThrown", "ace_advanced_throwing_throwableThrown"];

// 3) MG flas gizleyici (yerel AI MG'ler)
[] spawn {
    private _kuralFn = {
        params ["_u"];
        private _w = primaryWeapon _u;
        if (_w isEqualTo "") exitWith {};
        if ((_u getVariable [QGVAR(fhKey), ""]) isEqualTo _w) exitWith {};
        _u setVariable [QGVAR(fhKey), _w];

        private _rol = [_u] call (missionNamespace getVariable ["lambs_danger_fnc_getUnitRole", {"RIFLE"}]);
        if (_rol isNotEqualTo "MG") exitWith {};
        if (((primaryWeaponItems _u) param [0, ""]) isNotEqualTo "") exitWith {};   // zaten susturucu / flas gizleyici var

        private _adaylar = compatibleItems [_w, "MuzzleSlot"];
        if (!(_adaylar isEqualType [])) then { _adaylar = []; };
        private _en = "";
        private _enVis = 1;
        {
            private _ic = configFile >> "CfgWeapons" >> _x >> "ItemInfo" >> "AmmoCoef";
            private _vis = if (isNumber (_ic >> "visibleFire")) then {getNumber (_ic >> "visibleFire")} else {1};
            private _aud = if (isNumber (_ic >> "audibleFire")) then {getNumber (_ic >> "audibleFire")} else {1};
            if (_vis < 0.95 && {_aud >= 0.9} && {_vis < _enVis}) then {
                _en = _x;
                _enVis = _vis;
            };
        } forEach _adaylar;

        if (_en isNotEqualTo "") then {
            _u addPrimaryWeaponItem _en;
            diag_log format ["[SES] MG flas gizleyici takildi: %1 | %2 | %3 (visibleFire x%4)", groupId (group _u), name _u, _en, _enVis];
        };
    };

    while {true} do {
        sleep 20;
        {
            if (alive _x && {local _x} && {!isPlayer _x}) then { [_x] call _kuralFn; };
        } forEach allUnits;
    };
};

true
