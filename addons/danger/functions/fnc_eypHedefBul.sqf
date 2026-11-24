#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * EYP HEDEF BUL (v8.781; fnc_eypBombaYap + fnc_eypKos ortak): isaretli bomba birimi / araci icin tespit menzilindeki EN YAKIN dusmani doner (gercek konum; referans aral_canl_bomba / canl_bomba taramasi gibi, bilgi aranmaz).
 * Dusman = canli, captive olmayan, gizli olmayan, sivil olmayan, (hedef taraf secilmisse yalniz o taraf, degilse birimin dost saymadigi) CAManBase / LandVehicle; kendi murettebati haric.
 * Neden: fnc_eypKos hedefi olurse findNearestEnemy (bilgi tabanli) bos donuyordu -> 'hedef yok' ile cikip aracin AI'si geri aciliyor, 5 sn bekleyip yeniden basliyordu (RPT 0689d2a0: iki kez 'hedef yok', arac durdu).
 *
 * Arguments:
 * 0: Bomba birimi / araci <OBJECT>
 * 1: Tespit menzili (m) <NUMBER> (varsayilan 400)
 * 2: Hedef taraf 0 otomatik / 1 BLUFOR / 2 OPFOR / 3 INDEP <NUMBER> (varsayilan 0)
 *
 * Return Value: En yakin dusman ya da objNull <OBJECT>
 *
 * Public: No
*/

params [["_o", objNull, [objNull]], ["_men", 400, [0]], ["_ht", 0, [0]]];
if (isNull _o) exitWith {objNull};
private _r = if (_o isKindOf "CAManBase") then {_o} else {driver _o};
private _taraf = if (isNull _r) then {side _o} else {side group _r};
private _aday = ((getPosATL _o) nearEntities [["CAManBase", "LandVehicle"], _men]) select {
    alive _x && {_x isNotEqualTo _o} && {!(_x in (crew _o))} && {!captive _x} && {!isObjectHidden _x} && {(side _x) isNotEqualTo civilian}
    && {if (_ht > 0) then {(side _x) isEqualTo ([west, east, independent] select (_ht - 1))} else {(_taraf getFriend (side _x)) < 0.6}}
};
if (_aday isEqualTo []) exitWith {objNull};
([_aday, [], {_x distance _o}, "ASCEND"] call BIS_fnc_sortBy) select 0
