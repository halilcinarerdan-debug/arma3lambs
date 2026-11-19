#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * YUMUSAK SIPER OTURMA (v8.647; kullanici: 'siper oturtma baya yumusasin'; eskiden 0.3-1.2 sn'de 6-24 sabit adimli setPosATL: gorunur sicrama / kayma):
 * Askeri verilen noktaya (ATL) DOGAL yurutup son kismi yumusak kaydirir. Bir kez cagrilir: [_unit, _hedefATL] spawn FUNC(yumusakKay).
 *   1) kalan > 0.9 m ise: doMove (gercek yuruyus animasyonu, forceSpeed -1) hedefe 0.9 m kalana ya da en cok 5 sn
 *   2) kalan 0.1-1.6 m ise: son kisim 'smoothstep' (yavas basla / yavas bitir) egrisiyle setPosATL, hiz ~1.0 m/sn (en az 0.45 sn, en cok 1.6 sn), ~50 Hz adimlar
 *   3) kalan > 1.6 m ise (varamadi): kaydirma YOK (isinlanma gorunmez)
 * Baska bir emirle yer degistiriyorsa (hiz > 2.5 m/sn kaydirma sirasinda) kaydirma iptal.
 *
 * Arguments:
 * 0: Asker <OBJECT>
 * 1: Hedef nokta (ATL) <ARRAY>
 *
 * Return Value: Yok
 * Public: No
*/

params [["_a", objNull, [objNull]], ["_hedef", [], [[]]]];
if (isNull _a || {!alive _a} || {_hedef isEqualTo []}) exitWith {};
private _p1 = +_hedef;
_p1 set [2, (getPosATL _a) select 2];
if ((getPosATL _a) distance2D _p1 > 0.9) then {
    _a forceSpeed -1;
    _a doMove _p1;
    private _bit = time + ((((getPosATL _a) distance2D _p1) / 3) max 5) min 9;   // v8.649: uzak siperde sure mesafeye gore (5-9 sn)
    waitUntil { sleep 0.2; !alive _a || {time > _bit} || {((getPosATL _a) distance2D _p1) < 0.9} };
};
if (!alive _a) exitWith {};
_p1 set [2, (getPosATL _a) select 2];
private _p0 = getPosATL _a;
private _d = _p0 distance2D _p1;
if (_d < 0.1 || {_d > 1.6} || {surfaceIsWater _p1}) exitWith {};
private _sure = ((_d / 1.0) max 0.45) min 1.6;
private _t0 = time;
while {alive _a && {(time - _t0) < _sure}} do {
    private _k = ((time - _t0) / _sure) min 1;
    private _e = _k * _k * (3 - (2 * _k));
    _a setPosATL (_p0 vectorAdd ((_p1 vectorDiff _p0) vectorMultiply _e));
    sleep 0.02;
};
if (alive _a) then { _a setPosATL _p1; };
