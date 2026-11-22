#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * DUSMANIN OLASI SIPER KUMESI (v8.735; kullanici: '1 2 3 yap'; ongoru yeniden tasarimi): hiz ile 'su kadar sn sonra suradadir' tahmini YANLIS (v8.732 olcumu: hata 14.1 m vs 'yerinde kalir' 3.4 m); insan dusman durur / siper degistirir.
 * Bu yuzden 'dusman gercekci olarak hangi sipere atlar' kumesi: dusmanin <= _r (15) m cevresindeki sert nesneler (agac / kaya / duvar / saklanma, yukseklik >= 0.8 m); nesnenin BIZDEN UZAK tarafindaki nokta (0.6 m arkasi);
 * bizim goz hizamizdan (1.5 m) o noktaya (1.0 m) FIRE LOD hatti nesne tarafindan kesiliyorsa 'gercek siper'. En yakin _n tanesi.
 *
 * Arguments:
 * 0: Dusman (nesne ya da konum AGL) <OBJECT / ARRAY>
 * 1: Biz (tehdit) konumu AGL <ARRAY>
 * 2: En cok kac nokta (3) <NUMBER>
 * 3: Dusmana en cok uzaklik (15 m) <NUMBER>
 *
 * Return Value: [konum AGL, ...] <ARRAY>
 * Public: No
*/

params [["_e", objNull, [objNull, []]], ["_from", [], [[]]], ["_n", 3, [0]], ["_r", 15, [0]]];
private _ep = if (_e isEqualType objNull) then { if (isNull _e) then {[]} else { getPosATL _e } } else { _e };
if ((count _ep) < 2 || {(count _from) < 2}) exitWith {[]};
private _fromASL = AGLToASL [_from select 0, _from select 1, 1.5];
private _out = [];
{
    private _o = _x;
    private _op = getPosATL _o;
    private _bb = boundingBoxReal _o;
    private _yk = ((_bb select 1) select 2) - ((_bb select 0) select 2);
    if (_yk < 0.8) then { continue };
    private _rr = (((((_bb select 1) select 0) - ((_bb select 0) select 0)) max (((_bb select 1) select 1) - ((_bb select 0) select 1))) / 2) min 2.5;
    private _pt = _op getPos [_rr + 0.6, _from getDir _o];
    if (surfaceIsWater _pt || {(_pt distance2D _ep) > _r}) then { continue };
    private _pa = (AGLToASL [_pt select 0, _pt select 1, 0]) vectorAdd [0, 0, 1.0];
    if ((lineIntersectsSurfaces [_fromASL, _pa, objNull, objNull, true, 1, "FIRE", "NONE"]) isEqualTo []) then { continue };
    _out pushBack _pt;
    if ((count _out) >= _n) exitWith {};
} forEach (nearestTerrainObjects [_ep, ["TREE", "ROCK", "ROCKS", "WALL", "HIDE"], _r, true, true]);
_out
