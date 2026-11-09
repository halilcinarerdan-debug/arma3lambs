#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * 3DEN: ELITE HAREKAT modulu (v8.404). Fazli harekat tanimi: ad, taraf, niyet, dusman durumu, H-saati, faz gecisi, faz adlari. 'ELITE Objektif' modullerini bu module SYNC edin ve her Objektif modulunde 'Harekat fazi' secin
 *   (1..6): ayni fazin objektifleri birlikte baslar; faz bitince (planlar BITTI) toparlanma beklemesinden sonra siradaki faz baslar. Harekat bildirimi oyunculara ARMA GOREVI olarak (ana gorev = taslak OPORD) duser;
 *   planin gruplarinda oyuncu varsa rol gorevi yazilir. Modul konumu onemsiz (haritada isaret yok). Ayrinti: fnc_harekat. Log: [EDEN] / [HAREKAT].
 * Arguments: 0: modul <OBJECT>, 1: baglananlar (kullanilmaz), 2: etkin <BOOL>
 * Return Value: None
 * Public: No
*/

params ["_logic", "", "_activated"];
if (!_activated || {!isServer}) exitWith {};
// v8.501 TETIKLE BASLATMA (Asama 9 adim 1; modul isTriggerActivated = 1): bir Trigger SYNC'liyse fonksiyon tetik tetiklenince (_activated = true) cagrilir; tetik yoksa mission basinda. Tek seferlik: tetik tekrar tetiklenirse ikinci plan KURULMAZ.
if (_logic getVariable ["lambs_danger_tetikBasladi", false]) exitWith { diag_log format ["[EDEN] %1 (3DEN) %2: zaten baslatildi, ikinci tetik yok sayildi", "Harekat", mapGridPosition _logic] };
_logic setVariable ["lambs_danger_tetikBasladi", true];
diag_log format ["[EDEN] %1 (3DEN) %2: baslatildi | bagli tetik (Trigger): %3", "Harekat", mapGridPosition _logic, count ((synchronizedObjects _logic) select {_x isKindOf "EmptyDetector"})];

[_logic] spawn {
    params ["_logic"];
    if !(["BEKLE"] call FUNC(edenOrtak)) exitWith { diag_log "[EDEN] Harekat: ELITE hazir olmadi (180 sn)" };
    private _n = { params ["_ad", "_v"]; round (["SAYI", [_logic, "lambs_danger_" + _ad, _v]] call FUNC(edenOrtak)) };
    private _s = { params ["_ad", "_v"]; private _x = _logic getVariable ["lambs_danger_" + _ad, _v]; if (_x isEqualType "") then { (_x splitString (toString [34])) joinString "" } else {_v} };
    if ((_logic getVariable ["lambs_danger_harekatId", ""]) isNotEqualTo "") exitWith {};
    private _id = format ["H%1", (count (keys (missionNamespace getVariable ["lambs_danger_harekatlar", createHashMap]))) + 1];
    _logic setVariable ["lambs_danger_harekatId", _id, true];
    // taraf: acik secim, yoksa baglanan Objektif modullerinin tarafi (varsayilan BLUFOR)
    private _tarafA = ["edHrTaraf", 0] call _n;
    private _taraf = [west, east, independent] select (((_tarafA - 1) max 0) min 2);
    if (_tarafA <= 0) then {
        private _ob = (["MODUL", [_logic, QGVAR(EdenObjektif)]] call FUNC(edenOrtak)) + (["MODUL", [_logic, QGVAR(EdenSaldiri)]] call FUNC(edenOrtak)) + (["MODUL", [_logic, QGVAR(EdenSavunma)]] call FUNC(edenOrtak));
        { private _ta = round (["SAYI", [_x, "lambs_danger_edObTaraf", 0]] call FUNC(edenOrtak)); if (_ta > 0) exitWith { _taraf = [west, east, independent] select ((_ta - 1) min 2); }; } forEach _ob;
        { private _g = ["GRUPLAR", [_x]] call FUNC(edenOrtak); if (_g isNotEqualTo []) exitWith { _taraf = side (_g select 0); }; } forEach (_ob select {round (["SAYI", [_x, "lambs_danger_edObTaraf", 0]] call FUNC(edenOrtak)) <= 0});
    };
    private _hDk = [0, 5, 10, 15, 30] select (((["edHrBasla", 0] call _n) max 0) min 4);
    private _hMod = [0, 1] select ((["edHrBasla", 0] call _n) >= 5);
    private _bekle = [0, 120, 300, 600] select (((["edHrBekle", 0] call _n) max 0) min 3);
    private _fazSure = [0, 900, 1800, 2700, 3600, 7200] select (((["edHrFazSure", 0] call _n) max 0) min 5);
    private _adlar = [];
    for "_i" from 1 to 6 do { _adlar pushBack (([format ["edHrFaz%1", _i], ""] call _s)); };
    [
        "KUR", [
            _id, [["edHrAd", "Harekat"] call _s, "Harekat"] select ((["edHrAd", ""] call _s) isEqualTo ""), _taraf, ["edHrNiyet", ""] call _s, ["edHrDusman", ""] call _s,
            _hMod, _hDk, _bekle, _fazSure, (["edHrSureAsimi", 0] call _n) min 1, (["edHrBasarisiz", 1] call _n) >= 1, _adlar
        ]
    ] call lambs_danger_fnc_harekat;
};
