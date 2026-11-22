#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * COMBAT'TAN GEVSEME (v8.552; kullanici: 'orman anomalilerini incele'): [ANOMALI] TEMAS-YOK-COMBAT — RPT 04:58: Alpha 1-1 temas bitmesine 63 -> 433 sn gectigi halde lider COMBAT'ta kaldi (10 kayit / oturum).
 * COMBAT'ta asker siperden cikmaz, yavas, sik durur; temassiz uzun COMBAT hareketi / gorevi bozar.
 * KOSUL (5 sn'de bir, yerel AI grup, oyuncusuz): lider COMBAT; temas (_g contact) 120 sn'den eski; son atis sinyali 60 sn'den eski; grup bayraklari yok (bounding / geri cekilme / evade / temas kes / pusu / taktik / AT);
 *   bilinen dusman (SEZILDI) 300 m icinde yok; kacis / siperTut / reload / tibbi islemde asker yok; araca bagli degil; LAMBS gorevi / kal-bekle waypoint'li grup (fnc_senaryoKapi 'sabit') DEGIL.
 * EYLEM: davranis AWARE (silah hazir, ayakta yuruyebilir); combatMode ayni. Grup basina 60 sn'de bir. Kapatma: CBA combatGevset.  Log: [COMBAT-GEVSE] (ilk 20) + 60 sn ozeti.
 *
 * Arguments: None
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isNil "lambs_danger_combatGevsetStarted") exitWith {false};
lambs_danger_combatGevsetStarted = true;
diag_log "[COMBAT-GEVSE] temassiz uzun COMBAT -> AWARE izleyicisi baslatildi (v8.552)";

[] spawn {
    private _logN = 0;
    private _say = 0;
    private _ozetT = time + 60;
    while {true} do {
        sleep ([5, false, false, "combatGevset"] call FUNC(dusunSure));
        if !(missionNamespace getVariable ["lambs_danger_combatGevset", true]) then { continue };
        {
            private _g = _x;
            if (isNull _g || {!local _g} || {isNull (leader _g)} || {isPlayer (leader _g)} || {(side _g) isEqualTo civilian}) then { continue };
            // v8.767 TEMASTA AWARE KALMASIN (kullanici: 'botlar awarede kaldi'; RPT 23929743: 10 / 39 grup ornegi AWARE + temas var, cogu 1 kisilik EAST gruplar, bayrak BRK+TAK ya da bayraksiz, bilinen dusman 164-370 m / bilinmiyor): temas TAZE (son 8 sn) + bilinen dusman (SEZILDI, <= 600 m) + grup
            //   geri cekilme / kacis / temas kes / pusu / sniper / gafil bayragi YOK + lider AWARE ise COMBAT'a alinir (CBA temasCombat). Ilk 20 olay [TEMAS-COMBAT].
            if ((missionNamespace getVariable ["lambs_danger_temasCombat", true]) && {(behaviour (leader _g)) isEqualTo "AWARE"} && {(_g getVariable [QGVAR(contact), 0]) > (time - 8)}
                && {!(_g getVariable [QGVAR(isRetreating), false])} && {!(_g getVariable [QGVAR(isEvading), false])} && {!(_g getVariable [QGVAR(isBreakingContact), false])} && {!(_g getVariable [QGVAR(isAmbushing), false])}
                && {!(_g getVariable [QGVAR(sniperTeam), false])} && {!(_g getVariable [QGVAR(gafilAktif), false])} && {isNil {(leader _g) getVariable QGVAR(koseAktif)}}) then {
                private _le = leader _g;
                private _ee = _le findNearestEnemy _le;
                if (!isNull _ee && {alive _ee} && {(_le distance2D _ee) <= 600} && {(_le knowsAbout _ee) >= (["SEZILDI"] call FUNC(bilgiEsik))}) then {
                    _g setBehaviour "COMBAT";
                    _g setVariable [QGVAR(gevsetT), time + 20];
                    lambs_danger_temasCombatN = (missionNamespace getVariable ["lambs_danger_temasCombatN", 0]) + 1;
                    if (lambs_danger_temasCombatN <= 20) then { diag_log format ["[TEMAS-COMBAT] %1 | temas taze, bilinen dusman %2 m, lider AWARE -> COMBAT | toplam %3", groupId _g, round (_le distance2D _ee), lambs_danger_temasCombatN]; };
                };
            };
            if ((behaviour (leader _g)) isNotEqualTo "COMBAT") then { continue };
            if (time < (_g getVariable [QGVAR(gevsetT), 0])) then { continue };
            if (((_g getVariable [QGVAR(contact), 0]) > (time - 120)) || {(selectMax ([-999] + ((units _g) apply {_x getVariable [QGVAR(sonAtisT), -999]}))) > (time - 60)}) then { continue };
            if ((_g getVariable [QGVAR(isBounding), false]) || {_g getVariable [QGVAR(isRetreating), false]} || {_g getVariable [QGVAR(isEvading), false]} || {_g getVariable [QGVAR(isBreakingContact), false]}
                || {_g getVariable [QGVAR(isAmbushing), false]} || {_g getVariable [QGVAR(isExecutingTactic), false]} || {_g getVariable [QGVAR(isATEngage), false]}) then { continue };
            if ([_g, "combatGevset", true] call FUNC(senaryoKapi)) then { continue };
            private _l = leader _g;
            private _tehdit = (_l nearEntities ["CAManBase", 300]) findIf {
                alive _x && {(side _g) getFriend (side group _x) < 0.6} && {(side group _x) isNotEqualTo civilian} && {!captive _x}
                && {(_g knowsAbout _x) >= (["SEZILDI"] call FUNC(bilgiEsik))}
            };
            if (_tehdit >= 0) then { continue };
            if (((units _g) findIf {
                alive _x && {(_x getVariable [QGVAR(kacisT), 0]) > (time + 60) || {(_x getVariable [QGVAR(siperTutBit), 0]) > time} || {(_x getVariable [QGVAR(reloadState), []]) isNotEqualTo []} || {time < (_x getVariable [QGVAR(tcccBusy), 0])}}
            }) >= 0) then { continue };
            _g setVariable [QGVAR(gevsetT), time + 60];
            _g setBehaviour "AWARE";
            _say = _say + 1;
            if (_logN < 20) then {
                _logN = _logN + 1;
                diag_log format ["[COMBAT-GEVSE] %1 %2 | temas %3 sn once bitti, bilinen dusman 300 m'de yok -> COMBAT -> AWARE", str (side _g), groupId _g, round (time - (_g getVariable [QGVAR(contact), 0]))];
            };
        } forEach allGroups;
        if (time > _ozetT) then {
            _ozetT = time + 60;
            if (_say > 0) then { diag_log format ["[COMBAT-GEVSE-OZET] 60 sn: %1 grup COMBAT -> AWARE", _say]; };
            _say = 0;
        };
    };
};
true
