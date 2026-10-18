#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * GERCEK HEDEF MI (v8.247) — nearTargets nesnesi GERCEK bir dusman mi (yaya asker ya da murettebatli arac)?
 * Neden (RPT e88d7e9f): planZirh tanki 'HEDEF: trencher_main_Module_TrenchController (524 m)' secti — Trencher modunun mantik modulu (Logic) nearTargets'ta dusman tarafli hedef olarak gorunuyor;
 * ayni nedenle savunma planinda 'dusman 6, objektife 19 m' hayalet dusman sayildi (RPT c7592408) ve canli gozlem / topcu izni / nakil tehdit mesafesi yaniltilabilir.
 * Gercek hedef: yasayan CAManBase, ya da yasayan AllVehicles ve icinde yasayan murettebat var. Mantik modulu, bos arac, statik/obje HEDEF DEGILDIR.
 * Kapatma: lambs_danger_gercekHedefOff = true (her nesne hedef sayilir; eski davranis).
 *
 * Arguments:
 * 0: Nesne <OBJECT>
 *
 * Return Value: gercek hedef mi <BOOL>
 * Public: No
*/

params [["_o", objNull, [objNull]]];
if (isNull _o || {!alive _o}) exitWith {false};
if (missionNamespace getVariable ["lambs_danger_gercekHedefOff", false]) exitWith {true};
(_o isKindOf "CAManBase") || {(_o isKindOf "AllVehicles") && {(crew _o) findIf {alive _x} >= 0}}
