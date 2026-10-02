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
_p getOrDefault [_k, _d]
