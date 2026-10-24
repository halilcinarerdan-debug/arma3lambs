#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * HEDEF KUMELEME (v8.338) — gozlemlenen dusman nesnelerini 60 m'lik kumelere ayirir (dron gozlemli atis ve taciz bellegi icin).
 *   Degerler [T]: adam 1; hafif / yumusak arac 2.5; zirhli arac (Tank / APC) 3; statik silah 2; topcu / havan 4. Ic araca binmis adam ayrica sayilmaz (arac sayilir).
 *   Dost, sivil, esir (captive), SILAHSIZ asker (v8.344: teslim / yem), muretttebatsiz arac ve olu nesne sayilmaz.
 *
 * Arguments:
 * 0: Nesneler <ARRAY>
 * 1: Ates eden taraf <SIDE>
 *
 * Return Value: [[merkez <ARRAY>, uyeler <ARRAY>, deger <NUMBER>, adam <NUMBER>, arac <NUMBER>], ...] — degere gore azalan <ARRAY>
 * Public: No
*/

params [["_nesneler", [], [[]]], ["_taraf", sideUnknown, [sideUnknown]]];

private _aday = _nesneler select {
    !isNull _x && {alive _x} && {!(captive _x)}
    && {
        if (_x isKindOf "CAManBase") then {
            isNull objectParent _x && {(_taraf getFriend (side (group _x))) < 0.6} && {(side (group _x)) isNotEqualTo civilian} && {((primaryWeapon _x) isNotEqualTo "") || {(secondaryWeapon _x) isNotEqualTo ""} || {(handgunWeapon _x) isNotEqualTo ""}}
        } else {
            _x isKindOf "LandVehicle" && {
                private _mur = (crew _x) select {alive _x};
                _mur isNotEqualTo [] && {(_taraf getFriend (side (group (_mur select 0)))) < 0.6} && {(side (group (_mur select 0))) isNotEqualTo civilian}
            }
        }
    }
};

private _agirlik = {
    if (_this isKindOf "CAManBase") exitWith {1};
    if ((getNumber (configOf _this >> "artilleryScanner")) > 0) exitWith {4};
    if (_this isKindOf "StaticWeapon") exitWith {2};
    if (_this isKindOf "Tank" || {_this isKindOf "APC_Tracked_01_base_F"} || {_this isKindOf "Wheeled_APC_F"}) exitWith {3};
    2.5
};

private _kalan = +_aday;
private _kumeler = [];
while {_kalan isNotEqualTo []} do {
    private _en = _kalan select 0;
    private _enN = -1;
    {
        private _o = _x;
        private _n = {(_x distance2D _o) < 60} count _kalan;
        if (_n > _enN) then { _enN = _n; _en = _o; };
    } forEach _kalan;
    private _uye = _kalan select {(_x distance2D _en) < 60};
    _kalan = _kalan - _uye;
    private _sx = 0;
    private _sy = 0;
    private _deger = 0;
    private _adam = 0;
    private _arac = 0;
    {
        private _p = getPosATL _x;
        _sx = _sx + (_p select 0);
        _sy = _sy + (_p select 1);
        _deger = _deger + (_x call _agirlik);
        if (_x isKindOf "CAManBase") then { _adam = _adam + 1; } else { _arac = _arac + 1; };
    } forEach _uye;
    private _c = count _uye;
    _kumeler pushBack [[_sx / _c, _sy / _c, 0], _uye, _deger, _adam, _arac];
};
_kumeler = [_kumeler, [], {_x select 2}, "DESCEND"] call BIS_fnc_sortBy;
_kumeler
