#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * SAHTE GERI CEKILME + ALAN HAKIMIYETI (v8.693; kullanici: 'sahte geri cekilmede ekle ve bunu alan hakimiyeti ile iliskilendir, oyuncu squadini kotu araziye ceksin').
 * Yalniz INSAN OYUNCU hedeflere karsi. Hakim / ustun durumdaki (>= sahteMinAsker saglam asker, ort. baski < 0.4) yerel AI grubu, oyuncuyu bilirken (sahteMenzilMin - sahteMenzilMax):
 *   1) ARKA YER: fnc_avantajliYer 'SAVUNMA' (yukseklik + koy / ev + atis alani kapsami, esik 38) ile gruptan 150 m icinde, oyuncudan EN AZ 25 m daha UZAK bir 'mis gibi' savunma noktasi bulunur;
 *   2) KOTU ARAZI (oyuncu icin): oyuncu -> savunma noktasi yaklasma hattinda 8 ornek; ornek savunma noktasindan (yatik goz) GORUNUR ve ACIK (7 m'de sert nesne yok) ise 'olum alani'. Oran >= sahteKotuArazi (0.5) degilse sahte cekilme YAPILMAZ (cekilmenin anlami yok);
 *   3) GOZETLEME (alan hakimiyeti): sahteGozcuN (2) asker (once MG, sonra tufekli) fnc_hakimNokta ile hakim noktaya gecer / yerinde kalir ve oyuncuyu bekler (cekilmez);
 *   4) SAHTE CEKILME: kalan asker (lider dahil) savunma noktasina KOSAR (gorunur geri cekilme, forceMove + kilit, tehdit yonune dik hat, 5 m aralik); >= %70 varinca (en cok 45 sn) donup dusmana yonelir (COMBAT, doWatch) = kuruyuz;
 *   5) sahteSure (75 sn) bekler (oyuncu oluyse / grup kayip verirse / baski >= 0.7 / geri cekilme-temas kes baslarsa ERKEN biter); sonra kilitler birakilir, gozetlemeciler doFollowGuvenli ile gruba doner.
 *   Surec boyunca grup 'isExecutingTactic' (baska taktik baslamaz; en gec +150 sn guvenlik agi ile temizlenir). Grup basina sahteBekle (300 sn) bekleme, her uygun denemede sahteSans (0.5) olasilik.
 * CBA: lambs_danger_sahteCekilme (varsayilan KAPALI), sahteMinAsker, sahteMenzilMin, sahteMenzilMax, sahteKotuArazi, sahteBekle, sahteGozcuN, sahteSans, sahteSure. Log: [SAHTE-CEKILME] (ilk 25) + [SAHTE-CEKILME-OZET] 60 sn.
 *
 * Arguments: None
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isNil "lambs_danger_sahteStarted") exitWith {false};
lambs_danger_sahteStarted = true;
diag_log "[SAHTE-CEKILME] sahte geri cekilme + alan hakimiyeti (oyuncuyu kotu araziye cek) baslatildi (v8.693)";

[] spawn {
    private _logN = 0;
    private _say = createHashMapFromArray [["basladi", 0], ["bitti", 0], ["yerYok", 0], ["geriDegil", 0], ["kotuAraziYok", 0], ["gozcuYok", 0], ["sans", 0], ["hBayrak", 0], ["hSahip", 0], ["hBina", 0], ["hAskerAz", 0], ["hBaski", 0], ["hHedefYok", 0], ["hYakin", 0]];
    private _ozetT = time + 60;
    private _rolFn = missionNamespace getVariable ["lambs_danger_fnc_getUnitRole", {"RIFLE"}];
    while {true} do {
        sleep 5;
        if (time > _ozetT) then {
            _ozetT = time + 60;
            private _top = 0;
            { _top = _top + (_say get _x); } forEach (keys _say);
            if (_top > 0) then { diag_log format ["[SAHTE-CEKILME-OZET] 60 sn: basladi %1 | bitti %2 | ret nedenleri: arka yer yok %3, geri degil %4, kotu arazi yetersiz %5, gozetleyici yok %6, sans tutmadi %7 | HUNI (temasli grup-tur, v8.722): baska taktik / geri cekilme bayragi %8, LAMBS-TUTAN sahipli %9, binada %10, asker az (< %15) %11, baski >= 0.4 %12, oyuncu hedef yok (<= %16 m) %13, oyuncu < %17 m %14", _say get "basladi", _say get "bitti", _say get "yerYok", _say get "geriDegil", _say get "kotuAraziYok", _say get "gozcuYok", _say get "sans", _say get "hBayrak", _say get "hSahip", _say get "hBina", _say get "hAskerAz", _say get "hBaski", _say get "hHedefYok", _say get "hYakin", ((missionNamespace getVariable ["lambs_danger_sahteMinAsker", 6]) max 4) min 16, ((missionNamespace getVariable ["lambs_danger_sahteMenzilMax", 400]) max 170) min 700, ((missionNamespace getVariable ["lambs_danger_sahteMenzilMin", 120]) max 80) min 300]; };
            { _say set [_x, 0]; } forEach (keys _say);
        };
        if !(missionNamespace getVariable ["lambs_danger_sahteCekilme", false]) then { continue };
        private _minA = ((missionNamespace getVariable ["lambs_danger_sahteMinAsker", 6]) max 4) min 16;
        private _mMin = ((missionNamespace getVariable ["lambs_danger_sahteMenzilMin", 120]) max 80) min 300;
        private _mMax = ((missionNamespace getVariable ["lambs_danger_sahteMenzilMax", 400]) max (_mMin + 50)) min 700;
        private _kotuE = ((missionNamespace getVariable ["lambs_danger_sahteKotuArazi", 0.5]) max 0) min 1;
        private _bekle = ((missionNamespace getVariable ["lambs_danger_sahteBekle", 300]) max 60) min 900;
        private _owN = ((missionNamespace getVariable ["lambs_danger_sahteGozcuN", 2]) max 1) min 3;
        private _sans = ((missionNamespace getVariable ["lambs_danger_sahteSans", 0.5]) max 0) min 1;
        private _sure = ((missionNamespace getVariable ["lambs_danger_sahteSure", 75]) max 30) min 180;
        private _n = 0;
        {
            private _g = _x;
            if (_n >= 4) exitWith {};
            private _l = leader _g;
            if (isNull _l || {!local _g} || {isPlayer _l} || {!alive _l} || {!isNull objectParent _l}) then { continue };
            if (time < (_g getVariable [QGVAR(sahteT), 0])) then { continue };
            if (([_g] call FUNC(temasSeviye)) > 2) then { continue };
            // v8.722 HUNI: kapilar ayri ayri sayilir (sahte cekilme 111 RPT'de hic baslamadi; hangi kapida elendigi bilinmiyordu)
            if (
                (_g getVariable [QGVAR(isRetreating), false]) || {_g getVariable [QGVAR(isEvading), false]} || {_g getVariable [QGVAR(isBreakingContact), false]}
                || {_g getVariable [QGVAR(isBounding), false]} || {_g getVariable [QGVAR(isExecutingTactic), false]} || {_g getVariable [QGVAR(isSweeping), false]}
                || {_g getVariable [QGVAR(isAmbushing), false]} || {_g getVariable [QGVAR(sniperTeam), false]}
            ) then { _say set ["hBayrak", (_say get "hBayrak") + 1]; continue };
            if (([_g] call FUNC(wpSahip)) in ["LAMBS", "TUTAN"]) then { _say set ["hSahip", (_say get "hSahip") + 1]; continue };
            if ((insideBuilding _l) > 0.5) then { _say set ["hBina", (_say get "hBina") + 1]; continue };
            private _us = (units _g) select {alive _x && {isNull objectParent _x} && {!isPlayer _x} && {(lifeState _x) in ["HEALTHY", "INJURED"]}};
            if ((count _us) < _minA) then { _say set ["hAskerAz", (_say get "hAskerAz") + 1]; continue };
            private _bsk = 0;
            { _bsk = _bsk + (getSuppression _x); } forEach _us;
            if ((_bsk / (count _us)) >= 0.4) then { _say set ["hBaski", (_say get "hBaski") + 1]; continue };
            private _hedef = (_l targets [true, _mMax, [], 60]) select {alive _x && {(isPlayer _x) || {((crew _x) findIf {isPlayer _x}) >= 0}}};
            if (_hedef isEqualTo []) then { _say set ["hHedefYok", (_say get "hHedefYok") + 1]; continue };
            _n = _n + 1;
            _hedef = [_hedef, [], {_l distance2D _x}, "ASCEND"] call BIS_fnc_sortBy;
            private _p = _hedef select 0;
            private _d = _l distance2D _p;
            if (_d < _mMin) then { _say set ["hYakin", (_say get "hYakin") + 1]; continue };
            _g setVariable [QGVAR(sahteT), time + 45];   // bir sonraki bakis (sans / ret sonrasi)
            if ((random 1) > _sans) then { _say set ["sans", (_say get "sans") + 1]; continue };

            // 1) arka yer
            private _tpos = getPosATL _p;
            private _lpos = getPosATL _l;
            private _yer = [_lpos, _tpos, 150, "SAVUNMA", 38, 12] call FUNC(avantajliYer);
            if (_yer isEqualTo []) then { _say set ["yerYok", (_say get "yerYok") + 1]; continue };
            private _yp = _yer select 0;
            if ((_yp distance2D _tpos) < ((_lpos distance2D _tpos) + 25)) then { _say set ["geriDegil", (_say get "geriDegil") + 1]; continue };

            // 2) kotu arazi (oyuncu icin): yaklasma hatti ornekleri savunma noktasindan gorunur + acik mi
            private _ypA = AGLToASL (_yp vectorAdd [0, 0, 0.45]);
            private _dyp = _tpos distance2D _yp;
            private _dir = _tpos getDir _yp;
            private _kotuSay = 0;
            private _alcak = 0;
            for "_i" from 1 to 8 do {
                private _s = _tpos getPos [_dyp * (_i / 9), _dir];
                private _sA = AGLToASL (_s vectorAdd [0, 0, 1]);
                private _gor = !(terrainIntersectASL [_ypA, _sA]) && {!(lineIntersects [_ypA, _sA, objNull, objNull])};
                private _acik = (nearestTerrainObjects [_s, ["TREE", "ROCK", "ROCKS", "WALL", "BUILDING", "HOUSE", "HIDE"], 7, false, true]) isEqualTo [];
                if (_gor && {_acik}) then {
                    _kotuSay = _kotuSay + 1;
                    if ((getTerrainHeightASL _s) <= ((getTerrainHeightASL _yp) - 1)) then { _alcak = _alcak + 1; };
                };
            };
            private _oran = _kotuSay / 8;
            if (_oran < _kotuE) then { _say set ["kotuAraziYok", (_say get "kotuAraziYok") + 1]; continue };

            // 3) gozetleyiciler (alan hakimiyeti): once MG, sonra tufekli
            private _adaylar = _us select {_x isNotEqualTo _l && {(_x getVariable [QGVAR(forceMove), false]) isNotEqualTo true} && {time > (_x getVariable [QGVAR(taktikKilit), 0])} && {!captive _x}};
            private _mgs = _adaylar select {([_x] call _rolFn) isEqualTo "MG"};
            private _tuf = (_adaylar select {([_x] call _rolFn) isEqualTo "RIFLE"}) apply {[_x distance2D _tpos, _x]};
            _tuf sort true;
            private _ow = (_mgs + (_tuf apply {_x select 1})) select [0, _owN];
            if (_ow isEqualTo [] || {(count _us) - (count _ow) < 2}) then { _say set ["gozcuYok", (_say get "gozcuYok") + 1]; continue };

            _g setVariable [QGVAR(sahteT), time + _bekle + _sure];
            _g setVariable [QGVAR(sahteAktif), true];
            _g setVariable [QGVAR(isExecutingTactic), true];
            _say set ["basladi", (_say get "basladi") + 1];
            private _geri = _us - _ow;
            if (_logN < 25) then {
                _logN = _logN + 1;
                diag_log format ["[SAHTE-CEKILME] %1 | oyuncu %2 (%3 m) | arka nokta gruptan %4 m, oyuncudan %5 m | %6 | kotu arazi orani %7 (alcak ornek %8 / 8) | gozetleyici: %9 | geri cekilen %10 asker | tur %11 sn",
                    groupId _g, name _p, round _d, round (_lpos distance2D _yp), round _dyp, _yer select 2, _oran toFixed 2, _alcak, _ow apply {name _x}, count _geri, _sure];
            };

            [_g, _p, _ow, _geri, _yp, _tpos, _sure, _say, count _us] spawn {
                params ["_g", "_p", "_ow", "_geri", "_yp", "_tpos", "_sure", "_say", "_n0"];
                private _dirT = _yp getDir _tpos;
                private _iptal = {
                    params ["_gg", "_p0", "_n00"];
                    isNull _gg || {isNull (leader _gg)} || {!alive _p0} || {_gg getVariable [QGVAR(isRetreating), false]} || {_gg getVariable [QGVAR(isBreakingContact), false]} || {_gg getVariable [QGVAR(isEvading), false]}
                    || {({alive _x} count (units _gg)) < (_n00 - 2)}
                };
                // gozetleyiciler: hakim noktaya (ya da yerinde) - cekilmezler
                {
                    private _o = _x;
                    if (alive _o) then {
                        _o setVariable [QGVAR(sahteGozcu), true];
                        _o setVariable [QGVAR(taktikKilit), time + _sure + 60];
                        private _rol = if (([_o] call (missionNamespace getVariable ["lambs_danger_fnc_getUnitRole", {"RIFLE"}])) isEqualTo "MG") then { "MG" } else { "MARKSMAN" };
                        private _hn = [_o, _tpos, _rol] call FUNC(hakimNokta);
                        if (_hn isNotEqualTo []) then {
                            _o setVariable [QGVAR(forceMove), true];
                            _o forceSpeed -1;
                            _o setSpeedMode "NORMAL";
                            _o doMove (_hn select 0);
                        };
                    };
                } forEach _ow;
                // sahte geri cekilme: tehdit yonune dik hat, 5 m aralik, gorunur kosu
                private _nG = count _geri;
                private _atanan = [];
                {
                    private _off = (_forEachIndex - ((_nG - 1) / 2)) * 5;
                    private _pt = _yp getPos [abs _off, _dirT + ([90, -90] select (_off < 0))];
                    if (surfaceIsWater _pt) then { _pt = _yp; };
                    _atanan pushBack [_x, _pt];
                } forEach _geri;
                {
                    _x params ["_u", "_pt"];
                    if (alive _u) then {
                        _u setVariable [QGVAR(forceMove), true];
                        _u setVariable [QGVAR(taktikKilit), time + 55];
                        _u forceSpeed -1;
                        _u setSpeedMode "FULL";
                        _u doMove _pt;
                    };
                } forEach _atanan;
                private _bit = time + 45;
                waitUntil {
                    sleep 0.5;
                    ([_g, _p, _n0] call _iptal) || {time > _bit}
                    || {({alive (_x select 0) && {((_x select 0) distance2D (_x select 1)) <= 8}} count _atanan) >= (ceil (0.7 * ({alive (_x select 0)} count _atanan)))}
                };
                private _sebep = "sure doldu";
                if !([_g, _p, _n0] call _iptal) then {
                    // kuruldu: dusmana don, bekle
                    {
                        _x params ["_u", "_pt"];
                        if (alive _u) then {
                            _u setVariable [QGVAR(forceMove), nil];
                            _u setVariable [QGVAR(taktikKilit), nil];
                            _u doWatch (_u getPos [100, _dirT]);
                        };
                    } forEach _atanan;
                    if (!isNull _g) then { _g setFormDir _dirT; _g setBehaviour "COMBAT"; };
                    private _bit2 = time + _sure;
                    waitUntil { sleep 1; ([_g, _p, _n0] call _iptal) || {time > _bit2} };
                    if ([_g, _p, _n0] call _iptal) then { _sebep = "iptal (oyuncu oldu / kayip / geri cekilme-temas kes)"; };
                } else { _sebep = "iptal (oyuncu oldu / kayip / geri cekilme-temas kes) sahte cekilme sirasinda"; };
                // temizlik
                {
                    private _u = _x;
                    if (alive _u) then {
                        _u setVariable [QGVAR(sahteGozcu), nil];
                        _u setVariable [QGVAR(forceMove), nil];
                        _u setVariable [QGVAR(taktikKilit), nil];
                        _u doWatch objNull;
                    };
                } forEach (_ow + _geri);
                if (!isNull _g) then {
                    _g setVariable [QGVAR(sahteAktif), nil];
                    _g setVariable [QGVAR(isExecutingTactic), false];
                    if (!(_g getVariable [QGVAR(isRetreating), false]) && {!isNull (leader _g)}) then {
                        { if (alive _x) then { [_x, leader _g] call FUNC(doFollowGuvenli); }; } forEach (_ow + _geri);
                    };
                };
                _say set ["bitti", (_say getOrDefault ["bitti", 0]) + 1];
                diag_log format ["[SAHTE-CEKILME] %1 | BITTI: %2", (if (isNull _g) then {"-"} else {groupId _g}), _sebep];
            };
            // guvenlik agi: surec ne olursa olsun grup bayragi temizlenir
            [{ params ["_gg"]; if (!isNull _gg && {(_gg getVariable [QGVAR(sahteAktif), false]) isEqualTo true}) then { _gg setVariable [QGVAR(sahteAktif), nil]; _gg setVariable [QGVAR(isExecutingTactic), false]; }; }, [_g], _sure + 150] call CBA_fnc_waitAndExecute;
        } forEach allGroups;
    };
};
true
