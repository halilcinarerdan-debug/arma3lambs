#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * MUNISYON PENETRASYON GUCU (v8.666; kullanici: 'penetrasyonu farkindaligi ekle'): askerin SU AN taktigi sarjorun mermisinden bir 'guc' sayisi (TAHMIN; Arma'da gercek penetrasyon scriptle okunamaz).
 *   cap (mm) = CfgAmmo >> ACE_caliber (yoksa caliber x 4.7); hiz = typicalSpeed (yoksa 800 m/sn)
 *   guc = (cap / 5.6) x 2.4 x clamp(hiz / 900, 0.35, 1.2)    -> 5.56 NATO ~2.4, 7.62 NATO ~3.4, 12.7 mm ~5.6, 9 mm tabanca ~1.0
 * Sonuc mermi sinifi basina onbellekte (lambs_danger_munGucH). Taktik sarjor yoksa 2.4.
 *
 * Arguments:
 * 0: Asker <OBJECT>
 *
 * Return Value: Guc <NUMBER>
 * Public: No
*/

params [["_u", objNull, [objNull]]];
if (isNull _u) exitWith {2.4};
private _mag = currentMagazine _u;
if (_mag isEqualTo "") then { _mag = (primaryWeaponMagazine _u) param [0, ""]; };
if (_mag isEqualTo "") exitWith {2.4};
if (isNil "lambs_danger_munGucH") then { lambs_danger_munGucH = createHashMap; };
private _c = lambs_danger_munGucH get _mag;
if (!isNil "_c") exitWith {_c};
private _ammo = getText (configFile >> "CfgMagazines" >> _mag >> "ammo");
private _cap = getNumber (configFile >> "CfgAmmo" >> _ammo >> "ACE_caliber");
if (_cap <= 0) then { _cap = (getNumber (configFile >> "CfgAmmo" >> _ammo >> "caliber")) * 4.7; };
if (_cap <= 0) then { _cap = 5.6; };
private _hiz = getNumber (configFile >> "CfgAmmo" >> _ammo >> "typicalSpeed");
if (_hiz <= 0) then { _hiz = 800; };
private _g = ((_cap / 5.6) * 2.4 * (((_hiz / 900) min 1.2) max 0.35));
lambs_danger_munGucH set [_mag, _g];
if ((count lambs_danger_munGucH) <= 12) then { diag_log format ["[MUNISYON-GUC] %1 | ammo %2 | cap %3 mm | hiz %4 m/sn | guc %5", _mag, _ammo, _cap toFixed 1, round _hiz, _g toFixed 2]; };
_g
