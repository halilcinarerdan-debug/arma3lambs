#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * 3DEN: ELITE Karakol / Mevzi modulu (v8.362). Modul konumunda karakol / mevzi / gozetleme noktasi kaydi + harita isareti (Zeus lambs_danger_karakolIstegi). Savunma = HEMEN ve module gruplar SYNC edilmisse savunma plani
 * YALNIZ bu gruplarla kurulur (Zeus 'Elle sec' ile ayni: planIstegi, tip 1, secili); grup baglanmamissa yaricap x1.5 icindeki savunan gruplar otomatik alinir.
 * Arguments: 0: modul <OBJECT>, 1: baglananlar (kullanilmaz), 2: etkin <BOOL>
 * Return Value: None
 * Public: No
*/

params ["_logic", "", "_activated"];
if (!_activated || {!isServer}) exitWith {};

[_logic] spawn {
    params ["_logic"];
    if !(["BEKLE"] call FUNC(edenOrtak)) exitWith { diag_log "[EDEN] Karakol: ELITE hazir olmadi (180 sn)" };
    private _gruplar = ["GRUPLAR", [_logic]] call FUNC(edenOrtak);
    private _taraf = ["TARAF", [_logic, "lambs_danger_edKarTaraf", _gruplar]] call FUNC(edenOrtak);
    private _adI = (round (["SAYI", [_logic, "lambs_danger_edKarAd", 0]] call FUNC(edenOrtak))) max 0 min 2;
    private _yar = round (["SAYI", [_logic, "lambs_danger_edKarYar", 120]] call FUNC(edenOrtak));
    private _sav = (round (["SAYI", [_logic, "lambs_danger_edKarSav", 1]] call FUNC(edenOrtak))) max 0 min 2;
    private _poz = getPosATL _logic;
    private _secili = (_gruplar select {(side _x) isEqualTo _taraf}) apply {netId _x};
    private _elle = _sav isEqualTo 1 && {_secili isNotEqualTo []};
    ["lambs_danger_karakolIstegi", [_taraf, _poz, _adI, _yar, _sav, _elle]] call CBA_fnc_serverEvent;
    if (_elle) then {
        private _ayar = createHashMapFromArray [["tip", 1], ["grupN", count _secili], ["grupMesafe", _yar * 1.5], ["bina", true], ["piyade", true], ["rallyM", 250], ["orpM", 150], ["basla", 0], ["secili", _secili]];
        ["lambs_danger_planIstegi", [_taraf, _poz, _ayar toArray false]] call CBA_fnc_serverEvent;
    };
    diag_log format ["[EDEN] Karakol (3DEN) | %1 | %2 | %3 m | savunma %4 | baglanan grup %5 (%6)", _taraf, mapGridPosition _poz, _yar, ["YOK", "HEMEN", "ALARM"] select _sav, count _secili, ["otomatik grup", "elle secilmis"] select _elle];
};
