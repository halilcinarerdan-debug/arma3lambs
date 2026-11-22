#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * VARIS NOKTASINI SIPERE OTURT (v8.756; kullanici: '1 ve 2 yap'; RPT da79e331: gercek siper %0, %91-93 'uzak engel': asker sicrama / geri cekilme bacagini ACIKTA bitirip sonra siper ariyordu):
 * Verilen varis noktasinin R (12) m'sinde SERT nesne (duvar / cit / bina / kaya / bunker / harabe; nearestTerrainObjects) arar; her nesne icin dusmana GORE ARKA nokta (nesne merkezi + yaricap + 0.8 m, dusmandan uzaga)
 * hesaplanir; arka noktanin dusman gozunden (1.6 m) VIEW LOD hatti nesneye carpiyor VE FIRE LOD hatti nesneye carpiyor (mermi de durur) ise aday olur; _kabul kodu (ilerleme / uzaklasma kurali) onaylamali.
 * En yakin gecerli aday doner; yoksa []. Su / bina ici (insideBuilding > 0.5) noktalar elenir.
 * CBA: lambs_danger_bndSiperSnap (varsayilan ACIK), bndSiperSnapM (12). Kullanan: fnc_bndPlan (sicrama bacaklari), fnc_tacticsRetreat (geri cekilme WP'leri).
 *
 * Arguments:
 * 0: Varis noktasi (AGL) <ARRAY>
 * 1: Dusman / tehdit konumu (AGL) <ARRAY>
 * 2: Arama yaricapi (m) <NUMBER>
 * 3: Kabul kodu: [aday] -> BOOL <CODE> (varsayilan hepsini kabul)
 *
 * Return Value: Yeni varis noktasi (AGL) ya da [] <ARRAY>
 *
 * Public: No
*/

params [["_pt", [], [[]]], ["_dus", [], [[]]], ["_R", 12, [0]], ["_kabul", {true}, [{}]]];
if (_pt isEqualTo [] || {_dus isEqualTo []} || {!(missionNamespace getVariable ["lambs_danger_bndSiperSnap", true])}) exitWith {[]};
private _eASL = AGLToASL [_dus select 0, _dus select 1, 1.6];
private _objs = nearestTerrainObjects [_pt, ["WALL", "FENCE", "BUILDING", "HOUSE", "ROCK", "ROCKS", "BUNKER", "RUIN", "FORTRESS", "CHURCH", "CHAPEL"], _R, true, true];
private _en = [];
private _enM = 1e9;
{
    if (_forEachIndex >= 14) exitWith {};
    private _o = _x;
    private _oc = getPosATL _o;
    private _bb = boundingBoxReal _o;
    private _rad = (((_bb select 2) max 0.5) / 2) min 8;
    private _d = _dus getDir _oc;
    private _bh = _oc getPos [_rad + 0.8, _d];
    if (surfaceIsWater _bh) then { continue };
    private _bASL = AGLToASL [_bh select 0, _bh select 1, 1.0];
    private _v = lineIntersectsSurfaces [_eASL, _bASL, objNull, objNull, true, 1, "VIEW", "NONE"];
    private _f = lineIntersectsSurfaces [_eASL, _bASL, objNull, objNull, true, 1, "FIRE", "NONE"];
    if (_v isEqualTo [] || {_f isEqualTo []}) then { continue };
    if !([_bh] call _kabul) then { continue };
    private _m = _pt distance2D _bh;
    if (_m < _enM) then { _enM = _m; _en = _bh; };
} forEach _objs;
_en
