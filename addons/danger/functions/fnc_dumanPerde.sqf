#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * DUMAN PERDESI (v8.327) — iki nokta arasindaki gorus hattini kesen duman bulutu sayisi. Kullanici: 'IHA AI lar smokedan etkilensin, spot time olarak'.
 * Atilmis duman (SmokeShell sinifi: el/40mm dumani, arac duman firlaticisi) nesneleri hat uzerinde (3B, parca mesafesi <= yaricap) sayilir; bulut yaricapi 14 m varsayilir.
 * Kullanim: fnc_ihaSorti (AI FPV dalisi once 'kilit suresi' ister, duman varken kilitlenemez / son yaklasmada sapar).
 *
 * Arguments:
 * 0: Baslangic <ARRAY> (ASL)
 * 1: Bitis <ARRAY> (ASL)
 * 2: Bulut yaricapi <NUMBER> (varsayilan 14)
 *
 * Return Value: Hatti kesen duman bulutu sayisi <NUMBER>
 * Public: No
*/

params [["_a", [0, 0, 0], [[]]], ["_b", [0, 0, 0], [[]]], ["_yar", 14, [0]]];
private _ab = _b vectorDiff _a;
private _dd = vectorMagnitude _ab;
if (_dd < 1) exitWith {0};
private _paydaS = (_ab vectorDotProduct _ab) max 0.01;
private _n = 0;
{
    private _p = getPosASL _x;
    private _t = ((((_p vectorDiff _a) vectorDotProduct _ab) / _paydaS) max 0) min 1;
    private _en = _a vectorAdd (_ab vectorMultiply _t);
    if ((_p distance _en) <= _yar) then { _n = _n + 1; };
} forEach (nearestObjects [ASLToAGL ((_a vectorAdd _b) vectorMultiply 0.5), ["SmokeShell"], (_dd / 2) + _yar + 5]);
_n
