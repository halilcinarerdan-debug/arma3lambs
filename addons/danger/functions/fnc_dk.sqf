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
    _v = _v * ([1, 0.85, 0.7] select (["agr"] call FUNC(cag)));
};
// v8.823 MEKAN DOKTRINI (yol haritasi madde 34; kullanici: 'cevreye gore doktrin'): grubun MEKAN sinifina (fnc_mekanSinif) gore sayisal doktrin degerleri carpilir (tasarim degerleri; manevra secimi degismez).
//   deger = taban x (1 + (carpan - 1) x mekanDoktrinGuc); 'bantlar' dizisinde yalniz atilim (2. eleman) carpilir. CBA mekanDoktrin (kapali = degisiklik yok), mekanDoktrinGuc (0-1).
private _mekAnahtar = ["assaultM", "bndBitisM", "bantlar", "owKurulumS", "pusuAtesM", "yakinM", "konsolidasyonS"];
if (_k in _mekAnahtar && {missionNamespace getVariable ["lambs_danger_mekanDoktrin", true]}) then {
    private _tab = missionNamespace getVariable ["lambs_danger_mekanTablo", createHashMap];
    if ((count _tab) isEqualTo 0) then {
        _tab = createHashMapFromArray [
            ["ACIK|assaultM", 1.2], ["ACIK|bndBitisM", 1.2], ["ACIK|bantlar", 1.3], ["ACIK|pusuAtesM", 1.3],
            ["ORMAN|assaultM", 0.75], ["ORMAN|bndBitisM", 0.75], ["ORMAN|bantlar", 0.7], ["ORMAN|owKurulumS", 0.8], ["ORMAN|pusuAtesM", 0.6], ["ORMAN|yakinM", 0.8], ["ORMAN|konsolidasyonS", 1.1],
            ["KENTSEL|assaultM", 0.7], ["KENTSEL|bndBitisM", 0.7], ["KENTSEL|bantlar", 0.6], ["KENTSEL|owKurulumS", 0.8], ["KENTSEL|pusuAtesM", 0.5], ["KENTSEL|yakinM", 0.7], ["KENTSEL|konsolidasyonS", 1.3],
            ["TEPELIK|bndBitisM", 1.1], ["TEPELIK|bantlar", 0.9], ["TEPELIK|owKurulumS", 1.3], ["TEPELIK|assaultM", 1.1]
        ];
        missionNamespace setVariable ["lambs_danger_mekanTablo", _tab];
    };
    private _sinif = [_g] call FUNC(mekanSinif);
    private _m = _tab getOrDefault [_sinif + "|" + _k, 1];
    if (_m isNotEqualTo 1) then {
        private _guc = ((missionNamespace getVariable ["lambs_danger_mekanDoktrinGuc", 1]) max 0) min 1;
        _m = 1 + ((_m - 1) * _guc);
        if (_v isEqualType 0) then { _v = _v * _m; } else {
            if (_v isEqualType [] && {_k isEqualTo "bantlar"}) then { _v = _v apply { if (_x isEqualType [] && {(count _x) >= 3}) then { [_x select 0, (_x select 1) * _m, _x select 2] } else { _x } }; };
        };
        private _ms = missionNamespace getVariable ["lambs_danger_mekanDkSay", createHashMap];
        _ms set [_sinif + "|" + _k, (_ms getOrDefault [_sinif + "|" + _k, 0]) + 1];
        missionNamespace setVariable ["lambs_danger_mekanDkSay", _ms];
    };
};
_v
