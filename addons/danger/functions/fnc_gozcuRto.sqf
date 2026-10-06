#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * ILERI GOZCU + RTO (v8.83) — kullanici: "AWARE olsa bile ileriyi surekli gozlemleyecek biri lazim, RTO sisteme entegre edilebilir".
 *
 * RTO (telsizci): >= 4 canli piyadelik gruba atanir. Oncelik: telsiz sirt cantasi (backpack: radio / rt1523 / prc / tf_rt / tf_anprc / rto) ya da birim sinifi "rto / radio"; yoksa >= 6 kisilik grupta
 *   liderin yanindaki (hekim / MG / EOD / gozcu / nisanci haric) NOMINAL RTO. Grup degiskeni lambs_danger_rto. HQ istihbarat agi (fnc_hqIstihbarat): RTO canliysa grubun telsiz gucu 1 (tam menzil);
 *   RTO olduyse yalniz liderin kisa menzilli telsizi (menzil x0.4). Kucuk gruplar (< 4) eskisi gibi lider telsizi.
 * GOZCU (ileri gozlemci): dürbünlü (binocular) ya da nisanci rolunde bir asker (lider / hekim / MG / RTO / EOD / UGL / baski tufekcisi / nokta elemani / yan guvenlik haric). Temas yokken (>= 20 sn) ve lider durmus / yavassa
 *   (< 4 km/s) AWARE olsa bile 8 sn'de bir tehdit yonu etrafinda +-35 derece yelpazede 150 m ileriye doWatch yapar (tehdit yonu: komutanin son dusman raporu <= 300 sn, yoksa liderin bakisi);
 *   gorus becerisi (spotDistance / spotTime) x1.25 (en fazla 1; taban saklanir, gozcu degisince geri verilir) = durbunle dikkatli gozlem. Gozcu olunce yenisi secilir.
 * AI hilesi yok: yalniz bakis yonu + dikkat becerisi. Kapatma: lambs_danger_gozcuOff = true.   Log: [GOZCU] / [RTO] (ilk 80)
 *
 * Arguments: None
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isNil "lambs_danger_gozcuStarted") exitWith {false};
lambs_danger_gozcuStarted = true;

diag_log "[GOZCU] ileri gozcu + RTO watchdog'u baslatildi (v8.83)";

private _calis = {
    missionNamespace setVariable ["lambs_danger_gozcuAdim", "basladi"];
    private _logN = 0;
    private _rolFn = missionNamespace getVariable ["lambs_danger_fnc_getUnitRole", {"RIFLE"}];
    private _uglFn = missionNamespace getVariable ["lambs_danger_fnc_hasUGL", {""}];
    private _telsizSirt = ["radio", "rt1523", "prc", "tf_rt", "tf_anprc", "rto"];
    while {true} do {
        sleep 4;
        if (missionNamespace getVariable ["lambs_danger_gozcuOff", false]) then { continue };
        {
            private _g = _x;
            private _l = leader _g;
            if (isNull _l || {!local _g} || {isPlayer _l} || {!alive _l} || {!isNull objectParent _l}) then { continue };
            missionNamespace setVariable ["lambs_danger_gozcuAdim", format ["grup %1", groupId _g]];
            private _us = (units _g) select {alive _x && {isNull objectParent _x} && {!isPlayer _x} && {(lifeState _x) in ["HEALTHY", "INJURED"]}};
            if ((count _us) < 4) then { continue };

            private _uygun = {
                params ["_u"];
                _u isNotEqualTo _l && {!(_u getUnitTrait "medic")} && {!(_u getUnitTrait "explosiveSpecialist")}
                && {!(_u getVariable [QGVAR(baskiTuf), false])} && {!(_u getVariable [QGVAR(noktaEk), false])} && {isNil {_u getVariable QGVAR(yanGuv)}}
                && {!(_u getVariable [QGVAR(iedGuv), false])} && {!(_u getVariable [QGVAR(iedIsci), false])} && {([_u, true] call _rolFn) in ["RIFLE", "MARKSMAN", "AT"]}
            };

            // ---- RTO ----
            private _rto = _g getVariable [QGVAR(rto), objNull];
            if (isNull _rto || {!alive _rto} || {(group _rto) isNotEqualTo _g}) then {
                private _eskiOlu = !isNull _rto;
                _rto = objNull;
                private _gercek = _us select {
                    private _bp = toLower (backpack _x);
                    private _tp = toLower (typeOf _x);
                    [_x] call _uygun && {((_telsizSirt findIf {(_bp find _x) >= 0 || {(_tp find "rto") >= 0 || {(_tp find "radio") >= 0}}}) > -1)}
                };
                if (_gercek isNotEqualTo []) then { _rto = _gercek select 0; } else {
                    if ((count _us) >= 6 && {!_eskiOlu}) then {
                        private _ad = (_us select {[_x] call _uygun && {!(_x getVariable [QGVAR(gozcu), false])}}) apply {[_x distance2D _l, _x]};
                        _ad = [_ad, [], {_x select 0}, "ASCEND"] call BIS_fnc_sortBy;
                        if (_ad isNotEqualTo []) then { _rto = (_ad select 0) select 1; };
                    };
                };
                if (!isNull _rto) then {
                    _g setVariable [QGVAR(rto), _rto];
                    _g setVariable [QGVAR(rtoAtandi), true];
                    if (_logN < 80) then { _logN = _logN + 1; diag_log format ["[RTO] %1 | RTO: %2 | sirt cantasi: %3 | %4", groupId _g, name _rto, backpack _rto, ["nominal (telsiz sirt cantasi yok)", "gercek (telsiz cantasi / sinif)"] select ((_gercek findIf {_x isEqualTo _rto}) >= 0)]; };
                } else {
                    if (_eskiOlu) then {
                        _g setVariable [QGVAR(rto), objNull];
                        if (_logN < 80) then { _logN = _logN + 1; diag_log format ["[RTO] %1 | RTO KAYBI | HQ istihbarat: yalniz liderin kisa menzilli telsizi (menzil x0.4)", groupId _g]; };
                    };
                };
            };

            // ---- GOZCU ----
            private _gz = _g getVariable [QGVAR(gozcu), objNull];
            private _gzGecerli = !isNull _gz && {alive _gz} && {(group _gz) isEqualTo _g} && {(lifeState _gz) in ["HEALTHY", "INJURED"]};
            if (!_gzGecerli) then {
                if (!isNull _gz) then {
                    // eski gozcunun becerisini geri ver
                    private _b = _gz getVariable [QGVAR(gozcuBaz), []];
                    if (alive _gz && {_b isNotEqualTo []}) then { _gz setSkill ["spotDistance", _b select 0]; _gz setSkill ["spotTime", _b select 1]; };
                    _gz setVariable [QGVAR(gozcuBaz), nil];
                };
                _gz = objNull;
                private _ad = _us select {[_x] call _uygun && {_x isNotEqualTo (_g getVariable [QGVAR(rto), objNull])} && {([_x] call _uglFn) isEqualTo ""}};
                private _skorlu = _ad apply {
                    [(([0, 3] select ((binocular _x) isNotEqualTo "")) + ([0, 2] select (([_x, true] call _rolFn) isEqualTo "MARKSMAN"))), _x]
                };
                _skorlu = [_skorlu, [], {_x select 0}, "DESCEND"] call BIS_fnc_sortBy;
                if (_skorlu isNotEqualTo []) then {
                    _gz = (_skorlu select 0) select 1;
                    _g setVariable [QGVAR(gozcu), _gz];
                    if (_logN < 80) then { _logN = _logN + 1; diag_log format ["[GOZCU] %1 | ileri gozcu: %2 | durbun: %3 | rol %4", groupId _g, name _gz, binocular _gz, [_gz, true] call _rolFn]; };
                };
            };
            if (isNull _gz) then { continue };

            private _gozlem = ((_g getVariable [QGVAR(contact), 0]) < (time - 20))
                && {(speed _l) < 4}
                && {!(_gz getVariable [QGVAR(forceMove), false])} && {(_gz getVariable [QGVAR(taktikKilit), 0]) <= time}
                && {({_g getVariable [_x, false]} count [QGVAR(isRetreating), QGVAR(isEvading), QGVAR(isBreakingContact), QGVAR(isAmbushing), QGVAR(sniperTeam), QGVAR(disableGroupAI)]) == 0};
            if (_gozlem) then {
                if ((_gz getVariable [QGVAR(gozcuBaz), []]) isEqualTo []) then {
                    private _sd = _gz skill "spotDistance";
                    private _st = _gz skill "spotTime";
                    _gz setVariable [QGVAR(gozcuBaz), [_sd, _st]];
                    _gz setSkill ["spotDistance", (_sd * 1.25) min 1];
                    _gz setSkill ["spotTime", (_st * 1.25) min 1];
                };
                if (time > (_gz getVariable [QGVAR(gozcuBakT), 0])) then {
                    _gz setVariable [QGVAR(gozcuBakT), time + 8];
                    private _sit = _g getVariable [QGVAR(cmdSit), []];
                    private _taban = getDir _l;
                    if (_sit isNotEqualTo [] && {(time - (_sit select 0)) < 300} && {(_sit select 7) isEqualType []} && {(_sit select 7) isNotEqualTo [0,0,0]}) then { _taban = (getPosATL _l) getDir (_sit select 7); };
                    private _yon = _taban + (selectRandom [-35, -15, 0, 15, 35]);
                    _gz doWatch ((getPosATL _gz) getPos [150, _yon]);
                };
            };
        } forEach (allGroups select {local _x && {!isNull leader _x} && {!(_x getVariable ["lambs_danger_tarafKapali", false])}});
        missionNamespace setVariable ["lambs_danger_gozcuAdim", "tur bitti"];
    };
};

// bekci: betik hata ile olurse yeniden baslat
[_calis] spawn {
    params ["_fn"];
    while {true} do {
        private _h = [] spawn _fn;
        waitUntil { sleep 5; scriptDone _h };
        diag_log format ["[WATCHDOG-YENIDEN] gozcu betigi sonlandi (hata?), son adim: %1", missionNamespace getVariable ["lambs_danger_gozcuAdim", "?"]];
        sleep 5;
    };
};

true
