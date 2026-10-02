#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * YAKIN MESAFE REFLEKSI + SIPER DISIPLINI — hile yok: sadece BILDIKLERI (knowsAbout) dusmana tepki.
 *
 *  A) CQB (bilinen dusman <= 28 m):
 *     - hemen dusmana doner / hedef alir / ates eder (doWatch + doTarget + doFire), 4 sn'de bir tazelenir
 *     - roketatar elindeyse (ve hedef zirh degilse) tufege gecer
 *     - ayaktaysa ve dusman <= 15 m: diz cokup nisan (daha stabil, daha az gorunur)
 *     - CQB KALIBRASYONU: yakin mesafede nisan hizi / dogrulugu "egitimli asker" tabanina cekilir
 *       (aimingSpeed >= 0.65, aimingAccuracy >= 0.55; asla dusurulmez); temas bitince 8 sn sonra ESKI degerler
 *  B) SIPER DISIPLINI (bilinen dusman <= 220 m, baski >= 0.35, ayakta, acikta, 25 sn'de bir):
 *     - 12 m icinde siper varsa oraya gider (findCover DEFEND), yoksa YATAR (acikta ayakta ezilmez)
 *
 *  ATLANIR: oyuncu, arac, forceMove'lu / reload / el bombasi / rol istasyonu, geri cekilme / temas kes / evade,
 *           keskin nisanci takimi.
 *
 * Arguments:
 * None
 *
 * Return Value:
 * Baslatildi mi <BOOL>
 *
 * Public: No
*/

if (!isNil "lambs_danger_cqbReflexStarted") exitWith {false};
lambs_danger_cqbReflexStarted = true;

diag_log "[CQB] yakin mesafe refleksi + siper disiplini watchdog baslatildi";

[] spawn {
    private _rolFn = missionNamespace getVariable ["lambs_danger_fnc_getUnitRole", {"RIFLE"}];

    while {true} do {
        sleep 0.7;
        private _butce = 4;   // tikte en fazla bu kadar findCover

        {
            private _g = _x;
            if (isNull _g || {!local _g}) then { continue };
            if ((_g getVariable [QGVAR(contact), 0]) < (time - 30)) then { continue };
            if (_g getVariable [QGVAR(sniperTeam), false]) then { continue };
            if (
                (_g getVariable [QGVAR(isRetreating), false])
                || {_g getVariable [QGVAR(isBreakingContact), false]}
                || {_g getVariable [QGVAR(isEvading), false]}
            ) then { continue };

            {
                private _u = _x;
                if (
                    alive _u && {local _u} && {!isPlayer _u} && {isNull objectParent _u}
                    && {(lifeState _u) in ["HEALTHY", "INJURED"]}
                    && {!(_u getVariable [QGVAR(forceMove), false])} && {(_u getVariable [QGVAR(taktikKilit), 0]) <= time}
                    && {(_u getVariable [QGVAR(reloadState), []]) isEqualTo []}
                    && {(_u getVariable [QGVAR(grState), []]) isEqualTo []}
                    && {(_u getVariable [QGVAR(stationPos), []]) isEqualTo []}
                ) then {
                    private _e = _u findNearestEnemy _u;
                    private _d = if (isNull _e || {!alive _e}) then {9999} else {_u distance2D _e};
                    private _bilgi = if (_d < 9999) then {_u knowsAbout _e} else {0};

                    // ---------------- A) CQB ----------------
                    if (_d <= 28 && {_bilgi >= 1.0}) then {
                        // kalibrasyon (orijinali sakla, yukseltilmis tabana cek)
                        if ((_u getVariable [QGVAR(cqbSkill), []]) isEqualTo []) then {
                            _u setVariable [QGVAR(cqbSkill), [_u skill "aimingSpeed", _u skill "aimingAccuracy"]];
                            _u setSkill ["aimingSpeed", ((_u skill "aimingSpeed") max 0.65)];
                            _u setSkill ["aimingAccuracy", ((_u skill "aimingAccuracy") max 0.55)];
                        };
                        _u setVariable [QGVAR(cqbSon), time];

                        if ((time - (_u getVariable [QGVAR(cqbLast), -999])) > 4) then {
                            _u setVariable [QGVAR(cqbLast), time];
                            _u setVariable [QGVAR(stationLast), time];

                            // roketatar -> tufek (zirh degilse)
                            if (
                                (secondaryWeapon _u) isNotEqualTo ""
                                && {(currentWeapon _u) isEqualTo (secondaryWeapon _u)}
                                && {_e isKindOf "CAManBase"}
                                && {(primaryWeapon _u) isNotEqualTo ""}
                            ) then {
                                _u selectWeapon (primaryWeapon _u);
                            };

                            _u doWatch _e;
                            _u doTarget _e;
                            _u doFire _e;

                            if (_d <= 15 && {(stance _u) isEqualTo "STAND"} && {(getSuppression _u) < 0.7}) then {
                                _u setUnitPosWeak "MIDDLE";
                            };

                            if ((time - (_u getVariable [QGVAR(cqbLog), -999])) > 30) then {
                                _u setVariable [QGVAR(cqbLog), time];
                                diag_log format ["[CQB] %1 | %2 | dusman %3 m bilgi:%4 | refleks (hedef al + ates)", groupId _g, name _u, round _d, _bilgi toFixed 2];
                            };
                        };
                    } else {
                        // CQB bitti: 8 sn sonra eski beceriler
                        private _sk = _u getVariable [QGVAR(cqbSkill), []];
                        if (_sk isNotEqualTo [] && {(time - (_u getVariable [QGVAR(cqbSon), 0])) > 8}) then {
                            _u setSkill ["aimingSpeed", _sk select 0];
                            _u setSkill ["aimingAccuracy", _sk select 1];
                            _u setVariable [QGVAR(cqbSkill), []];
                            _u doWatch objNull;
                        };

                        // ---------------- B) SIPER DISIPLINI ----------------
                        if (
                            _d <= 220 && {_bilgi >= 1.0}
                            && {(getSuppression _u) >= 0.35}
                            && {(stance _u) isEqualTo "STAND"}
                            && {(speed _u) < 2}
                            && {(insideBuilding _u) < 0.5}
                            && {(time - (_u getVariable [QGVAR(siperLast), -999])) > 25}
                            && {(nearestTerrainObjects [_u, ["TREE", "ROCK", "WALL", "BUILDING", "HIDE"], 2.5, false, true]) isEqualTo []}
                        ) then {
                            _u setVariable [QGVAR(siperLast), time];
                            _u setVariable [QGVAR(stationLast), time];
                            private _gitti = false;
                            if (_butce > 0) then {
                                _butce = _butce - 1;
                                private _c = [_u, _e, 12, "ASCEND", 1, "DEFEND"] call EFUNC(main,findCover);
                                if (_c isNotEqualTo []) then {
                                    private _cp = (_c select 0) select 0;
                                    if (!surfaceIsWater _cp) then {
                                        _u doMove _cp;
                                        _u setUnitPosWeak "MIDDLE";
                                        _gitti = true;
                                        diag_log format ["[CQB] %1 | %2 | baski %3, acikta: siper %4 m", groupId _g, name _u, (getSuppression _u) toFixed 2, round (_u distance2D _cp)];
                                    };
                                };
                            };
                            if (!_gitti) then {
                                _u setUnitPosWeak "DOWN";
                                diag_log format ["[CQB] %1 | %2 | baski %3, acikta, siper yok: yatti", groupId _g, name _u, (getSuppression _u) toFixed 2];
                            };
                        };
                    };
                };
            } forEach (units _g);
        } forEach allGroups;
    };
};

true
