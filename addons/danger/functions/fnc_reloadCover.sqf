#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * SARJOR DEGISTIRME KORUMASI — acikta reload yok; buddy korur; PEEK-RELOAD-PEEK.
 *
 * Sorun: AI sarjor bitince oldugu yerde (acikta, ayakta) reload ediyor; o 3-8 sn'de vurulabilir
 *        ve ates gucu dusuyor (MG'de belt ~8 sn).
 *
 * Bu watchdog (server / HC basina bir kez, 1 sn'de bir), CATISMA halindeki yerel botlarda:
 *
 *   TETIK    birincil silahta mermi <= max(3, sarjor kapasitesi x %15) VE yedek sarjor var
 *            (yani sarjor BITMEDEN / bittigi anda; AI sarjoru bitirince zaten reload eder)
 *   1) SIPER ILK: zaten sert siperdeyse (engel <= 3 m + hat kapali) / binadaysa -> orada kal, MIDDLE
 *                 degilse en yakin siperi bul (findCover DEFEND, 20 m) ve ona kos (en fazla 8 sn)
 *                 YAKINDA SIPER YOKSA -> oldugu yerde YAT (DOWN): acikta ayakta reload yok
 *   2) BUDDY KORUR: kalici esi (yoksa en yakin dost) ayni anda dusmana odak ates + alana baski verir
 *                   (3 sn'de bir tazelenir) — reload eden korunur, ates kesilmez
 *   3) PEEK: sarjor doldu -> kisaca (2 sn) ayaga kalk, nisan al, sonra stance serbest (peek-reload-peek)
 *
 *   KOSARKEN (hizli / forceMove / Retreat / Evade / Temas kes) DURMAZ: reload yolda yapilir (kosu bozulmaz).
 *   Yakin dovus (< 20 m): siper icin sirt cevirmez, yerinde comelerek reload.
 *   ATLANIR: Retreat / Evade / Temas kes gruplari (kosuyorlar), forceMove (baska taktigin kosucusu),
 *            oyuncu, arac, baski >= 0.85 (FSM zaten yere yatirir -> sadece yatar), 15 sn cooldown
 *
 * Arguments:
 * None
 *
 * Return Value:
 * Baslatildi mi <BOOL>
 *
 * Public: No
*/

if (!isNil "lambs_danger_reloadCoverStarted") exitWith {false};
lambs_danger_reloadCoverStarted = true;

diag_log "[RELOAD] sarjor korumasi (once siper / buddy korur / peek-reload-peek) watchdog baslatildi";

[] spawn {
    private _rolFn = missionNamespace getVariable ["lambs_danger_fnc_getUnitRole", {"RIFLE"}];
    private _supFn = missionNamespace getVariable ["lambs_main_fnc_doSuppress", {false}];

    // Sert siperde mi? (binada / 3 m icinde engel + dusmana hat kapali)
    private _siperdeFn = {
        params ["_u", "_e"];
        if ((insideBuilding _u) > 0.5) exitWith {true};
        private _engel = (nearestTerrainObjects [_u, ["TREE", "ROCK", "WALL", "BUILDING", "HIDE"], 3, false, true]) isNotEqualTo [];
        if (!_engel) exitWith {false};
        if (isNull _e) exitWith {true};
        lineIntersects [eyePos _u, eyePos _e, _u, _e]
    };

    // Buddy kor: odak ates + (hat kapaliysa) alana baski
    private _korurFn = {
        params ["_b", "_e"];
        if (isNull _e || {!alive _e}) exitWith {};
        _b doTarget _e;
        _b doFire _e;
        if (lineIntersects [eyePos _b, eyePos _e, _b, _e]) then {
            private _bp = getPosATL _e;
            _bp set [2, 0.5];
            [_b, AGLToASL _bp] call _supFn;
        };
    };

    while {true} do {
        sleep 1;

        {
            private _g = _x;
            if (isNull _g) then { continue };
            // Temas bitti: yarim kalan sarjor durumlarini temizle (forceMove / stance takili kalmasin), sonra atla
            if ((_g getVariable [QGVAR(contact), 0]) <= time) then {
                {
                    private _cu = _x;
                    if (local _cu && {((_cu getVariable [QGVAR(reloadState), []]) isNotEqualTo []) || {(_cu getVariable [QGVAR(reloadPeekEnd), 0]) > 0}}) then {
                        private _cs = _cu getVariable [QGVAR(reloadState), []];
                        if (_cs isNotEqualTo [] && {(_cs param [9, false])}) then { _cu setVariable [QGVAR(forceMove), nil]; };
                        _cu setVariable [QGVAR(reloadState), []];
                        _cu setVariable [QGVAR(reloadPeekEnd), 0];
                        _cu setUnitPosWeak "AUTO";
                    };
                } forEach (units _g);
                continue
            };
            if (
                (_g getVariable [QGVAR(isRetreating), false])
                || {_g getVariable [QGVAR(isEvading), false]}
                || {_g getVariable [QGVAR(isBreakingContact), false]}
            ) then { continue };

            private _leader = leader _g;
            if (isNull _leader || {((units _g) findIf {isPlayer _x}) > -1}) then { continue };

            private _tum = (units _g) select {
                alive _x && {local _x} && {isNull objectParent _x}
                && {(lifeState _x) in ["HEALTHY", "INJURED"]}
            };
            if ((count _tum) < 1) then { continue };

            {
                private _u = _x;
                private _w = primaryWeapon _u;
                if (_w isEqualTo "" || {(currentWeapon _u) isNotEqualTo _w}) then {
                    // launcher / dürbün secildi: yarim kalan sarjor durumunu kapat
                    private _cs2 = _u getVariable [QGVAR(reloadState), []];
                    if (_cs2 isNotEqualTo []) then {
                        if (_cs2 param [9, false]) then { _u setVariable [QGVAR(forceMove), nil]; };
                        _u setVariable [QGVAR(reloadState), []];
                        _u setUnitPosWeak "AUTO";
                    };
                    continue
                };
                // el bombasi kacisi sirasinda sarjor korumasi karismaz
                if ((_u getVariable [QGVAR(grState), []]) isNotEqualTo []) then { continue };

                private _durum = _u getVariable [QGVAR(reloadState), []];
                private _mermi = _u ammo _w;

                // ---------------------------------------------------------
                // DURUM VAR: ilerlet (GO -> HOLD -> PEEK)
                // ---------------------------------------------------------
                if (_durum isNotEqualTo []) then {
                    _durum params ["_faz", "_t0", "_bitis", "_stance", "_pos", "_tetikMermi", "_buddy", "_sonKoru", "_enemy", "_forceBy"];

                    // Buddy korumasini tazele (3 sn'de bir)
                    if (!isNull _buddy && {alive _buddy} && {(time - _sonKoru) > 3}) then {
                        [_buddy, _enemy] call _korurFn;
                        _durum set [7, time];
                    };

                    // GO: siperine vardi mi / zaman asimi / ezildi
                    if (_faz isEqualTo "GO") then {
                        private _vardi = (_u distance2D _pos) < 3;
                        private _ezildi = (getSuppression _u) >= 0.85;
                        if (_vardi || {_ezildi} || {time > (_t0 + 8)}) then {
                            _u setVariable [QGVAR(forceMove), nil];
                            _u setUnitPosWeak ([_stance, "DOWN"] select _ezildi);
                            _durum set [0, "HOLD"];
                            _durum set [9, false];
                        };
                    };

                    // BITTI: sarjor doldu (mermi arttı) ya da zaman asimi -> PEEK
                    if ((_mermi > (_tetikMermi + 2)) || {time > _bitis}) then {
                        if (_forceBy) then { _u setVariable [QGVAR(forceMove), nil]; };   // sadece bizim koydugumuz forceMove
                        _u setVariable [QGVAR(reloadState), []];
                        // sarjor DOLDUYSA 15 sn, dolmadan zaman asimiysa 30 sn cooldown (engine mermi bitince reload eder)
                        _u setVariable [QGVAR(reloadLast), [time + 15, time] select (_mermi > (_tetikMermi + 2))];
                        if (_mermi > 0 && {(getSuppression _u) < 0.5}) then {
                            _u setUnitPosWeak "UP";
                            _u setVariable [QGVAR(reloadPeekEnd), time + 2];
                        } else {
                            _u setUnitPosWeak "AUTO";
                        };
                    };
                } else {
                    // -----------------------------------------------------
                    // PEEK sonu
                    // -----------------------------------------------------
                    private _pe = _u getVariable [QGVAR(reloadPeekEnd), 0];
                    if (_pe > 0 && {time > _pe}) then {
                        _u setVariable [QGVAR(reloadPeekEnd), 0];
                        _u setUnitPosWeak "AUTO";
                    };

                    // -----------------------------------------------------
                    // TETIK
                    // -----------------------------------------------------
                    if (
                        (time - (_u getVariable [QGVAR(reloadLast), -999])) > 15
                        && {!(_u getVariable [QGVAR(forceMove), false])}
                        && {(speed _u) < 2.5}
                    ) then {
                        private _mag = currentMagazine _u;
                        private _kap = missionNamespace getVariable ["lambs_rc_cap_" + _mag, -1];
                        if (_kap < 0) then {
                            _kap = getNumber (configFile >> "CfgMagazines" >> _mag >> "count");
                            missionNamespace setVariable ["lambs_rc_cap_" + _mag, _kap];
                        };
                        // AI sarjoru ancak BITINCE doldurur: tetik dusuk (%15, en az 3) -> siperde kalan mermiyi biter, orada doldurur
                        private _esik = (_kap * 0.15) max 3;
                        private _yedek = false;
                        if (_mermi <= _esik) then {
                            private _uyumlu = compatibleMagazines _w;
                            _yedek = ((magazinesAmmo _u) findIf {(_x select 1) > 0 && {(_x select 0) in _uyumlu}}) > -1;
                        };

                        if (_mermi <= _esik && {_yedek}) then {
                            private _rol = [_u] call _rolFn;
                            private _sure = [12, 16] select (_rol isEqualTo "MG");

                            private _e = _u findNearestEnemy _u;
                            if (isNull _e) then { _e = _leader findNearestEnemy _leader; };

                            // ---- 1) SIPER ILK ----
                            private _faz = "HOLD";
                            private _stance = "MIDDLE";
                            private _hedef = getPosATL _u;
                            private _not = "zaten siperde";
                            if (!([_u, _e] call _siperdeFn)) then {
                                // DURUMA GORE: dusman < 20 m (yakin dovus) -> siper icin sirt cevirme, yerinde reload;
                                // siper <= 4 m (birkac adim, acikta kosu yok) ve baski < 0.85 -> siper; aksi halde yerinde cok eger/yatarak reload (reload SONRASI kosu yok)
                                private _yakinDusman = !isNull _e && {(_u distance2D _e) < 20};
                                private _cv = if (isNull _e || {_yakinDusman}) then {[]} else {[_u, _e, 20, "ASCEND", 4, "DEFEND"] call EFUNC(main,findCover)};
                                if (
                                    _cv isNotEqualTo []
                                    && {(getSuppression _u) < 0.85}
                                    && {(_u distance2D ((_cv select 0) select 0)) <= 4}
                                ) then {
                                    _hedef = (_cv select 0) select 0;
                                    _stance = (_cv select 0) select 1;
                                    if ((_u distance2D _hedef) > 2) then {
                                        _faz = "GO";
                                        _not = format ["siper %1 m", round (_u distance2D _hedef)];
                                        _u setVariable [QGVAR(forceMove), true];
                                        _u setUnitPosWeak "UP";
                                        _u doMove _hedef;
                                        _u forceSpeed -1;
                                    } else {
                                        _not = "siper yanimda";
                                    };
                                } else {
                                    // Siper yok / uzak: acikta AYAKTA reload yok -> yat; yakin dovusta yerinde comelerek
                                    _stance = ["DOWN", "MIDDLE"] select _yakinDusman;
                                    _not = ["siper uzak -> yerinde yatarak", "dusman yakin -> yerinde comelerek"] select _yakinDusman;
                                };
                            };
                            if (_faz isEqualTo "HOLD") then { _u setUnitPosWeak _stance; };

                            // ---- 2) BUDDY KORUR ----
                            private _b = _u getVariable [QGVAR(buddy), objNull];
                            private _bGecerli = {
                                params ["_c"];
                                !isNull _c && {alive _c} && {_c isNotEqualTo _u} && {local _c} && {!isPlayer _c}
                                && {(_c distance2D _u) < 40}
                                && {(_c getVariable [QGVAR(reloadState), []]) isEqualTo []}
                                && {(_c ammo (primaryWeapon _c)) > 0}
                                && {(getSuppression _c) < 0.85}
                            };
                            if !([_b] call _bGecerli) then {
                                _b = objNull;
                                private _enYakin = 41;
                                {
                                    if ([_x] call _bGecerli) then {
                                        private _d = _u distance2D _x;
                                        if (_d < _enYakin) then { _enYakin = _d; _b = _x; };
                                    };
                                } forEach _tum;
                            };
                            if (!isNull _b) then {
                                [_b, _e] call _korurFn;
                                _b setVariable [QGVAR(stationLast), time];   // bond / dagilma / rol istasyonu rahat birakir
                            };

                            _u setVariable [QGVAR(stationLast), time];
                            _u setVariable [QGVAR(reloadState), [_faz, time, time + _sure, _stance, _hedef, _mermi, _b, time, _e, _faz isEqualTo "GO"]];

                            // Log (global 3 sn'de bir; catismada dalga dalga yazmasin)
                            if ((time - (missionNamespace getVariable ["lambs_danger_reloadLogT", -999])) > 3) then {
                                missionNamespace setVariable ["lambs_danger_reloadLogT", time];
                                diag_log format [
                                    "[RELOAD] %1 | %2 (%3) | mermi %4/%5 -> %6 | koruyan: %7",
                                    groupId _g, name _u, _rol, _mermi, _kap, _not,
                                    if (isNull _b) then {"yok"} else {name _b}
                                ];
                            };
                        };
                    };
                };
            } forEach _tum;
        } forEach allGroups;
    };
};

true
