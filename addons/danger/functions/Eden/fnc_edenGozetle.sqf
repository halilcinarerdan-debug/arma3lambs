#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * 3DEN: ELITE Gozetleme Ata modulu (v8.362). Module SYNC ile baglanan gruplar, modul konumuna en yakin ELITE karakol / mevzi / gozetleme noktasinda (arama mesafesi icinde) nobet tutar (Zeus lambs_danger_gozetleAta).
 * Karakol modulunden SONRA calisir (8 sn gecikme: harita isareti olusmus olmali).
 * Arguments: 0: modul <OBJECT>, 1: baglananlar (kullanilmaz), 2: etkin <BOOL>
 * Return Value: None
 * Public: No
*/

params ["_logic", "", "_activated"];
if (!_activated || {!isServer}) exitWith {};

[_logic] spawn {
    params ["_logic"];
    if !(["BEKLE"] call FUNC(edenOrtak)) exitWith { diag_log "[EDEN] Gozetle: ELITE hazir olmadi (180 sn)" };
    sleep 8;
    private _poz = getPosATL _logic;
    private _ara = ["SAYI", [_logic, "lambs_danger_edGozAra", 300]] call FUNC(edenOrtak);
    private _gruplar = ["GRUPLAR", [_logic]] call FUNC(edenOrtak);
    if (_gruplar isEqualTo []) exitWith { diag_log format ["[EDEN] Gozetle (3DEN) %1: module bagli grup yok", mapGridPosition _poz] };
    private _isaretler = (allMapMarkers select {(_x find "ELITE_KARAKOL_") isEqualTo 0 && {((markerPos _x) distance2D _poz) <= _ara}});
    _isaretler = [_isaretler, [], {(markerPos _x) distance2D _poz}, "ASCEND"] call BIS_fnc_sortBy;
    if (_isaretler isEqualTo []) exitWith {
        ["MESAJ", [format ["Gozetle (3DEN) %1: %2 m icinde ELITE karakol / mevzi yok - once Karakol modulu koyun", mapGridPosition _poz, round _ara]]] call FUNC(edenOrtak);
    };
    private _mn = _isaretler select 0;
    {
        ["lambs_danger_gozetleAta", [netId _x, _mn]] call CBA_fnc_serverEvent;
    } forEach _gruplar;
    diag_log format ["[EDEN] Gozetle (3DEN) | %1 grup -> %2 (%3)", count _gruplar, _mn, markerText _mn];
};
