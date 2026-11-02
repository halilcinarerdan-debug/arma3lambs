#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * UCAK TIPI IHA HAVADAN BASLATMA (v8.363; kullanici: 'vanilla tum uav dronlar sistem uyumlu olsun') — UCAK tipi insansiz araci (Greyhawk / Ababil / Falcon / Sentinel; isKindOf Plane) ucus hizina getirir.
 * Neden: ucak 40 m'de ya da yerde hizsiz baslarsa durma hizinin (stallSpeed) altinda kalir ve duser; AI yerden kalkis (pist) yapmaz. Hiz: config stallSpeed x 1.5 ile maxSpeed x 0.45'in buyugu, 160-450 km/sa arasi (TASARIM degeri;
 * 'FLY' ile yaratilmis ucak zaten uctugu icin bu yalniz guvenlik ekidir). Motor acilir, iniş takimi kalkar.
 * KAYNAK / DOGRULAMA: hiz secimi tasarim tahminidir, vanilla ucak IHA'lari oyunda DENENMEDI; RPT [IHA-UCAK] satiri secilen hiz ve irtifayi gosterir.
 *
 * Arguments:
 * 0: Ucak tipi IHA <OBJECT>
 *
 * Return Value: Hiz verildi mi <BOOL>
 * Public: No
*/

params [["_u", objNull, [objNull]]];
if (isNull _u || {!alive _u} || {!(_u isKindOf "Plane")} || {!local _u}) exitWith {false};
private _cfg = configOf _u;
private _kmh = (((getNumber (_cfg >> "stallSpeed")) * 1.5) max ((getNumber (_cfg >> "maxSpeed")) * 0.45)) max 160 min 450;
_u engineOn true;
_u action ["LandGearUp", _u];
_u setVelocityModelSpace [0, _kmh / 3.6, 0];
diag_log format ["[IHA-UCAK] %1 | ucus hizi %2 km/sa verildi (stall %3, maks %4) | irtifa %5 m", typeOf _u, round _kmh, round (getNumber (_cfg >> "stallSpeed")), round (getNumber (_cfg >> "maxSpeed")), round ((getPosATL _u) select 2)];
true
