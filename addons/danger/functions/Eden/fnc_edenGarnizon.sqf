#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * 3DEN: ELITE Karakol Garnizon modulu (v8.362; v8.400: karakol yoksa OTOMATIK karakol kurulur, SYNC'li IHA = surekli gozlem). Karakol yaricapi + CBA garnizonEk (v8.393: varsayilan 500 m) icine yerlestirilir (garnizon alani karakolun yaricapidir); nobetci / devriye / ust kat / arac mevzisi ayarlari (Zeus lambs_danger_garnizonIstegi). Karakol modulunden SONRA calisir (6 sn gecikme).
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
    // v8.398: IHA gozlem (karakola bagli): 0 yok / 1 surekli / 2 alarmda; modulle SYNC edilen IHA'lar (unitIsUAV) yalniz onlar kullanilir, baglanmazsa karakol cevresindeki bosta IHA
    private _ihaMod = ["edGarIha", 0] call _n;
    private _ihaNid = ((["BAGLI", [_logic]] call FUNC(edenOrtak)) select {unitIsUAV _x}) apply {netId _x};
    // v8.400 (RPT 2026: SYNC'li IHA vardi ama 'IHA gozlem = Yok' kalmisti, IHA hic kalkmadi): modulle IHA SYNC edildiyse mod 'Yok' olsa bile SUREKLI sayilir
    if (_ihaMod isEqualTo 0 && {_ihaNid isNotEqualTo []}) then {
        _ihaMod = 1;
        diag_log format ["[EDEN] Garnizon (3DEN) %1: %2 IHA SYNC'li ama 'IHA gozlem = Yok' -> Surekli gozlem olarak uygulandi", mapGridPosition _poz, count _ihaNid];
    };
    private _iha = [_ihaMod, ["edGarIhaYar", 0] call _n, ["edGarIhaSure", 0] call _n, _ihaNid];
    ["lambs_danger_garnizonIstegi", [_poz, 0, _nobet, _dev, _devBoy, _ust, _arac, _uyeler, _devMes, _gruplar, _iha, ["edGarAA", 0] call _n]] call CBA_fnc_serverEvent;
    diag_log format ["[EDEN] Garnizon (3DEN) | %1 | nobet %2 | devriye %3 x %4 | ust kat %5 | arac %6 | baglanan asker %7 | baglanan takim %9 | iha mod %10 (baglanan IHA %11) | devriye mesafesi %8", mapGridPosition _poz, _nobet, _dev, _devBoy, _ust, _arac, count _uyeler, _devMes, count _gruplar, _ihaMod, count _ihaNid];
};
