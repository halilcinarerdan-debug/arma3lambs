#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * Grubu 3 fire team'e boler: Fire Support / Maneuver / Reserve
 * NATO doktrini + dinamik boyut + ROL BAZLI dagitim
 *
 *   FSE      : MG -> nisanci -> AT (atis ussu), eksik kalirsa tufeklilerle tamamlanir
 *   MANEUVER : lider + tufekliler (artan agir silahlar yer varsa)
 *   RESERVE  : saglikci + artanlar
 *
 * Arguments:
 * 0: group <GROUP> or leader <OBJECT>
 *
 * Return Value:
 * [FSE <ARRAY>, Maneuver <ARRAY>, Reserve <ARRAY>]
 *
 * Public: No
*/

params [["_group", grpNull, [grpNull, objNull]]];
if (_group isEqualType objNull) then {_group = group _group;};
if (isNull _group) exitWith {[[], [], []]};

private _units = (units _group) select {alive _x && {isNull objectParent _x}};
private _count = count _units;
if (_count < 4) exitWith {[_units, [], []]};

// ---------------------------------------------------------------------------
// DINAMIK BOYUT TABLOSU (NATO doktrini)
// ---------------------------------------------------------------------------
private _fseSize = 0;
private _mvrSize = 0;

switch (true) do {
    case (_count >= 12): { _fseSize = 4; _mvrSize = 4; };
    case (_count >= 9):  { _fseSize = 3; _mvrSize = 3; };
    case (_count >= 7):  { _fseSize = 3; _mvrSize = 4; };
    case (_count >= 5):  { _fseSize = 2; _mvrSize = 3; };
    default              { _fseSize = 2; _mvrSize = 2; };
};

// ---------------------------------------------------------------------------
// ROL KATEGORIZE (getUnitRole: MG kapasiteyle tespit edilir)
// ---------------------------------------------------------------------------
private _leader = leader _group;
private _mgs = [];
private _marks = [];
private _ats = [];
private _medics = [];
private _rifles = [];

{
    if (_x isNotEqualTo _leader) then {
        switch ([_x] call FUNC(getUnitRole)) do {
            case "MG":       { _mgs pushBack _x; };
            case "MARKSMAN": { _marks pushBack _x; };
            case "AT":       { _ats pushBack _x; };
            case "MEDIC":    { _medics pushBack _x; };
            default          { _rifles pushBack _x; };
        };
    };
} forEach _units;

private _fse = [];
private _maneuver = [];
private _reserve = [];

// 1) Lider maneuver'a
if (_leader in _units) then {
    _maneuver pushBack _leader;
};

// 2) FSE = atis ussu: MG -> nisanci -> AT
{
    private _liste = _x;
    while {(count _fse) < _fseSize && {_liste isNotEqualTo []}} do {
        _fse pushBack (_liste deleteAt 0);
    };
} forEach [_mgs, _marks, _ats];

// 3) Maneuver = tufekliler
while {(count _maneuver) < _mvrSize && {_rifles isNotEqualTo []}} do {
    _maneuver pushBack (_rifles deleteAt 0);
};

// 3b) Maneuver'da hala yer varsa artan agir silahlar (AT -> nisanci -> MG)
{
    private _liste = _x;
    while {(count _maneuver) < _mvrSize && {_liste isNotEqualTo []}} do {
        _maneuver pushBack (_liste deleteAt 0);
    };
} forEach [_ats, _marks, _mgs];

// 3c) FSE hala eksikse (MG/nisanci yok) kalan tuflekliler son siradan tamamlar
while {(count _fse) < _fseSize && {_rifles isNotEqualTo []}} do {
    _fse pushBack (_rifles deleteAt ((count _rifles) - 1));
};

// 4) Reserve = artan (saglikci dahil)
_reserve = _medics + _rifles + _ats + _marks + _mgs;

// 5) Guvenlik: FSE veya Maneuver bos/az ise reserve'den ekle
if (_fse isEqualTo [] && {_reserve isNotEqualTo []}) then {
    _fse pushBack (_reserve deleteAt 0);
};
if ((count _maneuver) < 2 && {_reserve isNotEqualTo []}) then {
    _maneuver pushBack (_reserve deleteAt 0);
};

// Debug
if (EGVAR(main,debug_functions)) then {
    diag_log format [
        "[FIRETEAM] %1 (%2 kisi) -> FSE:%3 (MG:%4) MVR:%5 RES:%6",
        groupId _group, _count, count _fse,
        {([_x] call FUNC(getUnitRole)) isEqualTo "MG"} count _fse,
        count _maneuver, count _reserve
    ];
};

[_fse, _maneuver, _reserve]
