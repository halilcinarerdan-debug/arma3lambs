#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * HALT / SLOT KOVALAMAYI KES (v8.83) — kullanici: "komutan sabitken formasyon oturmuyor, AWARE'de cok adam varsa formasyonu bulamiyorlar".
 * RPT (v8.82, 26 BOSTA-HAREKET): yuruyen askerlerin beklenen hedef MODU 'LEADER PLANNED' / 'FORMATION PLANNED' = Arma'nin KENDI formasyon slot motoru (script emri degil); hedef 1-26 m.
 *   Lider durunca bile 13 kisilik grup slotlarini surekli yeniden hesaplayip kucuk mesafeler yuruyor (STAG COLUMN / WEDGE).
 * COZUM: lider >= 8 sn duruyorsa (hiz < 1 km/s), temas yok (>= 20 sn), taktik / retreat / bounding / IED isi yok, grup >= 6 piyade: SLOTA yakin (<= 20 m) yuruyen askerlere doStop (olduklari yerde DUR, halt);
 *   cok uzak (> 20 m) kalanlar slota yurumeye devam eder (spawn / dagilmadan sonra toplanma). Lider yurumeye baslayinca / temas / taktik baslayinca durdurulanlar doFollow ile serbest birakilir.
 * ATLANIR: oyuncu, arac, forceMove, taktikKilit, EOD, IED isci / guvenlik, nokta elemani, yan guvenlik gozcusu, hekim (TCCC mesgul), yaralilar.
 * Kapatma: lambs_danger_haltOff = true.   Log: [HALT] (ilk 60) + [HALT-OZET] 90 sn
 *
 * Arguments: None
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isNil "lambs_danger_haltStarted") exitWith {false};
lambs_danger_haltStarted = true;

diag_log "[HALT] halt / slot kovalama kesici watchdog'u baslatildi (v8.83)";

private _calis = {
    missionNamespace setVariable ["lambs_danger_haltAdim", "basladi"];
    private _logN = 0;
    private _say = createHashMap;
    private _ozetT = time + 90;
    while {true} do {
        sleep 2;
        if (missionNamespace getVariable ["lambs_danger_haltOff", false]) then { continue };
        {
            private _g = _x;
            private _l = leader _g;
            if (isNull _l || {!local _g} || {isPlayer _l} || {!alive _l} || {!isNull objectParent _l}) then { continue };
            missionNamespace setVariable ["lambs_danger_haltAdim", format ["grup %1", groupId _g]];

            private _us = (units _g) select {alive _x && {isNull objectParent _x} && {!isPlayer _x}};
            private _haltli = _us select {_x getVariable [QGVAR(haltOldu), false]};
            if ((speed _l) > 1) then { _g setVariable [QGVAR(haltHareketT), time]; };

            private _engel =
                ((_g getVariable [QGVAR(contact), 0]) > (time - 20))
                || {(count _us) < 6}
                || {({_g getVariable [_x, false]} count [QGVAR(isRetreating), QGVAR(isEvading), QGVAR(isBounding), QGVAR(isExecutingTactic), QGVAR(isBreakingContact), QGVAR(isAmbushing), QGVAR(sniperTeam), QGVAR(isSonDirenis), QGVAR(disableGroupAI)]) > 0}
                || {(time - (_g getVariable [QGVAR(haltHareketT), -999])) < 8}
                || {(_g getVariable [QGVAR(iedIs), []]) isNotEqualTo []};

            if (_engel) then {
                // serbest birak
                if (_haltli isNotEqualTo []) then {
                    { _x setVariable [QGVAR(haltOldu), nil]; _x doFollow _l; } forEach _haltli;
                    _say set ["serbest", (_say getOrDefault ["serbest", 0]) + (count _haltli)];
                };
                continue;
            };

            private _dur = 0;
            {
                private _u = _x;
                if (_u isEqualTo _l || {_u getVariable [QGVAR(haltOldu), false]}) then { continue };
                if ((lifeState _u) in ["INCAPACITATED", "UNCONSCIOUS"] || {_u getVariable ["ACE_isUnconscious", false]}) then { continue };
                if (_u getVariable [QGVAR(forceMove), false] || {(_u getVariable [QGVAR(taktikKilit), 0]) > time} || {time < (_u getVariable [QGVAR(tcccBusy), 0])}) then { continue };
                if (_u getUnitTrait "explosiveSpecialist" || {_u getVariable [QGVAR(iedIsci), false]} || {_u getVariable [QGVAR(iedGuv), false]} || {_u getVariable [QGVAR(noktaEk), false]} || {!isNil {_u getVariable QGVAR(yanGuv)}}) then { continue };
                private _ed = expectedDestination _u;
                if ((_ed select 1) in ["FORMATION PLANNED", "LEADER PLANNED"] && {(speed _u) > 1} && {(_u distance2D (_ed select 0)) <= 20}) then {
                    doStop _u;
                    _u setVariable [QGVAR(haltOldu), true];
                    _dur = _dur + 1;
                };
            } forEach _us;
            if (_dur > 0) then {
                _say set ["halt", (_say getOrDefault ["halt", 0]) + _dur];
                if (_logN < 60) then {
                    _logN = _logN + 1;
                    diag_log format ["[HALT] %1 | %2 asker slota yakin yurumeyi kesti (lider %3 sn duruyor) | formasyon %4 | beh %5", groupId _g, _dur, round (time - (_g getVariable [QGVAR(haltHareketT), -999])), formation _g, behaviour _l];
                };
            };
        } forEach (allGroups select {local _x && {!isNull leader _x} && {!(_x getVariable ["lambs_danger_tarafKapali", false])}});
        if (time > _ozetT) then {
            _ozetT = time + 90;
            if (count _say > 0) then { diag_log format ["[HALT-OZET] son 90 sn: %1", (keys _say) apply {format ["%1:%2", _x, _say get _x]}]; };
            _say = createHashMap;
        };
        missionNamespace setVariable ["lambs_danger_haltAdim", "tur bitti"];
    };
};

// bekci: betik hata ile olurse yeniden baslat
[_calis] spawn {
    params ["_fn"];
    while {true} do {
        private _h = [] spawn _fn;
        waitUntil { sleep 5; scriptDone _h };
        diag_log format ["[WATCHDOG-YENIDEN] halt betigi sonlandi (hata?), son adim: %1", missionNamespace getVariable ["lambs_danger_haltAdim", "?"]];
        sleep 5;
    };
};

true
