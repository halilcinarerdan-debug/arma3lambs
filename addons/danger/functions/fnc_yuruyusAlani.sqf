#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * YURUNEBILIR ALAN KAYDI (v8.331) — Eden 'ELITE Yurunebilir Alan' modul nesnelerinden alan listesi (10 sn onbellek, her makinede ayri okunur; Zeus'ta birakilan alan birkac sn icinde gorunur).
 * Modlar:
 *   "LISTE"           -> [[merkez, a, b, yon, dikdortgenMi, modul], ...]
 *   "MESAFE", konum   -> [indeks, mesafe] : konumun en yakin alana mesafesi (0 = icinde); alan yoksa [-1, 1e9]
 *   "MESAFE-ALAN", konum, indeks -> belirli alana mesafe
 *
 * Arguments:
 * 0: Mod <STRING>
 * 1: Konum <ARRAY>
 * 2: Indeks <NUMBER>
 *
 * Return Value: moda gore
 * Public: No
*/

params [["_mod", "LISTE", [""]], ["_p", [0, 0, 0], [[]]], ["_idx", -1, [0]]];

if (time > ((missionNamespace getVariable ["lambs_danger_yuruyusT", -99]) + 10)) then {
    lambs_danger_yuruyusT = time;
    lambs_danger_yuruyusL = (entities [[QGVAR(YuruyusAlani)], [], false, false]) apply {
        private _al = _x getVariable ["objectArea", [10, 4, 0, true, -1]];
        [getPosATL _x, (_al param [0, 10]) max 1, (_al param [1, 4]) max 1, _al param [2, 0], _al param [3, true], _x]
    };
};
private _l = missionNamespace getVariable ["lambs_danger_yuruyusL", []];
if (_mod isEqualTo "LISTE") exitWith {_l};

private _uzak = {
    params ["_z", "_q"];
    _z params ["_c", "_a", "_b", "_dir", "_rect"];
    private _d = [(_q select 0) - (_c select 0), (_q select 1) - (_c select 1)];
    private _lx = ((_d select 0) * (sin (90 + _dir))) + ((_d select 1) * (cos (90 + _dir)));
    private _ly = ((_d select 0) * (sin _dir)) + ((_d select 1) * (cos _dir));
    if (_rect) then {
        private _ex = ((abs _lx) - _a) max 0;
        private _ey = ((abs _ly) - _b) max 0;
        sqrt ((_ex * _ex) + (_ey * _ey))
    } else {
        private _v = sqrt (((_lx / _a) ^ 2) + ((_ly / _b) ^ 2));
        ((_v - 1) max 0) * ((_a + _b) / 2)
    }
};

if (_mod isEqualTo "MESAFE-ALAN") exitWith {
    if (_idx < 0 || {_idx >= count _l}) exitWith {1e9};
    [_l select _idx, _p] call _uzak
};
// MESAFE
private _en = [-1, 1e9];
{
    private _dm = [_x, _p] call _uzak;
    if (_dm < (_en select 1)) then { _en = [_forEachIndex, _dm]; };
} forEach _l;
_en
