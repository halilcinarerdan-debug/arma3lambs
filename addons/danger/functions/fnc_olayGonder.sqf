#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * GRUP OLAY MESAJI GONDER — VBS4 davranis agaclarindaki "Message Handler" (InContact / AllClear / UnderFire ...) fikrinin Arma 3 karsiligi.
 *
 * Polling (surekli zaman damgasi yoklama) yerine OLAY tabanli iletisim:
 *   [_grup, "InContact"] call lambs_danger_fnc_olayGonder;
 *   -> CBA yerel olayi "lambs_danger_grupOlayi" [grup, ad, veri] yayinlanir (dinleyiciler: CBA_fnc_addEventHandler)
 *   -> grupta son olay kaydi: lambs_danger_olaySon = [ad, zaman, veri]; sayac lambs_danger_olaySay_<ad>
 *   -> RPT: [OLAY] grup | ad | veri  (ilk 300 satir)
 *
 * OLAY ADLARI (uretici -> ad):
 *   fnc_olay watcher : InContact, AllClear, Casualty (grupta kayip)
 *   tacticsRetreat   : RetreatBasla, RetreatBitti
 *   tacticsBounding  : BoundingBasla, BoundingBitti
 *   grenadeAwareness : GrenadeAlgilandi
 *
 * Arguments:
 * 0: Grup <GROUP>
 * 1: Olay adi <STRING>
 * 2: Veri <ANY> (varsayilan "")
 *
 * Return Value:
 * Gonderildi mi <BOOL>
 *
 * Public: No
*/

params [["_g", grpNull, [grpNull]], ["_ad", "", [""]], ["_veri", ""]];
if (isNull _g || {_ad isEqualTo ""}) exitWith {false};

_g setVariable [QGVAR(olaySon), [_ad, time, _veri]];
private _k = format ["lambs_danger_olaySay_%1", _ad];
_g setVariable [_k, (_g getVariable [_k, 0]) + 1];

["lambs_danger_grupOlayi", [_g, _ad, _veri]] call CBA_fnc_localEvent;

if (isNil "lambs_danger_olayLogN") then { lambs_danger_olayLogN = 0; };
if (lambs_danger_olayLogN < 300) then {
    lambs_danger_olayLogN = lambs_danger_olayLogN + 1;
    diag_log format ["[OLAY] %1 | %2 | %3", groupId _g, _ad, _veri];
};
true
