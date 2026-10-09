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
 *   BOSTA-HAREKET    : temas > 30 sn yok, lider duruyor ama >= 2 asker yuruyor (> 10 sn)  -> formasyonda surekli hareket suphesi (gorev / buddy / rol istasyonu zamanlari ile)
 *   FORMASYON-FELC   : temas var + LINE / COLUMN / FILE / ECH formasyonunda >= %70 asker ayakta ve duruyor (> 20 sn) -> formasyon felci suphesi
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
                // bayrak KUMESI degisirse (BND+TAK -> TAK, BND+TAK -> RET+TAK ...) sure sifirlanir: uzun ama canli catisma takili sayilmaz
                if ((_g getVariable [QGVAR(saglikBayrakS), ""]) isNotEqualTo _bStr) then { _g setVariable [QGVAR(saglikBayrakS), _bStr]; _g setVariable [QGVAR(saglikBayrakT), time]; };
                if ((_g getVariable [QGVAR(saglikBayrakT), -1]) < 0) then { _g setVariable [QGVAR(saglikBayrakT), time]; };
                if ((time - (_g getVariable [QGVAR(saglikBayrakT), time])) > 200) then {
                    ["BAYRAK-TAKILI", _g, format ["bayrak:%1 | %2 sn acik (ayni bayrak kumesi) | %3 kisi | karar:%4 | gorev:%5", _bStr, round (time - (_g getVariable [QGVAR(saglikBayrakT), time])), count _us, _g getVariable [QGVAR(cmdLastDecision), "-"], (leader _g) getVariable [QEGVAR(main,currentTask), "-"]]] call _isaretle;
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
                    // v8.159: AFK / varmis ama komutu silinmemis askerde ayni uyari saatlerce tekrarlanmasin (ilk 120 sn serbest, sonra 300 sn'de bir)
                    private _durS = time - (_u getVariable [QGVAR(saglikMoveT), time]);
                    if (_durS > 15 && {_durS < 120 || {(time - (_u getVariable [QGVAR(saglikYurLogT), -999])) > 300}}) then {
                        _u setVariable [QGVAR(saglikYurLogT), time];
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

            // BOSTA-HAREKET (kullanici: "formasyonda surekli hareket eden AI"): temas >= 30 sn yok, lider duruyor (< 1 km/s) ama >= 2 asker yuruyor (> 3 km/s), > 10 sn
            if (!_bayrakVar && {(_g getVariable [QGVAR(contact), 0]) < (time - 30)} && {(speed _l) < 1}) then {
                private _yuruyen = _us select {_x isNotEqualTo _l && {(speed _x) > 3}};
                if ((count _yuruyen) >= 2) then {
                    if ((_g getVariable [QGVAR(saglikBostaT), -1]) < 0) then { _g setVariable [QGVAR(saglikBostaT), time]; };
                    if ((time - (_g getVariable [QGVAR(saglikBostaT), time])) > 10) then {
                        ["BOSTA-HAREKET", _g, (format ["%1 / %2 asker yuruyor, lider duruyor | formasyon:%3 beh:%4 | gorevler:%5 | buddy son:%6 sn once | rol istasyonu son:%7 sn once", count _yuruyen, count _us, formation _g, behaviour _l, (_yuruyen apply {_x getVariable [QEGVAR(main,currentTask), "-"]}) select [0, 3 min (count _yuruyen)], round (time - (_g getVariable [QGVAR(buddyLast), -999])), round (time - ((_yuruyen select 0) getVariable [QGVAR(stationLast), -999]))])
                            // v8.70 tani: yuruyen asker slota mi (formasyon) yoksa script emrine mi gidiyor?
                            + (format [" | ilk yuruyen:%1 mod:%2 hedefe:%3 m liderden:%4 m | formasyon degisim:%5 sn once, formDir:%6 sn once, dagilma:%7 sn once, yan:%8, nokta:%9",
                                name (_yuruyen select 0), (expectedDestination (_yuruyen select 0)) select 1, round ((_yuruyen select 0) distance2D ((expectedDestination (_yuruyen select 0)) select 0)), round ((_yuruyen select 0) distance2D _l),
                                round (time - (_g getVariable [QGVAR(cfDegisT), -999])), round (time - (_g getVariable [QGVAR(selFdirT), -999])), round (time - ((_yuruyen select 0) getVariable [QGVAR(dispLast), -999])),
                                !isNil {(_yuruyen select 0) getVariable QGVAR(yanGuv)}, (_yuruyen select 0) getVariable [QGVAR(noktaEk), false]])] call _isaretle;
                    };
                } else {
                    _g setVariable [QGVAR(saglikBostaT), -1];
                };
            } else {
                _g setVariable [QGVAR(saglikBostaT), -1];
            };

            // TELSIZ / REINFORCE TANISI: grup basina bir kez (LAMBS takviye bayragi + telsiz degiskenleri; "dynamic reinforcement calismadi" icin ham veri)
            if (!(_g getVariable [QGVAR(telsizLog), false])) then {
                _g setVariable [QGVAR(telsizLog), true];
                diag_log format ["[TELSIZ-GRUP] %1 | taraf:%2 | enableGroupReinforce:%3 | hasRadio:%4 | disableGroupAI:%5 | grup degiskenleri(reinforce/radio): %6", groupId _g, side _g, _g getVariable ["lambs_danger_enableGroupReinforce", "yok"], _g getVariable ["lambs_danger_dangerRadio", "yok"], _g getVariable [QGVAR(disableGroupAI), false], (allVariables _g) select {(_x find "einforce") >= 0 || {(_x find "adio") >= 0}}];
            };
            // FORMASYON-FELC (kullanici: "form line / column felc ediyor"): temas var, formasyon LINE / COLUMN / FILE / ECH, >= %70 asker AYAKTA ve duruyor (< 0.5 km/s, baski < 0.2), > 20 sn
            if ((_g getVariable [QGVAR(contact), 0]) > time && {!(_g getVariable [QGVAR(isAmbushing), false])} && {(formation _g) in ["LINE", "COLUMN", "FILE", "STAG COLUMN", "ECH LEFT", "ECH RIGHT"]}) then {
                private _atil = _us select {(speed _x) < 0.5 && {(stance _x) isEqualTo "STAND"} && {(getSuppression _x) < 0.2}};
                if ((count _atil) >= ceil ((count _us) * 0.7)) then {
                    if ((_g getVariable [QGVAR(saglikFelcT), -1]) < 0) then { _g setVariable [QGVAR(saglikFelcT), time]; };
                    if ((time - (_g getVariable [QGVAR(saglikFelcT), time])) > 20) then {
                        private _enF = _l findNearestEnemy _l;
                        ["FORMASYON-FELC", _g, format ["formasyon:%1 | %2 / %3 asker ayakta ve duruyor | %4 sn | dusman:%5 m | karar:%6 | bayrak:%7 | gorevler:%8", formation _g, count _atil, count _us, round (time - (_g getVariable [QGVAR(saglikFelcT), time])), if (isNull _enF) then {"-"} else {round (_l distance2D _enF)}, _g getVariable [QGVAR(cmdLastDecision), "-"], _bStr, (_atil apply {_x getVariable [QEGVAR(main,currentTask), "-"]}) select [0, 3 min (count _atil)]]] call _isaretle;
                    };
                } else {
                    _g setVariable [QGVAR(saglikFelcT), -1];
                };
            } else {
                _g setVariable [QGVAR(saglikFelcT), -1];
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
