#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * BAKIS ACIK YON (v8.500r; kullanici: 'askerler bazen kor noktalara / 1 m onlerindeki duvara bakiyor'): verilen yonde (+ yanlara kayarak) 40 m, olmazsa 20 m gorus ACIK ilk yonu dondurur.
 * fnc_sektorBakis ayni mantigi (v8.376) kendi icinde kullaniyordu; yurume halindeki yan emniyet (yanGuvenlik) ve arka emniyet (rearGuard) bu kontrolu yapmiyordu.
 *
 * Arguments:
 * 0: Asker <OBJECT>
 * 1: Istenen yon (derece) <NUMBER>
 * 2: Kayma dizisi <ARRAY> (varsayilan [0, 25, -25, 50, -50, 75, -75])
 *
 * Return Value: Acik yon (derece) ya da -999 (hicbiri acik degil: asker bakisi serbest birakilmali) <NUMBER>
 * Public: No
*/

params [["_u", objNull, [objNull]], ["_yon", 0, [0]], ["_kay", [0, 25, -25, 50, -50, 75, -75], [[]]]];
if (isNull _u) exitWith {-999};
private _eye = eyePos _u;
private _sec = -999;
{
    private _m = _x;
    {
        private _b = _yon + _x;
        private _p = _eye vectorAdd [(sin _b) * _m, (cos _b) * _m, 0];
        if (!(lineIntersects [_eye, _p, _u, objNull]) && {!(terrainIntersectASL [_eye, _p])}) exitWith { _sec = _b; };
    } forEach _kay;
    if (_sec > -900) exitWith {};
} forEach [40, 20];
_sec
