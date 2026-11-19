#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * COVER OLCUM KATMANI (v8.661; yol haritasi Asama 12 madde 1; kullanici: 'dediklerine basla'): temasli AI'in siper / manevra kalitesini sayilarla RPT'ye yazar (insan referansi karsilastirmasi icin).
 * 5 sn'de bir ornek (en cok 30 asker), 60 sn'de bir [COVER-OLCUM] ozeti:
 *   - ornek sayisi, dusman gozunden GIZLI % (VIEW LOD hatti arada nesneye / araziye carpiyor) / ACIKTA %
 *   - KUMELENME % (4 m icinde >= 2 dost) ve ort. en yakin dost mesafesi
 *   - DURUS dagilimi (UP / CROUCH / PRONE %)
 *   - KOSAN (hiz > 8 km/sa) asker sayisi ROLE GORE (RIFLE / MG / AT / MEDIC / MARKSMAN): 'MG kosan' ve 'MEDIC kosan' rol disiplini kontrolu
 * Yalniz YEREL AI, temasli (30 sn) grup, bilinen dusman <= 400 m. CBA: lambs_danger_coverOlcum (varsayilan ACIK).
 *
 * Arguments: None
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isNil "lambs_danger_coverOlcumStarted") exitWith {false};
lambs_danger_coverOlcumStarted = true;

diag_log "[COVER-OLCUM] cover / manevra olcum katmani baslatildi (v8.661)";

[] spawn {
    private _sayac = createHashMapFromArray [["n", 0], ["gizli", 0], ["acik", 0], ["kume", 0], ["dostMes", 0], ["UP", 0], ["CROUCH", 0], ["PRONE", 0], ["kosRIFLE", 0], ["kosMG", 0], ["kosAT", 0], ["kosMEDIC", 0], ["kosMARKSMAN", 0], ["rolMG", 0], ["rolAT", 0], ["rolMEDIC", 0], ["rolRIFLE", 0], ["rolMARKSMAN", 0]];
    private _ozetT = time + 60;
    private _rf = missionNamespace getVariable ["lambs_danger_fnc_getUnitRole", {"RIFLE"}];
    while {true} do {
        sleep 5;
        if !(missionNamespace getVariable ["lambs_danger_coverOlcum", true]) then { continue };
        private _esik = ["SUPHE"] call FUNC(bilgiEsik);
        private _k = 0;
        {
            private _u = _x;
            if (_k >= 30) exitWith {};
            if (
                !local _u || {isPlayer _u} || {!alive _u} || {!isNull objectParent _u} || {!((lifeState _u) in ["HEALTHY", "INJURED"])}
                || {((group _u) getVariable [QGVAR(contact), 0]) < (time - 30)} || {(insideBuilding _u) > 0.5}
            ) then { continue };
            private _e = _u findNearestEnemy _u;
            if (isNull _e || {!alive _e} || {(_u distance _e) > 400} || {(_u knowsAbout _e) < _esik}) then { continue };
            _k = _k + 1;
            _sayac set ["n", (_sayac get "n") + 1];
            private _rol = [_u] call _rf;
            _sayac set ["rol" + _rol, (_sayac getOrDefault ["rol" + _rol, 0]) + 1];
            if ((speed _u) > 8) then { _sayac set ["kos" + _rol, (_sayac getOrDefault ["kos" + _rol, 0]) + 1]; };
            private _pa = (getPosASL _u) vectorAdd [0, 0, 0.9];
            private _gizli = ((lineIntersectsSurfaces [eyePos _e, _pa, _e, _u, true, 1, "VIEW", "NONE"]) isNotEqualTo []) || {terrainIntersectASL [eyePos _e, _pa]};
            _sayac set [["acik", "gizli"] select _gizli, (_sayac get (["acik", "gizli"] select _gizli)) + 1];
            private _st = stance _u;
            if (_st in ["UP", "CROUCH", "PRONE"]) then { _sayac set [_st, (_sayac get _st) + 1]; };
            private _dm = ((_u nearEntities ["CAManBase", 12]) select {_x isNotEqualTo _u && {alive _x} && {(side group _x) isEqualTo (side group _u)}}) apply {_x distance _u};
            private _en = if (_dm isEqualTo []) then {12} else {selectMin _dm};
            _sayac set ["dostMes", (_sayac get "dostMes") + _en];
            if ((count (_dm select {_x < 4})) >= 2) then { _sayac set ["kume", (_sayac get "kume") + 1]; };
        } forEach allUnits;
        if (time > _ozetT) then {
            _ozetT = time + 60;
            private _n = _sayac get "n";
            if (_n > 0) then {
                diag_log format ["[COVER-OLCUM] 60 sn: ornek %1 | GIZLI %2 %% / ACIKTA %3 %% | KUMELENME (4 m icinde >= 2 dost) %4 %% | ort. en yakin dost %5 m | DURUS UP %6 %% CROUCH %7 %% PRONE %8 %% | KOSAN: RIFLE %9/%10 MG %11/%12 AT %13/%14 MEDIC %15/%16 MARKSMAN %17/%18",
                    _n, round (100 * (_sayac get "gizli") / _n), round (100 * (_sayac get "acik") / _n), round (100 * (_sayac get "kume") / _n), ((_sayac get "dostMes") / _n) toFixed 1,
                    round (100 * (_sayac get "UP") / _n), round (100 * (_sayac get "CROUCH") / _n), round (100 * (_sayac get "PRONE") / _n),
                    _sayac get "kosRIFLE", _sayac get "rolRIFLE", _sayac get "kosMG", _sayac get "rolMG", _sayac get "kosAT", _sayac get "rolAT", _sayac get "kosMEDIC", _sayac get "rolMEDIC", _sayac get "kosMARKSMAN", _sayac get "rolMARKSMAN"];
            };
            { _sayac set [_x, 0]; } forEach (keys _sayac);
        };
    };
};
true
