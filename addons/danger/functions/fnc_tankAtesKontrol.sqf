#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * TANK ATES KONTROLU (v8.251) — kullanici: "tank hedef dagitimi + AT atesine tepki + tank-piyade koruma". 2 sn'de bir, YEREL AI suruculu, oyuncusuz TANK sinifi araclar icin:
 *   A) ISABET TEPKISI: tank hasari >= 0.05 artti -> fnc_aracAtTepki (sebep ISABET; atici = grup liderinin en yakin bilinen gercek dusmani <= 1500 m).
 *   B) KORU: <= 450 m'de BILINEN gercek dusman AT unsuru (roketatarli piyade / ATGM'li arac / statik) -> fnc_tankKoru (tank basina 10 sn; dost piyade gruplari ates/bakis).
 *   C) HEDEF DAGITIMI (plan zirh destek GRUBU OLMAYAN tanklar; planZirh kendi tanklarini fnc_tankHedefSec ile zaten dagitir): 5 sn'de bir bilinen gercek dusman <= 1300 m adaylarindan fnc_tankHedefSec secimi;
 *      YALNIZ (<= 800 m'de baska dost tank var) ya da (secim puani >= 85: tank / ATGM / AT'li piyade / diger tank) ise nisanciya doTarget + doFire; aksi halde motorun kendi hedef secimi.
 *   D) YALNIZ TANK TESHISI: tank temasta (grup temas isareti) ve 250 m'de dost piyade yok -> [TANK-YALNIZ] (60 sn, ilk 20; davranis degistirmez).
 * Kapatma: lambs_danger_tankAtesOff = true (hepsi), lambs_danger_tankHedefDagitOff = true (yalniz C).  Log: [TANK-ATES].
 *
 * Arguments: None
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isNil "lambs_danger_tankAtesStarted") exitWith {false};
lambs_danger_tankAtesStarted = true;

diag_log "[TANK-ATES] tank ates kontrolu baslatildi (v8.251): hedef dagitimi + AT atesine tepki + tank koruma";

private _calis = {
    private _logN = 0;
    private _yalnizN = 0;
    while {true} do {
        sleep 2;
        if (missionNamespace getVariable ["lambs_danger_tankAtesOff", false]) then { continue };
        {
            private _v = _x;
            if (!local _v || {!alive _v} || {!(_v isKindOf "LandVehicle")}) then { continue };
            private _d = driver _v;
            if (isNull _d || {!alive _d} || {isPlayer _d} || {(crew _v) findIf {isPlayer _x} >= 0}) then { continue };
            if (((([_v] call FUNC(aracSinif)) select 0)) isNotEqualTo "TANK") then { continue };
            private _g = group _d;
            private _l = leader _g;
            if (isNull _l) then { continue };
            private _tf = side _g;
            if (_tf isEqualTo civilian) then { continue };

            // A) isabet
            private _h = damage _v;
            private _h0 = _v getVariable [QGVAR(tankHasar0), _h];
            _v setVariable [QGVAR(tankHasar0), _h];
            if (_h >= _h0 + 0.05) then {
                private _en = _l findNearestEnemy _v;
                if (!isNull _en && {(_v distance2D _en) > 1500 || {!([_en] call FUNC(gercekHedef))}}) then { _en = objNull; };
                [_v, _en, "ISABET", []] call FUNC(aracAtTepki);
            };

            // aday listesi (B / C / D ortak)
            private _adaylar = (_l nearTargets 1500) select {
                private _o = _x select 4;
                !isNull _o && {alive _o} && {(_tf getFriend (_x select 2)) < 0.6} && {(_l knowsAbout _o) >= 0.3} && {[_o] call FUNC(gercekHedef)}
            };

            // B) koru
            if ((time - (_v getVariable [QGVAR(tankKoruKT), -999])) >= 10) then {
                private _at = _adaylar select {
                    private _o = _x select 4;
                    (_v distance2D _o) <= 450 && {
                        if (_o isKindOf "CAManBase") then { ((secondaryWeapon _o) isNotEqualTo "") && {[_o] call FUNC(isATUnit)} } else { (([_o] call FUNC(aracSinif)) select 3) }
                    }
                };
                if (_at isNotEqualTo []) then {
                    _v setVariable [QGVAR(tankKoruKT), time];
                    _at = [_at, [], {_v distance2D (_x select 4)}, "ASCEND"] call BIS_fnc_sortBy;
                    [_v, [], (_at select 0) select 4] call FUNC(tankKoru);
                };
            };

            // C) hedef dagitimi (plan zirh destek grubu degilse)
            if (!(_g getVariable ["lambs_danger_planZirh", false]) && {!(missionNamespace getVariable ["lambs_danger_tankHedefDagitOff", false])} && {_adaylar isNotEqualTo []} && {(time - (_v getVariable [QGVAR(tankHedefT), -999])) >= 5}) then {
                _v setVariable [QGVAR(tankHedefT), time];
                private _hedefA = _adaylar select {(_v distance2D (_x select 4)) <= 1300};
                private _res = [_v, _hedefA] call FUNC(tankHedefSec);
                if (_res isNotEqualTo []) then {
                    private _dost = ((_v nearEntities ["Tank", 800]) findIf {_x isNotEqualTo _v && {alive _x} && {(side (group (effectiveCommander _x))) isEqualTo _tf}}) >= 0;
                    if (_dost || {(_res select 1) >= 85}) then {
                        private _gn = gunner _v;
                        private _hd = _res select 0;
                        if (!isNull _gn && {alive _gn}) then {
                            _gn doTarget _hd;
                            _gn doFire _hd;
                            if (_logN < 80 && {(_v getVariable [QGVAR(tankHedefSon), objNull]) isNotEqualTo _hd}) then {
                                _logN = _logN + 1;
                                diag_log format ["[TANK-ATES] %1 (%2) HEDEF %3 (%4 m, puan %5) | dagitim: yakinda dost tank %6", getText (configOf _v >> "displayName"), groupId _g, typeOf _hd, round (_v distance2D _hd), round (_res select 1), _dost];
                            };
                            _v setVariable [QGVAR(tankHedefSon), _hd];
                        };
                    };
                };
            };

            // D) yalniz tank teshisi
            if (_yalnizN < 20 && {(_g getVariable [QGVAR(contact), 0]) > time} && {(time - (_v getVariable [QGVAR(tankYalnizT), -999])) >= 60}) then {
                private _piy = (_v nearEntities ["CAManBase", 250]) select {alive _x && {isNull objectParent _x} && {(side (group _x)) isEqualTo _tf}};
                if (_piy isEqualTo []) then {
                    _v setVariable [QGVAR(tankYalnizT), time];
                    _yalnizN = _yalnizN + 1;
                    diag_log format ["[TANK-YALNIZ] %1 (%2) temasta ve 250 m'de dost piyade YOK | bilinen dusman %3 | en yakin %4 m", getText (configOf _v >> "displayName"), groupId _g, count _adaylar, if (_adaylar isEqualTo []) then {"-"} else {round (_v distance2D (([_adaylar, [], {_v distance2D (_x select 4)}, "ASCEND"] call BIS_fnc_sortBy) select 0 select 4))}];
                };
            };
        } forEach vehicles;
    };
};

[_calis] spawn {
    params ["_fn"];
    while {true} do {
        private _h = [] spawn _fn;
        waitUntil { sleep 5; scriptDone _h };
        diag_log "[WATCHDOG-YENIDEN] tankAtesKontrol betigi sonlandi (hata?)";
        sleep 5;
    };
};

true
