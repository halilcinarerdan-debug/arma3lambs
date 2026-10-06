#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * ASISTAN TURU (v8.108) — askerin MG / AT ASISTANI (yardimcisi, mermi tasiyicisi) olup olmadigini doner. Sinif adi ve gorunen ad ile (config), sonuc birim uzerinde onbellekte.
 *   "MG_ASIST" (otomatik tufekci / MG yardimcisi: ...aar..., machinegunner_assistant, Asst. Autorifleman), "AT_ASIST" (AT yardimcisi: ...aat..., Assistant AT / Missile Specialist),
 *   "ASIST" (genel: assistant / ammobearer; MG veya AT'ye eslesir), "" (asistan degil)
 * Vanilla: *_soldier_AAR_F (MG yardimcisi), *_soldier_AAT_F (AT yardimcisi), RHS: ...assistant...
 *
 * 0: unit <OBJECT>
 * "MG_ASIST" | "AT_ASIST" | "ASIST" | ""
 * Public: No
*/
params [["_u", objNull, [objNull]]];
if (isNull _u) exitWith {""};
private _c = _u getVariable [QGVAR(asistanTur), nil];
if (!isNil "_c") exitWith {_c};
private _t = toLower (typeOf _u);
private _ad = toLower (getText ((configOf _u) >> "displayName"));
private _her = _t + "|" + _ad;
private _bul = { params ["_liste"]; (_liste findIf {(_her find _x) >= 0}) >= 0 };
private _r = "";
private _asist = [["assistant", "asst", "ammobearer", "ammo bearer", "ammo_bearer", "_aar_", "_aat_", "_aar", "_aat"]] call _bul;
if (_asist) then {
    private _at = [["aat", "assistant at", "asst. at", "asst at", "at_assist", "missile", "antitank", "anti-tank", "launcher"]] call _bul;
    private _mg = [["aar", "autorifle", "machinegun", "machine gun", "mg_assist", "mg assist", "_mg"]] call _bul;
    _r = "ASIST";
    if (_mg) then { _r = "MG_ASIST"; };
    if (_at && {!_mg}) then { _r = "AT_ASIST"; };
};
_u setVariable [QGVAR(asistanTur), _r];
_r
