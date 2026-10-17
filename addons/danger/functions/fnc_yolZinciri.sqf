#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * YOL ZINCIRI (v8.245) — uzak hedef icin ara nokta zinciri. Neden (RPT 332d59ba: 3 BTR-80 nakil araci 5.3 km'lik TEK doMove ile 190 m gidip 8 sn hareketsiz kaldi, 'doMove sonuc vermedi',
 * sonunda kinematik surus gerekti; RPT c7592408'de 1.4 km'lik nakilde ayni sinif sorunsuz gitti; A/B testi (300 m) tum siniflarda HEPSI GITTI): AI surucu cok uzak tek hedefe yol planlarken
 * takiliyor olabilir (HIPOTEZ, kanit: mesafe korelasyonu). reconArac v8.241 zinciri ayni mantik; burada nakil icin genel yardimci.
 * Rota calculatePath ('safe') dugumlerinden ~aralik (varsayilan 300 m) aralikli ara noktalar, her biri 40 m icindeki YOLA oturtulur; arac yoldan > 25 m uzaktaysa ilk bacak en yakin yol dugumune
 * (<= 250 m, hedefi 250 m'den fazla uzaklastirmayan). Zincir kurulamazsa [hedef] doner (eski davranis). Programlanmis (scheduled) ortamda cagrilmali (en cok 4 sn bekler).
 *
 * Arguments:
 * 0: Arac <OBJECT>
 * 1: Hedef konum <ARRAY>
 * 2: Ara nokta araligi (m, varsayilan 300) <NUMBER>
 *
 * Return Value: ara noktalar (son eleman hedef) <ARRAY>
 * Public: No
*/

params [["_v", objNull, [objNull]], ["_dur", [0, 0, 0], [[]]], ["_aralik", 300, [0]]];
if (isNull _v || {_dur isEqualTo [0, 0, 0]}) exitWith {[_dur]};
private _zincir = [_dur];
private _kaynak = getPosATL _v;
_v setVariable [QGVAR(zincirYol), []];
private _ajan = calculatePath [["wheeled_APC", "tank"] select (((toLower (getText (configOf _v >> "simulation"))) find "tank") >= 0), "safe", _kaynak, _dur];
_ajan setVariable ["arac", _v];
_ajan addEventHandler ["PathCalculated", {
    params ["_a", "_yolH"];
    private _av = _a getVariable ["arac", objNull];
    if (!isNull _av && {count _yolH > 1}) then { _av setVariable ["lambs_danger_zincirYol", _yolH]; };
    deleteVehicle _a;
}];
private _bekle = time + 4;
waitUntil { sleep 0.3; (count (_v getVariable [QGVAR(zincirYol), []])) > 1 || {time > _bekle} };
private _dugum = _v getVariable [QGVAR(zincirYol), []];
private _yolaOturt = {
    params ["_pp"];
    private _yy = (_pp nearRoads 40) select {!surfaceIsWater (getPosATL _x)};
    if (_yy isEqualTo []) then {_pp} else { getPosATL (([_yy, [], {_x distance2D _pp}, "ASCEND"] call BIS_fnc_sortBy) select 0) }
};
if ((count _dugum) > 1) then {
    _zincir = [];
    private _son = _kaynak;
    { if ((_x distance2D _son) >= _aralik) then { private _nk = [_x] call _yolaOturt; if ((_nk distance2D _son) >= (_aralik * 0.5)) then { _zincir pushBack _nk; _son = _nk; }; }; } forEach _dugum;
    if (_zincir isNotEqualTo [] && {((_zincir select ((count _zincir) - 1)) distance2D _dur) < 150}) then { _zincir deleteAt ((count _zincir) - 1); };
    _zincir pushBack _dur;
    if ((count _zincir) > 60) then { _zincir = (_zincir select [0, 59]) + [_dur]; };
};
if ((_kaynak nearRoads 25) isEqualTo []) then {
    private _adayY = (_kaynak nearRoads 250) select {!surfaceIsWater (getPosATL _x)};
    if (_adayY isNotEqualTo []) then {
        _adayY = [_adayY, [], {(_x distance2D _kaynak) + 0.5 * (_x distance2D _dur)}, "ASCEND"] call BIS_fnc_sortBy;
        private _y0 = getPosATL (_adayY select 0);
        if ((_y0 distance2D _dur) <= ((_kaynak distance2D _dur) + 250)) then { _zincir = [_y0] + _zincir; };
    };
};
_zincir
