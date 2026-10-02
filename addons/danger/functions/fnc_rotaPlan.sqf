#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * TAKTIK ROTA PLANLAMA v1 (gizli yaklasma) — VBS4 "tactical route planning" fikrinin Arma 3 karsiligi.
 *
 * Arma 3'te navmesh yok: motor yalniz ara nokta verilince kendi yolunu secer. Bu fonksiyon, dusmana yaklasirken
 * dogrudan hat yerine ORTULU (gorus hatti kesilen, agac / cali / duvar / cukur arkasi) yone SAPMA ACISI secer.
 * Bounding atilimlari (_kosanHareket) bu acinin etrafinda yelpaze kurar -> grup "kisa yol" yerine korunakli hatti izler.
 *
 * Yontem: aday sapma acilari [0, +-20, +-40, +-60]. Her aday icin IKI BACAKLI plan (grup -> p1 -> p2, p2 hedefe donuk):
 *   maruziyet = dusman gozunden gorulen ornek orani (6 m'de bir ray)      -> -40 x maruziyet
 *   ortu      = nokta cevresindeki agac / cali / duvar / kaya (en fazla 4)  -> +2 x adet
 *   ilerleme  = hedefe yaklasma orani                                       -> +10 x oran
 *   sapma     = -0.15 x |aci|; bina icine dusme -12; su -500
 * Dogrudan hatta gore kazanc < 8 puansa SAPMA YOK (0 doner: gereksiz dolanma yok).
 * Onbellek: 20 sn ya da hedef 40 m oynarsa yenilenir. Kapatma: lambs_danger_rotaV1 = false.
 *
 * Arguments:
 * 0: Grup <GROUP>
 * 1: Hedef pozisyon <ARRAY>
 *
 * Return Value:
 * Sapma acisi (derece, +sag / -sol; hedefe dogru hatta gore) <NUMBER>
 *
 * Public: No
*/

params [["_g", grpNull, [grpNull]], ["_hedef", [0, 0, 0], [[]]]];

if (isNull _g || {!(missionNamespace getVariable ["lambs_danger_rotaV1", true])}) exitWith {0};

private _onbellek = _g getVariable [QGVAR(rotaOnbellek), []];
if (_onbellek isNotEqualTo [] && {(time - (_onbellek select 0)) < 20} && {((_onbellek select 1) distance2D _hedef) < 40}) exitWith { _onbellek select 2 };

private _ld = leader _g;
if (isNull _ld || {!alive _ld}) exitWith {0};

private _t0 = diag_tickTime;
private _c = getPosATL _ld;
private _d = _c distance2D _hedef;
// yakin mesafede (CQB / hucum) rota anlamsiz; cok uzakta ise bounding zaten uzun atilim yapar
if (_d < 90 || {_d > 600}) exitWith {
    _g setVariable [QGVAR(rotaOnbellek), [time, +_hedef, 0]];
    0
};

private _bacak = ((_d * 0.35) max 30) min 70;
private _eASL = AGLToASL (_hedef vectorAdd [0, 0, 1.6]);

// bir bacagin maruziyeti: [a -> b] hatti boyunca 6 m'de bir ornek, dusmanin gordugu oran
private _maruz = {
    params ["_a", "_b"];
    private _n = ((floor ((_a distance2D _b) / 6)) max 1);
    private _gorulen = 0;
    for "_k" from 1 to _n do {
        private _p = _a vectorAdd ((_b vectorDiff _a) vectorMultiply (_k / _n));
        private _pASL = AGLToASL (_p vectorAdd [0, 0, 1.2]);
        if (!(terrainIntersectASL [_eASL, _pASL]) && {!(lineIntersects [_eASL, _pASL, objNull, objNull])}) then { _gorulen = _gorulen + 1; };
    };
    _gorulen / _n
};

private _puanla = {
    params ["_aci"];
    private _yon = (_c getDir _hedef) + _aci;
    private _p1 = _c getPos [_bacak, _yon];
    if (surfaceIsWater _p1) exitWith {[-9999, 1, 0]};
    private _p2 = _p1 getPos [_bacak, _p1 getDir _hedef];
    if (surfaceIsWater _p2) then { _p2 = _p1; };
    private _e1 = [_c, _p1] call _maruz;
    private _e2 = [_p1, _p2] call _maruz;
    private _e = (_e1 + _e2) / 2;
    private _ortu = (count (nearestTerrainObjects [_p1, ["TREE", "BUSH", "SMALL TREE", "HIDE", "WALL", "FENCE", "ROCK"], 8, false, true])) min 4;
    private _bina = (count (nearestTerrainObjects [_p1, ["BUILDING", "HOUSE"], 6, false, true])) > 0;
    private _ilerleme = ((_c distance2D _hedef) - (_p2 distance2D _hedef)) / (2 * _bacak);
    private _s = (-40 * _e) + (2 * _ortu) + (10 * _ilerleme) - (0.15 * (abs _aci)) - ([0, 12] select _bina);
    [_s, _e, _ortu]
};

private _direkt = [0] call _puanla;
private _enIyiAci = 0;
private _enIyi = _direkt;
{
    private _r = [_x] call _puanla;
    if ((_r select 0) > (_enIyi select 0)) then { _enIyi = _r; _enIyiAci = _x; };
} forEach [20, -20, 40, -40, 60, -60];

// yeterli kazanc yoksa dogrudan (dolanma yok)
if (((_enIyi select 0) - (_direkt select 0)) < 8) then { _enIyiAci = 0; _enIyi = _direkt; };

_g setVariable [QGVAR(rotaOnbellek), [time, +_hedef, _enIyiAci]];
_g setVariable [QGVAR(rotaAci), _enIyiAci];

// tani: ilk 80 plan
if (isNil "lambs_danger_rotaLogN") then { lambs_danger_rotaLogN = 0; };
if (lambs_danger_rotaLogN < 80) then {
    lambs_danger_rotaLogN = lambs_danger_rotaLogN + 1;
    diag_log format [
        "[ROTA] %1 | hedef:%2 m | sapma:%3 | maruziyet direkt:%4%% -> plan:%5%% | ortu:%6 | sure:%7 ms",
        groupId _g, round _d, _enIyiAci,
        round (((_direkt select 1)) * 100), round (((_enIyi select 1)) * 100), _enIyi select 2,
        round ((diag_tickTime - _t0) * 1000)
    ];
};

_enIyiAci
