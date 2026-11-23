#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * KOORDINELI BINA GIRISI (v8.598; kullanici: 'koordineli giris olmadi; lambs garrison ile uyumlu olsun ve cqb'; RPT 38ac1efc: 10 kisilik grup binadaki dusmana 14 bomba denedi ama giris yok, [BINA-TEMIZLE] yalniz catisma BITTIKTEN sonra calisiyor).
 * Temasta (QGVAR(contact) > time) bilinen dusman BINADAYSA (insideBuilding > 0.3, 12-90 m) ve grup yeterliyse (>= 4 saglam piyade, kayip < %40, binadaki dusman <= grup x 1.5, baski < 0.8)
 * fnc_buildingClearRun'i SALDIRI modunda baslatir: kapi yaninda yigilma -> (varsa) bombanin patlamasini bekle (patlayici izleyicisi atar; yigilma sonrasi <= 6 sn, atildiysa ~3.5 sn sonra gir) -> iki kisilik takimlar ESZAMANLI girer, oda oda temizler.
 * UYUM: LAMBS Garrison / CQB / Camp ... gorevi ya da kal-bekle waypoint'li gruplar (fnc_senaryoKapi sabit kapisi: LAMBS / TUTAN) LAMBS'in kendi bina davranisini korur, ELITE girisi baslatmaz; hareket waypoint'li (MOVE / SAD) gruplar temasta serbest.
 * ATLANIR: oyunculu grup, retreat / evade / temas kes / AT / bounding / keskin nisanci / teslim, ates yasagi (GREEN / BLUE), zaten supuren grup, 150 sn bekleme. Kapatma: CBA lambs_danger_binaSaldiri ya da lambs_danger_buildingClearOff.
 * Log: [BINA-SALDIRI] (ilk 15) + fnc_buildingClearRun [BINA-TEMIZLE] / [ODA].
 *
 * Arguments: None
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isNil "lambs_danger_binaSaldiriStarted") exitWith {false};
lambs_danger_binaSaldiriStarted = true;

diag_log "[BINA-SALDIRI] koordineli bina girisi (temasta, binadaki dusman) watchdog baslatildi (v8.598)";

[] spawn {
    private _logN = 0;
    while {true} do {
        sleep ([3, false, true, "binaSaldiri"] call FUNC(dusunSure));
        if (!(missionNamespace getVariable ["lambs_danger_binaSaldiri", true]) || {missionNamespace getVariable ["lambs_danger_buildingClearOff", false]}) then { continue };
        {
            private _g = _x;
            if (isNull _g || {!local _g}) then { continue };
            if (((units _g) findIf {isPlayer _x}) > -1) then { continue };
            if (_g getVariable [QGVAR(isSweeping), false] || {time < (_g getVariable [QGVAR(saldiriT), 0])} || {time < (_g getVariable [QGVAR(sweepCooldown), 0])}) then { continue };
            private _temas = (_g getVariable [QGVAR(contact), 0]) > time;   // v8.604: temas YOKSA da bilinen binadaki dusmana gider (asagida bilgi / son gorulme sarti)
            if (
                (_g getVariable [QGVAR(isRetreating), false]) || {_g getVariable [QGVAR(isEvading), false]} || {_g getVariable [QGVAR(isBreakingContact), false]}
                || {_g getVariable [QGVAR(isATEngage), false]} || {(_g getVariable [QGVAR(isBounding), false]) && {!(missionNamespace getVariable ["lambs_danger_binaBoundingDahil", false])}} || {_g getVariable [QGVAR(sniperTeam), false]}   // v8.770: CBA binaBoundingDahil
                || {_g getVariable [QGVAR(teslimOldu), false]} || {(combatMode _g) in ["GREEN", "BLUE"]}
            ) then { continue };
            if ([_g, "binaSaldiri", true] call FUNC(senaryoKapi)) then { continue };
            private _l = leader _g;
            if (isNull _l || {!alive _l} || {isPlayer _l} || {!isNull objectParent _l}) then { continue };
            private _uyeler = (units _g) select {alive _x && {local _x} && {!isPlayer _x} && {isNull objectParent _x} && {(lifeState _x) in ["HEALTHY", "INJURED"]}};
            if ((count _uyeler) < (((missionNamespace getVariable ["lambs_danger_binaMinAsker", 4]) max 2) min 8) || {((count _uyeler) / ((count (units _g)) max 1)) < 0.6}) then { continue };   // v8.770: CBA binaMinAsker
            if (({(getSuppression _x) > 0.8} count _uyeler) > 0) then { continue };
            private _taraf = side _g;
            private _bMenzil = ((missionNamespace getVariable ["lambs_danger_binaMenzilM", 120]) max 60) min 250;   // v8.770: CBA binaMenzilM
            private _bMin = ((missionNamespace getVariable ["lambs_danger_binaMinM", 12]) max 4) min 30;   // v8.770: CBA binaMinM
            private _hedefler = (_l nearTargets _bMenzil) select {
                private _o = _x select 4;
                !isNull _o && {alive _o} && {_o isKindOf "CAManBase"} && {!([_o] call FUNC(teslimMi))} && {(_taraf getFriend (side (group _o))) < 0.6}
                && {(side (group _o)) isNotEqualTo civilian} && {(insideBuilding _o) > 0.15} && {(_l distance2D _o) >= _bMin}
                && {(_l knowsAbout _o) >= (["SEZILDI"] call FUNC(bilgiEsik))}
                && {_temas || {((_l knowsAbout _o) >= (["SUPHE"] call FUNC(bilgiEsik))) && {((_l targetKnowledge _o) select 2) > (time - 240)}}}
            };
            if (_hedefler isEqualTo []) then { continue };
            _hedefler = [_hedefler, [], {(_x select 4) distance2D _l}, "ASCEND"] call BIS_fnc_sortBy;
            private _o = (_hedefler select 0) select 4;
            private _b = nearestBuilding _o;
            if (isNull _b || {(count (_b buildingPos -1)) < 2}) then { continue };
            private _icDus = {alive _x && {(_taraf getFriend (side (group _x))) < 0.6} && {(insideBuilding _x) > 0.2}} count (_b nearEntities ["CAManBase", 30]);
            if (_icDus > ((count _uyeler) * 1.5)) then { continue };
            _g setVariable [QGVAR(saldiriT), time + (((missionNamespace getVariable ["lambs_danger_binaBekleS", 150]) max 10) min 300)];   // v8.770: CBA binaBekleS
            if (_logN < 15) then {
                _logN = _logN + 1;
                diag_log format ["[BINA-SALDIRI] %1 | bina %2 | en yakin icerideki dusman %3 m | asker %4 | binada dusman %5", groupId _g, typeOf _b, round (_l distance2D _o), count _uyeler, _icDus];
            };
            [_g, true, _b] spawn (missionNamespace getVariable ["lambs_danger_fnc_buildingClearRun", {false}]);
        } forEach allGroups;
    };
};

true
