#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * KOMUTAN PLANI SUNUCU KAPISI (v8.116) — Zeus modulleri CURATOR'UN makinesinde calisir; gruplar ise SUNUCUDA yereldir. Planlayici yerel gruplari kullandigi icin
 * dedicated / listen (Zeus istemcide) sunucuda plan 'uygun grup yok' diyerek kurulamazdi. Moduller artik CBA sunucu olayi gonderir; bu kapi sunucuda dinler ve plani sunucuda kurar.
 *   lambs_danger_planIstegi      [taraf, objektif, ayar (HashMap -> [[anahtar, deger]])]
 *   lambs_danger_planNoktaIstegi [taraf, nokta adi, pozisyon ya da []]  (manuel plan noktasi ekle / sil)
 * Log: [PLAN-KAPI]
 *
 * Arguments: None
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isNil "lambs_danger_planKapiStarted") exitWith {false};
lambs_danger_planKapiStarted = true;

["lambs_danger_planIstegi", {
    params ["_taraf", "_obj", "_ayarCiftler"];
    if (!isServer) exitWith {};
    diag_log format ["[PLAN-KAPI] plan istegi alindi (sunucu): %1 | %2", _taraf, mapGridPosition _obj];
    // v8.121: sonuc tum makinelere bildirilir (Zeus ekraninda systemChat); istemci RPT'sinde de gorunur
    [_taraf, _obj, _ayarCiftler] spawn {
        params ["_taraf", "_obj", "_ayarCiftler"];
        private _ayar = createHashMapFromArray _ayarCiftler;
        private _r = [_taraf, _obj, _ayar] call (missionNamespace getVariable ["lambs_danger_fnc_komutanPlan", {false}]);
        ["lambs_danger_planYanit", [_taraf, _ayar getOrDefault ["tip", 0], _r isEqualTo true]] call CBA_fnc_globalEvent;
    };
}] call CBA_fnc_addEventHandler;

// v8.121: sunucudan donen yanit (her makinede; yalniz arayuzu olan gosterir)
["lambs_danger_planYanit", {
    params ["_taraf", "_tip", "_ok"];
    if (!hasInterface) exitWith {};
    private _m = switch (_tip) do {
        case 2: { ["IPTAL: aktif plan yok", "IPTAL: plan durduruldu"] select _ok };
        case 3: { ["ONAY: bekleyen plan yok", "ONAY: plan baslatildi"] select _ok };
        default { ["PLAN KURULAMADI: uygun grup yok (en az 3 canli AI asker, o taraf icin ELITE acik, objektife <= 4000 m, baska planda degil)", "PLAN KURULDU (haritada ELITE_PLAN isaretleri + grup waypoint'leri)"] select _ok };
    };
    diag_log format ["[PLAN-YANIT] %1 | %2", _taraf, _m];
    if (!isNull (getAssignedCuratorLogic player)) then { systemChat format ["[ELITE] %1", _m]; };
}] call CBA_fnc_addEventHandler;

["lambs_danger_planNoktaIstegi", {
    params ["_taraf", "_ad", "_poz"];
    if (!isServer) exitWith {};
    if (isNil "lambs_danger_planManuel") then { lambs_danger_planManuel = createHashMap; };
    private _anahtar = format ["%1|%2", _taraf, _ad];
    private _mn = format ["ELITE_MANUEL_%1_%2", _taraf, _ad];
    if (_poz isEqualTo []) then {
        lambs_danger_planManuel deleteAt _anahtar;
        deleteMarker _mn;
    } else {
        lambs_danger_planManuel set [_anahtar, _poz];
        deleteMarker _mn;
        createMarker [_mn, _poz];
        _mn setMarkerType "mil_destroy";
        _mn setMarkerColor (switch (_taraf) do { case west: {"ColorBLUFOR"}; case east: {"ColorOPFOR"}; default {"ColorIndependent"} });
        _mn setMarkerText format ["MANUEL %1", _ad];
    };
    diag_log format ["[PLAN-MANUEL] %1 | %2 | %3", _taraf, _ad, ["SILINDI", format ["konuldu: %1 (sonraki Objektif planinda kullanilir)", mapGridPosition _poz]] select (_poz isNotEqualTo [])];
}] call CBA_fnc_addEventHandler;

diag_log "[PLAN-KAPI] komutan plani sunucu kapisi baslatildi (v8.116)";
true
