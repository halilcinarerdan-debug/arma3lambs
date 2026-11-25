#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * TARAF BAZLI AYAR OKUYUCU (v8.803; kullanici: 'blufor opfor ve independent icin herseyiyle ayri ayarlayabilelim, farkli kategorilerde olsun').
 * Genel CBA ayari (lambs_danger_<ad>) yerine, birimin / grubun / tarafin TARAFINA ozel ayar (lambs_danger_<ad><West|East|Ind>; BLUFOR = West, OPFOR = East, INDEPENDENT = Ind) varsa onu doner.
 * Tarafa ozel ayar -1 ise (varsayilan) ya da yoksa GENEL ayar doner; genel ayar da yoksa verilen varsayilan. Tarafa ozel degerin sinirlari cagiran kodda genel degerle ayni sekilde uygulanir (max / min).
 * Taraf ayarlari CBA'da uc ayri kategoride: 'ELITE BLUFOR', 'ELITE OPFOR', 'ELITE INDEPENDENT' (tools/taraf_uret.py uretir; XEH_PREP.hpp TARAF-AYAR blogu).
 * Kullanim: ([_u, "skillIsabetMax", 0.4] call FUNC(ayarTaraf)); _u = birim ya da grup ya da taraf (side).
 *
 * Arguments:
 * 0: Birim / grup / taraf <OBJECT / GROUP / SIDE>
 * 1: Ayar adi (lambs_danger_ oneksiz, taraf eksiz) <STRING>
 * 2: Varsayilan (genel ayar da yoksa) <NUMBER>
 *
 * Return Value: Ayar degeri <ANY>
 *
 * Public: No
*/

params ["_ctx", "_ad", "_varsayilan"];
private _genel = missionNamespace getVariable ["lambs_danger_" + _ad, _varsayilan];
private _s = switch (typeName _ctx) do {
    case "OBJECT": { if (isNull _ctx) then {sideUnknown} else {side group _ctx} };
    case "GROUP": { if (isNull _ctx) then {sideUnknown} else {side _ctx} };
    case "SIDE": {_ctx};
    default {sideUnknown};
};
private _ek = if (_s isEqualTo west) then {"West"} else { if (_s isEqualTo east) then {"East"} else { if (_s isEqualTo resistance) then {"Ind"} else {""} } };
if (_ek isEqualTo "") exitWith {_genel};
private _v = missionNamespace getVariable ["lambs_danger_" + _ad + _ek, -1];
if (_v isEqualType 0 && {_v >= 0}) then {_v} else {_genel}
