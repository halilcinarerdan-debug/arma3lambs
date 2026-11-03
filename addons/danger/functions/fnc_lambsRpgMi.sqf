#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * LAMBS RPG YUKLU MU (v8.387; kullanici: 'lambs rpg ile uyumlu hale getir'). LAMBS RPG (LAMBS ailesi: nkenny / diwako / joko) SQF icermeyen, config tabanli bir moddur: omuz roketatarlarinin (RPG-7 vb.) mermi / magazin
 * ozelliklerini (aiAmmoUsageFlags: hangi hedefe AI kullanir) degistirerek AI'nin roketi helikoptere / araca kullanmasini, piyadeye bosa atmamasini saglar (RHS / CUP / SOG ayri paketler).
 * UYUM ILKESI: ELITE launcher secimini sinif ADINA degil aiAmmoUsageFlags'e (LAMBS getLauncherUnits) dayandirir -> mod acik oldugunda RPG-7 'hava yetenekli' sayilir, ek is gerekmez. Kalan cakisma:
 *   (1) fnc_patlayici script roketini (omuz roketatari) PIYADEYE atiyordu -> mod yukluyken kapali (CBA 'lambs_danger_lambsRpgUyum', varsayilan acik);
 *   (2) fnc_havaFarkindalik saldirmayan silahli helide 'forgetTarget' (Weapons-Hold) yapiyordu -> hava yetenekli roketatari olan grupta mod yukluyken UYGULANMAZ (AI kendi kurallarina gore ates eder).
 * Algi: CfgPatches'te adi 'lambs_rpg' iceren herhangi bir sinif (alt paketler dahil). Sonuc onbellege alinir (lambs_danger_lambsRpg), bir kez [LAMBS-RPG] satiri yazar.
 *
 * Arguments: None
 * Return Value: LAMBS RPG yuklu mu <BOOL>
 * Public: No
*/

private _c = missionNamespace getVariable ["lambs_danger_lambsRpg", -1];
if (_c isEqualType true) exitWith {_c};
private _siniflar = ("(toLower (configName _x)) find 'lambs_rpg' >= 0" configClasses (configFile >> "CfgPatches")) apply {configName _x};
private _v = _siniflar isNotEqualTo [];
missionNamespace setVariable ["lambs_danger_lambsRpg", _v];
diag_log format ["[LAMBS-RPG] LAMBS RPG %1 | CfgPatches: %2 | uyum: roketatar secimi aiAmmoUsageFlags tabanli (mod adindan bagimsiz); script roketi piyadeye %3; saldirmayan heliye forgetTarget (hava yetenekli roketatar varsa) %4",
    ["YOK", "YUKLU"] select _v, _siniflar, ["serbest (mod yok)", "KAPALI (mod yuklu)"] select _v, ["uygulanir", "atlanir"] select _v];
_v
