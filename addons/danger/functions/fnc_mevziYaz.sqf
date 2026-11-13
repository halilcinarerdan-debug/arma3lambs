#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * MEVZI HAFIZASI YAZICI (v8.529) — taraf basina, oturum boyunca (dosya / SQL YOK) 40 m'lik hucre hafizasina kayit yazar. Her makinede ayni olaydan (lambs_danger_mevziKayit) cagrilir.
 *
 * Tur:  "iyi"   siperde tehdit altinda hasarsiz dayandi        "kotu"  siperde vuruldu / oldu       "maruz"  siper disinda vuruldu (acik bolge)
 *       "ufuk"  ufuk cizgisinde (siluet) vuruldu               "ates"  bu tarafin DUYDUGU dusman atis noktasi (kumelenirse = tahmini dusman mevzisi)
 * Depo (hucre -> [iyi, kotu, maruz, ufuk, zaman]); anahtar "cx|cy" (genel) ve "cx|cy|sektor" (tehdit yonu: 8 sektor, 45 derece). Degerler yaz / oku aninda yari omurle (lambs_danger_mevziYariOmur) sonumlenir.
 * Taraf basina en fazla 400 hucre (en eski 100 silinir); "ates" icin 80 hucre.
 *
 * Arguments:
 * 0: Taraf <SIDE>
 * 1: Tur <STRING>
 * 2: Konum <ARRAY>
 * 3: Sektor (0-7 ya da -1 bilinmiyor) <NUMBER>
 * 4: Agirlik <NUMBER>
 *
 * Return Value: Yazildi mi <BOOL>
 * Public: No
*/

params ["_side", "_tur", "_pos", ["_sek", -1], ["_w", 1]];
private _T = (missionNamespace getVariable ["lambs_danger_mevziYariOmur", 1800]) max 60;
private _cx = floor ((_pos select 0) / 40);
private _cy = floor ((_pos select 1) / 40);
private _sk = str _side;

if (_tur isEqualTo "ates") exitWith {
    private _a = missionNamespace getVariable ["lambs_danger_mevziAtes", createHashMap];
    missionNamespace setVariable ["lambs_danger_mevziAtes", _a];
    private _m = _a getOrDefault [_sk, createHashMap];
    _a set [_sk, _m];
    private _anahtar = format ["%1|%2", _cx, _cy];
    private _r = _m getOrDefault [_anahtar, [0, 0, 0, 0, time]];   // [n, sx, sy, sz, zaman]
    private _d = 0.5 ^ ((time - (_r select 4)) / _T);
    _r = [(_r select 0) * _d + _w, ((_r select 1) * _d) + ((_pos select 0) * _w), ((_r select 2) * _d) + ((_pos select 1) * _w), ((_r select 3) * _d) + ((_pos param [2, 0]) * _w), time];
    _m set [_anahtar, _r];
    if (count _m > 80) then {
        private _l = (keys _m) apply { [(_m get _x) select 4, _x] };
        _l sort true;
        { _m deleteAt (_x select 1); } forEach (_l select [0, 20]);
    };
    true
};

private _ix = ["iyi", "kotu", "maruz", "ufuk"] find _tur;
if (_ix < 0) exitWith {false};
private _h = missionNamespace getVariable ["lambs_danger_mevziH", createHashMap];
missionNamespace setVariable ["lambs_danger_mevziH", _h];
private _m = _h getOrDefault [_sk, createHashMap];
_h set [_sk, _m];
private _anahtarlar = [format ["%1|%2", _cx, _cy]];
if (_sek >= 0) then { _anahtarlar pushBack (format ["%1|%2|%3", _cx, _cy, _sek]); };
{
    private _r = _m getOrDefault [_x, [0, 0, 0, 0, time]];
    private _d = 0.5 ^ ((time - (_r select 4)) / _T);
    _r = [(_r select 0) * _d, (_r select 1) * _d, (_r select 2) * _d, (_r select 3) * _d, time];
    _r set [_ix, (_r select _ix) + _w];
    _m set [_x, _r];
} forEach _anahtarlar;
if (count _m > 400) then {
    private _l = (keys _m) apply { [(_m get _x) select 4, _x] };
    _l sort true;
    { _m deleteAt (_x select 1); } forEach (_l select [0, 100]);
};
true
