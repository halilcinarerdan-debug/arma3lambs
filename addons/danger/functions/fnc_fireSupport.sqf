#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * ATES DESTEGI — watchdog (3 sn): doktrine uygun UGL, stratejik sis, silahsiz dusmana ates.
 *
 * A) UGL (M203/GL, FM 3-22.31): 40mm HE; siperde / binada / kume halinde / kapali hatli dusmana,
 *    tufegin ulasamadigi yere. Sadece ates ekibinin (hucum eden manevra degil) UGL'cisi; 2'li salvo
 *    (ilk atis duzeltme, ikincisi etki). Birim basina 9 sn.
 * B) STRATEJIK SIS (obscuring / screening smoke):
 *    - Bastirilmis grup (>= 2 asker baski > 0.55, dusman > 40 m): sis perdesi (BREAK_CONTACT geometri)
 *    - Yarali / baygin dost + dusman 40-250 m: yaralinin onune sis (kurtarma icin gorusu kes)
 *    - Grup basina 45 sn cooldown (fnc_tacticalSmoke icinde)
 * C) SILAHSIZ DUSMAN: mermisi olan asker, silahsiz (veya mermisiz) fakat TESLIM OLMAMIS dusmani 100 m icinde
 *    gordugu halde ates etmiyorsa (LAMBS / motor "zararsiz hedef" yok sayar): reveal + doTarget + doFire +
 *    1 sn sonra fireAtTarget. 6 sn / birim. Esir (captive) ve teslim animasyonuna dokunmaz.
 * D) MERMI BITTI: yedek sarjor yok -> yan silaha gec; yoksa 40 m icindeki olu askerden uyumlu sarjor al.
 *
 * KAPATMA ANAHTARI: lambs_danger_fireSupportOff = true     RPT: [ATES-DESTEK]
 *
 * Arguments:
 * None
 *
 * Return Value:
 * Baslatildi mi <BOOL>
 *
 * Public: No
*/

if (!isNil "lambs_danger_fireSupportStarted") exitWith {false};
lambs_danger_fireSupportStarted = true;

diag_log "[ATES-DESTEK] UGL doktrini + stratejik sis + silahsiz dusman ates watchdog baslatildi";

[] spawn {
    private _rolFn = missionNamespace getVariable ["lambs_danger_fnc_getUnitRole", {"RIFLE"}];
    // silahsiz mi (kullanilabilir ates silahi yok)
    private _silahsiz = {
        params ["_e"];
        private _w = (weapons _e) select {
            private _t = getNumber (configFile >> "CfgWeapons" >> _x >> "type");
            _t in [1, 2, 4]
        };
        _w isEqualTo [] || {(magazines _e) isEqualTo []}
    };

    while {true} do {
        sleep 3;
        if (missionNamespace getVariable ["lambs_danger_fireSupportOff", false]) then { continue };

        {
            private _g = _x;
            if (isNull _g || {!local _g}) then { continue };
            if ((_g getVariable [QGVAR(contact), 0]) <= time) then { continue };
            private _l = leader _g;
            if (isNull _l || {!alive _l} || {isPlayer _l} || {!isNull objectParent _l}) then { continue };
            if (((units _g) findIf {isPlayer _x}) > -1) then { continue };
            if (_g getVariable [QGVAR(isRetreating), false]) then { continue };

            private _uyeler = (units _g) select {alive _x && {isNull objectParent _x} && {(lifeState _x) in ["HEALTHY", "INJURED"]}};
            if (_uyeler isEqualTo []) then { continue };

            // ---------------- A) UGL ----------------
            private _glFn = missionNamespace getVariable ["lambs_danger_fnc_hasUGL", {""}];
            private _glAtici = _uyeler select {
                (time - (_x getVariable [QGVAR(uglLast), -999])) > 9
                && {([_x] call _glFn) isNotEqualTo ""}
                && {!(_x getVariable [QGVAR(forceMove), false])}
            };
            if (_glAtici isNotEqualTo [] && {!(_g getVariable [QGVAR(isBounding), false]) || {(count _glAtici) > 1}}) then {
                private _u = selectRandom _glAtici;
                private _adaylar = (_u targets [true, 320]) select {
                    _x isKindOf "CAManBase" && {alive _x} && {isNull objectParent _x} && {(_u distance2D _x) > 40}
                    && {(_u knowsAbout _x) > 0.8}
                };
                if (_adaylar isNotEqualTo []) then {
                    // en degerli hedef: binada > kapali hat > kume > acikta duran
                    private _skor = {
                        params ["_e"];
                        private _s = 0;
                        if ((insideBuilding _e) > 0.5) then { _s = _s + 3 };
                        if (lineIntersects [eyePos _u, eyePos _e, _u, _e]) then { _s = _s + 2 };
                        _s = _s + ((count ((_e nearEntities ["CAManBase", 8]) select {alive _x && {(side _x) isEqualTo (side _e)}})) min 3);
                        _s
                    };
                    private _en = objNull; private _enSkor = 0;
                    {
                        private _sk = [_x] call _skor;
                        if (_sk > _enSkor) then { _enSkor = _sk; _en = _x; };
                    } forEach _adaylar;
                    // en az "kapali hat" veya kume / bina; sadece acikta tek hedefe %25
                    if (!isNull _en && {_enSkor >= 2 || {(random 1) < 0.25}}) then {
                        if ([_u, _en, true, 2] call (missionNamespace getVariable ["lambs_danger_fnc_tacticalUGL", {false}])) then {
                            diag_log format ["[ATES-DESTEK] %1 | %2 | UGL salvo -> %3 m (skor %4)", groupId _g, name _u, round (_u distance2D _en), _enSkor];
                        };
                    };
                };
            };

            // ---------------- B) stratejik sis ----------------
            private _dusman = _l findNearestEnemy _l;
            if (!isNull _dusman && {alive _dusman}) then {
                private _dm = _l distance2D _dusman;
                private _baskili = (_uyeler select {(getSuppression _x) > 0.55});
                private _yarali = (units _g) select {alive _x && {(lifeState _x) isEqualTo "INCAPACITATED"}};
                if (_dm > 40 && {_dm < 250}) then {
                    if ((count _baskili) >= 2 || {_yarali isNotEqualTo []}) then {
                        private _ok = [_g, _dusman, "BREAK_CONTACT"] call (missionNamespace getVariable ["lambs_danger_fnc_tacticalSmoke", {false}]);
                        if (_ok) then {
                            diag_log format ["[ATES-DESTEK] %1 | stratejik sis (%2) dusman %3 m", groupId _g, ["baski altinda", "yarali kurtarma"] select (_yarali isNotEqualTo []), round _dm];
                        };
                    };
                };
            };

            // ---------------- C) silahsiz dusman ----------------
            {
                private _u = _x;
                if (time < (_u getVariable [QGVAR(unarmedT), 0])) then { continue };
                if ((_u ammo (primaryWeapon _u)) <= 0 && {(_u ammo (handgunWeapon _u)) <= 0}) then { continue };
                private _e = _u findNearestEnemy _u;
                if (isNull _e || {!alive _e} || {!isNull objectParent _e}) then { continue };
                if ((_u distance2D _e) > 100) then { continue };
                if (captive _e || {(animationState _e) find "sdr" >= 0} || {(animationState _e) find "surrender" >= 0}) then { continue };
                // <= 6 m: silah durumuna bakmadan (LAMBS assault / "Enemy Detected" dongusunde 2-3 m'de ates etmeden bekleme)
                if ((_u distance2D _e) > 6 && {!([_e] call _silahsiz)}) then { continue };
                if ((_u distance2D _e) > 3 && {lineIntersects [eyePos _u, eyePos _e, _u, _e]}) then { continue };

                _u setVariable [QGVAR(unarmedT), time + 6];
                _u reveal [_e, 4];
                _u doWatch _e;
                _u doTarget _e;
                _u doFire _e;
                [{
                    params ["_a", "_t"];
                    if (alive _a && {alive _t} && {(_a ammo (currentWeapon _a)) > 0}) then {
                        _a fireAtTarget [_t];
                    };
                }, [_u, _e], 1] call CBA_fnc_waitAndExecute;
                diag_log format ["[ATES-DESTEK] %1 | %2 | silahsiz dusmana ates (%3 m)", groupId _g, name _u, round (_u distance2D _e)];
            } forEach _uyeler;

            // ---------------- D) MERMI BITTI: yedek sarjor yoksa sidearm / olu askerden mermi topla ----------------
            {
                private _u = _x;
                if (time < (_u getVariable [QGVAR(scavT), 0])) then { continue };
                private _pw = primaryWeapon _u;
                if (_pw isEqualTo "") then { continue };
                private _uyumlu = compatibleMagazines _pw;
                if (((magazines _u) arrayIntersect _uyumlu) isNotEqualTo [] || {(_u ammo _pw) > 0}) then { continue };
                _u setVariable [QGVAR(scavT), time + 4];

                // 1) yan silah
                private _hg = handgunWeapon _u;
                if (_hg isNotEqualTo "" && {(_u ammo _hg) > 0}) then {
                    _u selectWeapon _hg;
                    continue
                };

                // 2) yakindaki olu askerden uyumlu sarjor (doktrin: ates gucu bitince cephane devral)
                private _olu = (nearestObjects [_u, ["CAManBase"], 40]) select {
                    !alive _x && {((magazines _x) arrayIntersect _uyumlu) isNotEqualTo []}
                };
                if (_olu isEqualTo []) then { continue };
                private _hedef = _olu select 0;
                if ((_u distance2D _hedef) > 2.5) then {
                    _u doMove (getPosATL _hedef);
                } else {
                    private _mags = (magazines _hedef) select {_x in _uyumlu};
                    {
                        _hedef removeMagazine _x;
                        _u addMagazine _x;
                    } forEach (_mags select [0, 3]);
                    diag_log format ["[ATES-DESTEK] %1 | %2 | mermi bitti: %3 sarjor olu askerden alindi", groupId _g, name _u, count (_mags select [0, 3])];
                };
            } forEach _uyeler;
        } forEach allGroups;
    };
};

true
