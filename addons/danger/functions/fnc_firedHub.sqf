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

        // 0b) v8.93 BAYGIN HEDEFE PATLAYICI YOK (kullanici: 'yerdeki baygin adami rpg ve el bombasiyla infaz ediyor; etrafta tehdit yoksa gerek yok'):
        //   atilan el bombasi / roket / fuze / 40mm, birimin hedefi BAYGIN (ACE) bir dusman ise VE hedefin 35 m cevresinde bayilmamis bir dusman yoksa mermi hemen silinir + hedef unutulur.
        //   (Tufek ateşi serbest: dogrulama atisi; yalniz patlayici israfi / infaz engellenir.) Kapatma: lambs_danger_bayginPatlayiciOff = true.
        if (!isNull _proj && {!(missionNamespace getVariable ["lambs_danger_bayginPatlayiciOff", false])} && {_simTani in ["shotgrenade", "shotrocket", "shotmissile", "shotshell"]}) then {
            private _tgt = getAttackTarget _unit;
            if (isNull _tgt) then { _tgt = assignedTarget _unit; };
            // v8.99: atilan el bombasinin hedefi yok (getAttackTarget bos) -> balistik inis noktasi 12 m'sindeki en yakin dusman hedef sayilir
            if (isNull _tgt && {_simTani isEqualTo "shotgrenade"}) then {
                private _pv = velocity _proj;
                private _pp = getPosASL _proj;
                private _hh = (_pp select 2) - (getTerrainHeightASL [_pp select 0, _pp select 1]);
                private _tt = (((_pv select 2) + sqrt (((_pv select 2) ^ 2) + 19.62 * (_hh max 0))) / 9.81) max 0;
                private _land = [(_pp select 0) + (_pv select 0) * _tt, (_pp select 1) + (_pv select 1) * _tt, 0];
                private _uSide = side (group _unit);
                private _ad = ((_land nearEntities ["CAManBase", 12]) select {alive _x && {_uSide getFriend (side (group _x)) < 0.6}});
                if (_ad isNotEqualTo []) then {
                    _ad = [_ad, [], {_x distance2D _land}, "ASCEND"] call BIS_fnc_sortBy;
                    _tgt = _ad select 0;
                };
            };
            if (!isNull _tgt && {_tgt isKindOf "CAManBase"} && {alive _tgt} && {((lifeState _tgt) isEqualTo "INCAPACITATED") || {_tgt getVariable ["ACE_isUnconscious", false]}}) then {
                private _tSide = side (group _tgt);
                private _bilincliYakin = (_tgt nearEntities ["CAManBase", 35]) findIf {
                    alive _x && {_x isNotEqualTo _tgt} && {(side (group _x)) isEqualTo _tSide}
                    && {!((lifeState _x) in ["INCAPACITATED", "UNCONSCIOUS"])} && {!(_x getVariable ["ACE_isUnconscious", false])}
                };
                if (_bilincliYakin < 0) then {
                    deleteVehicle _proj;
                    _unit forgetTarget _tgt;
                    if (isNil "lambs_danger_bayginEngelN") then { lambs_danger_bayginEngelN = 0; };
                    if (lambs_danger_bayginEngelN < 60) then {
                        lambs_danger_bayginEngelN = lambs_danger_bayginEngelN + 1;
                        diag_log format ["[BAYGIN-ROE] %1 | %2 | %3 (%4) baygin hedefe PATLAYICI iptal | hedef %5 | 35 m'de bilincli dusman yok", groupId (group _unit), name _unit, _weapon, _ammo, name _tgt];
                    };
                };
            };
        };

        // 0c) v8.115 PLAN ROE: 'binalara agir silah / bomba yasak' (Zeus Objektif kisiti): grup bayragi lambs_danger_agirYasak; hedef (ya da bomba iniş noktasi) bir binanin 15 m'sindeyse patlayici iptal
        if (!isNull _proj && {(group _unit) getVariable ["lambs_danger_agirYasak", false]} && {_simTani in ["shotgrenade", "shotrocket", "shotmissile", "shotshell"]}) then {
            private _hedefP = [];
            private _tg = getAttackTarget _unit;
            if (isNull _tg) then { _tg = assignedTarget _unit; };
            if (!isNull _tg) then { _hedefP = getPosATL _tg; };
            if (_hedefP isEqualTo [] && {_simTani isEqualTo "shotgrenade"}) then { _hedefP = (getPosATL _unit) getPos [((_unit distance2D _proj) max 20) min 35, getDir _unit]; };
            if (_hedefP isNotEqualTo [] && {((nearestObjects [_hedefP, ["House"], 15]) findIf {count (_x buildingPos -1) > 0}) >= 0}) then {
                deleteVehicle _proj;
                if (isNil "lambs_danger_planRoeN") then { lambs_danger_planRoeN = 0; };
                if (lambs_danger_planRoeN < 40) then {
                    lambs_danger_planRoeN = lambs_danger_planRoeN + 1;
                    diag_log format ["[PLAN-ROE] %1 | %2 | %3 (%4) binadaki hedefe patlayici IPTAL (plan kisiti: binalara agir silah / bomba yasak)", groupId (group _unit), name _unit, _weapon, _ammo];
                };
            };
        };

        // 0c) v8.383 EL BOMBASI MESAFE KAPISI (kullanici: 'mesafe kontrolu olsun, cok uzaga el bombasi atmaya calisti'; RPT 12:08:29: Faulkner'in bombasi MOTOR atisiydi - [PATLAYICI] kapisindan gecmedi, hedefi bilinmiyordu).
        //   Script atislari (fnc_patlayici) createVehicle ile gelir ve 'Fired' olayi UretMEZ; Fired ile gelen 'Throw' el bombasi motorun kendi kararidir. Dusus noktasi azami mesafeyi (varsayilan 40 m +8) ya da bilinen hedef 55 m'yi asarsa
        //   mermi silinir + bomba envantere geri verilir; atici 20 sn bu tur bombayi elinde tutmaz (motor ayni uzak hedefe tekrar tekrar atmaya calismasin). Kapatma: lambs_danger_elBombasiMesafeOff = true.
        if (!isNull _proj && {_weapon isEqualTo "Throw"} && {_simTani isEqualTo "shotgrenade"} && {!isPlayer _unit} && {!(missionNamespace getVariable ["lambs_danger_elBombasiMesafeOff", false])}) then {
            private _bMax = missionNamespace getVariable ["lambs_danger_elBombasiMaxMesafe", 40];
            private _gv = velocity _proj;
            private _gp = getPosASL _proj;
            private _gh = (_gp select 2) - (getTerrainHeightASL [_gp select 0, _gp select 1]);
            private _gt = (((_gv select 2) + sqrt (((_gv select 2) ^ 2) + 19.62 * (_gh max 0))) / 9.81) max 0;
            private _gland = [(_gp select 0) + (_gv select 0) * _gt, (_gp select 1) + (_gv select 1) * _gt, 0];
            private _gUzak = (getPosASL _unit) distance2D _gland;
            private _gHedef = getAttackTarget _unit;
            if (isNull _gHedef) then { _gHedef = assignedTarget _unit; };
            private _gHM = if (isNull _gHedef) then { -1 } else { _unit distance2D _gHedef };
            // v8.384: dusus noktasinin 12 m'sinde yalniz BAYGIN dusman var (35 m'de saglam dusman yok) -> bomba israfi / infaz: iptal
            private _gTaraf = side (group _unit);
            private _gBay = (_gland nearEntities ["CAManBase", 12]) select {alive _x && {(_gTaraf getFriend (side (group _x))) < 0.6} && {((lifeState _x) in ["INCAPACITATED", "UNCONSCIOUS"]) || {_x getVariable ["ACE_isUnconscious", false]}}};
            private _gBaygin = _gBay isNotEqualTo [] && {((_gland nearEntities ["CAManBase", 35]) findIf {alive _x && {(_gTaraf getFriend (side (group _x))) < 0.6} && {(lifeState _x) in ["HEALTHY", "INJURED"]}}) isEqualTo -1};
            if (_gUzak > (_bMax + 8) || {_gHM > 55} || {_gBaygin}) then {
                deleteVehicle _proj;
                _unit addMagazine _mag;
                private _gN = {_x isEqualTo _mag} count (magazines _unit);
                _unit removeMagazines _mag;
                [{ params ["_uu", "_mm", "_nn"]; if (alive _uu) then { _uu addMagazines [_mm, _nn]; }; }, [_unit, _mag, _gN], 20] call CBA_fnc_waitAndExecute;
                lambs_danger_bombaMesafeN = (missionNamespace getVariable ["lambs_danger_bombaMesafeN", 0]) + 1;
                if (lambs_danger_bombaMesafeN <= 40) then {
                    diag_log format ["[EL-BOMBASI-MESAFE] %1 | %2 | motor atisi IPTAL: dusus %3 m (limit %4+8) | bilinen hedef %5 m (limit 55) | baygin hedef:%7 | bomba 20 sn elde tutulmaz | toplam %6", groupId (group _unit), name _unit, round _gUzak, _bMax, if (_gHM < 0) then {"yok"} else {round _gHM}, lambs_danger_bombaMesafeN, _gBaygin];
                };
            };
        };

        // 0d) v8.383 MOTOR SISI KAPISI (kullanici: 'sis cooldownunu test et, sis atip duruyorlar'): fnc_sisButce yalniz mod atislarini (tacticalSmoke / saldiri / kanat) sayar; motorun kendi (ates altinda) el dumani bu butceyi ATLIYORDU
        //   (RPT 12:07: Dorgan 8 sn arayla iki sis, [SIS-BUTCE] kaydi yok). Mod sis atmadan 'sisIzin' koyar (15 sn); izinsiz standart (beyaz) el dumani silinir + geri verilir. Kapatma: lambs_danger_sisMotorOff = true.
        if (!isNull _proj && {_weapon isEqualTo "Throw"} && {_simTani isEqualTo "shotsmoke"} && {!isPlayer _unit} && {!(missionNamespace getVariable ["lambs_danger_sisMotorOff", false])}) then {
            private _an = toLower _ammo;
            private _standart = (["red", "green", "blue", "yellow", "purple", "orange"] findIf {(_an find _x) >= 0}) < 0;
            if (_standart) then {
                if (time <= (_unit getVariable [QGVAR(sisIzin), -1])) then {
                    lambs_danger_sisAtisN = (missionNamespace getVariable ["lambs_danger_sisAtisN", 0]) + 1;
                    if (lambs_danger_sisAtisN <= 60) then {
                        diag_log format ["[SIS-ATIS] %1 | %2 | izinli sis atildi (butce kaydi var) | toplam izinli %3", groupId (group _unit), name _unit, lambs_danger_sisAtisN];
                    };
                } else {
                    deleteVehicle _proj;
                    _unit addMagazine _mag;
                    lambs_danger_sisEngelN = (missionNamespace getVariable ["lambs_danger_sisEngelN", 0]) + 1;
                    if (lambs_danger_sisEngelN <= 40) then {
                        diag_log format ["[SIS-ENGEL] %1 | %2 | MOTOR sisi iptal (sis butcesi kaydi / izni yok) | beh %3 | baski %4 | toplam engel %5", groupId (group _unit), name _unit, behaviour _unit, (getSuppression _unit) toFixed 2, lambs_danger_sisEngelN];
                    };
                };
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
            // v8.251: roketin yolu bir dusman ARACA dogru gidiyorsa arac AT ates drili (duman + yer degistirme + yakin piyade korumasi)
            if (!isNull _proj) then { [_unit, _proj] call (missionNamespace getVariable ["lambs_danger_fnc_atAtisIzle", {0}]); };
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

// 1b3) v8.251 ARAC ATISI: AT sinifi mermi (fuze / roket ya da hit >= 150 tank topu) atan kara araci icin de ayni yol testi (hedef arac AT ates drili); mermi sinifi onbellekli
[
    "LandVehicle",
    "Fired",
    {
        params ["_veh", "_weapon", "_muzzle", "_mode", "_ammo", "_mag", "_proj"];
        if (isNull _proj) exitWith {};
        if (isNil "lambs_danger_atMermiCache") then { lambs_danger_atMermiCache = createHashMap; };
        private _at = lambs_danger_atMermiCache getOrDefault [_ammo, -1];
        if (_at isEqualTo -1) then {
            private _sim = toLower (getText (configFile >> "CfgAmmo" >> _ammo >> "simulation"));
            private _hit = getNumber (configFile >> "CfgAmmo" >> _ammo >> "hit");
            _at = [0, 1] select ((_sim in ["shotmissile", "shotrocket"]) || {_hit >= 150 && {_sim in ["shotbullet", "shotshell"]}});
            lambs_danger_atMermiCache set [_ammo, _at];
        };
        if (_at isEqualTo 1) then { [_veh, _proj] call (missionNamespace getVariable ["lambs_danger_fnc_atAtisIzle", {0}]); };
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
