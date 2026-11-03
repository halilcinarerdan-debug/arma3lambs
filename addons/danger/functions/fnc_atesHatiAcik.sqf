#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * BASTIRMA ATES HATTI ACIK MI (v8.372; kullanici: 'askerler bazen duvar arkasini supressliyorlar').
 *
 * NEDEN: LAMBS shouldSuppressPosition hedefin 4-5 m USTUNE bakiyor (fnc_atisUstunlugu: aASL + 4 m) -> 3-4 m duvar / bina / konteyner hat'i kapatmiyor sayiliyor ve asker duvara mermi bosaltiyor.
 *   Diger bastirma noktalari (ates-hareket taban atesi, hucum hazirligi, kumanda destegi, pusu tepkisi) hic hat kontrolu yapmiyordu.
 * KURAL: gozden hedefin 1 m ustune (govde hizasi) FIRE LOD isini; atici cevresinde 2.5 m icindeki vurus (kendi siperi) ve insan vurusu sayilmaz;
 *   baska nesne (duvar / bina / enkaz / kaya) vurursa ya da arazi hatti keserse hat KAPALI. Calma / yaprak (FIRE LOD yok) hatti kapatmaz.
 *
 * Arguments:
 * 0: Atici <OBJECT>
 * 1: Hedef <OBJECT veya POSITION (AGL)>
 *
 * Return Value: Hat acik mi <BOOL>
 *
 * Public: No
*/
params ["_u", "_hedef"];
private _hASL = if (_hedef isEqualType objNull) then { (getPosASL _hedef) vectorAdd [0, 0, 1] } else { (AGLToASL _hedef) vectorAdd [0, 0, 1] };
private _eye = eyePos _u;
if (_eye distance _hASL < 3) exitWith {true};
if (terrainIntersectASL [_eye, _hASL]) exitWith {false};
private _vur = lineIntersectsSurfaces [_eye, _hASL, _u, [objNull, _hedef] select (_hedef isEqualType objNull), true, 4, "FIRE", "NONE"];
private _kapali = false;
{
    _x params ["_pos", "_n", "_obj"];
    if (!isNull _obj && {!(_obj isKindOf "CAManBase")} && {(_pos distance _eye) >= 2.5} && {(_pos distance _hASL) >= 1.5}) exitWith { _kapali = true; };
} forEach _vur;
!_kapali
