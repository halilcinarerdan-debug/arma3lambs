#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * TOPCU LISTESI (v8.338) — dron gozlemli atis (fnc_dronTopcu) ve taciz atisi (fnc_topcuTaciz) icin: tarafin kullanilabilir AI topcu / havan araclari ve her biri icin HE mermisi.
 * Filtre (fnc_topcuDestek ile ayni ilke): artilleryScanner > 0, canli, tarafin, yerel, nisanci AI (oyuncu degil), canFire, Zeus 'TOPCU_YOK' degil.
 * Mermi: getArtilleryAmmo icinden duman / isik / fisek / kume / mayin / lazer-güdümlü / roket (MLRS: RED tablosu yok) HARIC ilk HE.
 *
 * Arguments:
 * 0: Taraf <SIDE>
 *
 * Return Value: [[arac, mermi sinifi], ...] <ARRAY>
 * Public: No
*/

params [["_taraf", sideUnknown, [sideUnknown]]];

private _haric = ["smoke", "illum", "flare", "cluster", "mine", "laser", "guid", "rocket", "mlrs", "230mm"];
private _cikti = [];
{
    private _v = _x;
    if (alive _v && {(side (group _v)) isEqualTo _taraf} && {(getNumber (configOf _v >> "artilleryScanner")) > 0} && {!isNull (gunner _v)} && {!isPlayer (gunner _v)} && {local _v} && {canFire _v}
        && {!("TOPCU_YOK" in [_v getVariable ["lambs_danger_gorev", ""], (group (gunner _v)) getVariable ["lambs_danger_gorev", ""]])}) then {
        private _mg = ((getArtilleryAmmo [_v]) select { private _a = toLower _x; (_haric findIf {(_a find _x) >= 0}) < 0 }) param [0, ""];
        if (_mg isNotEqualTo "") then { _cikti pushBack [_v, _mg]; };
    };
} forEach vehicles;
_cikti
