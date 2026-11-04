#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * 3DEN: ELITE Karakol Garnizon modulu (v8.362). Karakol yaricapi + CBA garnizonEk (v8.393: varsayilan 500 m) icine yerlestirilir (garnizon alani karakolun yaricapidir); nobetci / devriye / ust kat / arac mevzisi ayarlari (Zeus lambs_danger_garnizonIstegi). Karakol modulunden SONRA calisir (6 sn gecikme).
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
    private _devMes = ["edGarDevMes", 0] call _n;
    // v8.394: module SYNC ile baglanan AI askerler garnizon havuzu olur (yaricap kurali yok); hic asker baglanmazsa yaricap havuzu
    private _uyeler = ((["BAGLI", [_logic]] call FUNC(edenOrtak)) select {(_x isKindOf "CAManBase") && {alive _x} && {!isPlayer _x}}) apply {netId _x};
    // v8.397: 'Secim modu' = 1 (takim): baglanan askerlerin TAKIMLARI (grup) garnizon askeri verebilir; 0 = yalniz baglanan askerler (v8.394)
    private _secimModu = ["edGarSecim", 0] call _n;
    private _gruplar = [];
    if (_secimModu isEqualTo 1 && {_uyeler isNotEqualTo []}) then {
        { _gruplar pushBackUnique (netId (group (objectFromNetId _x))); } forEach _uyeler;
        _uyeler = [];
    };
    ["lambs_danger_garnizonIstegi", [_poz, 0, _nobet, _dev, _devBoy, _ust, _arac, _uyeler, _devMes, _gruplar]] call CBA_fnc_serverEvent;
    diag_log format ["[EDEN] Garnizon (3DEN) | %1 | nobet %2 | devriye %3 x %4 | ust kat %5 | arac %6 | baglanan asker %7 | baglanan takim %9 | devriye mesafesi %8", mapGridPosition _poz, _nobet, _dev, _devBoy, _ust, _arac, count _uyeler, _devMes, count _gruplar];
};
