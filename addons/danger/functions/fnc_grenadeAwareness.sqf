#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * EL BOMBASI FARKINDALIGI — once yere at, sonra catismayi birak ve patlama yaricapindan uzaklas.
 *
 * Sorun: AI ustune el bombasi gelince oldugu yerde ates etmeye / reload'a devam ediyor; tek bombaya
 *        grup birden yakalaniyor.
 *
 * Bu watchdog (server / HC basina bir kez, 0.5 sn'de bir), son 20 sn'de catismada olan gruplarin
 * YEREL botlarinda, 60 m icindeki ELDEN / UGL BOMBASI (GrenadeCore; duman / flare / aydinlatma / flas haric)
 * mermilerini izler. Tehlike yaricapi (CfgAmmo indirectHitRange x 2.2, 10..25 m) icindeki her asker:
 *
 *   1) DOWN     hemen yere atar (setUnitPos DOWN + "Down" aksiyonu); 0.6 sn (zaten yatiyorsa beklemeden kacis karari:
 *               YATARKEN DE KACAR)
 *   2) KACIS    bomba FITILLI ise (el bombasi: explosionTime / ad kalibindan ~4 sn) ve yeterli sure varsa
 *               (kalan > 1.8 sn + mesafe / 5.5), CATISMAYI BIRAKIP yaricapin DISINA (+2 m) kosar:
 *               bombadan uzaga, dusmandan uzaga ve bombayla arasinda engel olan yonu tercih eder.
 *               Kosarken forceMove + TARGET / AUTOTARGET / AUTOCOMBAT / COVER kapali (ates yok)
 *   3) YAT      kacacak sure / yer yoksa (veya vardiysa) yatar, patlamayi bekler
 *   4) HOLD     patlamadan 1.5 sn sonra serbest: AI geri acilir, stance AUTO, catismaya doner
 *
 *   Darbeli (UGL / fitilsiz) bomba: sadece yere atma (kacis icin sure yok).
 *   ATLANIR: oyuncu, arac, forceMove'lu askerler (baska taktigin koşucusu), binada (sadece yatar, kacmaz).
 *   12 sn mutlak guvenlik valfi. Her tepkide stationLast isaretlenir (bond / dagilma / rol istasyonu 20-25 sn
 *   rahat birakir).
 *
 * Arguments:
 * None
 *
 * Return Value:
 * Baslatildi mi <BOOL>
 *
 * Public: No
*/

if (!isNil "lambs_danger_grenadeAwareStarted") exitWith {false};
lambs_danger_grenadeAwareStarted = true;

diag_log "[EL-BOMBASI] el bombasi farkindaligi (yere at -> yaricaptan uzaklas) watchdog baslatildi";

[] spawn {
    private _aktif = [];

    // Mermi config: [gecerli, tehlikeYaricap, fitil(0 = darbeli)] — sinif basina onbellek
    private _cfgFn = {
        params ["_ammo"];
        private _key = "lambs_danger_grCfg_" + _ammo;
        private _c = missionNamespace getVariable [_key, []];
        if (_c isEqualTo []) then {
            private _cfg = configFile >> "CfgAmmo" >> _ammo;
            private _ad = toLower _ammo;
            private _isik = (["smoke", "flare", "illum", "chem", "signal", "f_40mm", "stun", "flash"] findIf {(_ad find _x) >= 0}) > -1;
            private _guc = getNumber (_cfg >> "indirectHit");
            private _menzil = getNumber (_cfg >> "indirectHitRange");
            if (_menzil <= 0) then { _menzil = 6; };
            private _yaricap = ((_menzil * 2.2) max 10) min 25;

            private _fitil = getNumber (_cfg >> "explosionTime");
            if (_fitil <= 0) then { _fitil = getNumber (_cfg >> "timeToLive"); };
            private _elBombasi = (
                ((_ad find "grenadehand") isEqualTo 0)
                || {(_ad find "handgrenade") >= 0}
                || {(_ad find "mini_grenade") >= 0}
                || {(_ad find "m67") >= 0}
                || {(_ad find "rgo") >= 0}
                || {(_ad find "rgd") >= 0}
                || {(_ad find "rgn") >= 0}
            );
            if (_fitil < 1.5 || {_fitil > 8}) then {
                _fitil = [0, 4.2] select _elBombasi;
            };

            _c = [!_isik && {_guc > 0}, _yaricap, _fitil];
            missionNamespace setVariable [_key, _c];
        };
        _c
    };

    // Serbest birak: AI kilitleri, forceMove, stance
    private _birakFn = {
        params ["_u"];
        _u setVariable [QGVAR(grState), []];
        if (alive _u) then {
            _u setVariable [QGVAR(forceMove), nil];
            _u enableAI "TARGET";
            _u enableAI "AUTOTARGET";
            _u enableAI "AUTOCOMBAT";
            _u enableAI "COVER";
            _u setUnitPos "AUTO";
            _u setVariable [QGVAR(stationLast), time];
        };
    };

    while {true} do {
        sleep 0.5;

        // =================================================================
        // 1) MEVCUT TEPKILERI ILERLET
        // =================================================================
        _aktif = _aktif select {alive _x && {(_x getVariable [QGVAR(grState), []]) isNotEqualTo []}};
        {
            private _u = _x;
            private _st = _u getVariable [QGVAR(grState), []];
            _st params ["_p", "_t0", "_faz", "_esc", "_gPos", "_son", "_rad"];

            if (!isNull _p) then {
                _gPos = getPosATL _p;
                _st set [4, _gPos];
            };
            private _gecen = time - _t0;

            // Mutlak guvenlik valfi
            if ((time - (_u getVariable [QGVAR(grBasla), time])) > 12) then {
                [_u] call _birakFn;
            } else {
                // DOWN: 0.6 sn sonra kacis karari
                if (_faz isEqualTo "DOWN") then {
                    if (isNull _p) then {
                        _st set [2, "HOLD"];
                        _st set [1, time];
                    } else {
                        if (_gecen > 0.6) then {
                            private _d = _u distance2D _gPos;
                            private _kalan = _son - time;
                            private _mes = (((_rad + 2) - _d) max 6) min 20;

                            if (
                                _son > 0 && {_d < _rad} && {_kalan > (1.8 + (_mes / 5.5))}
                                && {(insideBuilding _u) < 0.5}
                            ) then {
                                // Kacis yonu: bombadan uzaga; dusmandan uzak + bombayla arada engel olan yon tercih
                                private _uPos = getPosATL _u;
                                private _bear = _gPos getDir _uPos;
                                private _en = _u findNearestEnemy _u;
                                private _enPos = if (isNull _en) then {[]} else {getPosATL _en};
                                private _hedef = [];
                                private _enS = -999999;
                                {
                                    private _c = _uPos getPos [_mes, _bear + _x];
                                    if (!surfaceIsWater _c) then {
                                        private _s = -((abs _x) * 0.1);
                                        if (_enPos isNotEqualTo []) then { _s = _s + (0.2 * (_c distance2D _enPos)); };
                                        if (lineIntersects [AGLToASL (_gPos vectorAdd [0, 0, 0.3]), AGLToASL (_c vectorAdd [0, 0, 0.5]), _p, _u]) then { _s = _s + 30; };
                                        if (_s > _enS) then { _enS = _s; _hedef = _c; };
                                    };
                                } forEach [0, 40, -40];

                                if (_hedef isNotEqualTo []) then {
                                    _u setVariable [QGVAR(forceMove), true];
                                    _u disableAI "TARGET";
                                    _u disableAI "AUTOTARGET";
                                    _u disableAI "AUTOCOMBAT";
                                    _u disableAI "COVER";
                                    _u allowFleeing 0;
                                    _u setUnitPos "UP";
                                    _u forceSpeed -1;
                                    _u moveTo _hedef;
                                    _st set [2, "ESCAPE"];
                                    _st set [3, _hedef];
                                    _st set [1, time];
                                    diag_log format [
                                        "[EL-BOMBASI] %1 | %2 | bomba %3 m (tehlike %4 m, fitil kalan %5 sn) -> yere atti, KACIYOR %6 m",
                                        groupId (group _u), name _u, round _d, round _rad, _kalan toFixed 1, round _mes
                                    ];
                                } else {
                                    _st set [2, "WAIT"];
                                };
                            } else {
                                // Kosacak sure yok: bombaya cok yakin (< 6 m) ve >1 sn varsa YATARAK surun (ayaga kalkma)
                                if (_son > 0 && {_d < 6} && {_kalan > 1} && {(insideBuilding _u) < 0.5}) then {
                                    private _sc = (getPosATL _u) getPos [5, _gPos getDir (getPosATL _u)];
                                    if (!surfaceIsWater _sc) then {
                                        _u setVariable [QGVAR(forceMove), true];
                                        _u disableAI "TARGET";
                                        _u disableAI "AUTOTARGET";
                                        _u disableAI "AUTOCOMBAT";
                                        _u disableAI "COVER";
                                        _u setUnitPos "DOWN";
                                        _u moveTo _sc;
                                        _st set [2, "ESCAPE"];
                                        _st set [3, _sc];
                                        _st set [1, time];
                                        diag_log format [
                                            "[EL-BOMBASI] %1 | %2 | bomba %3 m, fitil kalan %4 sn -> yatarak SURUNUYOR",
                                            groupId (group _u), name _u, round _d, _kalan toFixed 1
                                        ];
                                    } else {
                                        _st set [2, "WAIT"];
                                    };
                                } else {
                                    _st set [2, "WAIT"];
                                };
                            };
                        };
                    };
                };

                // ESCAPE: yaricap disina kosar; vardi / patladi / zaman asimi -> yat
                if (_faz isEqualTo "ESCAPE") then {
                    if (isNull _p) then {
                        _u setVariable [QGVAR(forceMove), nil];
                        _u setUnitPos "DOWN";
                        _st set [2, "HOLD"];
                        _st set [1, time];
                    } else {
                        if ((_u distance2D _esc) < 2.5 || {_gecen > 6}) then {
                            _u setVariable [QGVAR(forceMove), nil];
                            _u setUnitPos "DOWN";
                            _st set [2, "WAIT"];
                        } else {
                            _u moveTo _esc;
                        };
                    };
                };

                // WAIT: yatarak patlamayi bekle
                if (_faz isEqualTo "WAIT" && {isNull _p}) then {
                    _st set [2, "HOLD"];
                    _st set [1, time];
                };

                // HOLD: patlamadan 1.5 sn sonra serbest
                if (_faz isEqualTo "HOLD" && {_gecen > 1.5}) then {
                    [_u] call _birakFn;
                };
            };
        } forEach +_aktif;

        // =================================================================
        // 2) YENI TEHDIT TARAMASI (son 20 sn'de catisan gruplar)
        // =================================================================
        {
            private _g = _x;
            if (isNull _g) then { continue };
            if ((_g getVariable [QGVAR(contact), 0]) < (time - 20)) then { continue };

            private _leader = leader _g;
            if (isNull _leader) then { continue };

            private _birimler = (units _g) select {
                alive _x && {local _x} && {!isPlayer _x} && {isNull objectParent _x}
                && {(lifeState _x) in ["HEALTHY", "INJURED"]}
                && {(_x getVariable [QGVAR(grState), []]) isEqualTo []}
                && {!(_x getVariable [QGVAR(forceMove), false])}
            };
            if (_birimler isEqualTo []) then { continue };

            private _bombalar = (getPosATL _leader) nearObjects ["GrenadeCore", 60];
            {
                private _p = _x;
                private _cfg = [typeOf _p] call _cfgFn;
                if (_cfg select 0) then {
                    private _rad = _cfg select 1;
                    private _fitil = _cfg select 2;
                    private _gorulme = _p getVariable [QGVAR(grSeen), -1];
                    if (_gorulme < 0) then {
                        _gorulme = time;
                        _p setVariable [QGVAR(grSeen), time];
                    };
                    private _son = [0, _gorulme + _fitil] select (_fitil > 0);
                    private _gp = getPosATL _p;

                    {
                        private _u = _x;
                        if ((_u getVariable [QGVAR(grState), []]) isEqualTo [] && {(_u distance2D _gp) < _rad}) then {
                            // Zaten yatiyorsa dusme beklemesi yok: hemen kacis karari (yatarken de kacar)
                            private _yatiyor = (stance _u) isEqualTo "PRONE";
                            _u setUnitPos "DOWN";
                            if (!_yatiyor) then { _u playActionNow "Down"; };
                            _u setVariable [QGVAR(grState), [_p, [time, time - 0.7] select _yatiyor, "DOWN", [], _gp, _son, _rad]];
                            _u setVariable [QGVAR(grBasla), time];
                            _u setVariable [QGVAR(stationLast), time];
                            _aktif pushBackUnique _u;
                        };
                    } forEach _birimler;
                };
            } forEach _bombalar;
        } forEach allGroups;
    };
};

true
