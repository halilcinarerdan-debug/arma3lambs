#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * SAHA USTALIGI — yerel AI piyadeler icin tek watchdog (1 sn tik):
 *
 *  A) ONCE SIPERE, SONRA ATES: catismada acikta (dusmanin gozu govdeyi goruyor) olan asker 7 m (3-5 adim) icinde
 *     siper (duvar / kaya / agac / bina / cit) buluyorsa, ilk atesi ATMADAN once siperin dusmana gore arka yuzune gecer;
 *     varis + 2.5 sn (siperde yerlesme) boyunca TARGET / AUTOTARGET kapali, sonra ates serbest (coverHug siper yapismasini yapar).
 *     Zaman asimi 6 sn. Dusman < 15 m ise yapilmaz (yakin dovuste kosmak olum).
 *  B) YER DEGISTIRME (shoot and scoot): ayni yerden 12+ atis ve 6+ sn -> 6-9 m yana, siperli / gizli noktaya kayar. MG / nisanci / bina / tedavi muaf. 25 sn bekleme.
 *  C) 360 GUVENLIK: grup >= 3 kisi, lider duruyor (>= 8 sn), temas yok -> her asker farkli yone (80 m) bakar; hareket / temas olunca birakir.
 *  D) GECE: gece ise NVG'li AI NVG acar + IR lazer + tabanca/tufek feneri kapali; NVG'siz AI fener AUTO; gunduz NVG kapali.
 *
 * KAPATMA: lambs_danger_fieldCraftOff = true | RPT: [SAHA]
 *
 * Arguments:
 * None
 *
 * Return Value:
 * Baslatildi mi <BOOL>
 *
 * Public: No
*/

if (!isNil "lambs_danger_fieldCraftStarted") exitWith {false};
lambs_danger_fieldCraftStarted = true;
lambs_danger_fcLogN = 0;

diag_log "[SAHA] saha ustaligi baslatildi (once siper sonra ates + yer degistirme + 360 guvenlik + gece/NVG)";

// atis sayaci (yer degistirme icin)
[
    "CAManBase",
    "Fired",
    {
        params ["_u"];
        if (!local _u || {isPlayer _u}) exitWith {};
        private _p = _u getVariable [QGVAR(dpPos), []];
        if (_p isEqualTo [] || {(_u distance2D _p) > 4}) then {
            _u setVariable [QGVAR(dpPos), getPosATL _u];
            _u setVariable [QGVAR(dpN), 0];
            _u setVariable [QGVAR(dpT), time];
        };
        _u setVariable [QGVAR(dpN), (_u getVariable [QGVAR(dpN), 0]) + 1];
    },
    true, [], true
] call CBA_fnc_addClassEventHandler;

private _fnLog = {
    if (lambs_danger_fcLogN < 60) then {
        lambs_danger_fcLogN = lambs_danger_fcLogN + 1;
        diag_log _this;
    };
};

[_fnLog] spawn {
    params ["_log"];
    private _sutNoktasi = {
        // [asker, dusmanASL, merkez, yaricap, gizliOlmali] -> en yakin dusmandan gizli siperli nokta
        params ["_u", "_eASL", "_c", "_r"];
        private _best = [];
        private _bestD = 1e9;
        private _objs = nearestTerrainObjects [_c, ["WALL", "ROCK", "TREE", "BUILDING", "HOUSE", "FENCE", "ROCKS"], _r, false, true];
        {
            private _o = _x;
            private _bb = boundingBoxReal _o;
            private _yar = ((_bb select 1) select 0) max ((_bb select 1) select 1);
            private _pO = getPosATL _o;
            private _yon = _eASL getDir _pO;
            // objenin dusmandan uzak (arka) yuzu, 0.9 m disinda
            private _t = _pO getPos [(_yar min 4) + 0.9, _yon];
            _t set [2, 0];
            if (
                !surfaceIsWater _t
                && {(_u distance2D _t) <= _r + 2}
                && {lineIntersects [_eASL, AGLToASL (_t vectorAdd [0, 0, 1.1]), _u, objNull]}
                && {((_t nearEntities ["CAManBase", 1.2]) select {_x isNotEqualTo _u}) isEqualTo []}
            ) then {
                private _d = _u distance2D _t;
                if (_d < _bestD && {_d > 0.8}) then { _bestD = _d; _best = _t; };
            };
        } forEach (_objs select [0, 12]);
        _best
    };

    private _tick = 0;
    while {true} do {
        sleep 1;
        _tick = _tick + 1;
        if (missionNamespace getVariable ["lambs_danger_fieldCraftOff", false]) then { continue };

        // ---- gece / gunduz (10 sn'de bir, ayni zamanda tum yerel AI icin) ----
        private _geceKontrol = (_tick % 10) isEqualTo 0;
        private _gece = false;
        if (_geceKontrol) then {
            private _sf = sunOrMoon;
            _gece = _sf < 0.15;
        };

        {
            private _g = _x;
            if (isNull _g || {!local _g} || {isPlayer (leader _g)}) then { continue };
            private _us = (units _g) select {alive _x && {!isPlayer _x} && {isNull objectParent _x}};
            if (_us isEqualTo []) then { continue };
            private _temas = (_g getVariable [QGVAR(contact), 0]) > time;
            private _agirTaktik = (_g getVariable [QGVAR(isRetreating), false]) || {_g getVariable [QGVAR(isEvading), false]}
                || {_g getVariable [QGVAR(isBreakingContact), false]} || {_g getVariable [QGVAR(isBounding), false]}
                || {_g getVariable [QGVAR(isPeeling), false]} || {_g getVariable [QGVAR(isExecutingTactic), false]}
                || {_g getVariable [QGVAR(sniperTeam), false]} || {_g getVariable [QGVAR(disableGroupAI), false]}
                || {_g getVariable [QGVAR(isSweeping), false]};

            // ---------- D) GECE / NVG ----------
            if (_geceKontrol) then {
                {
                    private _u = _x;
                    private _nvg = (hmd _u) isNotEqualTo "";
                    if (_gece) then {
                        if (_nvg && {(currentVisionMode _u) isEqualTo 0}) then { _u action ["NVGoggles", _u]; };
                        if (_nvg) then {
                            _u enableIRLasers true;
                            _u enableGunLights "forceOff";
                        } else {
                            _u enableGunLights "AUTO";
                        };
                    } else {
                        if (_nvg && {(currentVisionMode _u) isEqualTo 1}) then { _u action ["NVGogglesOff", _u]; };
                        if (_u getVariable [QGVAR(nightSet), false]) then { _u enableGunLights "AUTO"; };
                    };
                    _u setVariable [QGVAR(nightSet), _gece];
                } forEach _us;
            };

            // ---------- E) TEK KALAN ASKER: savasma, kac / saklan (temas kes) ----------
            if (_temas && {(_tick % 2) isEqualTo 0} && {count ((units _g) select {alive _x}) isEqualTo 1} && {!(_g getVariable [QGVAR(isBreakingContact), false])}) then {
                private _tk = (units _g) select {alive _x};
                private _tu = _tk select 0;
                private _te = _tu findNearestEnemy _tu;
                if (!isNull _te && {alive _te} && {(_tu distance2D _te) < 400}) then {
                    private _ok = [_g, _te] call (missionNamespace getVariable ["lambs_danger_fnc_tacticsBreakContact", {false}]);
                    if (_ok) then { [format ["[SAHA] %1 | tek kalan %2 -> kaciyor / saklaniyor", groupId _g, name _tu]] call _log; };
                };
            };

            if (_agirTaktik) then { continue };

            // ---------- C) 360 GUVENLIK ----------
            if (!_temas) then {
                private _l = leader _g;
                if (count _us >= 3 && {(speed _l) < 0.8} && {isNull objectParent _l}) then {
                    private _t0 = _g getVariable [QGVAR(secT), -1];
                    if (_t0 < 0) then { _g setVariable [QGVAR(secT), time]; }
                    else {
                        if ((time - _t0) > 8 && {!(_g getVariable [QGVAR(secOn), false])} && {(behaviour _l) in ["AWARE", "SAFE", "COMBAT"]}) then {
                            _g setVariable [QGVAR(secOn), true];
                            private _taban = getDir _l;
                            private _n = count _us;
                            {
                                if (!(_x getVariable [QGVAR(forceMove), false]) && {(_x getVariable [QGVAR(taktikKilit), 0]) <= time} && {_x isNotEqualTo _l || {_n >= 4}}) then {
                                    _x doWatch (_x getPos [80, _taban + (_forEachIndex * (360 / _n))]);
                                };
                            } forEach _us;
                            ["[SAHA] 360 guvenlik: " + groupId _g + " (" + str _n + " kisi)"] call _log;
                        };
                    };
                } else {
                    if (_g getVariable [QGVAR(secOn), false]) then {
                        _g setVariable [QGVAR(secOn), false];
                        { _x doWatch objNull; } forEach _us;
                    };
                    _g setVariable [QGVAR(secT), -1];
                };
            } else {
                if (_g getVariable [QGVAR(secOn), false]) then {
                    _g setVariable [QGVAR(secOn), false];
                    { _x doWatch objNull; } forEach _us;
                };
                _g setVariable [QGVAR(secT), -1];
            };

            if (!_temas) then { continue };

            {
                private _u = _x;
                if (
                    !((lifeState _u) in ["HEALTHY", "INJURED"]) || {(insideBuilding _u) > 0.5}
                    || {_u getVariable [QGVAR(forceMove), false]} || {(_u getVariable [QGVAR(taktikKilit), 0]) > time} || {(_u getVariable [QGVAR(tcccBusy), 0]) > time}
                    || {(_u getVariable [QGVAR(grState), []]) isNotEqualTo []}
                ) then { continue };

                // ---------- A) ONCE SIPERE ----------
                private _bekle = _u getVariable [QGVAR(fcCoverUntil), 0];
                if (_bekle > 0) then {
                    private _hedef = _u getVariable [QGVAR(fcCoverPos), []];
                    private _vardi = _hedef isEqualTo [] || {(_u distance2D _hedef) < 1.3};
                    if (_vardi && {(_u getVariable [QGVAR(fcSettle), 0]) isEqualTo 0}) then {
                        _u setVariable [QGVAR(fcSettle), time + 2.5];
                    };
                    private _yerlesti = (_u getVariable [QGVAR(fcSettle), 0]) > 0 && {time > (_u getVariable [QGVAR(fcSettle), 0])};
                    if (_yerlesti || {time > _bekle}) then {
                        _u enableAI "TARGET"; _u enableAI "AUTOTARGET";
                        _u setVariable [QGVAR(fcCoverUntil), 0];
                        _u setVariable [QGVAR(fcSettle), 0];
                        _u setVariable [QGVAR(fcCool), time + 12];
                    };
                    continue;
                };

                private _role = [_u] call FUNC(getUnitRole);
                private _en = _u findNearestEnemy _u;
                if (isNull _en || {!alive _en}) then { continue };
                private _ed = _u distance2D _en;
                if (_ed < 15 || {_ed > 450}) then { continue };
                private _eASL = eyePos _en;

                if (time > (_u getVariable [QGVAR(fcCool), 0]) && {(speed _u) < 1.5}) then {
                    // acikta mi: dusman gozunden govdeye engel yok
                    private _acik = !(lineIntersects [_eASL, (getPosASL _u) vectorAdd [0, 0, 1.1], _en, _u]) && {!(terrainIntersectASL [_eASL, (getPosASL _u) vectorAdd [0, 0, 1.1]])};
                    if (_acik && {(getSuppression _u) > -1}) then {
                        private _s = [_u, _eASL, getPosATL _u, 7] call _sutNoktasi;
                        if (_s isNotEqualTo []) then {
                            _u setVariable [QGVAR(fcCoverPos), _s];
                            _u setVariable [QGVAR(fcCoverUntil), time + 6];
                            _u setVariable [QGVAR(fcSettle), 0];
                            _u disableAI "TARGET"; _u disableAI "AUTOTARGET";
                            _u doMove _s;
                            [format ["[SAHA] %1 | %2 | acikta -> siper %3 m (once siper sonra ates)", groupId _g, name _u, round (_u distance2D _s)]] call _log;
                            continue;
                        };
                    };
                };

                // ---------- B) YER DEGISTIRME ----------
                if (
                    !(_role in ["MG", "MARKSMAN"]) && {time > (_u getVariable [QGVAR(dpCool), 0])}
                    && {(_u getVariable [QGVAR(dpN), 0]) >= 12} && {(time - (_u getVariable [QGVAR(dpT), time])) >= 6}
                ) then {
                    _u setVariable [QGVAR(dpN), 0];
                    _u setVariable [QGVAR(dpPos), []];
                    _u setVariable [QGVAR(dpCool), time + 25];
                    private _yon = _eASL getDir _u;
                    private _sec = [];
                    {
                        private _c = _u getPos [7.5, _yon + _x];
                        if (!surfaceIsWater _c && {((_c nearEntities ["CAManBase", 1.5]) select {_x isNotEqualTo _u}) isEqualTo []}
                            && {!(lineIntersects [(getPosASL _u) vectorAdd [0, 0, 0.9], AGLToASL (_c vectorAdd [0, 0, 0.9]), _u])}) exitWith { _sec = _c; };
                    } forEach selectRandom [[90, -90], [-90, 90]];
                    if (_sec isNotEqualTo []) then {
                        private _s2 = [_u, _eASL, _sec, 6] call _sutNoktasi;
                        _u doMove ([_sec, _s2] select (_s2 isNotEqualTo []));
                        [format ["[SAHA] %1 | %2 | 12+ atis ayni yerden -> yer degistiriyor", groupId _g, name _u]] call _log;
                    };
                };
            } forEach _us;
        } forEach allGroups;
    };
};

true
