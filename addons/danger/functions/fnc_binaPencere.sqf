#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * BINA ICI PENCERE / ATIS POZISYONU (v8.354; kullanici: 'binalari aktif kullansinlar'; 'pasif birakacak noktalarda konumlaniyor'). Bina ICINDE bekleyen (LAMBS garnizon / saklanma / mevzi) AI asker temasta dusmani
 * gormuyorsa (arada duvar) AYNI BINADA, ayni katta, dusmana pencere / kapi hatti acik bir pozisyona gecer; boylece bina sadece saklanma yeri degil ATIS mevzisi olur.
 *
 * KOSUL (1.2 sn'de bir, tick butcesi 3 birim, birim basina 20 sn'de bir):
 *   - yerel AI piyade, grupta oyuncu yok, grup temasta (QGVAR(contact) damgasi > time), taktik yok (retreat / evade / break contact / sweeping / son direnis), birim bina ICINDE (insideBuilding > 0.6), duruyor (< 2 km/s),
 *     son 8 sn ates etmemis, baski <= 0.5, teslim / esir degil, forceMove / taktikKilit / yeniden doldurma yok, grup combatMode GREEN / BLUE degil (ates yasagi), davranis STEALTH degil, AT degil (geri tepme: bina ici)
 *   - bilinen dusman (knowsAbout >= 0.5) 8-250 m icinde ve askerin goz hizasindan dusmana hat KAPALI (duvar)
 * SECIM: ayni binanin pozisyonlari (buildingPos), ayni kat (|dz| < 1.6 m), askerden <= 14 m, baska askere ayrilmamis (1.8 m, acikSiper ortak rezerv listesi) ve 1.2 m icinde baska asker yok;
 *   dusman gozunden ayakta (1.5 m) ya da comelmis (1.0 m) goz hizasina hat ACIK; skor = mesafe + (5 yanal ornek hepsi aciksa +8 tamamen acik yapi) + ust ortu yoksa +15; keskin nisanci ust katta tercih (-6).
 * DAVRANIS: doMove (taktikKilit 12 sn), varinca durus (ayakta gorunuyorsa UP, yalniz comelirken gorunuyorsa MIDDLE) + dusmana doWatch; 40 sn sonra serbest. Log: [BINA-PENCERE] (ilk 40) + 60 sn ozeti.
 * Kapatma: CBA 'ELITE CQB' (lambs_danger_cqbV2 = false) ya da lambs_danger_binaPencereOff = true.
 *
 * Arguments: None
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isNil "lambs_danger_binaPencereStarted") exitWith {false};
lambs_danger_binaPencereStarted = true;

diag_log "[BINA-PENCERE] bina ici pencere / atis pozisyonu watchdog baslatildi (v8.354)";

[] spawn {
    private _rolFn = missionNamespace getVariable ["lambs_danger_fnc_getUnitRole", {"RIFLE"}];
    private _sayac = createHashMapFromArray [["tespit", 0], ["tasindi", 0], ["pozYok", 0]];
    private _sonOzet = time;

    while {true} do {
        sleep 1.2;
        if ((time - _sonOzet) >= 60) then {
            _sonOzet = time;
            if ((_sayac get "tespit") > 0) then {
                diag_log format ["[BINA-PENCERE-OZET] 60 sn: dusmani goremeyen bina ici asker %1 | pencereye tasindi %2 | uygun pozisyon yok %3", _sayac get "tespit", _sayac get "tasindi", _sayac get "pozYok"];
            };
            { _sayac set [_x, 0]; } forEach (keys _sayac);
        };
        if (missionNamespace getVariable ["lambs_danger_binaPencereOff", false] || {!(missionNamespace getVariable ["lambs_danger_cqbV2", true])}) then { continue };
        private _butce = 3;

        {
            private _g = _x;
            if (_butce <= 0) exitWith {};
            if (isNull _g || {!local _g}) then { continue };
            if ((_g getVariable [QGVAR(contact), 0]) <= time) then { continue };
            if ((combatMode _g) in ["GREEN", "BLUE"]) then { continue };
            if (_g getVariable [QGVAR(sniperTeam), false]) then { continue };
            if (
                (_g getVariable [QGVAR(isRetreating), false]) || {_g getVariable [QGVAR(isBreakingContact), false]} || {_g getVariable [QGVAR(isEvading), false]}
                || {_g getVariable [QGVAR(isSweeping), false]} || {_g getVariable [QGVAR(isSonDirenis), false]}
            ) then { continue };
            if (((units _g) findIf {isPlayer _x}) > -1) then { continue };

            {
                private _u = _x;
                if (_butce <= 0) exitWith {};
                if (
                    !alive _u || {!local _u} || {!isNull objectParent _u} || {!((lifeState _u) in ["HEALTHY", "INJURED"])}
                    || {captive _u} || {_u getVariable [QGVAR(teslim), false]}
                    || {(speed _u) > 2} || {(insideBuilding _u) < 0.6}
                    || {(time - (_u getVariable [QGVAR(pencereT), -999])) < 20}
                    || {(time - (_u getVariable [QGVAR(sonAtisT), -999])) < 8} || {(getSuppression _u) > 0.5}
                    || {_u getVariable [QGVAR(forceMove), false]} || {(_u getVariable [QGVAR(taktikKilit), 0]) > time}
                    || {(_u getVariable [QGVAR(reloadState), []]) isNotEqualTo []} || {(_u getVariable [QGVAR(grState), []]) isNotEqualTo []}
                    || {(behaviour _u) isEqualTo "STEALTH"}
                ) then { continue };

                private _en = _u findNearestEnemy _u;
                if (isNull _en || {!alive _en}) then { continue };
                private _ed = _u distance2D _en;
                if (_ed < 8 || {_ed > 250} || {(_u knowsAbout _en) < 0.5}) then { continue };
                private _rol = [_u] call _rolFn;
                if (_rol isEqualTo "AT") then { continue };

                // zaten goruyor mu? (goz hizasindan dusmana hat acik ise yerinde kalir)
                private _uA = eyePos _u;
                private _eASL = eyePos _en;
                if (!((lineIntersects [_uA, _eASL, _u, _en]) || {terrainIntersectASL [_uA, _eASL]})) then { continue };

                _u setVariable [QGVAR(pencereT), time];
                _butce = _butce - 1;
                _sayac set ["tespit", (_sayac get "tespit") + 1];

                private _b = nearestBuilding _u;
                if (isNull _b || {(_u distance2D _b) > 25}) then { continue };
                private _uZ = (getPosATL _u) select 2;
                private _dolu = (missionNamespace getVariable ["lambs_danger_acikSiperDolu", []]) select {(time - (_x select 1)) < 30};
                private _edir = (getPosATL _u) getDir _en;
                private _perp = [cos _edir, -(sin _edir), 0];
                private _enB = [];
                private _enS = 1e9;
                private _enDurus = "UP";
                {
                    private _bp = _x;
                    private _d = _u distance2D _bp;
                    if (_d >= 1.5 && {_d <= 14} && {(abs ((_bp select 2) - _uZ)) < 1.6} && {(_dolu findIf {((_x select 0) distance2D _bp) < 1.8}) < 0} && {(((_bp nearEntities ["CAManBase", 1.2]) - [_u]) isEqualTo [])}) then {
                        private _bA = AGLToASL _bp;
                        private _gUp = (lineIntersects [_eASL, _bA vectorAdd [0, 0, 1.5], _en, _u]) || {terrainIntersectASL [_eASL, _bA vectorAdd [0, 0, 1.5]]};
                        private _gMid = (lineIntersects [_eASL, _bA vectorAdd [0, 0, 1.0], _en, _u]) || {terrainIntersectASL [_eASL, _bA vectorAdd [0, 0, 1.0]]};
                        if (!_gUp || {!_gMid}) then {
                            private _sk = _d;
                            private _acik = 0;
                            {
                                private _yp = (_bA vectorAdd [0, 0, 1.4]) vectorAdd (_perp vectorMultiply _x);
                                if (!((lineIntersects [_eASL, _yp, _en, _u]) || {terrainIntersectASL [_eASL, _yp]})) then { _acik = _acik + 1; };
                            } forEach [-0.8, -0.4, 0, 0.4, 0.8];
                            if (_acik >= 5) then { _sk = _sk + 8; };
                            if !(lineIntersects [_bA vectorAdd [0, 0, 1.6], _bA vectorAdd [0, 0, 25], _u]) then { _sk = _sk + 15; };
                            if (_rol isEqualTo "MARKSMAN" && {((_bp select 2) - _uZ) > 0.5}) then { _sk = _sk - 6; };
                            if (_sk < _enS) then { _enS = _sk; _enB = _bp; _enDurus = ["MIDDLE", "UP"] select (!_gUp); };
                        };
                    };
                } forEach (_b buildingPos -1);

                if (_enB isEqualTo []) then {
                    _sayac set ["pozYok", (_sayac get "pozYok") + 1];
                    continue
                };
                _dolu pushBack [_enB, time];
                missionNamespace setVariable ["lambs_danger_acikSiperDolu", _dolu];
                _u setVariable [QGVAR(taktikKilit), time + 12];
                _u forceSpeed -1;
                _u doMove _enB;
                _sayac set ["tasindi", (_sayac get "tasindi") + 1];
                [{ params ["_uu", "_hp"]; !alive _uu || {(_uu distance2D _hp) < 1.5} }, { params ["_uu", "_hp", "_ds", "_e"]; if (alive _uu) then { _uu setUnitPos _ds; if (!isNull _e && {alive _e}) then { _uu doWatch _e; }; }; }, [_u, _enB, _enDurus, _en], 14, {}] call CBA_fnc_waitUntilAndExecute;
                [{ params ["_uu"]; if (alive _uu) then { _uu setUnitPos "AUTO"; _uu doWatch objNull; }; }, [_u], 40] call CBA_fnc_waitAndExecute;
                if ((missionNamespace getVariable ["lambs_danger_pencereLogN", 0]) < 40) then {
                    missionNamespace setVariable ["lambs_danger_pencereLogN", (missionNamespace getVariable ["lambs_danger_pencereLogN", 0]) + 1];
                    diag_log format ["[BINA-PENCERE] %1 | %2 (%3) | dusman %4 m, arada duvar -> ayni binada ATIS pozisyonu %5 m (durus %6, skor %7) | %8", groupId _g, name _u, _rol, round _ed, round (_u distance2D _enB), _enDurus, round _enS, typeOf _b];
                };
            } forEach (units _g);
        } forEach allGroups;
    };
};

true
