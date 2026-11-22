#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * ROTA RISKI (v8.735; kullanici: '1 2 3 yap'; madde 2): bir hareket hattinin (A -> B) dusman goz noktalarindan ACIKLIGINI sayar. Hat 3 noktada orneklenir (%33, %66, %100; kosan govde 1.2 m); her ornek icin her goz noktasindan
 * FIRE LOD hatti acik + arazi acik ise o goz noktasinin agirligi risk'e eklenir. Siper seciminde (acikSiper: oraya KOSARKEN acikta kalir miyim?) ve bounding bacak seciminde (bndPlan) kullanilir.
 *
 * Arguments:
 * 0: Baslangic AGL <ARRAY>
 * 1: Varis AGL <ARRAY>
 * 2: Goz noktalari [[ASL, agirlik], ...] <ARRAY>
 * 3: Yok sayilacak nesne (asker) <OBJECT>
 *
 * Return Value: Risk (0 = hat tamamen gizli) <NUMBER>
 * Public: No
*/

params [["_from", [], [[]]], ["_to", [], [[]]], ["_eyes", [], [[]]], ["_ign", objNull, [objNull]]];
if ((count _from) < 2 || {(count _to) < 2} || {_eyes isEqualTo []}) exitWith {0};
private _r = 0;
{
    private _f = _x;
    private _pt = [(_from select 0) + (((_to select 0) - (_from select 0)) * _f), (_from select 1) + (((_to select 1) - (_from select 1)) * _f), 0];
    private _pa = (AGLToASL _pt) vectorAdd [0, 0, 1.2];
    {
        _x params ["_ge", "_w"];
        if (((lineIntersectsSurfaces [_ge, _pa, objNull, _ign, true, 1, "FIRE", "NONE"]) isEqualTo []) && {!(terrainIntersectASL [_ge, _pa])}) then { _r = _r + _w; };
    } forEach _eyes;
} forEach [0.33, 0.66, 1];
_r
