#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * LAZER GUDUMLU (LG) MERMILI TOPCU LISTESI (v8.365; fnc_sihaLazer canlandirmasi) — dron gozlemli atista SIHA lazer isaretlemesiyle kullanilabilecek bataryalar.
 * fnc_topcuListe lazer-gudumlu mermileri BILEREK disarida tutar (genel HE atisi icin); bu fonksiyon tersini yapar: yalniz LG mermisi olan, hedefi menzilinde tutan AI topcu / havan araclarini dondurur.
 * Filtre (topcuListe ile ayni ilke): artilleryScanner > 0, canli, tarafin, yerel, nisanci AI (oyuncu degil), canFire, Zeus 'TOPCU_YOK' degil.
 * LG mermi tanimi (sinif adi, kucuk harf): '_lg' ile biter (vanilla Sh_155mm_AMOS_LG, 8Rnd_82mm_Mo_LG ...) ya da 'laser' / 'copperhead' / 'krasnopol' icerir (RHS / CUP). Mod sinifi bu kaliba uymazsa LG sayilmaz (sessizce HE akisi surer).
 *
 * Arguments:
 * 0: Taraf <SIDE>
 * 1: Hedef konumu <ARRAY> (menzil kontrolu)
 *
 * Return Value: [[arac, LG mermi sinifi], ...] <ARRAY>
 * Public: No
*/

params [["_taraf", sideUnknown, [sideUnknown]], ["_hedef", [], [[]]]];
if (_hedef isEqualTo []) exitWith {[]};
private _cikti = [];
{
    private _v = _x;
    if (alive _v && {(side (group _v)) isEqualTo _taraf} && {(getNumber (configOf _v >> "artilleryScanner")) > 0} && {!isNull (gunner _v)} && {!isPlayer (gunner _v)} && {local _v} && {canFire _v}
        && {!("TOPCU_YOK" in [_v getVariable ["lambs_danger_gorev", ""], (group (gunner _v)) getVariable ["lambs_danger_gorev", ""]])}) then {
        private _lg = (getArtilleryAmmo [_v]) select {
            private _a = toLower _x;
            ((_a select [(count _a) - 3, 3]) isEqualTo "_lg") || {(_a find "laser") >= 0} || {(_a find "copperhead") >= 0} || {(_a find "krasnopol") >= 0}
        };
        private _mg = _lg param [0, ""];
        if (_mg isNotEqualTo "" && {_hedef inRangeOfArtillery [[_v], _mg]}) then { _cikti pushBack [_v, _mg]; };
    };
} forEach vehicles;
_cikti
