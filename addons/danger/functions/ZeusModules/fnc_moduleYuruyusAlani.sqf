#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * ELITE YURUNEBILIR ALAN (v8.331) — Eden (3D editor) modulu; kullanici: 'yogun objeli trench'ler icin 3D editorden koyabilelim, ustunde yurusebilsin AI; isim yazmamiza gerek yok'.
 * Editor: Systems > Modules > (LAMBS Danger kategorisi) 'ELITE Yurunebilir Alan'; dikdortgen / elips ALAN boyutu ve yonu modulun kendi alan tutamaclariyla ayarlanir (yari boyutlar: a = yan, b = boy).
 * Modul yalnizca kaydi loglar; alan listesi fnc_yuruyusAlani ile modul nesnelerinden (entities) okunur, yurutme fnc_yuruyusIzle bekcisindedir.
 *
 * Arguments:
 * 0: Modul <OBJECT>
 * 1: Birimler <ARRAY> (kullanilmaz)
 * 2: Etkin mi <BOOL>
 *
 * Return Value: Yok
 * Public: No
*/

params [["_logic", objNull, [objNull]], ["_units", [], [[]]], ["_activated", true, [true]]];
if (!isServer || {isNull _logic} || {!_activated}) exitWith {};
private _alan = _logic getVariable ["objectArea", [10, 4, 0, true, -1]];
diag_log format ["[YURUYUS-ALANI] modul kaydedildi: %1 | yari boyut %2 x %3 m | yon %4 | sekil %5", mapGridPosition _logic, _alan param [0, 10], _alan param [1, 4], round (_alan param [2, 0]), ["elips", "dikdortgen"] select (_alan param [3, true])];
