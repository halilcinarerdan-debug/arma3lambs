#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * LOG ORNEKLEME KAPISI (v8.817; kullanici: 'hepsini yapalim'; yol haritasi Asama 15 / 5): sabit 'ilk N satir' tavani oturumun BASINDA doluyor ve sonraki olaylar gorunmez oluyordu (RPT ea78a960: ilk 15 [DURUS-AKICI] kilidi
 * 20:00-20:02'de doldu, 20:10'daki [SIPER-VARIS] basarisizliklariyla eslestirilemedi; retreat izi ilk 160 satirla (ilk 2-3 sicrama) sinirliydi). Bu kapi: ilk ilkN satir her zaman serbest; sonra anahtar basina EN FAZLA aralikS sn'de BIR satir.
 * Arguments: 0: anahtar <STRING> | 1: ilk N <NUMBER> | 2: sonraki satirlar arasi en az sure (sn) <NUMBER>
 * Return Value: Bu satir loglanabilir mi <BOOL>
 * Public: No
*/

params [["_k", "?", [""]], ["_ilk", 20, [0]], ["_ar", 30, [0]]];
private _vn = format ["lambs_danger_li_%1_n", _k];
private _c = missionNamespace getVariable [_vn, 0];
if (_c < _ilk) exitWith { missionNamespace setVariable [_vn, _c + 1]; true };
private _vt = format ["lambs_danger_li_%1_t", _k];
if ((time - (missionNamespace getVariable [_vt, -1e9])) >= _ar) exitWith { missionNamespace setVariable [_vt, time]; true };
false
