#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * TOHUM BASLAT (v8.501; Asama 7 adim 1, bkz. YOL_HARITASI_v8.4xx.md + RNG_ENVANTERI.md): oturumun rastgelelik tohumunu belirler ve yayar.
 * ONCELIK: (1) senaryo degiskeni lambs_danger_tohum (> 0; init.sqf / 3DEN) > (2) CBA sunucu ayari lambs_danger_tohumAyar (> 0 sabit; 0 = otomatik) > (3) OTOMATIK (UTC saati + diag_tickTime).
 * Tohum SADECE sunucuda uretilir; missionNamespace lambs_danger_tohumDeger (+ kaynak: lambs_danger_tohumKaynak) publicVariable ile yayilir. Log: [TOHUM] tek satir; fnc_onUcus RUN satirina da yazilir.
 * SINIR: SQF sayilari 32-bit kayan nokta (24 bit hassasiyet): tohum 1 .. 999983 araliginda tutulur, kareler / carpimlar 16.7 milyonu gecmez.
 * Kapatma (eski davranis: motorun random'u): lambs_danger_rastgeleEskiOff = true.
 *
 * Arguments: None
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isServer) exitWith {false};
if (!isNil "lambs_danger_tohumDeger") exitWith {false};

private _kaynak = "OTOMATIK";
private _t = missionNamespace getVariable ["lambs_danger_tohum", 0];
if (!(_t isEqualType 0) || {_t <= 0}) then {
    _t = missionNamespace getVariable ["lambs_danger_tohumAyar", 0];
    if (_t isEqualType 0 && {_t > 0}) then { _kaynak = "CBA AYARI"; };
} else { _kaynak = "SENARYO DEGISKENI"; };
if (!(_t isEqualType 0) || {_t <= 0}) then {
    private _u = systemTimeUTC;
    _t = 1 + (floor ((((((_u select 3) * 60 + (_u select 4)) * 60 + (_u select 5)) * 17) + (_u select 6) + (floor ((diag_tickTime * 10) mod 997))) mod 999983));
    _kaynak = "OTOMATIK";
};
_t = 1 + ((floor (_t - 1)) mod 999983);
missionNamespace setVariable ["lambs_danger_tohumDeger", _t, true];
missionNamespace setVariable ["lambs_danger_tohumKaynak", _kaynak, true];
diag_log format ["[TOHUM] tohum %1 (%2) | rastgelelik: karar duzeyi cagrilari tohumlu / birim bazli; mikro (konum / zaman sapmasi) motorun random'u", _t, _kaynak];
true
