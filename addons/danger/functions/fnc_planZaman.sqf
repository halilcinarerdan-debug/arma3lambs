#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * PLAN ZAMAN CIZELGESI (v8.227; kullanici: "loglari guclendir") — plan baslangicindan itibaren onemli olaylarin zamani tek formatta: [PLAN-ZAMAN] <plan> | t+<sn> | <olay> | <ayrinti>.
 * Recon ve ana kol sirasi (kim ne zaman bindi / kalkti / indi) tek bakista okunur. Ayni (plan, olay) cifti yalniz bir kez yazilir (tekrar = true ise her seferinde).
 *
 * Arguments:
 * 0: Olay adi <STRING>
 * 1: Ayrinti <STRING> (opsiyonel)
 * 2: Tekrar mi <BOOL> (opsiyonel, varsayilan false)
 *
 * Return Value: Yok
 * Public: No
*/

params [["_olay", "?", [""]], ["_ayr", "", [""]], ["_tekrar", false, [true]]];
private _id = missionNamespace getVariable ["lambs_danger_planZamanId", "?"];
private _t0 = missionNamespace getVariable ["lambs_danger_planZamanT0", time];
if (isNil "lambs_danger_planZamanKayit") then { lambs_danger_planZamanKayit = createHashMap; };
private _anahtar = format ["%1|%2", _id, _olay];
if (!_tekrar && {_anahtar in lambs_danger_planZamanKayit}) exitWith {};
lambs_danger_planZamanKayit set [_anahtar, time];
diag_log format ["[PLAN-ZAMAN] %1 | t+%2 sn | %3 | %4", _id, round (time - _t0), _olay, _ayr];
