#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * AT ROKET PASLAMA (v8.242) — kullanici: "AT asistan RPG saglasin AT askerine". cephanePaylas yalniz tufek / MG sarjoru ve el bombasi paslar; roketatar fuzeleri paslanmiyordu.
 * 6 sn'de bir, YEREL AI gruplarinda: rokatatari olan (secondaryWeapon) ve YEDEK fuzesi < 1 olan AT askeri, gruptaki bir vericiden fuze alir:
 *   - verici onceligi: AT ASISTANI (fnc_asistanTur "AT_ASIST" / "ASIST") > baska piyade (en cok yedek fuze); verici kendi roketatari varsa EN AZ 1 yedek tutar (asistanda bu sinir yok),
 *   - mesafe: sakinken <= 25 m, temas / baski altinda <= 12 m; aktarim aninda (animasyon yok, cephanePaylas varsayilaniyla ayni), alici 'canAdd' degilse atlanir,
 *   - bir seferde en cok 2 fuze; ayni AT icin 20 sn bekleme. Tek kullanimlik roketatarlar (RPG-26 vb.: uyumlu sarjor yok) atlanir. Ayrintili zaman cizgisi icin [AT-PASLA].
 * Uyumlu fuzeler: CBA_fnc_compatibleMagazines (magazineWell dahil); yoksa CfgWeapons magazines.
 * Kapatma: lambs_danger_atPaylasOff = true.  Log: [AT-PASLA] (aktarim + her 90 sn'de 'verici yok' ozeti).
 *
 * Arguments: None
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isNil "lambs_danger_atPaylasStarted") exitWith {false};
lambs_danger_atPaylasStarted = true;

diag_log "[AT-PASLA] AT roket paslama watchdog'u baslatildi (v8.242): AT asistani / gruptaki verici -> yedek fuzesi biten AT askerine";

private _calis = {
    private _uyum = createHashMap;
    private _asistFn = missionNamespace getVariable ["lambs_danger_fnc_asistanTur", {""}];
    private _yokT = time;
    private _yokSay = createHashMap;
    private _uyumMag = {
        params ["_w"];
        if (_w in _uyum) exitWith { _uyum get _w };
        private _m = if (isNil "CBA_fnc_compatibleMagazines") then { (getArray (configFile >> "CfgWeapons" >> _w >> "magazines")) apply {toLower _x} } else { ([_w] call CBA_fnc_compatibleMagazines) apply {toLower _x} };
        _uyum set [_w, _m];
        _m
    };
    while {true} do {
        sleep 6;
        if (missionNamespace getVariable ["lambs_danger_atPaylasOff", false]) then { continue };
        {
            private _g = _x;
            private _l = leader _g;
            if (isNull _l || {!local _g} || {isPlayer _l} || {!alive _l}) then { continue };
            private _us = (units _g) select { alive _x && {isNull objectParent _x} && {!isPlayer _x} && {(lifeState _x) in ["HEALTHY", "INJURED"]} && {!(_x getVariable ["ACE_isUnconscious", false])} };
            if ((count _us) < 2) then { continue };
            private _temas = (_g getVariable ["lambs_danger_contact", -999]) > time;
            private _menzil = [25, 12] select _temas;
            {
                private _a = _x;
                private _w = secondaryWeapon _a;
                if (_w isEqualTo "") then { continue };
                if ((time - (_a getVariable [QGVAR(atPaslaT), -999])) < 20) then { continue };
                private _uyumL = [_w] call _uyumMag;
                if (_uyumL isEqualTo []) then { continue };   // tek kullanimlik
                // YEDEK = namluda/roketatarda YUKLU olmayan uyumlu fuzeler (magazinesAmmoFull: [sinif, mermi, yuklu mu, tip, konum])
                private _yedek = { ((toLower (_x select 0)) in _uyumL) && {!(_x select 2)} } count (magazinesAmmoFull _a);
                if (_yedek >= 1) then { continue };
                // verici adaylari
                private _aday = [];
                {
                    private _v = _x;
                    if (_v isEqualTo _a || {(_v distance2D _a) > _menzil}) then { continue };
                    private _vm = ((magazinesAmmoFull _v) select { ((toLower (_x select 0)) in _uyumL) && {!(_x select 2)} }) apply { _x select 0 };
                    if (_vm isEqualTo []) then { continue };
                    private _asist = ([_v] call _asistFn) in ["AT_ASIST", "ASIST"];
                    private _tut = if (_asist || {(secondaryWeapon _v) isEqualTo ""}) then {0} else {1};
                    private _verilebilir = (count _vm) - _tut;
                    if (_verilebilir >= 1) then { _aday pushBack [[0, 1] select _asist, _verilebilir, _v, _vm select 0]; };
                } forEach _us;
                if (_aday isEqualTo []) then {
                    _yokSay set [groupId _g, (_yokSay getOrDefault [groupId _g, 0]) + 1];
                    continue
                };
                // asistan once, sonra en cok verilebilir
                _aday = [_aday, [], { -(_x select 0) * 100 - (_x select 1) }, "ASCEND"] call BIS_fnc_sortBy;
                (_aday select 0) params ["_oncelik", "_vb", "_v", "_sinif"];
                private _n = (_vb min 2);
                private _verilen = 0;
                for "_i" from 1 to _n do {
                    if (_a canAdd _sinif) then {
                        _v removeMagazineGlobal _sinif;
                        _a addMagazineGlobal _sinif;
                        _verilen = _verilen + 1;
                    };
                };
                _a setVariable [QGVAR(atPaslaT), time];
                if (_verilen > 0) then {
                    diag_log format ["[AT-PASLA] %1 | %2 (%3) -> %4 | %5 x%6 | verici %7 | mesafe %8 m | alici yedek %9 -> %10 | %11",
                        groupId _g, name _v, ["verici", "AT ASISTANI"] select (_oncelik > 0), name _a, _sinif, _verilen, typeOf _v, round (_v distance2D _a), _yedek, { ((toLower (_x select 0)) in _uyumL) && {!(_x select 2)} } count (magazinesAmmoFull _a), ["sakin", "TEMAS"] select _temas];
                } else {
                    diag_log format ["[AT-PASLA] %1 | %2 -> %3 | %4 | IPTAL: alici envanteri dolu (canAdd false)", groupId _g, name _v, name _a, _sinif];
                };
            } forEach (_us select { (secondaryWeapon _x) isNotEqualTo "" });
        } forEach (allGroups select { local _x });
        if ((time - _yokT) > 90) then {
            _yokT = time;
            if (count _yokSay > 0) then { diag_log format ["[AT-PASLA] son 90 sn: yedek fuzesi biten ama VERICI YOK (grup: tur sayisi) %1", (keys _yokSay) apply { format ["%1:%2", _x, _yokSay get _x] }]; };
            _yokSay = createHashMap;
        };
    };
};

[_calis] spawn {
    params ["_fn"];
    while {true} do {
        private _h = [] spawn _fn;
        waitUntil { sleep 5; scriptDone _h };
        diag_log "[WATCHDOG-YENIDEN] atPaylas betigi sonlandi (hata?)";
        sleep 5;
    };
};

true
