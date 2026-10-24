#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * YURUNEBILIR ALAN TARAMASI (v8.335) — kullanici: 'kullanimi kolay olsun, nerede ne koyabilecegimizi bilelim'. Bir alanin (fnc_yuruyusAlani LISTE ogesi) ICINDE en cok ~150 ornek noktasi (izgara) olcer ve alanin YURUME ICIN uygun olup olmadigini soyler.
 * Her ornek icin: arazi yuksekligi + ayaktan +12 / -3 m GEOM isini (fnc_yuruyusIzle ile ayni olcum; bina / arac / asker nesne sayilmaz) -> nesne ustu yuksekligi.
 *   NESNE : yukseklik > 0.3 m    UZUN : > 3.0 m (tirmanilamaz)    SU : surfaceIsWater    BINA : House (AI binaya kendi yoluyla girer, alan bina icini kapsamaz)
 * Sonuc durumu: 0 TAMAM (yesil) | 1 UYARI (turuncu: bazi noktalar 3 m ustu / bina var) | 2 HATA (kirmizi: > %25 tirmanilamaz, > %30 su, ornek < 4) | 3 BOS (sari: neredeyse hic nesne yok - AI zaten yurur, alani nesneli hendegin USTUNE koy).
 * Kullanim: fnc_yuruyusGorsel (Zeus isaret rengi + sohbet raporu), fnc_moduleYuruyusAlani (Eden / sunucu logu).
 *
 * Arguments:
 * 0: Alan <ARRAY> (fnc_yuruyusAlani LISTE ogesi: [merkez, a, b, yon, dikdortgenMi, modul])
 *
 * Return Value: [durum <NUMBER>, metin <STRING>, [ornek, su, nesne, uzun, bina, enYuksek]] <ARRAY>
 * Public: No
*/

params [["_z", [], [[]]]];
if (_z isEqualTo []) exitWith {[2, "alan yok", []]};
_z params ["_c", "_a", "_b", "_dir", "_rect"];
private _ex = [cos _dir, -(sin _dir)];
private _ey = [sin _dir, cos _dir];
private _adim = (sqrt ((4 * _a * _b) / 150)) max 1.5;
private _n = 0;
private _su = 0;
private _nesne = 0;
private _uzun = 0;
private _bina = 0;
private _maxRel = 0;
private _lx = -_a;
while {_lx <= _a} do {
    private _ly = -_b;
    while {_ly <= _b} do {
        if (_rect || {(((_lx / _a) ^ 2) + ((_ly / _b) ^ 2)) <= 1}) then {
            private _wx = (_c select 0) + ((_ex select 0) * _lx) + ((_ey select 0) * _ly);
            private _wy = (_c select 1) + ((_ex select 1) * _lx) + ((_ey select 1) * _ly);
            private _h = getTerrainHeightASL [_wx, _wy];
            _n = _n + 1;
            if (surfaceIsWater [_wx, _wy]) then {
                _su = _su + 1;
            } else {
                private _top = _h;
                {
                    private _o = _x select 2;
                    if (!isNull _o && {!(_o isKindOf "AllVehicles")}) exitWith {
                        if (_o isKindOf "House") then { _bina = _bina + 1; } else { _top = _top max (((_x select 0) select 2)); };
                    };
                } forEach (lineIntersectsSurfaces [[_wx, _wy, _h + 12], [_wx, _wy, _h - 3], objNull, objNull, true, 4, "GEOM", "NONE"]);
                private _rel = _top - _h;
                if (_rel > 0.3) then { _nesne = _nesne + 1; };
                if (_rel > 3) then { _uzun = _uzun + 1; };
                if (_rel > _maxRel) then { _maxRel = _rel; };
            };
        };
        _ly = _ly + _adim;
    };
    _lx = _lx + _adim;
};

private _durum = 0;
private _not = [];
if (_n < 4) then { _durum = 2; _not pushBack "alan cok kucuk (ornek < 4)"; };
if (_n > 0 && {(_su / _n) > 0.3}) then { _durum = 2; _not pushBack format ["alanin %1%2'i suda", round ((_su / _n) * 100), "%"]; };
if (_n > 0 && {(_uzun / _n) > 0.25}) then {
    _durum = 2; _not pushBack format ["noktalarin %1%2'i 3 m'den yuksek (tirmanilamaz)", round ((_uzun / _n) * 100), "%"];
} else {
    if (_n > 0 && {(_uzun / _n) > 0.05}) then { _durum = _durum max 1; _not pushBack format ["bazi noktalar 3 m'den yuksek (%1%2): yan gecis denenir", round ((_uzun / _n) * 100), "%"]; };
};
if (_bina > 0) then { _durum = _durum max 1; _not pushBack "alanda bina var (alan bina icini kapsamaz)"; };
if (_durum isEqualTo 0 && {_n > 0} && {(_nesne / _n) < 0.05}) then { _durum = 3; _not pushBack "alanda neredeyse hic nesne yok: AI zaten yurur; alani nesneli hendegin USTUNE koy"; };
private _baslik = ["TAMAM", "UYARI", "HATA", "BOS"] select _durum;
private _ozet = format ["%1 x %2 m, %3 nesne ornegi, en yuksek %4 m", round (_a * 2), round (_b * 2), _nesne, _maxRel toFixed 1];
[_durum, format ["%1 - %2%3", _baslik, _ozet, if (_not isEqualTo []) then {" | " + (_not joinString "; ")} else {""}], [_n, _su, _nesne, _uzun, _bina, _maxRel]]
