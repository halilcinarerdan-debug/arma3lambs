#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * CAG (DONEM) ANAHTARI (v8.526; kullanici: 'sog gm csla gibi cdlc lerin donemine uygun hale getir, opsiyonel cba dan; oyuncu kendisi secsin').
 * Donemi OYUNCU / SUNUCU CBA'dan secer (lambs_danger_cag; otomatik algilama YOK): 0 Modern (varsayilan, mevcut davranis), 1 Soguk Savas / Vietnam (S.O.G. Prairie Fire, Global Mobilization, CSLA), 2 Ikinci Dunya Savasi.
 * Bu fonksiyon yalniz secimi okur ve donemden turetilen carpanlari verir; davranis degisiklikleri ilgili fonksiyonlarda (dk, tacticsBounding, tacticsRetreat, yakinHareket, reloadCover, cqbReflex, tacticalUGL).
 *
 * Arguments:
 * 0: Ne <STRING> "cag" (varsayilan: 0 / 1 / 2) | "agr" (donemle sinirlanmis bounding agresifligi 0-2) | "sicrama" (bounding sicrama carpani)
 *
 * Return Value: <NUMBER>
 *
 * Example:
 * ["agr"] call lambs_danger_fnc_cag;
 *
 * Public: No
*/

params [["_ne", "cag"]];
private _c = ((missionNamespace getVariable ["lambs_danger_cag", 0]) max 0 min 2);
if (_ne isEqualTo "agr") exitWith {
    ((missionNamespace getVariable ["lambs_danger_bndAgresif", 2]) max 0 min 2) min ([2, 1, 0] select _c)
};
if (_ne isEqualTo "sicrama") exitWith { [1, 0.85, 0.7] select _c };
_c
