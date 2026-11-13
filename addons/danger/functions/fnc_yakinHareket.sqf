#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * YAKIN MESAFE HAREKETLILIK (v8.522; kullanici: 'botlar ozellikle yakin mesafede agresif harekete sahip oyuncular icin STATIK HEDEF olmasin').
 * Neden: fnc_siperTut (v8.521) / siper alma / CQB refleksi askeri yerinde durdurur; yakin mesafede (<= 25-40 m) duran asker, hareketli oyuncu icin kolay hedef (AI nisan alip ayni yerde ates ediyor).
 * Bu bekci 0.5 sn'de bir, BILDIGI (knowsAbout >= SEZILDI) dusman yakinda iken (insan oyuncu: <= 40 m, AI: <= 22 m; CBA lambs_danger_yakinHareketM) ve asker DURUYORSA (hiz < 1 km/s; 2 sn'den uzun):
 *   - 'PEEK-STRAFE': dusman dogrultusuna dik +-2 / 3 m yana (ya da 1.5 m geri-yana) kisa kosu: hedef noktasi (a) yol hatti engelsiz (GEOM isini), (b) su yok, (c) tercihen dusman gozunden gizli
 *     (siper kenari: ates edip tekrar gizlenir) ya da 3 m'de sert nesne yakininda; 1.2-2.5 sn sure, hedef secimi / ates ACIK kalir (kosarken ates), varinca comel / ayakta rastgele durus, tekrar 2.5-6 sn sonra.
 *   - Oyuncuya karsi daha sik (2.5 + rastgele 2 sn), AI'ya karsi daha seyrek (4.5 + rastgele 3 sn). Seed'li RNG (fnc_rastgele / birimId).
 * ATLANIR: oyuncu, arac, yaralilar / tibbi, yeniden doldurma, el bombasi, forceMove (bounding kosucusu), geri cekilme, sipere zorla atilisi, LAMBS gorevi / kal-bekle waypoint'li grup (fnc_senaryoKapi 'sabit'),
 *   dusman <= 3 m (yakin dovus: fnc_yakinAtes ates etsin), dost cevresi 1.5 m (yigilma), 3 m'den uzak yol.  siperTut / taktik kilidi bu bekcide ASILIR (yakin mesafede siperde donmak yerine yan adim).
 * Kapatma: lambs_danger_yakinHareket = false.  Log: [YAKIN-HAREKET] (ilk 30) + 60 sn ozeti.
 *
 * Arguments: None
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isNil "lambs_danger_yakinHareketStarted") exitWith {false};
lambs_danger_yakinHareketStarted = true;
diag_log "[YAKIN-HAREKET] yakin mesafe hareketlilik (peek-strafe) baslatildi (v8.522): bilinen dusman <= 22 m (oyuncu 40 m) ve asker duruyorsa kisa yan adim";

[] spawn {
    private _indeks = 0;
    private _say = createHashMapFromArray [["oyuncuya", 0], ["aiya", 0], ["yer_yok", 0]];
    private _logN = 0;
    private _ozetT = time + 60;
    while {true} do {
        sleep 0.5;
        if !(missionNamespace getVariable ["lambs_danger_yakinHareket", true]) then { continue };
        private _menzilAI = missionNamespace getVariable ["lambs_danger_yakinHareketM", 22];
        private _adaylar = allUnits select {
            local _x && {alive _x} && {!isPlayer _x} && {isNull objectParent _x} && {(side group _x) in [west, east, resistance]}
            && {(lifeState _x) in ["HEALTHY", "INJURED"]} && {!captive _x} && {!(_x getVariable [QGVAR(teslim), false])}
            && {(speed _x) < 1} && {time >= (_x getVariable [QGVAR(ykHrkT), 0])} && {(primaryWeapon _x) isNotEqualTo ""}
        };
        private _n = count _adaylar;
        if (_n > 0) then {
            private _kesit = 12 min _n;
            for "_i" from 0 to (_kesit - 1) do {
                private _u = _adaylar select ((_indeks + _i) mod _n);
                private _g = group _u;
                if ((_u getVariable [QGVAR(forceMove), false]) isEqualTo true || {(_u getVariable [QGVAR(zorlaBitis), 0]) > time} || {time < (_u getVariable [QGVAR(tcccBusy), 0])}
                    || {(_u getVariable [QGVAR(reloadState), []]) isNotEqualTo []} || {(_u getVariable [QGVAR(grState), []]) isNotEqualTo []}
                    || {_g getVariable [QGVAR(isRetreating), false]} || {_g getVariable [QGVAR(isBreakingContact), false]}) then { continue };
                // taktik kilidi yalniz siperTut'tan kaynakliysa asilir (baska emir / kosu kilidi korunur)
                if ((_u getVariable [QGVAR(taktikKilit), 0]) > time && {(_u getVariable [QGVAR(siperTutBit), 0]) <= time}) then { continue };
                if ([_g, "yakinHareket", true] call FUNC(senaryoKapi)) then { continue };
                private _e = _u findNearestEnemy _u;
                if (isNull _e || {!alive _e} || {!(_e isKindOf "CAManBase")} || {captive _e} || {(lifeState _e) in ["INCAPACITATED", "UNCONSCIOUS"]}) then { continue };
                private _oyuncu = isPlayer _e;
                private _d = _u distance2D _e;
                if (_d < 3 || {_d > ([_menzilAI, _menzilAI * 1.8] select _oyuncu)}) then { continue };
                if ((_u knowsAbout _e) < (["SEZILDI"] call FUNC(bilgiEsik))) then { continue };
                // en az 2 sn'dir duruyor mu
                private _dur = _u getVariable [QGVAR(ykDurT), -1];
                if (_dur < 0) then { _u setVariable [QGVAR(ykDurT), time]; continue };
                if ((time - _dur) < 2) then { continue };
                // seed'li rastgele: bekleme ve yon
                private _bid = [_u] call FUNC(birimId);
                private _r1 = ["yakinHareketYon", _bid] call FUNC(rastgele);
                private _r2 = ["yakinHareketSure", _bid] call FUNC(rastgele);
                _u setVariable [QGVAR(ykHrkT), time + ([4.5 + (_r2 * 3), 2.5 + (_r2 * 2)] select _oyuncu)];
                _u setVariable [QGVAR(ykDurT), -1];
                // aday noktalar: dusman dogrultusuna dik +-3 / +-2 m, geri-yan 1.5 m
                private _yon = _u getDir _e;
                private _ilk = [90, -90] select (_r1 < 0.5);
                private _adayYon = [[_yon + _ilk, 3], [_yon - _ilk, 3], [_yon + _ilk, 2], [_yon - _ilk, 2], [_yon + (_ilk * 0.6) + 180, 1.5]];
                private _eASL = eyePos _e;
                private _u06 = (getPosASL _u) vectorAdd [0, 0, 0.6];
                private _en = [];
                private _enP = -999;
                {
                    _x params ["_ay", "_mes"];
                    private _p = _u getPos [_mes, _ay];
                    _p set [2, 0];
                    if (!surfaceIsWater _p) then {
                        private _pASL = AGLToASL [_p select 0, _p select 1, 0];
                        // (a) yol: GEOM isini engelsiz
                        if ((lineIntersectsSurfaces [_u06, _pASL vectorAdd [0, 0, 0.6], _u, objNull, true, 1, "GEOM", "NONE"]) isEqualTo []) then {
                            // (b) dost yigilma: 1.5 m icinde baska dost yok
                            if (((_u nearEntities ["CAManBase", 5]) findIf {_x isNotEqualTo _u && {(_x distance2D _p) < 1.5}}) < 0) then {
                                private _puan = 0;
                                // gizli (siper kenari) tercih: dusman gozunden 1.0 m yukseklikte hat kesiliyorsa +5
                                if ((lineIntersectsSurfaces [_eASL, _pASL vectorAdd [0, 0, 1.0], _e, _u, true, 1, "FIRE", "NONE"]) isNotEqualTo [] || {terrainIntersectASL [_eASL, _pASL vectorAdd [0, 0, 1.0]]}) then { _puan = _puan + 5; };
                                if ((nearestTerrainObjects [_p, ["TREE", "WALL", "ROCK", "BUILDING", "HIDE", "BUSH"], 3, false, true]) isNotEqualTo []) then { _puan = _puan + 2; };
                                _puan = _puan - (_mes * 0.3);
                                if (_puan > _enP) then { _enP = _puan; _en = _p; };
                            };
                        };
                    };
                } forEach _adayYon;
                if (_en isEqualTo []) then { _say set ["yer_yok", (_say get "yer_yok") + 1]; continue };
                _say set [["aiya", "oyuncuya"] select _oyuncu, (_say get (["aiya", "oyuncuya"] select _oyuncu)) + 1];
                _u setVariable [QGVAR(siperTutBit), 0];
                _u setVariable [QGVAR(taktikKilit), time + 2.8];
                _u forceSpeed -1;
                _u setSpeedMode "FULL";
                _u setUnitPosWeak (["UP", "MIDDLE"] select (_r2 < 0.5));
                _u doMove _en;
                _u doWatch _e;
                if (_logN < 30) then {
                    _logN = _logN + 1;
                    diag_log format ["[YAKIN-HAREKET] %1 | %2 | dusman %3 (%4) %5 m | yan adim %6 m (%7)", groupId _g, name _u, name _e, ["AI", "OYUNCU"] select _oyuncu, round _d, (_u distance2D _en) toFixed 1, ["acik", "GIZLI nokta"] select (_enP >= 3)];
                };
                [{
                    params ["_uu", "_pp"];
                    !alive _uu || {(_uu distance2D _pp) < 1}
                }, {
                    params ["_uu", "_pp", "_ee"];
                    if (alive _uu) then {
                        _uu setVariable [QGVAR(taktikKilit), 0];
                        if (!isNull _ee && {alive _ee}) then { _uu doWatch _ee; };
                        doStop _uu;
                    };
                }, [_u, _en, _e], 2.8, {
                    params ["_uu", "_pp", "_ee"];
                    if (alive _uu) then { _uu setVariable [QGVAR(taktikKilit), 0]; };
                }] call CBA_fnc_waitUntilAndExecute;
            };
            _indeks = _indeks + _kesit;
        };
        if (time > _ozetT) then {
            _ozetT = time + 60;
            if (((_say get "oyuncuya") + (_say get "aiya") + (_say get "yer_yok")) > 0) then {
                diag_log format ["[YAKIN-HAREKET-OZET] 60 sn: yan adim oyuncuya karsi %1 | AI'ya karsi %2 | uygun nokta yok %3", _say get "oyuncuya", _say get "aiya", _say get "yer_yok"];
            };
            { _say set [_x, 0]; } forEach ["oyuncuya", "aiya", "yer_yok"];
        };
    };
};
true
