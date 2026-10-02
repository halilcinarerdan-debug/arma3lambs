#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * KUMANDA MODULU: TAKVIYE (dinamik reinforcement, karar beyinli).
 *
 * LAMBS'ta (upstream XEH_preInit OnInformationShared) tum "enableGroupReinforce" bayrakli gruplar telsiz menzilinde HEPSI ayni anda dusman noktasina kosar,
 * kimin gercekten yardima ihtiyaci oldugu, kimin musait oldugu sorulmaz, bayrak varsayilan KAPALIDIR (RPT: [TELSIZ-GRUP] reinforce:'yok').
 * Bu modul: durum tahtasindan YARDIM ISTEYEN grubu secer, MUSAIT en uygun 1-2 grubu belirler, her birine KANATTAN yaklasan hedef noktasi ile TAKVIYE emri verir.
 *
 * YARDIM ISTEYEN: temasta + commanderAssess durumu taze (< 30 sn) + (kayip >= %25 ya da guc orani >= 1.2 ya da retreat / kacis / son direnis bayragi);
 *   en yakin dusman pozisyonu bilinmeli; son 90 sn'de takviye almamis.
 * MUSAIT (tahta): taktik bayragi yok, temas 20 sn+ yok, >= 3 kisi, tasitta degil, son 180 sn'de gorev almamis, hqTakviyeKatilim != false.
 *   Menzil: 60 - hqYardimM (900) m. Skor = -mesafe + 10 * kisi.  Ihtiyac: oran >= 2 ya da kayip >= %50 -> 2 grup, aksi 1 grup.
 * HEDEF: dusmanin 110 m'si, yardim isteyenin dusmandan geri yonune +-65 derece (musait grubun yakin oldugu kanat); su ya da gecersizse yardim isteyenin konumu.
 * ZAMANLAMA: 8 sn'de bir; turda en acil 1 yardim isteyen islenir (toplu kosusma yok).
 *
 * Kapatma: lambs_danger_hqTakviyeV1 = false (varsayilan acik); grup basina: grup.setVariable ["lambs_danger_hqTakviyeKatilim", false] (musait olmaz);
 *   doktrin anahtari hqTakviye (varsayilan true), hqYardimM (varsayilan 900).
 * Log: [HQ-TAKVIYE] (ilk 150 satir)
 *
 * Arguments:
 * 0: Taraf <SIDE>
 * 1: Durum tahtasi <ARRAY of HASHMAP> (fnc_hq)
 *
 * Return Value: Emir verildi mi <BOOL>
 * Public: No
*/

params [["_taraf", sideUnknown, [sideUnknown]], ["_tahta", [], [[]]]];

private _musaitlar = _tahta select {_x get "musait"};
if (_musaitlar isEqualTo []) exitWith {false};

// yardim isteyenler
private _istekler = _tahta select {
    private _g = _x get "g";
    (_x get "temasta")
    && {(_x get "n") >= 1}
    && {(time - (_g getVariable ["lambs_danger_hqYardimT", -999])) > 90}
    && {[_g, "hqTakviye", true] call FUNC(dk)}
    && {
        private _sit = _x get "sit";
        (_sit isEqualType []) && {(count _sit) >= 8} && {(time - (_sit select 0)) < 30}
        && {(_sit select 7) isEqualType []} && {(_sit select 7) isNotEqualTo [0, 0, 0]}
        && {
            (_x get "kayip") >= 0.25
            || {(_sit select 5) >= 1.2}
            || {_g getVariable ["lambs_danger_isRetreating", false]}
            || {_g getVariable ["lambs_danger_isBreakingContact", false]}
            || {_g getVariable ["lambs_danger_isSonDirenis", false]}
        }
    }
};
if (_istekler isEqualTo []) exitWith {false};

// en acil: retreat / kacis > guc orani > kayip
private _aciliyet = {
    private _g = _x get "g";
    private _sit = _x get "sit";
    (_sit select 5) + ((_x get "kayip") * 2)
    + ([0, 3] select ((_g getVariable ["lambs_danger_isRetreating", false]) || {_g getVariable ["lambs_danger_isBreakingContact", false]} || {_g getVariable ["lambs_danger_isSonDirenis", false]}))
};
private _siraliIstek = [_istekler, [], _aciliyet, "DESCEND"] call BIS_fnc_sortBy;
private _istek = _siraliIstek select 0;
private _istekG = _istek get "g";
private _istekPoz = _istek get "poz";
private _sit = _istek get "sit";
private _enP = +(_sit select 7);
private _oran = _sit select 5;
private _menzil = [_istekG, "hqYardimM", 900] call FUNC(dk);

// aday musaitler
private _adaylar = _musaitlar select {
    private _d = (_x get "poz") distance2D _istekPoz;
    (_x get "g") isNotEqualTo _istekG && {_d >= 60} && {_d <= _menzil}
};
if (_adaylar isEqualTo []) exitWith {false};
private _siraliAday = [_adaylar, [], { -((_x get "poz") distance2D _istekPoz) + (10 * (_x get "n")) }, "DESCEND"] call BIS_fnc_sortBy;

private _kac = [1, 2] select (_oran >= 2 || {(_istek get "kayip") >= 0.5});
private _verilen = 0;
private _B = _enP getDir _istekPoz;   // dusmandan yardim isteyene yon

{
    private _y = _x;
    private _yG = _y get "g";
    private _yPoz = _y get "poz";
    private _c1 = _enP getPos [110, _B + 65];
    private _c2 = _enP getPos [110, _B - 65];
    private _hedef = [_c2, _c1] select ((_yPoz distance2D _c1) < (_yPoz distance2D _c2));
    if (surfaceIsWater _hedef) then { _hedef = +_istekPoz; };

    [_yG, "TAKVIYE", [_hedef, groupId _istekG]] call FUNC(hqEmir);
    _verilen = _verilen + 1;

    if (isNil "lambs_danger_hqTakviyeN") then { lambs_danger_hqTakviyeN = 0; };
    if (lambs_danger_hqTakviyeN < 150) then {
        lambs_danger_hqTakviyeN = lambs_danger_hqTakviyeN + 1;
        diag_log format [
            "[HQ-TAKVIYE] %1 | yardim isteyen %2 (%3 kisi, kayip %4%%, oran %5, dusman %6 m) -> destek %7 (%8 kisi, %9 m uzakta) | hedef %10 | aday:%11 istek:%12",
            _taraf, groupId _istekG, _istek get "n", round ((_istek get "kayip") * 100), _oran toFixed 2, round (_sit select 1),
            groupId _yG, _y get "n", round (_yPoz distance2D _istekPoz), mapGridPosition _hedef, count _adaylar, count _istekler
        ];
    };
} forEach (_siraliAday select [0, _kac]);

if (_verilen > 0) then {
    _istekG setVariable ["lambs_danger_hqYardimT", time];
    [_istekG, "YARDIM_YOLDA", _verilen] call FUNC(olayGonder);
};
_verilen > 0
