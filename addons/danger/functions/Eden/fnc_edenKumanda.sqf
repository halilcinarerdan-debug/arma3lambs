#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * 3DEN: ELITE Koordinasyon (Kumanda) modulu (v8.362). Zeus 'ELITE Koordinasyon' ile AYNI genel degiskenleri yazar (lambs_danger_hqAktif ve hq*V1 anahtarlari). Baglanti gerekmez.
 * Arguments: 0: modul <OBJECT>, 1: baglananlar (kullanilmaz), 2: etkin <BOOL>
 * Return Value: None
 * Public: No
*/

params ["_logic", "", "_activated"];
if (!_activated || {!isServer}) exitWith {};

[_logic] spawn {
    params ["_logic"];
    if !(["BEKLE"] call FUNC(edenOrtak)) exitWith { diag_log "[EDEN] Koordinasyon: ELITE hazir olmadi (180 sn)" };
    private _b = { params ["_ad", "_v"]; ["BOOL", [_logic, _ad, _v]] call FUNC(edenOrtak) };
    private _aktif = ["lambs_danger_edKumAktif", true] call _b;
    private _ist = ["lambs_danger_edKumIstihbarat", true] call _b;
    private _tak = ["lambs_danger_edKumTakviye", true] call _b;
    private _kan = ["lambs_danger_edKumKanat", true] call _b;
    private _fei = ["lambs_danger_edKumFeint", true] call _b;
    private _med = ["lambs_danger_edKumMedevac", false] call _b;
    private _up = ["lambs_danger_edKumUpstream", true] call _b;
    missionNamespace setVariable ["lambs_danger_hqAktif", _aktif, true];
    missionNamespace setVariable ["lambs_danger_hqIstihbaratV1", _ist, true];
    missionNamespace setVariable ["lambs_danger_hqTakviyeV1", _tak, true];
    missionNamespace setVariable ["lambs_danger_hqKanatV1", _kan, true];
    missionNamespace setVariable ["lambs_danger_hqFeintV1", _fei, true];
    missionNamespace setVariable ["lambs_danger_hqMedevacV1", _med, true];
    missionNamespace setVariable ["lambs_danger_hqUpstreamKapat", _up, true];
    diag_log format ["[EDEN] Koordinasyon (3DEN) | kumanda %1 | istihbarat:%2 takviye:%3 kanat:%4 feint:%5 medevac:%6 | LAMBS reinforcement kapat:%7", ["KAPALI", "AKTIF"] select _aktif, _ist, _tak, _kan, _fei, _med, _up];
};
