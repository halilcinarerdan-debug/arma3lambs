#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * ARAC DUMAN ATICISI (v8.251) — AT atesi altindaki arac gorus kesmek icin duman atar (ATP 3-20.15 3-136: tank / arac duman: kendi gorus hattini kes, yer degistir).
 * Silah bulma: aracin tum taretlerinde (weaponsTurret) magazinin mermisi 'smoke' iceren (simulation ya da sinif adi) silah; tip basina onbellek (lambs_danger_aracDumanCache).
 * Atis: vehicle fireAtTarget [objNull, silah] (TEST EDILMEDI: RHS / vanilla duman atici SINIFLARINDA sonuc bilinmiyor; donus degeri + cephane [ARAC-DUMAN] logunda). Aracin kendi yonune/taretin baktigi yone atar - cagiran once taret/gozcuyu tehdide cevirmeli.
 * 30 sn bekleme / arac. Yerel olmayan arac, cephanesi bitmis atici -> false. Kapatma: lambs_danger_aracDumanOff = true.
 *
 * Arguments:
 * 0: Arac <OBJECT>
 *
 * Return Value: Atildi mi <BOOL>
 * Public: No
*/

params [["_v", objNull, [objNull]]];
if (isNull _v || {!alive _v} || {!local _v}) exitWith {false};
if (missionNamespace getVariable ["lambs_danger_aracDumanOff", false]) exitWith {false};
if ((time - (_v getVariable [QGVAR(aracDumanT), -999])) < 30) exitWith {false};

private _tip = typeOf _v;
if (isNil "lambs_danger_aracDumanCache") then { lambs_danger_aracDumanCache = createHashMap; };
private _w = lambs_danger_aracDumanCache getOrDefault [_tip, "?"];
if (_w isEqualTo "?") then {
    _w = "";
    {
        {
            private _mags = getArray (configFile >> "CfgWeapons" >> _x >> "magazines");
            if (_mags isEqualTo [] || {_w isNotEqualTo ""}) then { continue };
            private _ammo = getText (configFile >> "CfgMagazines" >> (_mags select 0) >> "ammo");
            private _sim = toLower (getText (configFile >> "CfgAmmo" >> _ammo >> "simulation"));
            if ((_sim find "smoke") >= 0 || {((toLower _ammo) find "smoke") >= 0}) then { _w = _x; };
        } forEach (_v weaponsTurret _x);
    } forEach ([[-1]] + (allTurrets _v));
    lambs_danger_aracDumanCache set [_tip, _w];
    diag_log format ["[ARAC-DUMAN] %1 (%2) duman atici silahi: %3", getText (configOf _v >> "displayName"), _tip, if (_w isEqualTo "") then {"YOK"} else {_w}];
};
if (_w isEqualTo "" || {(_v ammo _w) <= 0}) exitWith {false};

_v setVariable [QGVAR(aracDumanT), time];
private _ok = _v fireAtTarget [objNull, _w];
if (isNil "lambs_danger_aracDumanLogN") then { lambs_danger_aracDumanLogN = 0; };
if (lambs_danger_aracDumanLogN < 40) then {
    lambs_danger_aracDumanLogN = lambs_danger_aracDumanLogN + 1;
    diag_log format ["[ARAC-DUMAN] %1 | %2 | fireAtTarget %3 -> %4 | kalan %5", groupId (group (driver _v)), getText (configOf _v >> "displayName"), _w, _ok, _v ammo _w];
};
true
