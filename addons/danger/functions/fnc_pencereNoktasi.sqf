#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * PENCEREDEN GORULEN IC BOLGE (v8.604; kullanici: 'bilinen duvar arkasi atesi icin pencere yonune ates acsinlar, gorusunun oldugu ic bolgeye'): bilinen dusman konumu (_aim) bir binanin icindeyse ve asker -> _aim hatti duvarla KAPALIYSA,
 * ayni binanin _aim'e en yakin pozisyonlari (buildingPos, 9 m icinde, ayni kat +-3 m) taranir; askerin gozunden o noktaya (1.2 m yukseklik) GORUS hatti (VIEW) ACIK ve ates hatti acik olan (pencere / kapi araligindan gorulen) EN YAKIN nokta dondurulur.
 * Cagiran: fnc_atisUstunlugu (bastirma hedefi duvarla kapaliyken). Birim basina 3 sn onbellek (taraf basina ucuz: en cok 12 aday).
 *
 * Arguments:
 * 0: Asker <OBJECT>
 * 1: Bilinen dusman konumu (AGL) <ARRAY>
 *
 * Return Value: Gorulen ic nokta (AGL) ya da [] <ARRAY>
 * Public: No
*/

params [["_u", objNull, [objNull]], ["_aim", [], [[]]]];
if (isNull _u || {_aim isEqualTo []}) exitWith {[]};
private _onb = _u getVariable [QGVAR(pencereOnb), [-99, []]];
if ((time - (_onb select 0)) < 3 && {((_onb select 1) isEqualTo []) || {((_onb select 1) distance2D _aim) < 9}}) exitWith { _onb select 1 };
private _b = nearestBuilding _aim;
private _sonuc = [];
if (!isNull _b && {(_b distance2D _aim) < 14}) then {
    private _adaylar = ((_b buildingPos -1) select {(_x distance2D _aim) <= 9 && {(abs ((_x select 2) - (_aim select 2))) <= 3}});
    _adaylar = [_adaylar, [], {_x distance2D _aim}, "ASCEND"] call BIS_fnc_sortBy;
    private _eP = eyePos _u;
    {
        private _p = _x;
        if (((lineIntersectsSurfaces [_eP, AGLToASL (_p vectorAdd [0, 0, 1.2]), _u, objNull, true, 1, "VIEW", "NONE"]) isEqualTo []) && {[_u, _p] call FUNC(atesHatiAcik)}) exitWith { _sonuc = _p; };
    } forEach (_adaylar select [0, 12]);
};
_u setVariable [QGVAR(pencereOnb), [time, _sonuc]];
_sonuc
