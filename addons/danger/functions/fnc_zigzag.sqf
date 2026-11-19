#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * ACIK ARAZIDE ZIKZAK (v8.688; kullanici: 'acik arazide zigzagla ilerlesinler vurulmasi guc olsun, 7-10 metrede zigzag atsinlar').
 * Temasli grupta KOSAN (taktik kosucusu, kendi doMove emri VEYA formasyonu izleyen) asker, gozu acik dusmandan (40 m - zigzagMaxM) gorunuyorsa ve cevresi AÇIK ise
 *   GERCEK hedefine dogru dogrudan gitmez: her ~1.8 sn'de ileri 6-14 m + yana 7-10 m (CBA) ARA NOKTA, yan yon her seferinde ters -> hedefe zikzakla ilerler.
 * GERCEK HEDEF: askerin su anki doMove hedefi (expectedDestination); baska sistem yeni emir verirse (ara noktamiz degil) o yeni gercek hedef olur (emri EZMEZ: zikzak her zaman en son verilen hedefe yoneliktir).
 * BITIS: hedefe < 25 m, asker kosmuyor (hiz < 6 km/sa), forceMove kalkti, dusman gorus disi / yakin (< 40 m), cevre kapali (>= 2 sert nesne 10 m icinde), binada -> zikzak biter; ara noktadaysa gercek hedefe doMove verilir.
 * CBA: lambs_danger_zigzag (acik / kapali), zigzagYanMin / zigzagYanMax (m), zigzagMaxM (dusman azami mesafe). Log: [ZIGZAG] (ilk 20) + 60 sn ozeti.
 *
 * Arguments: None
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isNil "lambs_danger_zigzagStarted") exitWith {false};
lambs_danger_zigzagStarted = true;
diag_log "[ZIGZAG] acik arazide zikzak (kosan asker 7-10 m yana, ters yon) baslatildi (v8.688)";

[] spawn {
    private _logN = 0;
    private _say = 0;
    private _red = createHashMap;   // v8.690: aday askerin (kosuyor + temasli) NEDEN zikzak yapmadigi sayaclari
    private _ozetT = time + 60;
    while {true} do {
        sleep 0.5;
        if (time > _ozetT) then {
            _ozetT = time + 60;
            if (_say > 0 || {count _red > 0}) then { diag_log format ["[ZIGZAG-OZET] 60 sn: zikzak adimi %1 | aday asker-tur ret nedenleri: %2", _say, (keys _red) apply {format ["%1:%2", _x, _red get _x]}]; };
            _say = 0; _red = createHashMap;
        };
        if !(missionNamespace getVariable ["lambs_danger_zigzag", true]) then { continue };
        private _yMin = ((missionNamespace getVariable ["lambs_danger_zigzagYanMin", 7]) max 3) min 15;
        private _yMax = ((missionNamespace getVariable ["lambs_danger_zigzagYanMax", 10]) max _yMin) min 20;
        private _enMax = ((missionNamespace getVariable ["lambs_danger_zigzagMaxM", 350]) max 100) min 500;
        private _n = 0;
        {
            private _u = _x;
            if (_n >= 20) exitWith {};
            if (!local _u || {isPlayer _u} || {!alive _u} || {!isNull objectParent _u} || {!((lifeState _u) in ["HEALTHY", "INJURED"])}) then { continue };
            private _son = _u getVariable [QGVAR(zigNokta), []];
            private _g = group _u;
            // zikzak kosullari (v8.690 GENISLETILDI: 'zigzag yok' - taktik bayragi sarti kalkti; temasli grupta kosan her asker: forceMove (taktik kosucusu) YA DA kendi doMove emri (expectedDestination 'DoNotPlan'); formasyon izleyen asker haric)
            private _mod = (expectedDestination _u) select 1;
            private _kosEmir = ((_u getVariable [QGVAR(forceMove), false]) isEqualTo true) || {_mod isEqualTo "DoNotPlan"};
            private _uygun = (speed _u) > 6;
            if (_uygun) then {
                private _neden = "";
                if ((_g getVariable [QGVAR(contact), 0]) < (time - 60)) then { _neden = "temas yok"; } else {
                if (isPlayer (leader _g)) then { _neden = "oyuncu liderli grup"; } else {
                if ((currentCommand _u) isNotEqualTo "MOVE") then { _neden = "komut MOVE degil"; } else {
                if ((insideBuilding _u) >= 0.5) then { _neden = "binada"; } else {
                if ((time - (((_u getVariable [QGVAR(acikSiperHedef), [0, -999]]) param [1, -999]))) < 8 || {(time - (_u getVariable [QGVAR(hugAt), -999])) < 8}) then { _neden = "siper kosusu"; }; }; }; }; };
                if (_neden isNotEqualTo "") then { _uygun = false; _red set [_neden, (_red getOrDefault [_neden, 0]) + 1]; };
            };
            private _en = objNull;
            private _ed = 0;
            if (_uygun) then {
                private _neden = "";
                _en = _u findNearestEnemy _u;
                if (isNull _en || {!alive _en}) then { _neden = "dusman yok"; } else {
                    _ed = _u distance2D _en;
                    if (_ed < 40) then { _neden = "dusman < 40 m"; } else {
                    if (_ed > _enMax) then { _neden = "dusman uzak"; } else {
                    if ((terrainIntersectASL [eyePos _en, eyePos _u]) || {lineIntersects [eyePos _en, eyePos _u, _en, _u]}) then { _neden = "gorus kapali (gizli)"; } else {
                    if (count (nearestTerrainObjects [_u, ["TREE", "ROCK", "ROCKS", "WALL", "BUILDING", "HOUSE", "HIDE"], 10, false, true]) >= 3) then { _neden = "cevre kapali (>= 3 nesne)"; }; }; }; };
                };
                if (_neden isNotEqualTo "") then { _uygun = false; _red set [_neden, (_red getOrDefault [_neden, 0]) + 1]; };
            };
            private _gercek = _u getVariable [QGVAR(zigGercek), []];
            private _ep = (expectedDestination _u) select 0;
            if (_uygun) then {
                // baska sistem yeni emir verdiyse (ara noktamiz degil): o yeni GERCEK hedef
                if (_son isEqualTo [] || {(_ep distance2D _son) > 4}) then {
                    // v8.690: formasyon izleyen asker (kendi emri yok): gercek hedef = formasyon slotu; zikzak bitince doFollowGuvenli ile lidere / formasyona donulur
                    _u setVariable [QGVAR(zigForm), !_kosEmir];
                    _gercek = if (_kosEmir) then { _ep } else { formationPosition _u };
                    _u setVariable [QGVAR(zigGercek), _gercek];
                    _son = [];
                    _u setVariable [QGVAR(zigNokta), nil];
                } else {
                    if (_u getVariable [QGVAR(zigForm), false]) then { _gercek = formationPosition _u; _u setVariable [QGVAR(zigGercek), _gercek]; };
                };
                if (_gercek isEqualTo [] || {(_gercek distance2D [0, 0, 0]) < 5} || {(_u distance2D _gercek) < 25}) then { _uygun = false; };
            };
            if (!_uygun) then {
                // zikzak bitti: ara noktamizdaysa gercek hedefe don (baska sistem emir vermediyse)
                if (_son isNotEqualTo [] && {_gercek isNotEqualTo []} && {(_ep distance2D _son) <= 4}) then {
                    if (_u getVariable [QGVAR(zigForm), false]) then { [_u, leader _g] call FUNC(doFollowGuvenli); } else { _u doMove _gercek; };
                };
                if (_son isNotEqualTo []) then { _u setVariable [QGVAR(zigNokta), nil]; };
                if (_son isEqualTo [] || {(_ep distance2D _son) > 4}) then { _u setVariable [QGVAR(zigGercek), nil]; };
                continue
            };
            _n = _n + 1;
            if (time < (_u getVariable [QGVAR(zigT), 0])) then { continue };
            private _dir = _u getDir _gercek;
            private _yan = _yMin + (random (_yMax - _yMin));
            private _isaret = -(_u getVariable [QGVAR(zigYon), 1]);
            private _ileri = (((_u distance2D _gercek) - 15) min (6 + (random 8))) max 6;
            private _pt = [];
            for "_t" from 0 to 1 do {
                private _c = (_u getPos [_ileri, _dir]) getPos [_yan, _dir + (90 * _isaret)];
                if (!surfaceIsWater _c && {((surfaceNormal _c) select 2) > 0.8}) exitWith { _pt = _c; };
                _isaret = -_isaret;
            };
            if (_pt isEqualTo []) then { _u setVariable [QGVAR(zigT), time + 1]; continue };
            _u setVariable [QGVAR(zigYon), _isaret];
            _u setVariable [QGVAR(zigNokta), _pt];
            _u setVariable [QGVAR(zigT), time + 1.8];
            _u doMove _pt;
            _say = _say + 1;
            if (_logN < 20) then {
                _logN = _logN + 1;
                diag_log format ["[ZIGZAG] %1 | %2 | dusman %3 m | ileri %4 m yan %5 m | gercek hedefe %6 m", groupId _g, name _u, round _ed, round _ileri, round _yan, round (_u distance2D _gercek)];
            };
        } forEach allUnits;
    };
};
true
