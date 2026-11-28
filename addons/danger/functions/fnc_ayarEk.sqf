#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * TARAF / DOKTRIN EKI (v8.845; kullanici: 'ISIS ve Amerika farkini net koy' + RPT c30f0e7f: ABD fraksiyonu EAST, duzensiz fraksiyon WEST'te; taraf bazli ayar fraksiyon yerlesimine bagliydi).
 * Ayar adi sonekini ('West' / 'East' / 'Ind' / '') belirler: fnc_ayarTaraf ve fnc_rpgTarafDeger bunu kullanir.
 *   CBA 'ayarDoktrinBazli' KAPALI (varsayilan): taraf bazli (BLUFOR = West, OPFOR = East, INDEPENDENT = Ind) - eski davranis.
 *   ACIK: birim / grup icin DOKTRINE gore: grubun doktrini DUZENSIZ ise 'East' ayarlari (IS / milis profili), baska her doktrin (ABD, USMC, RUS...) 'West' ayarlari (duzenli ordu profili), TARAF FARK ETMEZ.
 *   Yalniz taraf verilirse (grup yok) her zaman taraf bazli.
 * Arguments: 0: Birim / grup / taraf <OBJECT / GROUP / SIDE> | Return Value: Sonek <STRING> | Public: No
*/
params ["_ctx"];
private _g = switch (typeName _ctx) do {
    case "OBJECT": { if (isNull _ctx) then {grpNull} else {group _ctx} };
    case "GROUP": {_ctx};
    default {grpNull};
};
private _s = if (!isNull _g) then {side _g} else { if (_ctx isEqualType west) then {_ctx} else {sideUnknown} };
if !(_s in [west, east, resistance]) exitWith {""};
if (!isNull _g && {missionNamespace getVariable ["lambs_danger_ayarDoktrinBazli", false]} && {!isNull leader _g}) exitWith {
    ["West", "East"] select ((([_g, "ad", "GENEL"] call FUNC(dk)) isEqualTo "DUZENSIZ"))
};
["West", "East", "Ind"] select ([west, east, resistance] find _s)
