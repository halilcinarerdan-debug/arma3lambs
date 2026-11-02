#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * ARAC SINIFI (v8.164) — kullanici: "apc ile ifv'nin gorevlerine dikkat et".
 * Config'ten (silahlar + koltuk + zirh) sinif cikarir, tip basina onbellek (lambs_danger_aracSinifCache):
 *   TOPCU  : artilleryScanner > 0 -> plana katilmaz (ayri atis destegi)
 *   TANK   : isKindOf "Tank" ve kargo < 3                                      -> ZIRH DESTEK (ates pozisyonu, objektife ates)
 *   IFV    : kargo >= 3 ve top (mermi hit >= 25) ya da ATGM (shotMissile)   -> TASIR + indirdikten sonra ates destegi (RUS: bronegruppa; ABD: ates pozisyonu)
 *   APC    : kargo >= 3, top yok (yalniz MG / GMG), zirh >= 120      -> "savas taksisi": piyadeyi atesin disinda indirir, geride REZERV, savasmaz
 *   KAMYON : kargo >= 3, topsuz, zirh < 120 (yumusak)               -> APC gibi tasir / geride rezerv
 *   DIGER  : kargo < 3 (silahli cip, teknik, kucuk arac)             -> ZIRH DESTEK unsuru olarak secilebilir (kirilgan)
 * Doktrin kaynagi (tasarim, kitapta sayi yok): IFV piyadeyle birlikte savasir ve ateş destegi verir (Bradley / BMP / Marder); APC "battle taxi" (Stryker ICV / BTR / Fuchs) piyadeyi iner, atesten uzak durur.
 *
 * Arguments:
 * 0: Arac <OBJECT>
 *
 * Return Value:
 * [sinif <STRING>, kargo <NUMBER>, top <BOOL>, atgm <BOOL>]
 * Public: No
*/

params [["_v", objNull, [objNull]]];
if (isNull _v) exitWith {["DIGER", 0, false, false]};
private _tip = typeOf _v;
if (isNil "lambs_danger_aracSinifCache") then { lambs_danger_aracSinifCache = createHashMap; };
private _on = lambs_danger_aracSinifCache getOrDefault [_tip, []];
if (_on isNotEqualTo []) exitWith {_on};

private _kargo = count (fullCrew [_v, "cargo", true]);
private _top = false;
private _atgm = false;
{
    private _p = _x;
    {
        private _mags = getArray (configFile >> "CfgWeapons" >> _x >> "magazines");
        if (_mags isEqualTo []) then { continue };
        private _ammo = getText (configFile >> "CfgMagazines" >> (_mags select 0) >> "ammo");
        private _sim = toLower (getText (configFile >> "CfgAmmo" >> _ammo >> "simulation"));
        private _hit = getNumber (configFile >> "CfgAmmo" >> _ammo >> "hit");
        if (_sim isEqualTo "shotmissile") then { if ((getNumber (configFile >> "CfgAmmo" >> _ammo >> "airLock")) < 2) then { _atgm = true; }; };
        if (_sim in ["shotbullet", "shotshell"] && {_hit >= 25}) then { _top = true; };
    } forEach (_v weaponsTurret _p);
} forEach ([[-1]] + (allTurrets _v));

private _zirh = getNumber (configOf _v >> "armor");
// v8.169: "Tank" taban sinifi tum paletli araclari kapsar (M113 / Marder / BMP kargo tasir; RPT 94f3b4aa: M113A1G TANK sayilip zirh destege atandi, nakilde kullanilmadi) -> yalniz kargosu < 3 olanlar TANK
// v8.184: topcu (artilleryScanner > 0; M109 / havan) TANK degil - plana ZIRH DESTEK olarak katilmaz, ayri atis destegi (RPT 94057b17: M109G "TANK" secilip 650 m ateş pozisyonuna surulmus ve yok olmustu)
private _sinif = if ((getNumber (configOf _v >> "artilleryScanner")) > 0) then {"TOPCU"} else { if (_v isKindOf "Tank" && {_kargo < 3}) then {"TANK"} else {
    if (_kargo >= 3 && {_top || _atgm}) then {"IFV"} else {
        if (_kargo >= 3 && {_zirh >= 120}) then {"APC"} else {
            if (_kargo >= 3) then {"KAMYON"} else {"DIGER"}
        }
    }
}};
// v8.364 ELLE DUZELTME (denetim: kargo >= 3 olan Tank-tabanli arac otomatik IFV/APC sayilir; kargolu ANA MUHAREBE TANKI (ornek Merkava, kargo 4-6) bu kuralla IFV olur ve ZIRH DESTEK / tankAtesKontrol/tankMuhimmat disinda kalir). Config'ten
//   guvenilir ayirt edici yok (BMP-3 de 100 mm top + kargo tasir) -> tahmin yerine sinif adina ELLE gecersiz kilma: lambs_danger_aracSinifOverride = createHashMapFromArray [["sinif_adi", "TANK"]] (TANK / IFV / APC / KAMYON / DIGER).
private _ov = missionNamespace getVariable ["lambs_danger_aracSinifOverride", createHashMap];
private _ovAyar = _tip in _ov;
if (_ovAyar) then { _sinif = _ov get _tip; };
private _sonuc = [_sinif, _kargo, _top, _atgm];
lambs_danger_aracSinifCache set [_tip, _sonuc];
diag_log format ["[ARAC-SINIF] %1 (%2) -> %3%8 | kargo %4 | top %5 | atgm %6 | zirh %7", getText (configOf _v >> "displayName"), _tip, _sinif, _kargo, _top, _atgm, _zirh, ["", " (ELLE GECERSIZ KILINDI)"] select _ovAyar];
if (!_ovAyar && {_v isKindOf "Tank"} && {_kargo >= 3} && {_zirh >= 300}) then {
    diag_log format ["[ARAC-SINIF] %1 (%2): Tank tabanli, kargo %3, zirh %4 -> IFV/APC sayildi; ANA MUHAREBE TANKI ise lambs_danger_aracSinifOverride ile TANK yapin", getText (configOf _v >> "displayName"), _tip, _kargo, _zirh];
};
_sonuc
