#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * KOMUTAN FORMASYON ZEKASI — bounding disinda de calisan watchdog (5 sn'de bir, yerel AI gruplari).
 *
 *   TEMASTA : fnc_selectFormation "COMBAT" baglami (komutan durum raporu: mesafe / dusman gucu / MG / zirh /
 *             kayip / arazi) formasyonu ve formasyon yonunu (dusmana) secer. Degisim en az 25 sn arayla.
 *   TEMAS BITTI (25 sn sonra): COMBAT'ta takili kalan davranis AWARE'e, formasyon "TRAVEL" baglamina
 *             (yol / orman / acik) doner — arazi taramasindan sonra ebedi COMBAT / kolon kalmaz.
 *   ATLANIR : oyuncu lider, < 3 asker, arac ekibi, retreat / peel / evade / breakContact / bounding / keskin nisanci / disableGroupAI.
 *
 * Arguments:
 * None
 *
 * Return Value:
 * Baslatildi mi <BOOL>
 *
 * Public: No
*/

if (!isNil "lambs_danger_commanderFormationStarted") exitWith {false};
lambs_danger_commanderFormationStarted = true;

diag_log "[KOMUTAN-FORM] komutan formasyon zekasi watchdog baslatildi (temasta COMBAT analizi, temas bitince TRAVEL)";

[] spawn {
    while {true} do {
        sleep 5;
        {
            private _g = _x;
            private _l = leader _g;
            if (isNull _l || {isPlayer _l} || {!local _l}) then { continue };
            if ((count (units _g)) < 3) then { continue };
            if (
                (_g getVariable [QGVAR(isRetreating), false]) || {_g getVariable [QGVAR(isPeeling), false]}
                || {_g getVariable [QGVAR(isEvading), false]} || {_g getVariable [QGVAR(isBreakingContact), false]}
                || {_g getVariable [QGVAR(isBounding), false]} || {_g getVariable [QGVAR(sniperTeam), false]}
                || {_g getVariable [QGVAR(disableGroupAI), false]}
            ) then { continue };
            if (!isNull objectParent _l) then { continue };

            // v8.45: GERCEK formasyon degisimi izleyicisi (kim cevirdi? RPT 879966ca: ASSAULT'ta LINE <-> STAG COLUMN her ~20 sn = 'formasyon felci')
            private _formSimdi = formation _g;
            private _formOnce = _g getVariable [QGVAR(cfIzle), ""];
            if (_formOnce isNotEqualTo "" && {_formSimdi isNotEqualTo _formOnce}) then {
                _g setVariable [QGVAR(cfDegisT), time];
                if (isNil "lambs_danger_formDegN") then { lambs_danger_formDegN = 0; };
                if (lambs_danger_formDegN < 200) then {
                    lambs_danger_formDegN = lambs_danger_formDegN + 1;
                    diag_log format ["[FORM-DEGISIM] %1 | %2 -> %3 | karar:%4 (%5 sn once) | komutan-son:%6 sn once", groupId _g, _formOnce, _formSimdi, _g getVariable [QGVAR(cmdLastDecision), "-"], round (time - (_g getVariable [QGVAR(cmdSonKararZaman), -999])), round (time - (_g getVariable [QGVAR(cfSon), -999]))];
                };
            };
            _g setVariable [QGVAR(cfIzle), _formSimdi];

            // v8.45: LAMBS taktigi (ASSAULT / FLANK / SUPPRESS / DELAY / HOLD) kendi formasyonunu (tacticsAssault: LINE) verir; komutan 60 sn karismaz,
            //   ve herhangi bir formasyon degisiminden sonra 60 sn yeni degisiklik yapmaz (her setFormation askerleri yeni slota kosturur)
            if (((_g getVariable [QGVAR(cmdLastDecision), ""]) in ["ASSAULT", "FLANK", "SUPPRESS_ASSAULT", "DELAY", "HOLD"]) && {(time - (_g getVariable [QGVAR(cmdSonKararZaman), -999])) < 60}) then { continue };
            if ((time - (_g getVariable [QGVAR(cfDegisT), -999])) < 60) then { continue };

            private _contact = _g getVariable [QGVAR(contact), 0];
            private _sonKarar = _g getVariable [QGVAR(cfSon), -999];

            if (_contact > time) then {
                // v8.38: 25 sn aralik (baslikta da oyle) + ates altindaki / bastirilmis grupta formasyona dokunma (slota kosma = etkisizlik)
                if ((time - _sonKarar) > 25 && {((units _g) findIf {alive _x && {(getSuppression _x) >= 0.3}}) < 0}) then {
                    _g setVariable [QGVAR(cfSon), time];
                    private _f = [_g, [0, 0, 0], "COMBAT"] call (missionNamespace getVariable ["lambs_danger_fnc_selectFormation", {""}]);
                    if (_f isNotEqualTo "" && {(formation _g) isNotEqualTo _f}) then {
                        _g setFormation _f;
                        diag_log format ["[KOMUTAN-FORM] %1 | TEMAS | formasyon -> %2", groupId _g, _f];
                    };
                };
            } else {
                // temas bitti: 25 sn sonra COMBAT'tan cik, intikal formasyonu
                if ((time - _contact) > 25 && {(time - _sonKarar) > 20} && {_contact > 0}) then {
                    _g setVariable [QGVAR(cfSon), time];
                    if ((behaviour _l) in ["COMBAT", "STEALTH"] && {!(_g getVariable [QGVAR(isExecutingTactic), false])}) then {
                        _g setBehaviour "AWARE";
                        diag_log format ["[KOMUTAN-FORM] %1 | temas bitti -> AWARE", groupId _g];
                    };
                    private _f = [_g, [0, 0, 0], "TRAVEL"] call (missionNamespace getVariable ["lambs_danger_fnc_selectFormation", {""}]);
                    if (_f isNotEqualTo "" && {(formation _g) isNotEqualTo _f}) then {
                        _g setFormation _f;
                        diag_log format ["[KOMUTAN-FORM] %1 | SAKIN | formasyon -> %2", groupId _g, _f];
                    };
                };
            };
        } forEach (allGroups select {local _x && {!isNull leader _x}});
    };
};

true
