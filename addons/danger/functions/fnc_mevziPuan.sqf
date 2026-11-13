#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * MEVZI PUANI (v8.529) — bir konumun (siper adayi) bu tarafin OTURUM HAFIZASINA gore puani; yuksek = iyi. Cagiranlar: main fnc_findCover (siper puani), fnc_acikSiper (aday maliyeti), fnc_ufukAlgi (yer degistirme).
 *
 * Girdi hafizasi (fnc_mevziHafiza yazar): hucre (40 m) basina iyi / kotu / maruz / ufuk sayaclari (yari omurle sonumlu) + tehdit yonu sektoru + DUYULAN dusman atis noktalari.
 * Puan: 2.2 x iyi(sektor) + 0.8 x iyi - 3.0 x kotu(sektor) - 1.6 x kotu - 0.6 x maruz - 0.7 x komsu hucre kotu (en cok 2);  kotu >= 2.5 ise 'olum bolgesi' -5;  ufuk istenirse -3 x ufuk;
 *   TAHMIN DUSMAN MEVZISI (>= 2.5 sonumlu atis, 450 m icinde, en yakin 3): aday o noktadan arazi ile gizliyse +1.5, aciksa -2 x min(1, n / 5).   Sinir [-14, 8], x lambs_danger_mevziAgirlik.
 *
 * Arguments:
 * 0: Taraf <SIDE>
 * 1: Aday konum <ARRAY>
 * 2: Tehdit konumu <ARRAY> (opsiyonel; yoksa yon ayrimi yok)
 * 3: Ufuk hafizasi da dahil mi <BOOL> (varsayilan false)
 *
 * Return Value: Puan <NUMBER>
 *
 * Public: No
*/

params ["_side", "_pos", ["_tehdit", []], ["_ufuk", false]];
if !(missionNamespace getVariable ["lambs_danger_mevziHafiza", true]) exitWith {0};
private _h = missionNamespace getVariable ["lambs_danger_mevziH", createHashMap];
private _a = missionNamespace getVariable ["lambs_danger_mevziAtes", createHashMap];
private _sk = str _side;
private _m = _h getOrDefault [_sk, createHashMap];
private _am = _a getOrDefault [_sk, createHashMap];
if ((count _m) isEqualTo 0 && {(count _am) isEqualTo 0}) exitWith {0};

private _T = (missionNamespace getVariable ["lambs_danger_mevziYariOmur", 1800]) max 60;
private _cx = floor ((_pos select 0) / 40);
private _cy = floor ((_pos select 1) / 40);
private _sek = -1;
if (_tehdit isNotEqualTo []) then { _sek = floor (((((_pos getDir _tehdit) + 22.5) mod 360)) / 45); };
private _oku = {
    params ["_anahtar"];
    private _r = _m get _anahtar;
    if (isNil "_r") exitWith {[0, 0, 0, 0]};
    private _d = 0.5 ^ ((time - (_r select 4)) / _T);
    [(_r select 0) * _d, (_r select 1) * _d, (_r select 2) * _d, (_r select 3) * _d]
};

private _puan = 0;
private _genel = [format ["%1|%2", _cx, _cy]] call _oku;
_genel params ["_iyiA", "_kotuA", "_maA", "_ufA"];
private _iyiS = 0;
private _kotuS = 0;
if (_sek >= 0) then {
    private _s = [format ["%1|%2|%3", _cx, _cy, _sek]] call _oku;
    _iyiS = _s select 0;
    _kotuS = _s select 1;
};
private _komsu = 0;
for "_dx" from -1 to 1 do {
    for "_dy" from -1 to 1 do {
        if (_dx isNotEqualTo 0 || {_dy isNotEqualTo 0}) then {
            _komsu = _komsu + ((([format ["%1|%2", _cx + _dx, _cy + _dy]] call _oku) select 1) * 0.25);
        };
    };
};
_puan = (2.2 * (_iyiS min 3)) + (0.8 * (_iyiA min 4)) - (3 * (_kotuS min 3)) - (1.6 * (_kotuA min 4)) - (0.6 * (_maA min 4)) - (0.7 * (_komsu min 2));
if (_kotuA >= 2.5) then { _puan = _puan - 5; };
if (_ufuk) then { _puan = _puan - (3 * (_ufA min 3)); };

// tahmini dusman mevzisi (duyulan atis kumeleri): arazi ile gizli mi?
if ((count _am) > 0) then {
    private _kumeler = [];
    {
        private _r = _y;
        private _d = 0.5 ^ ((time - (_r select 4)) / _T);
        private _n = (_r select 0) * _d;
        if (_n >= 2.5) then {
            private _c = [(_r select 1) / (_r select 0), (_r select 2) / (_r select 0), (_r select 3) / (_r select 0)];
            private _dm = _pos distance2D _c;
            if (_dm <= 450 && {_dm >= 15}) then { _kumeler pushBack [_dm, _c, _n]; };
        };
    } forEach _am;
    if (_kumeler isNotEqualTo []) then {
        _kumeler sort true;
        private _pASL = AGLToASL [_pos select 0, _pos select 1, 0.8];
        {
            _x params ["_dm", "_c", "_n"];
            private _cASL = AGLToASL [_c select 0, _c select 1, 1.7];
            if (terrainIntersectASL [_cASL, _pASL]) then {
                _puan = _puan + 1.5;
            } else {
                _puan = _puan - (2 * ((_n / 5) min 1));
            };
        } forEach (_kumeler select [0, 3]);
    };
};
(((_puan max -14) min 8) * ((missionNamespace getVariable ["lambs_danger_mevziAgirlik", 1]) max 0 min 3))
