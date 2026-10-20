#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * CROCUS CANTASI -> DRON ARAC SINIFI (v8.272) — kullanici: "canta olarak crocus bag olunca iha atamasinda saymiyor, crocus at / ap secmek gerekiyor".
 * Cantadan arac sinifini bulur: once config `assembleInfo >> assembleTo`; yoksa sinif adindan '_Bag' son ekini atar (O_Crocus_AT_Bag -> O_Crocus_AT); sinif yoksa "".
 * Ayrica `[sinif, true]` ile cagrilirsa yalniz 'bu sinif bir Crocus cantasi mi' sorusuna BOOL doner.
 *
 * Arguments:
 * 0: Canta sinifi <STRING>
 * 1: Yalniz Crocus cantasi mi sorusu <BOOL> (varsayilan false)
 *
 * Return Value: Arac sinifi <STRING> (ya da BOOL)
 * Public: No
*/

params [["_bag", "", [""]], ["_sadeceSor", false, [false]]];
private _l = toLower _bag;
private _crocus = _l isNotEqualTo "" && {(_l find "crocus") >= 0} && {(_l find "bag") >= 0};
if (_sadeceSor) exitWith {_crocus};
if (!_crocus) exitWith {""};
private _at = getText (configFile >> "CfgVehicles" >> _bag >> "assembleInfo" >> "assembleTo");
if (_at isNotEqualTo "" && {isClass (configFile >> "CfgVehicles" >> _at)}) exitWith {_at};
private _i = _l find "_bag";
private _b = if (_i > 0) then {_bag select [0, _i]} else {""};
if (_b isNotEqualTo "" && {isClass (configFile >> "CfgVehicles" >> _b)}) exitWith {_b};
""
