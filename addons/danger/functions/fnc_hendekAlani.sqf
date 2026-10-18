#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * HENDEK ALANI (v8.229; kullanici: Eden "Trench Generator" hendekleri + kendi AI fighting position'lari KULLANILMAZ, "sadece alan olsun, elle koyabilelim") —
 * Hendek ALANI = haritada (Eden / Zeus) elle konan DIKDORTGEN (ya da elips) isaret; ad "elite_hendek" ile baslar (buyuk / kucuk harf onemsiz). Isaretin boyutu hendegin YARI boyutlari, yonu hendegin yonudur.
 *   Taraf kisiti: adda "_west" / "_east" / "_guer" gecerse yalniz o tarafin birlikleri kullanir; yoksa herkes. Isaret gorunmez (alpha 0) olabilir.
 *   Hendek modunun kendi nesne / AI mevzilerinden BAGIMSIZDIR (hicbir mod sinifina bakilmaz).
 * Modlar (ilk parametre):
 *   "LISTE"                      -> [[merkez, a, b, yon, isaretAdi, taraf], ...]  (20 sn onbellek)
 *   "EN-YAKIN", konum, enCokM, taraf -> [nokta, indeks, mesafe] ya da []   (nokta = dikdortgenin konuma EN YAKIN ic noktasi; kenardan 0.8 m iceride)
 *   "NOKTALAR", indeks, n        -> n nokta, hendegin UZUN ekseni boyunca esit aralikli (kenardan 1 m iceride)
 *   "ICERDE", indeks, _, _, konum -> konumun o hendek alani dikdortgenine mesafesi (0 = icinde; v8.255 tani)
 *   "KAPASITE", indeks           -> hendege sigan asker sayisi (v8.252: uzun eksen / 2.5 m aralik + 1, en az 1, en cok 12; RPT f39a5919: 8-9 kisilik grup kisa hendege sigmadi, bir kismi yaninda bekledi)
 * Log: yok (cagiranlar yazar).
 *
 * Return Value: moda gore
 * Public: No
*/

params [["_mod", "LISTE", [""]], ["_p", [0, 0, 0], [[], 0]], ["_maxD", 60, [0]], ["_taraf", sideUnknown, [sideUnknown]], ["_ekPoz", [0, 0, 0], [[]]]];

if (time > ((missionNamespace getVariable ["lambs_danger_hendekT", -99]) + 20)) then {
    lambs_danger_hendekT = time;
    lambs_danger_hendekL = (allMapMarkers select {((toLower _x) find "elite_hendek") isEqualTo 0}) apply {
        private _s = markerSize _x;
        private _ad = toLower _x;
        private _t = if ((_ad find "_west") >= 0) then {west} else { if ((_ad find "_east") >= 0) then {east} else { if ((_ad find "_guer") >= 0) then {independent} else {sideUnknown} } };
        [markerPos _x, (_s select 0) max 1, (_s select 1) max 1, markerDir _x, _x, _t]
    };
};
private _l = missionNamespace getVariable ["lambs_danger_hendekL", []];

if (_mod isEqualTo "LISTE") exitWith {_l};

if (_mod isEqualTo "EN-YAKIN") exitWith {
    if (_l isEqualTo []) exitWith {[]};
    private _en = [];
    private _enD = 1e9;
    {
        _x params ["_c", "_a", "_b", "_dir", "_ad", "_tr"];
        if (_tr isEqualTo sideUnknown || {_taraf isEqualTo sideUnknown} || {_tr isEqualTo _taraf}) then {
            private _ex = [sin (90 + _dir), cos (90 + _dir)];
            private _ey = [sin _dir, cos _dir];
            private _d = [(_p select 0) - (_c select 0), (_p select 1) - (_c select 1)];
            private _lx = (_d select 0) * (_ex select 0) + (_d select 1) * (_ex select 1);
            private _ly = (_d select 0) * (_ey select 0) + (_d select 1) * (_ey select 1);
            private _ma = (_a - 0.8) max 0;
            private _mb = (_b - 0.8) max 0;
            private _cx = (_lx max -_ma) min _ma;
            private _cy = (_ly max -_mb) min _mb;
            private _nk = [(_c select 0) + (_ex select 0) * _cx + (_ey select 0) * _cy, (_c select 1) + (_ex select 1) * _cx + (_ey select 1) * _cy, 0];
            private _dm = _nk distance2D _p;
            if (_dm < _enD) then { _enD = _dm; _en = [_nk, _forEachIndex, _dm]; };
        };
    } forEach _l;
    if (_en isNotEqualTo [] && {_enD <= _maxD}) then {_en} else {[]}
};

if (_mod isEqualTo "ICERDE") exitWith {
    private _iIdx = _p;
    if (!(_iIdx isEqualType 0) || {_iIdx < 0} || {_iIdx >= count _l}) exitWith {-1};
    (_l select _iIdx) params ["_ic", "_ia", "_ib", "_idir"];
    private _id = [(_ekPoz select 0) - (_ic select 0), (_ekPoz select 1) - (_ic select 1)];
    private _ilx = (_id select 0) * (sin (90 + _idir)) + (_id select 1) * (cos (90 + _idir));
    private _ily = (_id select 0) * (sin _idir) + (_id select 1) * (cos _idir);
    private _idx2 = ((abs _ilx) - _ia) max 0;
    private _idy2 = ((abs _ily) - _ib) max 0;
    sqrt ((_idx2 * _idx2) + (_idy2 * _idy2))
};

if (_mod isEqualTo "KAPASITE") exitWith {
    private _kIdx = _p;
    if (!(_kIdx isEqualType 0) || {_kIdx < 0} || {_kIdx >= count _l}) exitWith {0};
    (_l select _kIdx) params ["_kc", "_ka", "_kb"];
    private _kL = ((_ka max _kb) - 1) max 0;
    ((floor ((2 * _kL) / 2.5)) + 1) max 1 min 12
};

if (_mod isEqualTo "NOKTALAR") exitWith {
    private _idx = _p;
    private _n = (_maxD max 1) min 12;
    if (!(_idx isEqualType 0) || {_idx < 0} || {_idx >= count _l}) exitWith {[]};
    (_l select _idx) params ["_c", "_a", "_b", "_dir"];
    private _uzunX = _a >= _b;
    private _eks = if (_uzunX) then {[sin (90 + _dir), cos (90 + _dir)]} else {[sin _dir, cos _dir]};
    private _L = ((if (_uzunX) then {_a} else {_b}) - 1) max 0;
    private _r = [];
    for "_i" from 0 to (_n - 1) do {
        private _t = if (_n isEqualTo 1) then {0} else {-_L + (2 * _L) * (_i / (_n - 1))};
        _r pushBack [(_c select 0) + (_eks select 0) * _t, (_c select 1) + (_eks select 1) * _t, 0];
    };
    _r
};
[]
