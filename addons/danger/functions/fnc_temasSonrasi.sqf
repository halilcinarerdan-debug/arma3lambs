#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * TEMAS SONRASI GEVSEME (v8.670; kullanici: 'bulgulara bak, combatta kalma falan'; RPT c6c1f3e6: [ANOMALI] TEMAS-YOK-COMBAT 63 / 148 / 243 sn, saglik izleyicisi sadece UYARIYORDU, duzelten yoktu).
 *
 * NEDEN: Grubu COMBAT'tan indiren mekanizma yok; temas bittikten dakikalar sonra lider COMBAT'ta kaliyor (cok alcak durus / yavas yuruyus / siki formasyon).
 *   Temas bayragi (QGVAR(contact)) LAMBS tasarimi geregi dusman gorulunce ~10 dk ILERIYE yazilir (log: 'InContact | -598'), yalniz 'dusman yok' cagrisinda kisalir; AllClear ancak bayrak bitince + 20 sn sonra gelir
 *   (bu RPT'de hic gelmedi) -> bayraga bakan bir kural 10 dk gec kalir. Bu yuzden olcut BAYRAK DEGIL, 'son bilinen dusmandan beri sessizlik'.
 * KURAL (5 sn'de bir, yerel AI grup, oyuncusuz lider; temas bayragi bir kez kurulmus (> 0) olmali = tasarimcinin kurdugu COMBAT'a dokunulmaz): lider COMBAT iken
 *   grubun HICBIR sagliklı askeri 500 m icinde bilinen dusmani (knowsAbout >= SEZILDI) tanimiyorsa, hicbiri son sessizlik suresinde ates etmediyse ve baski altinda degilse sessizlik sayaci calisir;
 *   sayac >= lambs_danger_temasSonrasiAwareS (75 sn) olunca grup AWARE (tufek yukarda, sakin yuruyus) olur; 60 sn tekrar bakmaz. Bilinen dusman / ates / baski sayaci sifirlar.
 * DOKUNMAZ: retreat / evade / temas kes / bounding / taktik yurutme / supurme / pusu / soyma / AT / sniper takimi / mevzi, LAMBS gorevi ya da 'TUTAN' waypoint (fnc_wpSahip), aktif waypoint davranisi COMBAT (tasarimci istegi),
 *   grupta sagliklı asker yoksa. Yeni temas olursa LAMBS / ELITE COMBAT'a geri alir.
 * CBA: lambs_danger_temasSonrasiAware (acik / kapali), lambs_danger_temasSonrasiAwareS (sn). Log: [TEMAS-SONRASI] (ilk 20) + 60 sn ozeti.
 *
 * Arguments: None
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isNil "lambs_danger_temasSonrasiStarted") exitWith {false};
lambs_danger_temasSonrasiStarted = true;

diag_log "[TEMAS-SONRASI] temas sonrasi gevseme (temas bittikten sonra COMBAT -> AWARE) baslatildi (v8.670)";

[] spawn {
    private _logN = 0;
    private _say = 0;
    private _ozetT = time + 60;
    while {true} do {
        sleep 5;
        if (time > _ozetT) then {
            _ozetT = time + 60;
            if (_say > 0) then { diag_log format ["[TEMAS-SONRASI-OZET] 60 sn: COMBAT -> AWARE indirilen grup %1", _say]; };
            _say = 0;
        };
        if !(missionNamespace getVariable ["lambs_danger_temasSonrasiAware", true]) then { continue };
        private _s = ((missionNamespace getVariable ["lambs_danger_temasSonrasiAwareS", 75]) max 30) min 300;
        private _esik = ["SEZILDI"] call FUNC(bilgiEsik);
        {
            private _g = _x;
            private _l = leader _g;
            if (isNull _l || {isPlayer _l} || {!local _g}) then { continue };
            if ((behaviour _l) isNotEqualTo "COMBAT" || {(_g getVariable [QGVAR(contact), 0]) <= 0}) then { _g setVariable [QGVAR(sessizT), nil]; continue };
            if (time < (_g getVariable [QGVAR(gevsemeT), 0])) then { continue };
            if (
                (_g getVariable [QGVAR(isRetreating), false]) || {_g getVariable [QGVAR(isEvading), false]} || {_g getVariable [QGVAR(isBreakingContact), false]}
                || {_g getVariable [QGVAR(isBounding), false]} || {_g getVariable [QGVAR(isExecutingTactic), false]} || {_g getVariable [QGVAR(isSweeping), false]}
                || {_g getVariable [QGVAR(isAmbushing), false]} || {_g getVariable [QGVAR(isPeeling), false]} || {_g getVariable [QGVAR(isATEngage), false]}
                || {_g getVariable [QGVAR(sniperTeam), false]} || {[_g] call FUNC(mevziDeMi)}
                || {([_g] call FUNC(wpSahip)) in ["LAMBS", "TUTAN"]}
            ) then { _g setVariable [QGVAR(sessizT), nil]; continue };
            private _wi = currentWaypoint _g;
            if (_wi > 0 && {_wi < (count (waypoints _g))} && {(waypointBehaviour [_g, _wi]) isEqualTo "COMBAT"}) then { continue };
            private _canli = (units _g) select {alive _x && {!isPlayer _x} && {(lifeState _x) in ["HEALTHY", "INJURED"]} && {isNull objectParent _x}};
            if (_canli isEqualTo []) then { continue };

            // sessizlik sayaci: bilinen dusman / yeni ates / baski varsa sifirlanir
            private _hareketli = (_canli findIf {
                private _e = _x findNearestEnemy _x;
                (!isNull _e && {alive _e} && {(_x distance _e) < 500} && {(_x knowsAbout _e) >= _esik})
                || {(time - (_x getVariable [QGVAR(sonAtisT), -999])) < 15} || {(getSuppression _x) > 0.05}
            }) >= 0;
            if (_hareketli) then { _g setVariable [QGVAR(sessizT), time]; continue };
            private _st = _g getVariable [QGVAR(sessizT), -1];
            if (_st < 0) then { _g setVariable [QGVAR(sessizT), time]; continue };
            if ((time - _st) < _s) then { continue };

            _g setBehaviour "AWARE";
            _g setVariable [QGVAR(gevsemeT), time + 60];
            _g setVariable [QGVAR(sessizT), nil];
            _say = _say + 1;
            if (_logN < 20) then {
                _logN = _logN + 1;
                diag_log format ["[TEMAS-SONRASI] %1 | %2 sn sessizlik (500 m icinde bilinen dusman yok, ates / baski yok), lider COMBAT -> AWARE | temas bayragi %3 sn sonra | formasyon %4 | combatMode %5", groupId _g, round (time - _st), round ((_g getVariable [QGVAR(contact), 0]) - time), formation _g, combatMode _g];
            };
        } forEach allGroups;
    };
};
true
