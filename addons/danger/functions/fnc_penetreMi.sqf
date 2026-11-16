#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * PENETRASYON TESTI (v8.557; kullanici: 'botlar gorus acisinin olmadigi ama penetrasyonun mumkun oldugu tahta objeleri bulsunlar, sutre arkasindaki hedefe atmaya devam etsinler').
 * Atici gozunden hedefe FIRE LOD hatti: terrain (tepe) YOK ve hattaki nesneler (<= 3) HEPSI penetre edilebilir (tahta / kumas / brandra / bambu / hasir / calı / yaprak ...) ve HICBIRI sert (beton / tugla / tas / kaya / metal / celik / kum torbasi / konteyner / arac) degilse mermi gecer sayilir.
 * Nesne turu model adi + sinif adi JETONLARIYLA siniflanir (Arma'da malzeme penetrasyonu scriptle okunamaz; TAHMIN): jeton yoksa BILINMEYEN = gecmez (muhafazakar). Misyon degiskeni lambs_danger_penetreJetonlari = [[penetre jetonlari], [sert jetonlar]] ekleyebilir.
 * Hat tamamen temizse (hic nesne yok) [true, 0] doner.
 *
 * Arguments:
 * 0: Atici goz ASL <ARRAY>
 * 1: Hedef ASL <ARRAY>
 * 2: Yoksayilacak nesne 1 (atici / arac) <OBJECT>
 * 3: Yoksayilacak nesne 2 (hedef) <OBJECT>
 *
 * Return Value: [gecer mi <BOOL>, nesne sayisi <NUMBER>]
 *
 * Public: No
*/

params ["_a", "_b", ["_i1", objNull], ["_i2", objNull]];
if (terrainIntersectASL [_a, _b]) exitWith {[false, -1]};
private _hits = lineIntersectsSurfaces [_a, _b, _i1, _i2, true, 5, "FIRE", "NONE"];
if (_hits isEqualTo []) exitWith {[true, 0]};
if ((count _hits) > 3) exitWith {[false, count _hits]};
private _ekstra = missionNamespace getVariable ["lambs_danger_penetreJetonlari", [[], []]];
private _pJ = ["wood", "plank", "fence", "tent", "tarp", "cloth", "sheet", "curtain", "camonet", "bamboo", "thatch", "straw", "hay", "hut", "shack", "shed", "crate", "barn", "plywood", "board", "pallet", "bush", "foliage", "palm", "reed", "mat_"] + (_ekstra select 0);
private _sJ = ["concrete", "brick", "stone", "rock", "metal", "steel", "iron", "armor", "armour", "bunker", "sandbag", "container", "cinder", "block", "wreck", "pipe", "pillar", "tank", "vehicle"] + (_ekstra select 1);
private _tamam = true;
{
    private _o = _x select 2;
    if (isNull _o || {_o isKindOf "AllVehicles"}) exitWith { _tamam = false; };
    private _ad = toLower (((getModelInfo _o) select 0) + " " + (typeOf _o));
    if ((_sJ findIf {(_ad find _x) >= 0}) >= 0) exitWith { _tamam = false; };
    if ((_pJ findIf {(_ad find _x) >= 0}) < 0) exitWith { _tamam = false; };
} forEach _hits;
[_tamam, count _hits]
