#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * SAGLIK / ANOMALI IZLEYICISI — RPT'yi rahat okumak icin: sorunlar ayri bir etiketle ([ANOMALI]) kendini ISARETLER.
 *
 * Her 5 sn'de yerel, oyuncusuz AI gruplari taranir; kosullar tutarsa [ANOMALI] kod | grup | detay (ayni anahtar 60 sn'de bir kez):
 *   BAYRAK-TAKILI    : taktik bayragi (RET/BND/EVD/BRK/AMB/TAK) > 200 sn acik
 *   AI-KAPALI-SIZINTI: grup lambs disableGroupAI acik ama taktik bayragi yok, > 20 sn   (retreat / pusu kalintisi)
 *   BIRIM-AI-KAPALI  : birim lambs_danger_disableAI acik ama grupta taktik bayragi yok, > 20 sn
 *   KILIT-UZUN       : birimin taktikKilit'i 40 sn'den uzun
 *   YURUMUYOR        : komut MOVE ama hiz < 0.8 km/s, > 15 sn (ezilmis / baski >= 0.85 haric)
 *   LIDER-YALNIZ     : lider en yakin astindan > 80 m, > 10 sn
 *   GRUP-EZILMIS     : askerlerin >= %50'si baski >= 0.85, > 10 sn
 *   TEMAS-YOK-COMBAT : temas > 60 sn yok ama lider COMBAT ve taktik bayragi yok (uzun sure COMBAT'ta kalma)
 * Her 60 sn: [SAGLIK] ozet satiri (grup / asker sayisi, anomali sayilari). Kapatma: lambs_danger_saglikOff = true.
 *
 * Arguments: None
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isNil "lambs_danger_saglikStarted") exitWith {false};
lambs_danger_saglikStarted = true;

diag_log "[SAGLIK] saglik / anomali izleyicisi baslatildi";

[] spawn {
    private _sonOzet = time;
    private _sayac = createHashMap;
    private _sonLog = createHashMap;
    private _isaretle = {
        params ["_kod", "_g", "_detay"];
        private _anahtar = format ["%1|%2", _kod, groupId _g];
        if ((time - (_sonLog getOrDefault [_anahtar, -999])) < 60) exitWith {};
        _sonLog set [_anahtar, time];
        _sayac set [_kod, (_sayac getOrDefault [_kod, 0]) + 1];
        diag_log format ["[ANOMALI] %1 | %2 | %3", _kod, groupId _g, _detay];
    };

    while {true} do {
        sleep 5;
        if (missionNamespace getVariable ["lambs_danger_saglikOff", false]) then { continue };
        private _gSay = 0;
        private _uSay = 0;

        {
            private _g = _x;
            if (isNull _g || {!local _g} || {(side _g) isEqualTo civilian}) then { continue };
            if ((units _g) findIf {isPlayer _x} > -1) then { continue };
            private _us = (units _g) select {alive _x && {isNull objectParent _x}};
            if (_us isEqualTo []) then { continue };
            _gSay = _gSay + 1;
            _uSay = _uSay + (count _us);
            private _l = leader _g;
            if (isNull _l || {!alive _l}) then { continue };

            private _bayrakAd = [];
            {
                if (_g getVariable [_x select 0, false]) then { _bayrakAd pushBack (_x select 1); };
            } forEach [
                [QGVAR(isRetreating), "RET"], [QGVAR(isBounding), "BND"], [QGVAR(isEvading), "EVD"], [QGVAR(isBreakingContact), "BRK"],
                [QGVAR(isAmbushing), "AMB"], [QGVAR(isExecutingTactic), "TAK"], [QGVAR(isATEngage), "ATE"]
            ];
            private _bayrakVar = _bayrakAd isNotEqualTo [];
            private _bStr = _bayrakAd joinString "+";

            // BAYRAK-TAKILI
            if (_bayrakVar) then {
                if ((_g getVariable [QGVAR(saglikBayrakT), -1]) < 0) then { _g setVariable [QGVAR(saglikBayrakT), time]; };
                if ((time - (_g getVariable [QGVAR(saglikBayrakT), time])) > 200) then {
                    ["BAYRAK-TAKILI", _g, format ["bayrak:%1 | %2 sn acik | %3 kisi", _bStr, round (time - (_g getVariable [QGVAR(saglikBayrakT), time])), count _us]] call _isaretle;
                };
            } else {
                _g setVariable [QGVAR(saglikBayrakT), -1];
            };

            // AI-KAPALI-SIZINTI (grup)
            if (!_bayrakVar && {_g getVariable [QGVAR(disableGroupAI), false]}) then {
                if ((_g getVariable [QGVAR(saglikDgaT), -1]) < 0) then { _g setVariable [QGVAR(saglikDgaT), time]; };
                if ((time - (_g getVariable [QGVAR(saglikDgaT), time])) > 20) then {
                    ["AI-KAPALI-SIZINTI", _g, format ["disableGroupAI acik, tactik bayragi yok | %1 sn", round (time - (_g getVariable [QGVAR(saglikDgaT), time]))]] call _isaretle;
                };
            } else {
                _g setVariable [QGVAR(saglikDgaT), -1];
            };

            // BIRIM-AI-KAPALI
            private _dai = _us select {_x getVariable [QGVAR(disableAI), false]};
            if (!_bayrakVar && {_dai isNotEqualTo []}) then {
                if ((_g getVariable [QGVAR(saglikDaiT), -1]) < 0) then { _g setVariable [QGVAR(saglikDaiT), time]; };
                if ((time - (_g getVariable [QGVAR(saglikDaiT), time])) > 20) then {
                    ["BIRIM-AI-KAPALI", _g, format ["%1 / %2 birimde disableAI acik: %3", count _dai, count _us, (_dai apply {name _x}) select [0, 3]]] call _isaretle;
                };
            } else {
                _g setVariable [QGVAR(saglikDaiT), -1];
            };

            // KILIT-UZUN / YURUMUYOR / LIDER-YALNIZ
            private _ezilmis = 0;
            {
                private _u = _x;
                private _kilit = (_u getVariable [QGVAR(taktikKilit), 0]) - time;
                if (_kilit > 40) then {
                    ["KILIT-UZUN", _g, format ["%1 | kilit %2 sn kaldi | bayrak:%3", name _u, round _kilit, _bStr]] call _isaretle;
                };
                private _bsk = getSuppression _u;
                if (_bsk >= 0.85) then { _ezilmis = _ezilmis + 1; };
                if ((currentCommand _u) isEqualTo "MOVE" && {(speed _u) < 0.8} && {_bsk < 0.85}) then {
                    if ((_u getVariable [QGVAR(saglikMoveT), -1]) < 0) then { _u setVariable [QGVAR(saglikMoveT), time]; };
                    if ((time - (_u getVariable [QGVAR(saglikMoveT), time])) > 15) then {
                        ["YURUMUYOR", _g, format ["%1 | MOVE komutu ama %2 sn duruyor | gorev:%3 | stance:%4 | bayrak:%5 | fm:%6", name _u, round (time - (_u getVariable [QGVAR(saglikMoveT), time])), _u getVariable [QEGVAR(main,currentTask), "-"], stance _u, _bStr, _u getVariable [QGVAR(forceMove), false]]] call _isaretle;
                    };
                } else {
                    _u setVariable [QGVAR(saglikMoveT), -1];
                };
            } forEach _us;

            if ((count _us) > 1) then {
                private _komsu = 9999;
                { if (_x isNotEqualTo _l) then { _komsu = _komsu min (_l distance2D _x); }; } forEach _us;
                if (_komsu > 80) then {
                    if ((_g getVariable [QGVAR(saglikLiderT), -1]) < 0) then { _g setVariable [QGVAR(saglikLiderT), time]; };
                    if ((time - (_g getVariable [QGVAR(saglikLiderT), time])) > 10) then {
                        ["LIDER-YALNIZ", _g, format ["%1 (lider) en yakin asttan %2 m | gorev:%3 | bayrak:%4", name _l, round _komsu, _l getVariable [QEGVAR(main,currentTask), "-"], _bStr]] call _isaretle;
                    };
                } else {
                    _g setVariable [QGVAR(saglikLiderT), -1];
                };
            };

            // GRUP-EZILMIS
            if (_ezilmis >= ceil ((count _us) * 0.5) && {_ezilmis > 0}) then {
                if ((_g getVariable [QGVAR(saglikEzT), -1]) < 0) then { _g setVariable [QGVAR(saglikEzT), time]; };
                if ((time - (_g getVariable [QGVAR(saglikEzT), time])) > 10) then {
                    private _en = _l findNearestEnemy _l;
                    ["GRUP-EZILMIS", _g, format ["%1 / %2 asker baski>=0.85 | %3 sn | dusman:%4 m | bayrak:%5", _ezilmis, count _us, round (time - (_g getVariable [QGVAR(saglikEzT), time])), if (isNull _en) then {"-"} else {round (_l distance2D _en)}, _bStr]] call _isaretle;
                };
            } else {
                _g setVariable [QGVAR(saglikEzT), -1];
            };

            // TEMAS-YOK-COMBAT
            if (!_bayrakVar && {(_g getVariable [QGVAR(contact), 0]) < (time - 60)} && {(behaviour _l) isEqualTo "COMBAT"}) then {
                ["TEMAS-YOK-COMBAT", _g, format ["temas %1 sn once bitti ama lider COMBAT | combatMode:%2 | formasyon:%3", round (time - (_g getVariable [QGVAR(contact), 0])), combatMode _g, formation _g]] call _isaretle;
            };
        } forEach allGroups;

        if ((time - _sonOzet) >= 60) then {
            _sonOzet = time;
            diag_log format ["[SAGLIK] t=%1 | yerel AI grup:%2 asker:%3 | anomali (60 sn): %4", round time, _gSay, _uSay, if ((count _sayac) isEqualTo 0) then {"yok"} else {(keys _sayac) apply {format ["%1=%2", _x, _sayac get _x]}}];
            _sayac = createHashMap;
        };
    };
};

true
