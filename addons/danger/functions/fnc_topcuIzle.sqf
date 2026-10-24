#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * TOPCU IZLEME (v8.338) — topcu / havan aracina bir kez 'Fired' olay isleyicisi ekler:
 *   - son atis zamanini tutar (lambs_danger_dtSonAtis): taciz atisi mesgul topu secmesin;
 *   - 'lambs_danger_dtIzle' = true iken sonraki mermiyi takip eder ve DUSME NOKTASINI (AGL) lambs_danger_dtSplash = [zaman, konum] olarak yazar.
 *     Gozlemci (dron) bu 'splash' noktasini hedefle karsilastirip duzeltme verir (adjust fire). Kitaptaki 'SPLASH' haberi: TC 3-21.76 Tablo 3-6 (call-for-fire ornegi: SHOT / SPLASH).
 *     Son konum, mermi silindiginde son hiz vektoruyla yere kadar tasinir (kare araligi hatasini azaltmak icin).
 *
 * Arguments:
 * 0: Topcu araci <OBJECT>
 *
 * Return Value: Isleyici yeni eklendi mi <BOOL>
 * Public: No
*/

params [["_v", objNull, [objNull]]];
if (isNull _v || {_v getVariable [QGVAR(dtEH), false]}) exitWith {false};
_v setVariable [QGVAR(dtEH), true];
_v addEventHandler ["Fired", {
    params ["_u", "", "", "", "", "", "_p"];
    _u setVariable [QGVAR(dtSonAtis), time];
    if (_u getVariable [QGVAR(dtIzle), false]) then {
        _u setVariable [QGVAR(dtIzle), false];
        [_u, _p] spawn {
            params ["_uu", "_pp"];
            private _son = [];
            private _vel = [0, 0, 0];
            while {!isNull _pp} do {
                _son = getPosASL _pp;
                _vel = velocity _pp;
                sleep 0.02;
            };
            if (_son isNotEqualTo []) then {
                private _sp = ASLToAGL _son;
                if ((_vel select 2) < -5 && {(_sp select 2) > 0.5}) then {
                    private _t = (_sp select 2) / (-(_vel select 2));
                    _sp = [(_sp select 0) + (_vel select 0) * _t, (_sp select 1) + (_vel select 1) * _t, 0];
                };
                _uu setVariable [QGVAR(dtSplash), [time, _sp]];
            };
        };
    };
}];
true
