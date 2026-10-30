#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * OYUNCUYA MERMI VERME — ALICI TARAFI (v8.354; kullanici: 'oyunculara mermi paslama olsun, envantere gelsin, mermimiz bitince'). fnc_cephanePaylas'in oyuncu kolu, AI askerin sarjorlerini kendi envanterinden alip
 * OYUNCUNUN MAKINESINDE (remoteExecCall) bu fonksiyonu cagirir: sarjorler dogrudan OYUNCUNUN ENVANTERINE eklenir (sigdigi kadar); sigmayan yere (GroundWeaponHolder, oyuncunun ayagina) birakilir.
 * Oyuncuya sohbet satiri gelir: '[ASKER] <ad> sana N sarjor verdi (<sarjor adi>)'. Sunucu / AI makinesi oyuncu yerelse dogrudan cagirir.
 * Kapatma: lambs_danger_cephaneOyuncuOff = true (fnc_cephanePaylas oyuncu kolu).
 *
 * Arguments:
 * 0: Oyuncu <OBJECT>
 * 1: Sarjor sinifi <STRING>
 * 2: Sarjor mermi sayilari <ARRAY> (ornek [30, 30, 24])
 * 3: Veren adi <STRING>
 *
 * Return Value: Envantere eklenen sarjor sayisi <NUMBER>
 * Public: No
*/

params [["_p", objNull, [objNull]], ["_sinif", "", [""]], ["_liste", [], [[]]], ["_veren", "", [""]]];
if (isNull _p || {!alive _p} || {!local _p} || {_sinif isEqualTo ""} || {_liste isEqualTo []}) exitWith {0};

private _eklenen = 0;
private _yere = [];
{
    if (_p canAdd _sinif) then {
        _p addMagazine [_sinif, _x];
        _eklenen = _eklenen + 1;
    } else {
        _yere pushBack _x;
    };
} forEach _liste;

if (_yere isNotEqualTo []) then {
    private _ph = createVehicle ["GroundWeaponHolder", getPosATL _p, [], 0, "CAN_COLLIDE"];
    _ph setPosATL (getPosATL _p);
    { _ph addMagazineAmmoCargo [_sinif, 1, _x]; } forEach _yere;
    [{ params ["_h"]; if (!isNull _h) then { deleteVehicle _h; }; }, [_ph], 180] call CBA_fnc_waitAndExecute;
};

private _ad = getText (configFile >> "CfgMagazines" >> _sinif >> "displayName");
if (_ad isEqualTo "") then { _ad = _sinif; };
systemChat format ["[ASKER] %1 sana %2 sarjor verdi (%3)%4", _veren, count _liste, _ad, if (_yere isEqualTo []) then {""} else {format [" - envanter DOLU: %1 sarjor ayagina birakildi", count _yere]}];
diag_log format ["[CEPHANE-OYUNCU] %1 <- %2 | %3 x%4 | envantere %5, yere %6", name _p, _veren, _sinif, count _liste, _eklenen, count _yere];
_eklenen
