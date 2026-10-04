#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * DRON + HELIKOPTER FARKINDALIGI (v8.47, v8.50: atlama tanisi + bounding / taktik gruplari da tepki verir)
 *
 * Doktrin (MCWP 3-11.1 "Air attack" drill, UA/UAS mentions): hava tehdidinde piyade dagilir, ortuye girer, hava savunma silahi olan ates eder.
 * Sayisal esikler yoktur (TASARIM):
 *   - Dusman silahli helikopter <= 1200 m veya silahli dron <= 900 m (gozlemci dron 700 m; knowsAbout >= 0.8, lambs_danger_havaBilgiEsik ile ayarlanir): grup bina varsa GARRISON (42 m),
 *     yoksa HIDE (dagil + ates kes), 120 sn. Hava savunma fuzesi olan asker (Stinger / Strela / Igla / AA) hedefe doTarget + doFire.
 *   - Silahsiz dron (gozlemci) <= 700 m: grup gizlenir (pozisyon verme) ama sadece temas yoksa; 90 sn.
 *   - Silahsiz tasima helikopteri: sadece uyari (reveal), saklanma yok.
 *   - Grup basina 120 sn bekleme. ATLANIR: oyuncu lider, arac, retreat / evade / breakContact / bounding / isExecutingTactic.
 * v8.50: bilgi esigi 0.8 -> 0.4 (ses ile fark eden AI'nin knowsAbout degeri dusuk kalir); silahli tehdit varken bounding / taktik yurutenler
 *   saklanmaz ama AA asker ates eder + reveal + [HAVA-FARK] BOUNDING-DEVAM logu; atlama nedenleri [HAVA-FARK-ATLA] ile 30 sn'de bir yazilir; yakin hava araci listesi 30 sn'de bir [HAVA-FARK-TANI].
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
    private _tani = 0;
    private _taniN = 0;
    private _atlaT = 0;
    while {true} do {
        sleep 5;
        if (missionNamespace getVariable ["lambs_danger_havaFarkOff", false]) then { continue };
        // dunya capinda hava araclari (sade liste)
        private _hava = vehicles select {alive _x && {(_x isKindOf "Helicopter") || {unitIsUAV _x}} && {(count (crew _x)) > 0}};
        if (_hava isEqualTo []) then { continue };
        // tani: yakin hava araci (<=1500 m) varsa 30 sn'de bir listele (neden tepki yok sorusu icin)
        if (time > _tani) then {
            _tani = time + 30;
            {
                private _gv = _x;
                private _lv = leader _gv;
                if (!isNull _lv && {local _lv} && {!isPlayer _lv} && {alive _lv}) then {
                    {
                        private _dv = _lv distance2D _x;
                        if (_dv <= 1500 && {_taniN < 120}) then {
                            _taniN = _taniN + 1;
                            diag_log format ["[HAVA-FARK-TANI] %1 | %2 %3 %4 m | taraf:%5 dost:%6 | knows:%7 | silahli:%8 uav:%9 | bayrak: bnd:%10 tac:%11 ret:%12",
                                groupId _gv, typeOf _x, side (group (effectiveCommander _x)), round _dv, side _gv, (side _gv) getFriend (side (group (effectiveCommander _x))),
                                (_gv knowsAbout _x) toFixed 2, ((_x weaponsTurret [-1]) isNotEqualTo []) || {(_x weaponsTurret [0]) isNotEqualTo []}, unitIsUAV _x,
                                _gv getVariable [QGVAR(isBounding), false], _gv getVariable [QGVAR(isExecutingTactic), false], _gv getVariable [QGVAR(isRetreating), false]];
                        };
                    } forEach _hava;
                };
            } forEach (allGroups select {local _x && {!isNull leader _x} && {side _x != civilian}});
        };
        {
            private _g = _x;
            private _l = leader _g;
            if (isNull _l || {isPlayer _l} || {!local _l} || {!alive _l} || {!isNull objectParent _l}) then { continue };
            if ((time - (_g getVariable [QGVAR(havaT), -999])) < 120) then { continue };
            if (
                (_g getVariable [QGVAR(isRetreating), false]) || {_g getVariable [QGVAR(isEvading), false]} || {_g getVariable [QGVAR(isBreakingContact), false]}
                || {_g getVariable [QGVAR(sniperTeam), false]}
            ) then { continue };
            private _mesgul = (_g getVariable [QGVAR(isBounding), false]) || {_g getVariable [QGVAR(isExecutingTactic), false]};

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
                if ((_g knowsAbout _v) < (missionNamespace getVariable ["lambs_danger_havaBilgiEsik", 0.4])) then { continue };
                private _arm = ((_v weaponsTurret [-1]) isNotEqualTo []) || {(_v weaponsTurret [0]) isNotEqualTo []};
                private _uav = unitIsUAV _v;
                if (_uav && {!_arm} && {_d > 700}) then { continue };
                if (_uav && {_arm} && {_d > 900}) then { continue };
                if (!_uav && {!_arm}) then { _g reveal [_v, 2]; continue };
                _hedef = _v; _silahli = _arm; _dron = _uav;
                break;
            } forEach _hava;
            if (isNull _hedef) then { continue };
            if (_mesgul && {!_silahli}) then {
                if (time > _atlaT) then { _atlaT = time + 30; diag_log format ["[HAVA-FARK-ATLA] %1 | gozlemci dron ama grup bounding / taktik yurutuyor", groupId _g]; };
                continue;
            };
            // gozlemci dron: temasta saklanma yok
            if (!_silahli && {(_g getVariable [QGVAR(contact), 0]) > time}) then { continue };

            _g setVariable [QGVAR(havaT), time];
            private _sure = [90, 120] select _silahli;
            private _aa = (units _g) select {alive _x && {(magazines _x) findIf {private _m = toLower _x; (_m find "_aa_") >= 0 || {(_m find "stinger") >= 0} || {(_m find "strela") >= 0} || {(_m find "igla") >= 0} || {(_m find "_aa") >= 0}} >= 0}};
            // bounding / taktik yurutuyorsa saklanma yok: yalniz farkindalik + hava savunma atesi (bounding bozulmaz)
            if (_mesgul) then {
                _g reveal [_hedef, 3];
                { _g reveal [_hedef, 4]; _x doTarget _hedef; _x doFire _hedef; } forEach _aa;
                if (_logN < 120) then {
                    _logN = _logN + 1;
                    diag_log format ["[HAVA-FARK] %1 | %2 %3 %4 m (silahli:%5) | tepki:BOUNDING-DEVAM | AA asker:%6", groupId _g, ["HELI", "DRON"] select _dron, typeOf _hedef, round (_lp distance2D _hedef), _silahli, count _aa];
                };
                continue;
            };
            private _garrisonF = missionNamespace getVariable ["lambs_danger_fnc_tacticsGarrison", {false}];
            private _yontem = "HIDE";
            private _ok = false;
            if ((count (nearestObjects [_lp, ["House", "Building"], 42])) > 0) then {
                _ok = [_g, getPosATL _l, [], _sure] call _garrisonF;
                if (_ok isEqualType true && {_ok}) then { _yontem = "GARRISON"; };
            };
            if (_yontem isEqualTo "HIDE") then { [_g, _hedef, false, _sure] call FUNC(tacticsHide); };

            // hava savunma
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
