#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * HAKIM GOZLEM NOKTASI (v8.342; kullanici: 'lider hakim noktaya cikarken ev ustlerine falan merdivenlerden cikabiliyorsa ya da etrafi / savunma yonunu goren bir bolgeye ciksin').
 * Liderin (gozlemci) cevresinde hedefi / tehdit yonunu GOREN en iyi gozlem noktasini arar:
 *   1) BINA: <= maxYuru icindeki binalarin (en yakin 20) buildingPos listesinden en yuksek 3 ic pozisyon; yukseklik >= 3 m (ust kat / cati; AI merdivenle cikar); hedefe arazi + nesne gorusu acik
 *      (kendi binasi sayilmaz = pencere / cati); hedefe 350-1800 m. Skor = yukseklik x 3 + acik gorus yonu (8 yon x 400 m, kac tanesi acik) x 3 + 8 (bina bonusu) - yuruyus x 0.03.
 *   2) ARAZI: liderden hedef yonune +-60 derece (20'ser), 60-420 m halkalarda nokta; su / bina yakini haric; hedefe gorus acik; hedefe 350-1800 m.
 *      Skor = yukseklik farki (m) + acik gorus yonu x 3 - yuruyus x 0.04.
 * 'Etrafi goren' olcutu: 8 yonde 400 m yatay isin; kapali yon azsa nokta genis gorus sunar. Sayilar [T] (kitapta gozlem noktasi sayisi yok; ilke: gozlem noktasi genis gorus + ortu: TC 3-21.76 LP/OP).
 * Maliyet yuksek (yuzlerce isin): yalniz planlanmis (zamanlanmis) betikten cagrilir.
 *
 * Arguments:
 * 0: Liderin konumu <ARRAY AGL>
 * 1: Hedef / tehdit konumu <ARRAY AGL>
 * 2: En cok yuruyus mesafesi (m, varsayilan 450) <NUMBER>
 *
 * Return Value: [konum AGL, tip "BINA"/"ARAZI", skor, yukseklik] ya da [] <ARRAY>
 * Public: No
*/

params [["_g0", [], [[]]], ["_t0", [], [[]]], ["_maxY", 450, [0]]];
if (_g0 isEqualTo [] || {_t0 isEqualTo []}) exitWith {[]};

private _hG = getTerrainHeightASL _g0;
private _hedefG = AGLToASL (_t0 vectorAdd [0, 0, 1.0]);
private _yon = _g0 getDir _t0;
private _en = [];
private _enS = -1e9;
private _enTip = "";
private _enZ = 0;

private _acikFn = {
    params ["_eye", "_ign"];
    private _a = 0;
    for "_k" from 0 to 7 do {
        private _u = _eye vectorAdd [(sin (_k * 45)) * 400, (cos (_k * 45)) * 400, 0];
        if !(terrainIntersectASL [_eye, _u] || {lineIntersects [_eye, _u, _ign, objNull]}) then { _a = _a + 1; };
    };
    _a
};

// ---- 1) binalar ----
private _binalar = (nearestObjects [_g0, ["House", "Building"], _maxY]) select {((_x distance2D _t0) >= 350) && {(_x distance2D _t0) <= 1800}};
_binalar = _binalar select [0, 20];
{
    private _b = _x;
    private _pozlar = (_b buildingPos -1) select {(_x select 2) >= 3};
    _pozlar = [_pozlar, [], {_x select 2}, "DESCEND"] call BIS_fnc_sortBy;
    {
        private _p = _x;
        private _eye = (AGLToASL _p) vectorAdd [0, 0, 1.5];
        if (!(lineIntersects [_eye, _hedefG, _b, objNull]) && {!(terrainIntersectASL [_eye, _hedefG])}) then {
            private _s = ((_p select 2) * 3) + (([_eye, _b] call _acikFn) * 3) + 8 - ((_g0 distance2D _p) * 0.03);
            if (_s > _enS) then { _enS = _s; _en = _p; _enTip = "BINA"; _enZ = _p select 2; };
        };
    } forEach (_pozlar select [0, 3]);
} forEach _binalar;

// ---- 2) arazi ----
{
    private _a = _x;
    {
        private _p = _g0 getPos [_x, _yon + _a];
        if (!surfaceIsWater _p && {((_p distance2D _t0) >= 350) && {(_p distance2D _t0) <= 1800}} && {(nearestTerrainObjects [_p, ["BUILDING", "HOUSE", "ROCK", "WALL"], 5, false, true]) isEqualTo []}) then {
            private _eye = (AGLToASL (_p vectorAdd [0, 0, 1.6]));
            if (!(terrainIntersectASL [_eye, _hedefG]) && {!(lineIntersects [_eye, _hedefG, objNull, objNull])}) then {
                private _fark = (getTerrainHeightASL _p) - _hG;
                private _s = _fark + (([_eye, objNull] call _acikFn) * 3) - ((_g0 distance2D _p) * 0.04);
                if (_s > _enS) then { _enS = _s; _en = _p; _enTip = "ARAZI"; _enZ = _fark; };
            };
        };
    } forEach [60, 120, 200, 300, 420];
} forEach [-60, -40, -20, 0, 20, 40, 60];

if (_en isEqualTo []) exitWith {[]};
[_en, _enTip, _enS, _enZ]
