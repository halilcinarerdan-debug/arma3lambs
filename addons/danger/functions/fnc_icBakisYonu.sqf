#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * BINA ICI BAKIS YONU (v8.614; kullanici: 'hala gelis yonune degil kor noktaya bakiyorlardi; merdivene falan gelis yonune onem gostersinler'; RPT b24f0608: duran askerlerin yalniz %5'i dusman yonune <= 30 derece, %29'u 120-150 derece ters bakiyordu):
 * Bina ICINDEKI asker icin namlu yonu: duvara / kor noktaya degil, dusmanin GELEBILECEGI acik yone.
 *   1) KAT GECISI (merdiven): bilinen en yakin dusman >= 2.2 m farkli katta ise, ona dogru giden en yakin kat gecis noktasi (ust / alt kat bina pozisyonu, 2-5 m yukseklik farki, <= 10 m) -> nokta + 1.4 m (merdiven basina nisan)
 *   2) ACIK YON (kapi / pencere / koridor): tehdit yonune en yakin gorus ACIK yon (bina ici kisa mesafe 12 / 6 m, fnc_bakisAcikYon); hicbiri yoksa [] (bakis serbest)
 * Cagiranlar: fnc_sektorBakis, fnc_gelisYonu (bina ici dallar; CBA icBakisKose acikken ses yonune / dusman yonune DEGIL buraya bakilir).
 *
 * Arguments:
 * 0: Asker <OBJECT>
 * 1: Tehdit yonu (derece) <NUMBER>
 *
 * Return Value: doWatch konumu ya da [] <ARRAY>
 * Public: No
*/

params [["_u", objNull, [objNull]], ["_yon", 0, [0]]];
if (isNull _u) exitWith {[]};
private _sonuc = [];
private _en = _u findNearestEnemy _u;
if (!isNull _en && {alive _en}) then {
    private _uz = (getPosATL _u) select 2;
    private _dz = ((getPosATL _en) select 2) - _uz;
    if ((abs _dz) >= 2.2) then {
        private _b = nearestBuilding _u;
        private _ad = if (isNull _b) then {[]} else { (_b buildingPos -1) select { private _d = (_x select 2) - _uz; ((_d * _dz) > 0) && {(abs _d) >= 2} && {(abs _d) <= 5} && {(_x distance2D _u) <= 10} } };
        if (_ad isNotEqualTo []) then {
            _ad = [_ad, [], {_x distance2D _u}, "ASCEND"] call BIS_fnc_sortBy;
            _sonuc = (_ad select 0) vectorAdd [0, 0, 1.4];
        };
    };
};
if (_sonuc isEqualTo []) then {
    private _by = [_u, _yon, [0, 25, -25, 50, -50, 75, -75], [12, 6]] call FUNC(bakisAcikYon);
    if (_by > -900) then { _sonuc = (eyePos _u) getPos [20, _by]; };
};
_sonuc
