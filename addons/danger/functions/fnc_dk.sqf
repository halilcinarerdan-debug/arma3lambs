#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * Doktrin degeri okuyucu: tek anahtar. Profil yoksa / anahtar yoksa verilen varsayilan doner (davranis degismez).
 *
 * Arguments:
 * 0: Grup <GROUP> (veya birim)
 * 1: Anahtar <STRING>
 * 2: Varsayilan <ANY>
 *
 * Return Value:
 * Deger <ANY>
 *
 * Example:
 * [_group, "assaultM", 45] call lambs_danger_fnc_dk;
 *
 * Public: No
*/

params ["_g", "_k", "_d"];
private _p = [_g] call FUNC(doktrin);
private _v = _p getOrDefault [_k, _d];
// v8.507 BOUNDING AGRESIFLIGI: hucum / bounding bitis mesafesi (dusmana ne kadar yaklasilir) temkinli 1.0 / dengeli 0.85 / agresif 0.7 ile carpilir
if (_k in ["assaultM", "bndBitisM"] && {_v isEqualType 0}) then {
    _v = _v * ([1, 0.85, 0.7] select ((missionNamespace getVariable ["lambs_danger_bndAgresif", 2]) max 0 min 2));
};
_v
