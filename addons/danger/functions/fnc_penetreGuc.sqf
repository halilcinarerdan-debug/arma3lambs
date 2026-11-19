#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * PENETRASYON FARKINDALIGI (v8.666; kullanici: 'penetrasyonu farkindaligi ekle, bu duvar arkasi atislar icin de gelsin'): FIRE LOD hattindaki nesnelerin MALZEME x KALINLIK direncini toplayip mermi gucu ile karsilastirir.
 *   (Arma'da gercek penetrasyon scriptle okunamaz: bu bir TAHMIN modeli; CBA penetreOlcek ile ayarlanir.)
 *   - hat: lineIntersectsSurfaces FIRE (<= 6 kesisim); ayni nesnenin ardisik iki kesisimi = giris / cikis -> KALINLIK (0.005-1.5 m); tek kesisimde malzemeye gore varsayilan kalinlik
 *   - malzeme jetonlari (model + sinif adi) -> direnc / m: kumas 4, bitki 10, tahta 30, ince metal 150 (varsayilan kalinlik 4 mm), kum cuvali 50, tugla / blok 60, beton 100, tas / kaya 120, bina duvari (house / building / wall) 35, BILINMEYEN 40; arac / null = gecmez
 *   - mesafe kaybi: guc x (1 - min(0.5, mesafe / 1500)); gecer = toplam direnc <= etkili guc x penetreOlcek
 * Arguments:
 * 0: Atici goz ASL <ARRAY>
 * 1: Hedef / nokta ASL <ARRAY>
 * 2: Yoksay 1 <OBJECT>
 * 3: Yoksay 2 <OBJECT>
 * 4: Mermi gucu <NUMBER> (fnc_munisyonGucu; varsayilan 2.4)
 *
 * Return Value: [gecer mi <BOOL>, kesisim sayisi <NUMBER>, bilinmeyen malzeme sayisi <NUMBER>, toplam direnc <NUMBER>, etkili guc <NUMBER>]
 * Public: No
*/

params ["_a", "_b", ["_i1", objNull], ["_i2", objNull], ["_guc", 2.4]];
private _mes = _a distance _b;
private _eg = _guc * (1 - ((_mes / 1500) min 0.5)) * ((missionNamespace getVariable ["lambs_danger_penetreOlcek", 1]) max 0.2);
if (terrainIntersectASL [_a, _b]) exitWith {[false, -1, 0, 999, _eg]};
private _hits = lineIntersectsSurfaces [_a, _b, _i1, _i2, true, 6, "FIRE", "NONE"];
if (_hits isEqualTo []) exitWith {[true, 0, 0, 0, _eg]};
private _tablo = [
    [["cloth", "tarp", "tent", "curtain", "camonet", "thatch", "straw", "hay"], 4, 0.02],
    [["bush", "foliage", "palm", "leaf", "branch", "hedge"], 10, 0.3],
    [["wood", "plank", "plywood", "board", "pallet", "fence", "crate", "barn", "hut", "shack", "shed", "door"], 30, 0.04],
    [["sandbag", "hesco", "gabion"], 50, 0.4],
    [["brick", "block", "cinder"], 60, 0.2],
    [["concrete", "bunker", "pillar", "cement"], 100, 0.2],
    [["stone", "rock", "cliff", "boulder"], 120, 0.5],
    [["metal", "steel", "iron", "container", "armor", "armour", "tin", "sheet"], 150, 0.004],
    [["house", "building", "wall", "shop", "villa", "hotel", "market"], 35, 0.15]
];
private _top = 0;
private _bil = 0;
private _gec = true;
private _n = count _hits;
private _i = 0;
while {_i < _n} do {
    private _o = (_hits select _i) select 2;
    if (isNull _o || {_o isKindOf "AllVehicles"}) exitWith { _gec = false; };
    private _kal = -1;
    if ((_i + 1) < _n && {((_hits select (_i + 1)) select 2) isEqualTo _o}) then {
        _kal = (((_hits select _i) select 0) distance ((_hits select (_i + 1)) select 0)) max 0.005 min 1.5;
        _i = _i + 2;
    } else { _i = _i + 1; };
    private _ad = toLower (((getModelInfo _o) select 0) + " " + (typeOf _o));
    private _res = 40;
    private _vk = 0.15;
    private _bulundu = false;
    {
        if ((_x select 0) findIf {(_ad find _x) >= 0} >= 0) exitWith { _res = _x select 1; _vk = _x select 2; _bulundu = true; };
    } forEach _tablo;
    if (!_bulundu) then { _bil = _bil + 1; };
    if (_kal < 0) then { _kal = _vk; };
    _top = _top + (_res * _kal);
};
private _gecer = _gec && {_top <= _eg};
if ((missionNamespace getVariable ["lambs_danger_penetreGucLogN", 0]) < 20) then {
    missionNamespace setVariable ["lambs_danger_penetreGucLogN", (missionNamespace getVariable ["lambs_danger_penetreGucLogN", 0]) + 1];
    diag_log format ["[PENETRE-GUC] mesafe %1 m | %2 kesisim | toplam direnc %3 | etkili guc %4 (mermi %5) | bilinmeyen malzeme %6 | %7", round _mes, _n, _top toFixed 1, _eg toFixed 1, _guc toFixed 1, _bil, ["GECMEZ", "GECER"] select _gecer];
};
[_gecer, _n, _bil, _top, _eg]
