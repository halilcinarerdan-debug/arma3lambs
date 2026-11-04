#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * C2 YETKI KONTROLU (v8.391) — oyuncu komuta aglari (topcu cagirma / bot grubuna emir) icin kim yetkili.
 * CBA 'lambs_danger_c2Yetki': 0 = herkes, 1 = grup lideri, 2 = komutan degiskeni (Eden init: this setVariable ["lambs_danger_komutan", true, true]), 3 = grup lideri VEYA komutan degiskeni (varsayilan).
 * ACRE2 yuklu ve CBA 'lambs_danger_c2TelsizSart' aciksa YEREL oyuncuda aktif telsiz de aranir (acre_api_fnc_getCurrentRadio; ACRE yalniz yerel oyuncuyu sorgular, bu yuzden SUNUCU tarafi
 * bu on kontrolu atlar: radyo = false ile cagirir — telsiz sarti istemci tarafi kolaylik / rol oyunudur, guvenlik siniri degildir).
 *
 * Arguments:
 * 0: Birim <OBJECT>
 * 1: Telsiz sarti uygulansin mi (yalniz istemci, yerel oyuncu) <BOOL> (varsayilan true)
 *
 * Return Value: Yetkili mi <BOOL>
 * Public: No
*/

params [["_u", objNull, [objNull]], ["_radyo", true, [true]]];

if (isNull _u || {!alive _u} || {!(missionNamespace getVariable ["lambs_danger_c2Aktif", true])}) exitWith {false};

private _lider = (leader (group _u)) isEqualTo _u;
private _deg = _u getVariable ["lambs_danger_komutan", false];
private _ok = switch (missionNamespace getVariable ["lambs_danger_c2Yetki", 3]) do {
    case 0: {true};
    case 1: {_lider};
    case 2: {_deg};
    default {_lider || {_deg}};
};
if (!_ok) exitWith {false};

if (
    _radyo && {hasInterface} && {_u isEqualTo player}
    && {missionNamespace getVariable ["lambs_danger_c2TelsizSart", true]}
    && {isClass (configFile >> "CfgPatches" >> "acre_api")} && {!isNil "acre_api_fnc_getCurrentRadio"}
) then {
    _ok = ([] call acre_api_fnc_getCurrentRadio) isNotEqualTo "";
};
_ok
