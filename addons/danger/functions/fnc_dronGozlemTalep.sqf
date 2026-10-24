#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * DRON GOZLEMCISI TALEBI (v8.336) — kullanici: 'dron saldirisi israrla tekrar edilirse gelis yonune dogru gozlem dronu gonderebilsinler, eger dron gozlemci varsa'. fnc_dronTepki'den (her dron izi, grup basina 15 sn) cagrilir: tarafin dron gozlemlerini
 * (600 sn, dron kimligiyle) tutar; SALDIRI ISRARLA TEKRARLANIYORSA (600 sn'de >= 2 FARKLI dron VEYA 300 sn'de >= 4 gozlem) ucus izlerinden operator bolgesini tahmin eder (farkli dronlarin geri-yon dogrularinin kesisimi, yoksa tek dogruda 650 m)
 * ve sunucuya 'lambs_danger_dronGozlemIstegi' olayi gonderir (fnc_dronGozlemci gozlem dronunu ucurur). Taraf basina 240 sn'de bir; kapatma: CBA 'Dron gozlemcisi' (lambs_danger_dronGozlemAktif) / lambs_danger_dronGozlemOff = true.
 *
 * Arguments:
 * 0: Grup <GROUP>
 * 1: Dronun ilk goruldugu nokta <ARRAY>
 * 2: Geri yon (operator yonu, derece) <NUMBER>
 * 3: Dron <OBJECT>
 *
 * Return Value: Talep gonderildi mi <BOOL>
 * Public: No
*/

params [["_g", grpNull, [grpNull]], ["_p0", [], [[]]], ["_geri", 0, [0]], ["_dr", objNull, [objNull]]];
if (isNull _g || {_p0 isEqualTo []} || {!(missionNamespace getVariable ["lambs_danger_dronGozlemAktif", true])} || {missionNamespace getVariable ["lambs_danger_dronGozlemOff", false]}) exitWith {false};
private _taraf = side _g;
private _obs = (missionNamespace getVariable ["lambs_danger_dronGozObs", []]) select {(time - (_x select 0)) < 600 && {(_x select 1) isEqualTo _taraf}};
_obs pushBack [time, _taraf, netId _dr, _p0, _geri];
if ((count _obs) > 20) then { _obs = _obs select [(count _obs) - 20, 20]; };
missionNamespace setVariable ["lambs_danger_dronGozObs", _obs];

// v8.344 FARKLI YONLER: yalniz ayni yondeki (geri-yon +-40 derece) gozlemler birlikte degerlendirilir (farkli operatorlerin dogrulari kesistirilmez)
_obs = _obs select {(abs ((((_x select 4) - _geri) + 540) mod 360 - 180)) <= 40};
// v8.345 SALVO: ayni anda (<= 40 sn arayla ilk gorulen) cikan dronlar TEK sayilir
private _ilkZ = createHashMap;
{ private _nid = _x select 2; _ilkZ set [_nid, (_ilkZ getOrDefault [_nid, 1e9]) min (_x select 0)]; } forEach _obs;
private _zam = values _ilkZ;
_zam sort true;
private _dronlar = [];
private _sonZ = -1e9;
{ if ((_x - _sonZ) > 40) then { _dronlar pushBack _x; _sonZ = _x; }; } forEach _zam;
private _son300 = {(time - (_x select 0)) < 300} count _obs;
if ((count _dronlar) < 2 && {_son300 < 4}) exitWith {false};
private _ozK = format ["lambs_danger_dronGozTalepT_%1_%2", _taraf, floor (_geri / 60)];
if ((time - (missionNamespace getVariable [_ozK, -999])) < 240) exitWith {false};

// ---- operator bolgesi tahmini: farkli dronlarin geri-yon dogrularinin kesisimi (>= 15 derece, 100-2500 m) ----
private _kx = [];
private _ky = [];
for "_i" from 0 to ((count _obs) - 2) do {
    for "_j" from (_i + 1) to ((count _obs) - 1) do {
        private _o1 = _obs select _i;
        private _o2 = _obs select _j;
        if ((_o1 select 2) isNotEqualTo (_o2 select 2) || {abs ((_o2 select 0) - (_o1 select 0)) >= 20}) then {
            private _d1 = [sin (_o1 select 4), cos (_o1 select 4)];
            private _d2 = [sin (_o2 select 4), cos (_o2 select 4)];
            private _det = ((_d1 select 0) * (_d2 select 1)) - ((_d1 select 1) * (_d2 select 0));
            if ((abs _det) > 0.26) then {
                private _a1 = _o1 select 3;
                private _a2 = _o2 select 3;
                private _ab = [(_a2 select 0) - (_a1 select 0), (_a2 select 1) - (_a1 select 1)];
                private _t = (((_ab select 0) * (_d2 select 1)) - ((_ab select 1) * (_d2 select 0))) / _det;
                private _s = (((_ab select 0) * (_d1 select 1)) - ((_ab select 1) * (_d1 select 0))) / _det;
                if (_t > 100 && {_t < 2500} && {_s > 100} && {_s < 2500}) then {
                    _kx pushBack ((_a1 select 0) + _t * (_d1 select 0));
                    _ky pushBack ((_a1 select 1) + _t * (_d1 select 1));
                };
            };
        };
    };
};
private _est = [];
private _kesisim = false;
if (_kx isNotEqualTo []) then {
    private _sx = +_kx;
    private _sy = +_ky;
    _sx sort true;
    _sy sort true;
    _est = [_sx select (floor ((count _sx) / 2)), _sy select (floor ((count _sy) / 2)), 0];
    _kesisim = true;
} else {
    _est = _p0 getPos [650, _geri];
};
missionNamespace setVariable [_ozK, time];
["lambs_danger_dronGozlemIstegi", [_taraf, _est, _geri, _kesisim, count _dronlar, _son300]] call CBA_fnc_serverEvent;
diag_log format ["[DRON-GOZLEM] %1 | saldiri israrla tekrarlaniyor (%2 farkli dron, son 300 sn %3 gozlem) -> gozlem dronu talebi: tahmin %4 (%5), geri yon %6 derece", _taraf, count _dronlar, _son300, mapGridPosition _est, ["tek dogru 650 m", "kesisim"] select _kesisim, round _geri];
true
