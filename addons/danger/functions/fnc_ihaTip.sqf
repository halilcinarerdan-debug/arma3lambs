#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * IHA TURU (v8.233) — sinif adi / gorunen ad / silah sayisindan TAHMIN: "FPV-AT" (tank / zirh avcisi kamikaze), "FPV-AP" (personel / termobarik kamikaze), "BOMBA" (Mavic benzeri, bomba birakan), "GOZLEM" (digerleri).
 *   FPV: ad "crocus" ya da "fpv" icerir; "_at" / "anti-tank" / " at" -> FPV-AT; "_ap" / "personnel" / " ap" -> FPV-AP; belirsizse FPV-AT.
 *   BOMBA: ad "mavic" / "dji" / "quadcopter" icerir (drop modu gerekli; mod olmasa da bu betik bombayi KENDISI yaratir).
 *   Elle gecersiz kilma: lambs_danger_ihaTipOverride (HashMap sinif -> tur) ya da arac degiskeni lambs_danger_ihaTip.
 *
 * Arguments:
 * 0: Arac nesnesi ya da sinif adi <OBJECT / STRING>
 *
 * Return Value: tur <STRING>
 * Public: No
*/

params [["_a", "", [objNull, ""]]];
private _cls = if (_a isEqualType "") then {_a} else { typeOf _a };
private _ov = if (_a isEqualType "") then {""} else { _a getVariable ["lambs_danger_ihaTip", ""] };
if (_ov isNotEqualTo "") exitWith {_ov};
private _hm = missionNamespace getVariable ["lambs_danger_ihaTipOverride", createHashMap];
if (_cls in _hm) exitWith { _hm get _cls };
private _s = toLower (_cls + " " + getText (configFile >> "CfgVehicles" >> _cls >> "displayName"));
if ((_s find "crocus") >= 0 || {(_s find "fpv") >= 0}) exitWith {
    if ((_s find "_ap") >= 0 || {(_s find "personnel") >= 0} || {(_s find " ap") >= 0}) then {"FPV-AP"} else {"FPV-AT"}
};
if ((_s find "mavic") >= 0 || {(_s find "dji") >= 0} || {(_s find "quadcopter") >= 0}) exitWith {"BOMBA"};
"GOZLEM"
