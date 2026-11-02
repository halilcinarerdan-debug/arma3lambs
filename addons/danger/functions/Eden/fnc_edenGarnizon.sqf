#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * 3DEN: ELITE Karakol Garnizon modulu (v8.362). Karakol yaricapi + 150 m icine yerlestirilir; nobetci / devriye / ust kat / arac mevzisi ayarlari (Zeus lambs_danger_garnizonIstegi). Karakol modulunden SONRA calisir (6 sn gecikme).
 * Arguments: 0: modul <OBJECT>, 1: baglananlar (kullanilmaz), 2: etkin <BOOL>
 * Return Value: None
 * Public: No
*/

params ["_logic", "", "_activated"];
if (!_activated || {!isServer}) exitWith {};

[_logic] spawn {
    params ["_logic"];
    if !(["BEKLE"] call FUNC(edenOrtak)) exitWith { diag_log "[EDEN] Garnizon: ELITE hazir olmadi (180 sn)" };
    sleep 6;
    private _n = { params ["_ad", "_v"]; round (["SAYI", [_logic, "lambs_danger_" + _ad, _v]] call FUNC(edenOrtak)) };
    private _b = { params ["_ad", "_v"]; ["BOOL", [_logic, "lambs_danger_" + _ad, _v]] call FUNC(edenOrtak) };
    private _poz = getPosATL _logic;
    private _nobet = ["edGarNobet", 3] call _n;
    private _dev = ["edGarDev", 1] call _n;
    private _devBoy = ["edGarDevBoy", 3] call _n;
    private _ust = ["edGarUst", true] call _b;
    private _arac = ["edGarArac", true] call _b;
    ["lambs_danger_garnizonIstegi", [_poz, 0, _nobet, _dev, _devBoy, _ust, _arac]] call CBA_fnc_serverEvent;
    diag_log format ["[EDEN] Garnizon (3DEN) | %1 | nobet %2 | devriye %3 x %4 | ust kat %5 | arac %6", mapGridPosition _poz, _nobet, _dev, _devBoy, _ust, _arac];
};
