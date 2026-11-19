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
    // v8.632 EN YAKIN ACIK YON (kullanici: 'bilinen yone ve gelis yonune bakis pek iyi degil'; RPT 2857f308: dusman yonu 351 -> secilen yon 109 (118 derece sapma), 350 -> 141, 40 -> 321; eski +-75 derece penceresi disinda kalinca 12 yonlu 'en uzun acik yon' dusman yonunun tam tersini seciyordu):
    //   24 yon (15 derece), her yonde 12 / 8 / 5 / 3 m gorus hatti acik mi; acik (>= 3 m) yonlerden skor = dusman yonune aci farki - 1.5 x acik mesafe (kapi / koridor hafif bonus) EN DUSUK olan secilir -> hep tehdide en yakin ACIK yon
    private _eye = eyePos _u;
    private _enB = -999;
    private _enS = 1e9;
    for "_k" from 0 to 23 do {
        private _b = _k * 15;
        private _m = 0;
        { if (!(lineIntersects [_eye, _eye vectorAdd [(sin _b) * _x, (cos _b) * _x, 0], _u, objNull])) exitWith { _m = _x; }; } forEach [12, 8, 5, 3];
        if (_m >= 3) then {
            private _s = (abs ((_b - _yon + 540) mod 360 - 180)) - (1.5 * _m);
            if (_s < _enS) then { _enS = _s; _enB = _b; };
        };
    };
    if (_enB > -900) then { _sonuc = _eye getPos [20, _enB]; };
};
_sonuc
