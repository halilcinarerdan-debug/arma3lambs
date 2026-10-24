#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * TOPCU MERMI BUTCESI (v8.338) — dron gozlemli atis + taciz atisi icin taraf basina kayan pencere (600 sn) mermi sayaci. Ates kontrolu / mermi disiplini ilkesi (kaynak: TC 3-21.76 'Ammo' durumu
 * kavrami ve taciz atisinin 'az mermi' ilkesi); sayi [T]: CBA lambs_danger_dronTopcuButce (varsayilan 30 mermi / 600 sn / taraf).
 *
 * Arguments:
 * 0: Taraf <SIDE>
 * 1: Eklenecek mermi (0 = yalniz sorgu) <NUMBER>
 *
 * Return Value: Pencerede kullanilan mermi (ekleme dahil) <NUMBER>
 * Public: No
*/

params [["_taraf", sideUnknown, [sideUnknown]], ["_ekle", 0, [0]]];
private _k = format ["lambs_danger_dtButce_%1", _taraf];
private _l = (missionNamespace getVariable [_k, []]) select {(time - (_x select 0)) < 600};
if (_ekle > 0) then { _l pushBack [time, _ekle]; };
missionNamespace setVariable [_k, _l];
private _t = 0;
{ _t = _t + (_x select 1); } forEach _l;
_t
