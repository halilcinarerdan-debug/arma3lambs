#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * TESLIM / ETKISIZ MI (v8.581; kullanici: 'teslim olan adama el bombasi attilar; teslim olduysa takim supressi biraksin; teslim olan askerler bilgi saglamayi kessin').
 * Piyade teslim olmus ya da etkisiz mi? captive (teslim / baygin koruma: setCaptive) VEYA ELITE teslim bayragi (lambs_danger_teslim) VEYA ACE teslim / kelepce (ace_captives_isSurrendering / isHandcuffed).
 * Teslim olan: hedef alinmaz (bomba / UGL / bastirma / roket), bilgi KAYNAGI sayilmaz (callout, konusma, ayak sesi dinleme, muhbir / komutan zihni / HQ istihbarati).
 *
 * Arguments:
 * 0: Nesne <OBJECT>
 *
 * Return Value: teslim / etkisiz mi <BOOL>
 * Public: No
*/

params [["_o", objNull, [objNull]]];
if (isNull _o || {!(_o isKindOf "CAManBase")}) exitWith {false};
(captive _o) || {_o getVariable [QGVAR(teslim), false]} || {_o getVariable ["ace_captives_isSurrendering", false]} || {_o getVariable ["ace_captives_isHandcuffed", false]}
