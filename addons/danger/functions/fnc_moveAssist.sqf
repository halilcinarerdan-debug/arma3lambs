#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * HAREKET YARDIMCISI — yerel AI piyadeler icin (0.3 sn'de bir, tek watchdog):
 *
 *   1) SAGA / SOLA DONUS HIZI +%20 (lambs_danger_turnCoef = 1.2): sadece DONUS animasyonu ("turn")
 *      oynarken animasyon hizi 1.2, digerlerinde 1.0 (yurume / kosu hizi degismez -> duvara gomulme azalir).
 *      Geri cekilme / zirhtan kacista yurume 1.15 (o taktikler kendisi koyar), donus yine 1.2.
 *   2) DUVAR KORUMASI: iki tick arasinda bir askerin yolu bina / duvar / cit geometrisini kesiyorsa
 *      (duvardan gecme) onceki konuma geri alinir; o asker 3 sn boyunca animasyon 1.0 ile yurur.
 *      Tirmanma / atlama / merdiven animasyonlari muaf; 3 ust uste duzeltmeden sonra 6 sn vazgecer
 *      (sonsuz salinim yok).
 *   3) SIKISMA (ONUNU BLOKLAMA): hareket emri olan asker yerinde (hiz < 1 km/s) ve onunde 1.8 m icinde
 *      bir dost varsa, kendi emri bitmeden SAGA / SOLA 3.5 m adim atar (engelsiz, bos, su olmayan yan),
 *      2.2 sn sonra eski hedefine doner. Geride olan (hedefe daha uzak) yol verir; duran dosta karsi yuruyen yol verir.
 *
 * Arguments:
 * None
 *
 * Return Value:
 * Baslatildi mi <BOOL>
 *
 * Public: No
*/

if (!isNil "lambs_danger_moveAssistStarted") exitWith {false};
lambs_danger_moveAssistStarted = true;
if (isNil "lambs_danger_turnCoef") then { lambs_danger_turnCoef = 1.2; };
lambs_danger_mvLogN = 0;

diag_log "[HAREKET] hareket yardimcisi baslatildi (donus hizi x1.2 + duvar korumasi + sikisma adimi)";

[] spawn {
    private _birakAnim = ["aovr", "ladder", "climb", "vault", "ainv", "adth", "acts", "apanp", "amov_pro", "abdl"];

    private _tick = 0;
    while {true} do {
        sleep 0.15;
        _tick = _tick + 1;
        private _agir = (_tick % 2) isEqualTo 0;   // duvar korumasi / sikisma: 0.3 sn'de bir

        private _birimler = allUnits select {
            local _x && {alive _x} && {!isPlayer _x} && {isNull objectParent _x}
            && {(lifeState _x) in ["HEALTHY", "INJURED"]}
        };

        {
            private _u = _x;
            private _now = getPosASL _u;

            // ---------------------------------------------------------
            // 1) DONUS HIZI (+%20 sadece donus animasyonunda)
            // ---------------------------------------------------------
            private _donuyor = ((toLower (animationState _u)) find "turn") >= 0;
            private _g = group _u;
            private _tabanAnim = if ((_g getVariable [QGVAR(isRetreating), false]) || {_g getVariable [QGVAR(isEvading), false]}) then {1.15} else {1.0};
            private _istenen = if (_donuyor) then {missionNamespace getVariable ["lambs_danger_turnCoef", 1.2]} else {_tabanAnim};
            // SENKRON: retreat / evade / baska kod setAnimSpeedCoef'i dogrudan yazinca onbellek bayat kaliyor, donus hizi bir daha
            // uygulanmiyordu. Artik deger degisince VEYA en geç 1.5 sn'de bir yeniden uygulanir; remoteExec ile TUM makinelerde
            // (setAnimSpeedCoef etkisi yerel: oyuncu istemcisi bot animasyonunu hizlanmis gormezdi).
            if (
                ((_u getVariable [QGVAR(mvAnim), -1]) isNotEqualTo _istenen)
                || {time > (_u getVariable [QGVAR(mvAnimT), 0])}
            ) then {
                _u setVariable [QGVAR(mvAnim), _istenen];
                _u setVariable [QGVAR(mvAnimT), time + 1.5];
                // YEREL dogrudan uygula (remoteExec CfgRemoteExec ile engellenmis olabilir; v7.22'de sadece remoteExec vardi -> donus hizi hic uygulanmamis olabilir),
                // sonra diger makinelere (oyuncu istemcisi) gonder
                _u setAnimSpeedCoef _istenen;
                if (isMultiplayer) then { [_u, _istenen] remoteExecCall ["setAnimSpeedCoef", -clientOwner]; };
            };

            if (_agir) then {
            // ---------------------------------------------------------
            // 2) DUVAR KORUMASI
            // ---------------------------------------------------------
            private _prev = _u getVariable [QGVAR(mvPos), []];
            _u setVariable [QGVAR(mvPos), _now];
            if (_prev isNotEqualTo [] && {time > (_u getVariable [QGVAR(mvGrace), 0])}) then {
                private _mv = _prev distance _now;
                if (_mv > 0.35 && {_mv < 5}) then {
                    private _an = toLower (animationState _u);
                    private _muaf = (_birakAnim findIf {(_an find _x) >= 0}) > -1;
                    if (!_muaf) then {
                        private _hit = lineIntersectsSurfaces [
                            _prev vectorAdd [0, 0, 1.1], _now vectorAdd [0, 0, 1.1],
                            _u, objNull, true, 1, "GEOM", "NONE"
                        ];
                        if (_hit isNotEqualTo []) then {
                            private _o = (_hit select 0) select 2;
                            if (!isNull _o && {!(_o isKindOf "AllVehicles")} && {!(_o isKindOf "Man")}) then {
                                _u setPosASL _prev;
                                _u setVariable [QGVAR(mvSlowUntil), time + 3];
                                private _n = (_u getVariable [QGVAR(mvFix), 0]) + 1;
                                if ((time - (_u getVariable [QGVAR(mvFixT), -99])) > 2) then { _n = 1; };
                                _u setVariable [QGVAR(mvFix), _n];
                                _u setVariable [QGVAR(mvFixT), time];
                                if (_n >= 3) then { _u setVariable [QGVAR(mvGrace), time + 15];   // 3 duzeltmeden sonra 15 sn dokunma: bina kapisi / sorunlu navmesh'te asker surekli geri alinip takiliyordu (RPT: retreat lideri bina yaninda 40 sn kipirdamadi) _u setVariable [QGVAR(mvFix), 0]; };
                                if (lambs_danger_mvLogN < 25) then {
                                    lambs_danger_mvLogN = lambs_danger_mvLogN + 1;
                                    diag_log format ["[DUVAR-KORUMA] %1 | %2 | %3 icinden gecmeye calisti -> geri alindi (%4)", groupId (group _u), name _u, typeOf _o, round (_mv * 100) / 100];
                                };
                            };
                        };
                    };
                };
            };

            // ---------------------------------------------------------
            // 3) SIKISMA — onundeki dosta takilma: saga / sola adim
            // ---------------------------------------------------------
            private _sideUntil = _u getVariable [QGVAR(sideUntil), 0];
            if (_sideUntil > 0) then {
                if (time > _sideUntil) then {
                    _u setVariable [QGVAR(sideUntil), 0];
                    private _sd = _u getVariable [QGVAR(sideDest), []];
                    if (_sd isNotEqualTo [] && {alive _u}) then {
                        if (_u isEqualTo (leader _u)) then { _u doMove _sd; } else { _u doMove _sd; };
                    };
                };
            } else {
                // TEMAS / TAKTIK / KOMUTAN: sikisma adimi SADECE sakin intikalde (temasta siperde bekleyen cift, bound bekleyen, komutan "dur-kalk" yapmasin)
if (
    (speed _u) < 1 && {(stance _u) in ["STAND", "CROUCH"]} && {time > (_u getVariable [QGVAR(sideLast), 0])}
    && {_u isNotEqualTo (leader _u)}
    && {((_g getVariable [QGVAR(contact), 0]) < time)}
    && {!(_g getVariable [QGVAR(isBounding), false])} && {!(_g getVariable [QGVAR(isExecutingTactic), false])}
    && {!(_g getVariable [QGVAR(isRetreating), false])} && {!(_g getVariable [QGVAR(isBreakingContact), false])}
    && {isNil {_u getVariable QGVAR(forceMove)}}
) then {
                    private _ed = expectedDestination _u;
                    private _d = _ed select 0;
                    private _mode = toLower (_ed select 1);
                    if (
                        _d isNotEqualTo [0, 0, 0] && {(_u distance2D _d) > 4}
                        && {!(_mode in ["donotplan", "do not plan"])}
                        && {(_u getVariable [QGVAR(grState), []]) isEqualTo []}
                    ) then {
                        private _t0 = _u getVariable [QGVAR(blkT), 0];
                        if (_t0 isEqualTo 0) then {
                            _u setVariable [QGVAR(blkT), time];
                        } else {
                            if ((time - _t0) > 1.6) then {
                                _u setVariable [QGVAR(blkT), 0];
                                private _bdir = _u getDir _d;
                                private _blk = (_u nearEntities ["CAManBase", 1.8]) select {
                                    !(_x isEqualTo _u) && {alive _x} && {isNull objectParent _x}
                                    && {((side group _u) getFriend (side group _x)) >= 0.6}
                                    && {(abs ((((_u getDir _x) - _bdir) + 540) mod 360 - 180)) < 70}
                                    && {((speed _x) < 1) || {(_u distance2D _d) > (_x distance2D _d)}}
                                };
                                if (_blk isNotEqualTo []) then {
                                    private _b = _blk select 0;
                                    private _yonler = selectRandom [[90, -90], [-90, 90]];
                                    private _secildi = [];
                                    {
                                        private _c = _u getPos [3.5, _bdir + _x];
                                        if (
                                            !surfaceIsWater _c
                                            && {((_c nearEntities ["CAManBase", 1.3]) select {!(_x isEqualTo _u)}) isEqualTo []}
                                            && {!(lineIntersects [_now vectorAdd [0, 0, 0.9], AGLToASL (_c vectorAdd [0, 0, 0.9]), _u, _b])}
                                            && {(nearestTerrainObjects [_c, ["TREE", "WALL", "FENCE", "BUILDING", "HOUSE", "ROCK"], 0.9, false, true]) isEqualTo []}
                                        ) exitWith { _secildi = _c; };
                                    } forEach _yonler;
                                    if (_secildi isNotEqualTo []) then {
                                        _u setVariable [QGVAR(sideDest), _d];
                                        _u setVariable [QGVAR(sideUntil), time + 2.2];
                                        _u setVariable [QGVAR(sideLast), time + 25];
                                        _u doMove _secildi;
                                        if (lambs_danger_mvLogN < 25) then {
                                            lambs_danger_mvLogN = lambs_danger_mvLogN + 1;
                                            diag_log format ["[SIKISMA] %1 | %2 | %3 onunde -> yana adim", groupId (group _u), name _u, name _b];
                                        };
                                    };
                                };
                            };
                        };
                    } else {
                        _u setVariable [QGVAR(blkT), 0];
                    };
                } else {
                    _u setVariable [QGVAR(blkT), 0];
                };
            };
            };   // _agir
        } forEach _birimler;
    };
};

true
