#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * TOPCU RED (v8.338) — risk estimate distance (RED): dost birligin atis etkisine yaklasabilecegi en kisa mesafe.
 * [K] TC 3-21.76 Tablo 3-3 (%0.1 Pi): 60 mm ~145 m, 81/82 mm ~195 m, 120 mm ~430 m, 105 mm ~455 m (azami sarj, ayakta). Kitapta olmayan kalibreler (152 / 155 / 122 vb.) icin 455 m KULLANILIR
 * [T] (en buyuk tablo degeri; muhafazakar). fnc_komutanPlanDongu'deki plan atisi ayni degerleri satir icinde kullanir; bu fonksiyon yeni sistemler (dron gozlemli atis, taciz) icindir.
 *
 * Arguments:
 * 0: Topcu araci <OBJECT>
 * 1: Mermi sinifi <STRING>
 *
 * Return Value: RED (m) <NUMBER>
 * Public: No
*/

params [["_v", objNull, [objNull]], ["_mg", "", [""]]];
private _cap = toLower (_mg + "|" + typeOf _v);
private _red = 455;
if ((_cap find "60mm") >= 0) then { _red = 145; };
if ((_cap find "81mm") >= 0 || {(_cap find "82mm") >= 0}) then { _red = 195; };
if ((_cap find "120mm") >= 0) then { _red = 430; };
_red
