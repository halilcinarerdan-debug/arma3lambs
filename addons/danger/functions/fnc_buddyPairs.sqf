#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * BUDDY CIFTLERI — NATO/USMC doktrini: asker ASLA tek basina dolasmaz, 2'li calisir.
 *
 * Eslestirme: en guclu + en zayif (SNAKE) -> her cift bir agir silah/lider + bir tufekli.
 * Tek sayida asker: ortadaki son cifte eklenir (uclu cift). Tek asker kalirsa [[asker]].
 * Oncelik skoru: MG 100 > AT 80 > nisanci 70 > saglikci 50; lider +60.
 *
 * Arguments:
 * 0: birimler <ARRAY of OBJECT>
 *
 * Return Value:
 * Ciftler <ARRAY>: [[a, b], [c, d, e], ...]  (her cift icinde index 0 = en guclu; 2'li ciftte son = en zayif,
 *   3'lu ciftte index 1 = en zayif, index 2 = ortadaki (orta guc) asker)
 *
 * Example:
 * [units _group] call lambs_danger_fnc_buddyPairs;
 *
 * Public: No
*/

params [["_units", [], [[]]]];

private _alive = _units select {alive _x};
if (_alive isEqualTo []) exitWith {[]};
if ((count _alive) < 2) exitWith {[_alive]};

// Fonksiyon kayitli degilse (XEH_PREP eksik) herkes TUFEKLI sayilir
private _rolFn = missionNamespace getVariable ["lambs_danger_fnc_getUnitRole", {"RIFLE"}];

// ---------------------------------------------------------------------------
// ONCELIK SKORU
// ---------------------------------------------------------------------------
private _skorlu = _alive apply {
    private _u = _x;
    private _skor = switch ([_u] call _rolFn) do {
        case "MG":       {100};
        case "AT":       {80};
        case "MARKSMAN": {70};
        case "MEDIC":    {50};
        default          {0};
    };
    if (_u isEqualTo (leader (group _u))) then { _skor = _skor + 60; };
    [_skor, _u]
};

// Skora gore AZALAN sirala (nesne eslesmesinde sort'a guvenme: elle secim)
private _sirali = [];
while {_skorlu isNotEqualTo []} do {
    private _enIyi = 0;
    private _enIyiSkor = -1;
    {
        if ((_x select 0) > _enIyiSkor) then {
            _enIyiSkor = _x select 0;
            _enIyi = _forEachIndex;
        };
    } forEach _skorlu;
    _sirali pushBack ((_skorlu select _enIyi) select 1);
    _skorlu deleteAt _enIyi;
};

// ---------------------------------------------------------------------------
// SNAKE ESLESTIRME: en guclu + en zayif
// ---------------------------------------------------------------------------
private _ciftler = [];
private _n = count _sirali;
for "_p" from 0 to ((floor (_n / 2)) - 1) do {
    _ciftler pushBack [_sirali select _p, _sirali select (_n - 1 - _p)];
};
if ((_n % 2) isEqualTo 1) then {
    (_ciftler select ((count _ciftler) - 1)) pushBack (_sirali select (floor (_n / 2)));
};

_ciftler
