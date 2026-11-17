#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * PERFORMANS KAYDI (v8.579; kullanici: 'projeyi profesyonel bir gelistirici gibi tara ... 6 parca, her bitti dediginde log atarim'): hafif etiketli sure / sayac toplayici.
 * Kullanim: private _t0 = diag_tickTime; ...is...; [etiket, _t0] call lambs_danger_fnc_perfKayit;   (yalniz sayac icin: [etiket, -1] -> sure eklenmez, sayac artar)
 * 60 sn'de bir [PERF-FNC] logu: etiket basina cagri sayisi / toplam ms / ort ms / en yuksek ms (toplama gore ilk 12). Kapatma: CBA perfProfil (varsayilan ACIK; yalniz log, davranis degistirmez).
 *
 * Arguments:
 * 0: Etiket <STRING>
 * 1: Baslangic diag_tickTime (-1 = yalniz sayac) <NUMBER>
 *
 * Return Value: Yok
 * Public: No
*/

params ["_ad", ["_t0", -1]];
if !(missionNamespace getVariable ["lambs_danger_perfProfil", true]) exitWith {};
if (isNil "lambs_danger_perfH") then { lambs_danger_perfH = createHashMap; lambs_danger_perfT = time + 60; };
private _k = lambs_danger_perfH getOrDefault [_ad, [0, 0, 0]];
private _ms = if (_t0 < 0) then {0} else {(diag_tickTime - _t0) * 1000};
_k set [0, (_k select 0) + 1];
_k set [1, (_k select 1) + _ms];
_k set [2, (_k select 2) max _ms];
lambs_danger_perfH set [_ad, _k];
if (time > lambs_danger_perfT) then {
    lambs_danger_perfT = time + 60;
    private _satirlar = (keys lambs_danger_perfH) apply { private _v = lambs_danger_perfH get _x; [_v select 1, _x, _v select 0, _v select 2] };
    _satirlar sort false;
    diag_log format ["[PERF-FNC] son 60 sn (cagri / toplam ms / ort ms / en yuksek ms): %1", (_satirlar select [0, 12]) apply { _x params ["_tm", "_ad2", "_n", "_mx"]; format ["%1 %2 / %3 / %4 / %5", _ad2, _n, round _tm, if (_n > 0) then {(_tm / _n) toFixed 2} else {"-"}, _mx toFixed 1] } joinString " | "];
    lambs_danger_perfH = createHashMap;
};
