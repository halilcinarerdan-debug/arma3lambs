#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * BASTIRMA ATES HATTI ACIK MI (v8.372; kullanici: 'askerler bazen duvar arkasini supressliyorlar').
 *
 * NEDEN: LAMBS shouldSuppressPosition hedefin 4-5 m USTUNE bakiyor (fnc_atisUstunlugu: aASL + 4 m) -> 3-4 m duvar / bina / konteyner hat'i kapatmiyor sayiliyor ve asker duvara mermi bosaltiyor.
 *   Diger bastirma noktalari (ates-hareket taban atesi, hucum hazirligi, kumanda destegi, pusu tepkisi) hic hat kontrolu yapmiyordu.
 * KURAL: gozden hedefin 1 m ustune (govde hizasi) FIRE LOD isini; insan vurusu sayilmaz; atici cevresinde 2.5 m icindeki vurus YALNIZ goz hizinin 0.45 m altindaysa (alcak kendi siperi) sayilmaz (v8.403: eskiden 2.5 m icindeki her vurus yok sayiliyordu -> duvar arkasi atis);
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
    if (isNull _obj || {_obj isKindOf "CAManBase"} || {(_pos distance _hASL) < 1.5}) then { continue };
    // v8.403 DUVARIN ARKASINDAN BASTIRMA (kullanici: 'combata gectiler sonra duvar arkasi ates ediyorlar, supress de sorun var'; v8.372 / v8.386 duzeltmesi yetmedi):
    //   eski kural atici 2.5 m icindeki HER vurusu 'kendi siperi' sayip yok sayiyordu -> ACIK-SIPER'in duvarin 0.55 m arkasina gizledigi asker icin hat 'acik' cikiyor, bastirma atesi 0.5 m onundeki duvara gidiyordu.
    //   Yeni: yakin (< 2.5 m) vurus YALNIZ goz hizindan 0.45 m'den daha ASAGIDAysa (alcak kendi siperi / zemin pürüzü) yok sayilir; goz hizinda (duvarin tepesi / govdesi) vurus = duvarin arkasindayiz -> hat KAPALI.
    if ((_pos distance _eye) < 2.5 && {(_pos select 2) < ((_eye select 2) - 0.45)}) then { continue };
    _kapali = true;
    if (_kapali && {(_pos distance _eye) < 2.5} && {(missionNamespace getVariable ["lambs_danger_atesHatiLogN", 0]) < 12}) then {
        missionNamespace setVariable ["lambs_danger_atesHatiLogN", (missionNamespace getVariable ["lambs_danger_atesHatiLogN", 0]) + 1];
        diag_log format ["[ATES-HATI] %1 (%2) | YAKIN DUVAR %3 (%4 m, yukseklik %5 m) -> bastirma hatti KAPALI (eski kural 'kendi siperi' sayip atesi duvara bosaltiyordu)", name _u, groupId (group _u), [typeOf _obj, (getModelInfo _obj) select 0] select ((typeOf _obj) isEqualTo ""), (_pos distance _eye) toFixed 1, ((_pos select 2) - ((getPosASL _u) select 2)) toFixed 1];
    };
    break;
} forEach _vur;
!_kapali
