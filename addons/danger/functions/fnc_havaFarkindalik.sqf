#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * DRON + HELIKOPTER FARKINDALIGI (v8.47)
 *
 * Doktrin (MCWP 3-11.1 "Air attack" drill, UA/UAS mentions): hava tehdidinde piyade dagilir, ortuye girer, hava savunma silahi olan ates eder.
 * Sayisal esikler yoktur (TASARIM):
 *   - Dusman silahli helikopter <= 1200 m veya silahli dron <= 900 m (gozlemci dron 700 m; knowsAbout >= 0.8, lambs_danger_havaBilgiEsik ile ayarlanir): grup bina varsa GARRISON (42 m),
 *     yoksa HIDE (dagil + ates kes), 120 sn. Hava savunma fuzesi olan asker (Stinger / Strela / Igla / AA) hedefe doTarget + doFire.
 *   - Silahsiz dron (gozlemci) <= 700 m: grup gizlenir (pozisyon verme) ama sadece temas yoksa; 90 sn.
 *   - Silahsiz tasima helikopteri: sadece uyari (reveal), saklanma yok.
 *   - Grup basina 120 sn bekleme. ATLANIR: oyuncu lider, arac, retreat / evade / breakContact / bounding / isExecutingTactic.
 * Kapatma: lambs_danger_havaFarkOff = true.
 *
 * Arguments:
 * None
 *
 * Return Value:
 * Baslatildi mi <BOOL>
 *
 * Public: No
*/

if (!isNil "lambs_danger_havaFarkStarted") exitWith {false};
lambs_danger_havaFarkStarted = true;

diag_log "[HAVA-FARK] dron / helikopter farkindaligi watchdog baslatildi";

[] spawn {
    private _logN = 0;
    while {true} do {
        sleep 5;
        if (missionNamespace getVariable ["lambs_danger_havaFarkOff", false]) then { continue };
        // dunya capinda hava araclari (sade liste)
        private _hava = vehicles select {alive _x && {(_x isKindOf "Helicopter") || {unitIsUAV _x}} && {(count (crew _x)) > 0}};
        if (_hava isEqualTo []) then { continue };
        {
            private _g = _x;
            private _l = leader _g;
            if (isNull _l || {isPlayer _l} || {!local _l} || {!alive _l} || {!isNull objectParent _l}) then { continue };
            if ((time - (_g getVariable [QGVAR(havaT), -999])) < 120) then { continue };
            if (
                (_g getVariable [QGVAR(isRetreating), false]) || {_g getVariable [QGVAR(isEvading), false]} || {_g getVariable [QGVAR(isBreakingContact), false]}
                || {_g getVariable [QGVAR(isBounding), false]} || {_g getVariable [QGVAR(isExecutingTactic), false]} || {_g getVariable [QGVAR(sniperTeam), false]}
            ) then { continue };

            private _taraf = side _g;
            private _lp = getPosATL _l;
            private _hedef = objNull;
            private _silahli = false;
            private _dron = false;
            {
                private _v = _x;
                private _d = _lp distance2D _v;
                if (_d > 1200) then { continue };
                if ((_taraf getFriend (side (group (effectiveCommander _v)))) >= 0.6) then { continue };
                if ((_g knowsAbout _v) < (missionNamespace getVariable ["lambs_danger_havaBilgiEsik", 0.8])) then { continue };
                private _arm = ((_v weaponsTurret [-1]) isNotEqualTo []) || {(_v weaponsTurret [0]) isNotEqualTo []};
                private _uav = unitIsUAV _v;
                if (_uav && {!_arm} && {_d > 700}) then { continue };
                if (_uav && {_arm} && {_d > 900}) then { continue };
                if (!_uav && {!_arm}) then { _g reveal [_v, 2]; continue };
                _hedef = _v; _silahli = _arm; _dron = _uav;
                break;
            } forEach _hava;
            if (isNull _hedef) then { continue };
            // gozlemci dron: temasta saklanma yok
            if (!_silahli && {(_g getVariable [QGVAR(contact), 0]) > time}) then { continue };

            _g setVariable [QGVAR(havaT), time];
            private _sure = [90, 120] select _silahli;
            private _garrisonF = missionNamespace getVariable ["lambs_danger_fnc_tacticsGarrison", {false}];
            private _yontem = "HIDE";
            private _ok = false;
            if ((count (nearestObjects [_lp, ["House", "Building"], 42])) > 0) then {
                _ok = [_g, getPosATL _l, [], _sure] call _garrisonF;
                if (_ok isEqualType true && {_ok}) then { _yontem = "GARRISON"; };
            };
            if (_yontem isEqualTo "HIDE") then { [_g, _hedef, false, _sure] call FUNC(tacticsHide); };

            // hava savunma
            private _aa = (units _g) select {alive _x && {(magazines _x) findIf {private _m = toLower _x; (_m find "_aa_") >= 0 || {(_m find "stinger") >= 0} || {(_m find "strela") >= 0} || {(_m find "igla") >= 0} || {(_m find "_aa") >= 0}} >= 0}};
            {
                _g reveal [_hedef, 4];
                _x doTarget _hedef;
                _x doFire _hedef;
            } forEach _aa;

            if (_logN < 120) then {
                _logN = _logN + 1;
                diag_log format ["[HAVA-FARK] %1 | %2 %3 %4 m (silahli:%5) | tepki:%6 | AA asker:%7", groupId _g, ["HELI", "DRON"] select _dron, typeOf _hedef, round (_lp distance2D _hedef), _silahli, _yontem, count _aa];
            };
        } forEach (allGroups select {local _x && {!isNull leader _x}});
    };
};

true
