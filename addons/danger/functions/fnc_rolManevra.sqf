#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * ROL DISIPLINI (v8.661; kullanici: 'herkesin rolleri belli olsun, mg rushlamasin'): manevra (hucum / kanat / bounding kosucusu) icin uygun askerleri verir.
 *   Roller (fnc_getUnitRole): MG = taban ates / bastirma (ASLA kosmaz), MEDIC = yarali / arkada, MARKSMAN = uzak nisan / overwatch, AT = zirh / overwatch (manevrada son tercih), RIFLE (+ SMG / UGL) = manevra.
 *   Siralama: 1) RIFLE / UGL, yoksa 2) + AT, yoksa 3) + MARKSMAN, yoksa 4) herkes (MG / MEDIC en son care; yalniz baska kimse kalmadiysa).
 *   En az _min (varsayilan 2) kisilik manevra ekibi doner; daha az varsa bir sonraki kademe eklenir.
 * CBA: lambs_danger_rolDisiplini (varsayilan ACIK; kapaliysa liste degismeden doner).
 *
 * Arguments:
 * 0: Asker listesi <ARRAY>
 * 1: En az manevra eden sayisi <NUMBER> (varsayilan 2)
 *
 * Return Value: Manevra edecek askerler <ARRAY>
 * Public: No
*/

params [["_l", [], [[]]], ["_min", 2, [0]]];
if (!(missionNamespace getVariable ["lambs_danger_rolDisiplini", true]) || {_l isEqualTo []}) exitWith {_l};
private _rf = missionNamespace getVariable ["lambs_danger_fnc_getUnitRole", {"RIFLE"}];
private _rol = _l apply { [_x, [_x] call _rf] };
private _kademeler = [[], ["AT"], ["MARKSMAN"], ["MEDIC"], ["MG"]];
private _izinli = ["RIFLE"];
private _sonuc = _rol select { (_x select 1) in _izinli };
for "_i" from 1 to 4 do {
    if ((count _sonuc) >= _min) exitWith {};
    _izinli append (_kademeler select _i);
    _sonuc = _rol select { (_x select 1) in _izinli };
};
_sonuc apply { _x select 0 }
