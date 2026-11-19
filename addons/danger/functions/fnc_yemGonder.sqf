#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * YEM + TACIZ ATESI (v8.693; kullanici: 'oyuncu grubuna yem gonderme: ileri gozlemci disinda en basiti once gidecek ve taciz atisi acacak, farkli bir bolgeden; amac oyunculari spot edip dikkatini dagitmak ve yerini aciga cikarmak').
 * Yalniz INSAN OYUNCU hedeflere karsi. Temasli / oyuncuyu bilen (knowsAbout >= SUPHE; group targets) yerel AI grubunda (oyuncu liderli grup haric, >= yemMinAsker asker):
 *   YEM BIRIMI = en basit asker: en dusuk rutbeli DUZ TUFEKLI (lider / ileri gozcu / nokta elemani / MG / hekim / AT / UGL / nisanci / kosucu / kilitli / baskili haric);
 *   YER = oyuncudan gruba cizgiye DIK yonde, gruptan yemYanM (90 m) yanda (iki yan x 3 mesafe), oyuncuya yemMenzilMin - yemMenzilMax araliginda; puan: yakin sert nesne (siper) + oyuncuya gorus hatti (spot icin) ;
 *   yem birimi oraya KOSAR (forceMove, kilit), varinca yemSure (40 sn) boyunca grubun BILDIGI oyuncu konumuna 6-10 sn'de bir doSuppressiveFire ile TACIZ ATESI acar (oyuncunun dikkatini dagitir / ates acmaya iter -> yeri aciga cikar);
 *   bitince / olurse / grup taktik, geri cekilme, temas kes yurutmeye baslarsa kilitler birakilir ve doFollowGuvenli ile gruba doner. Grup basina yemBekle (240 sn) bekleme. Ayni anda grupta tek yem.
 * CBA: lambs_danger_yemGonder (varsayilan KAPALI), yemMinAsker, yemMenzilMin, yemMenzilMax, yemYanM, yemSure, yemBekle. Log: [YEM] (ilk 25) + [YEM-OZET] 60 sn.
 *
 * Arguments: None
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isNil "lambs_danger_yemStarted") exitWith {false};
lambs_danger_yemStarted = true;
diag_log "[YEM] yem + taciz atesi (oyuncu grubuna: en basit asker farkli bolgeden taciz atar) baslatildi (v8.693)";

[] spawn {
    private _logN = 0;
    private _say = createHashMapFromArray [["basladi", 0], ["bitti", 0], ["yerYok", 0], ["adayYok", 0]];
    private _ozetT = time + 60;
    private _rolFn = missionNamespace getVariable ["lambs_danger_fnc_getUnitRole", {"RIFLE"}];
    while {true} do {
        sleep 3;
        if (time > _ozetT) then {
            _ozetT = time + 60;
            if ((_say get "basladi") + (_say get "yerYok") + (_say get "adayYok") > 0) then { diag_log format ["[YEM-OZET] 60 sn: yem basladi %1 | bitti %2 | yer bulunamadi %3 | yem adayi yok %4", _say get "basladi", _say get "bitti", _say get "yerYok", _say get "adayYok"]; };
            { _say set [_x, 0]; } forEach (keys _say);
        };
        if !(missionNamespace getVariable ["lambs_danger_yemGonder", false]) then { continue };
        private _minA = ((missionNamespace getVariable ["lambs_danger_yemMinAsker", 6]) max 4) min 12;
        private _mMin = ((missionNamespace getVariable ["lambs_danger_yemMenzilMin", 150]) max 80) min 400;
        private _mMax = ((missionNamespace getVariable ["lambs_danger_yemMenzilMax", 450]) max (_mMin + 50)) min 700;
        private _yanM = ((missionNamespace getVariable ["lambs_danger_yemYanM", 90]) max 40) min 160;
        private _sure = ((missionNamespace getVariable ["lambs_danger_yemSure", 40]) max 15) min 120;
        private _bekle = ((missionNamespace getVariable ["lambs_danger_yemBekle", 240]) max 60) min 900;
        private _n = 0;
        {
            private _g = _x;
            if (_n >= 6) exitWith {};
            private _l = leader _g;
            if (isNull _l || {!local _g} || {isPlayer _l} || {!alive _l} || {!isNull objectParent _l}) then { continue };
            if (time < (_g getVariable [QGVAR(yemT), 0])) then { continue };
            if ((_g getVariable [QGVAR(contact), 0]) < (time - 120)) then { continue };
            if (
                (_g getVariable [QGVAR(isRetreating), false]) || {_g getVariable [QGVAR(isEvading), false]} || {_g getVariable [QGVAR(isBreakingContact), false]}
                || {_g getVariable [QGVAR(isBounding), false]} || {_g getVariable [QGVAR(isExecutingTactic), false]} || {_g getVariable [QGVAR(isSweeping), false]}
                || {_g getVariable [QGVAR(isAmbushing), false]} || {_g getVariable [QGVAR(sniperTeam), false]} || {(_g getVariable [QGVAR(sahteAktif), false]) isEqualTo true}
                || {([_g] call FUNC(wpSahip)) in ["LAMBS", "TUTAN"]} || {(insideBuilding _l) > 0.5}
            ) then { continue };
            private _us = (units _g) select {alive _x && {isNull objectParent _x} && {!isPlayer _x} && {(lifeState _x) in ["HEALTHY", "INJURED"]}};
            if ((count _us) < _minA) then { continue };
            private _hedef = (_l targets [true, _mMax, [], 60]) select {alive _x && {(isPlayer _x) || {((crew _x) findIf {isPlayer _x}) >= 0}}};
            if (_hedef isEqualTo []) then { continue };
            _n = _n + 1;
            _hedef = [_hedef, [], {_l distance2D _x}, "ASCEND"] call BIS_fnc_sortBy;
            private _p = _hedef select 0;
            if ((_l distance2D _p) < _mMin) then { continue };
            // yem birimi: en basit asker
            private _aday = _us select {
                _x isNotEqualTo _l && {([_x] call _rolFn) isEqualTo "RIFLE"} && {(_x getVariable [QGVAR(gozcu), false]) isNotEqualTo true} && {(_x getVariable [QGVAR(noktaEk), false]) isNotEqualTo true}
                && {(_x getVariable [QGVAR(forceMove), false]) isNotEqualTo true} && {time > (_x getVariable [QGVAR(taktikKilit), 0])} && {(getSuppression _x) < 0.3} && {!captive _x}
            };
            if (_aday isEqualTo []) then { _say set ["adayYok", (_say get "adayYok") + 1]; _g setVariable [QGVAR(yemT), time + 30]; continue };
            _aday = [_aday, [], {(rankId _x) + (random 0.5)}, "ASCEND"] call BIS_fnc_sortBy;
            private _u = _aday select 0;
            // yer: oyuncudan gruba cizgiye dik yan, oyuncuya menzil bandinda; puan = yakin sert nesne + oyuncuya gorus hatti
            private _tpos = getPosATL _p;
            private _b = _tpos getDir _l;
            private _eyeP = eyePos _p;
            private _en = [];
            private _enS = -1e9;
            {
                private _isaret = _x;
                {
                    private _c = (getPosATL _l) getPos [_yanM * _x, _b + (90 * _isaret)];
                    private _dp = _c distance2D _tpos;
                    if (surfaceIsWater _c || {((surfaceNormal _c) select 2) < 0.8} || {_dp < _mMin} || {_dp > _mMax}) then { continue };
                    private _nesne = (count (nearestTerrainObjects [_c, ["TREE", "ROCK", "ROCKS", "WALL", "HIDE", "BUILDING", "HOUSE"], 8, false, true])) min 3;
                    private _cA = AGLToASL (_c vectorAdd [0, 0, 1]);
                    private _gor = !(terrainIntersectASL [_eyeP, _cA]) && {!(lineIntersects [_eyeP, _cA, _p, objNull])};
                    private _sk = (_nesne * 5) + ([0, 8] select _gor) - ((abs (_x - 1)) * 4);
                    if (_sk > _enS) then { _enS = _sk; _en = _c; };
                } forEach [0.7, 1, 1.3];
            } forEach [1, -1];
            if (_en isEqualTo []) then { _say set ["yerYok", (_say get "yerYok") + 1]; _g setVariable [QGVAR(yemT), time + 30]; continue };

            _g setVariable [QGVAR(yemT), time + _bekle];
            _say set ["basladi", (_say get "basladi") + 1];
            _u setVariable [QGVAR(yemBirim), true];
            _u setVariable [QGVAR(forceMove), true];
            _u setVariable [QGVAR(taktikKilit), time + _sure + 45];
            _u forceSpeed -1;
            _u setSpeedMode "FULL";
            _u doMove _en;
            if (_logN < 25) then {
                _logN = _logN + 1;
                diag_log format ["[YEM] %1 | yem birimi %2 (rutbe %3) | oyuncu %4 (%5 m) | taciz noktasi gruptan %6 m, oyuncuya %7 m | tur %8 sn", groupId _g, name _u, rank _u, name _p, round (_l distance2D _p), round (_u distance2D _en), round (_en distance2D _tpos), _sure];
            };

            [_g, _u, _p, _en, _sure, _say] spawn {
                params ["_g", "_u", "_p", "_pt", "_sure", "_say"];
                private _iptal = {
                    params ["_gg", "_uu"];
                    isNull _gg || {!alive _uu} || {!((lifeState _uu) in ["HEALTHY", "INJURED"])} || {_gg getVariable [QGVAR(isRetreating), false]} || {_gg getVariable [QGVAR(isBreakingContact), false]}
                    || {_gg getVariable [QGVAR(isEvading), false]}
                };
                private _vBit = time + 35;
                private _tazeT = 0;
                waitUntil {
                    sleep 0.5;
                    // v8.694 EMIR TAZELEME: baska sistem (bounding sonu / komutan) emri bozduysa (hedef modu farkli / forceMove silindi) yem hedefine yeniden gonderilir (2 sn'de en cok bir)
                    if (alive _u && {time > _tazeT} && {(_u distance2D _pt) > 8} && {((((expectedDestination _u) select 0) distance2D _pt) > 8) || {(_u getVariable [QGVAR(forceMove), false]) isNotEqualTo true}}) then {
                        _tazeT = time + 2;
                        _u setVariable [QGVAR(forceMove), true];
                        _u setVariable [QGVAR(taktikKilit), time + 60];
                        _u doMove _pt;
                    };
                    ([_g, _u] call _iptal) || {(_u distance2D _pt) <= 6} || {time > _vBit}
                };
                if !([_g, _u] call _iptal) then {
                    private _bit = time + _sure;
                    private _sonAtis = 0;
                    while {time < _bit && {!([_g, _u] call _iptal)} && {alive _p}} do {
                        if (time > _sonAtis) then {
                            private _kp = ((_u targetKnowledge _p) select 6);
                            if (_kp isEqualType [] && {(count _kp) >= 2} && {_kp isNotEqualTo [0, 0, 0]}) then {
                                _u doSuppressiveFire [_kp select 0, _kp select 1, 1];
                            };
                            _sonAtis = time + 6 + (random 4);
                        };
                        sleep 1;
                    };
                };
                if (alive _u) then {
                    _u setVariable [QGVAR(yemBirim), nil];
                    _u setVariable [QGVAR(forceMove), nil];
                    _u setVariable [QGVAR(taktikKilit), nil];
                    _u doWatch objNull;
                    if (!isNull _g && {!(_g getVariable [QGVAR(isRetreating), false])}) then { [_u, leader _g] call FUNC(doFollowGuvenli); };
                };
                _say set ["bitti", (_say getOrDefault ["bitti", 0]) + 1];
            };
        } forEach allGroups;
    };
};
true
