#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * ARAZI ANALIZI (KOMUTAN arazi bilinci) — [merkez, yaricap, tehditPos] -> HashMap profil
 *
 *   egim      : ortalama / en yuksek egim (m / 16 m ornek) — dik arazide yaklasma yavas, sirt belirgin
 *   aciklik   : "ACIK" / "KARISIK" / "KAPALI" (agac + cali + bina yogunlugu)
 *   olu       : dusman gozunden yatik (0.4 m) askerin GIZLI kaldigi ornek orani 0..1 (olu arazi / ortulu alan)
 *   hakim     : HAKIM NOKTA [pos, yukseklikFarki] — merkezden >= 2.5 m yuksek, tehdidi yatikken GOREBILEN, ufuk cizgisinde OLMAYAN,
 *               su / bina disi en iyi nokta (yoksa [])
 *   ufukRisk  : merkezin kendisi ufuk cizgisinde mi (bool)
 *
 * Kullanim: tacticsBounding (MG / nisanci gozetleme pozisyonu: hakim nokta); rota / hold ileride ayni profili kullanir.
 * 20 sn onbellek (anahtar: merkez 25 m karesi + tehdit 40 m karesi). Log: [ARAZI] (ilk 30).
 *
 * Arguments:
 * 0: Merkez <ARRAY AGL>
 * 1: Yaricap m (varsayilan 60) <NUMBER>
 * 2: Tehdit pozisyonu <ARRAY AGL>
 *
 * Return Value:
 * Profil <HASHMAP>
 *
 * Public: No
*/

params [["_c", [0, 0, 0], [[]]], ["_r", 60, [0]], ["_t", [0, 0, 0], [[]]]];

private _anahtar = format ["%1_%2_%3_%4", round ((_c select 0) / 25), round ((_c select 1) / 25), round ((_t select 0) / 40), round ((_t select 1) / 40)];
private _onb = missionNamespace getVariable ["lambs_danger_araziOnb", createHashMap];
private _kayit = _onb getOrDefault [_anahtar, []];
if (_kayit isNotEqualTo [] && {(time - (_kayit select 0)) < 20}) exitWith { _kayit select 1 };

private _t0 = diag_tickTime;
private _prof = createHashMap;
private _tehditVar = _t isNotEqualTo [0, 0, 0];
private _egoz = AGLToASL (_t vectorAdd [0, 0, 1.6]);
private _zM = getTerrainHeightASL _c;

// egim + olu arazi + hakim nokta: 16 ornek (iki halka)
private _egimler = [];
private _gizli = 0;
private _topOrnek = 0;
private _hakim = [];
private _hakimS = 2.5;
{
    private _rr = _x;
    {
        private _p = _c getPos [_rr, _x];
        if (surfaceIsWater _p) then { continue };
        _topOrnek = _topOrnek + 1;
        private _hFark = (getTerrainHeightASL _p) - _zM;
        _egimler pushBack ((abs _hFark) / ((_rr max 1)) * 16);
        if (_tehditVar) then {
            private _pYat = AGLToASL (_p vectorAdd [0, 0, 0.4]);
            private _gizliMi = (terrainIntersectASL [_egoz, _pYat]) || {lineIntersects [_egoz, _pYat, objNull, objNull]};
            if (_gizliMi) then { _gizli = _gizli + 1; } else {
                // hakim aday: yuksek + tehdidi gorebilir + ufukta degil + bina yok
                if (_hFark >= _hakimS && {(nearestTerrainObjects [_p, ["BUILDING", "HOUSE"], 6, false, true]) isEqualTo []}) then {
                    private _dd = vectorNormalized (_pYat vectorDiff _egoz);
                    private _s3 = _pYat vectorAdd (_dd vectorMultiply 300);
                    if (terrainIntersectASL [_pYat, _s3] || {lineIntersects [_pYat, _s3, objNull, objNull]}) then {
                        _hakim = [_p, _hFark];
                        _hakimS = _hFark;
                    };
                };
            };
        };
    } forEach [0, 45, 90, 135, 180, 225, 270, 315];
} forEach [(_r * 0.5), _r];

private _egimOrt = if (_egimler isEqualTo []) then {0} else {(_egimler call BIS_fnc_arithmeticMean)};
private _egimMax = if (_egimler isEqualTo []) then {0} else {selectMax _egimler};

// aciklik: agac + cali + bina yogunlugu (yaricap icinde)
private _nesneler = count (nearestTerrainObjects [_c, ["TREE", "SMALL TREE", "BUSH", "BUILDING", "HOUSE", "ROCK", "WALL"], _r, false, true]);
private _yogunluk = _nesneler / ((_r * _r * pi) / 10000);   // 1 hektar basina
private _aciklik = "KARISIK";
if (_yogunluk >= 90) then { _aciklik = "KAPALI"; };
if (_yogunluk < 30) then { _aciklik = "ACIK"; };

// merkez ufuk cizgisinde mi
private _ufuk = false;
if (_tehditVar) then {
    private _cYat = AGLToASL (_c vectorAdd [0, 0, 1.0]);
    private _d2 = vectorNormalized (_cYat vectorDiff _egoz);
    private _s2 = _cYat vectorAdd (_d2 vectorMultiply 300);
    _ufuk = !(terrainIntersectASL [_cYat, _s2]) && {!(lineIntersects [_cYat, _s2, objNull, objNull])};
};

_prof set ["egim", [_egimOrt, _egimMax]];
_prof set ["aciklik", _aciklik];
_prof set ["olu", [0, _gizli / (_topOrnek max 1)] select _tehditVar];
_prof set ["hakim", _hakim];
_prof set ["ufukRisk", _ufuk];

_onb set [_anahtar, [time, _prof]];
if ((count _onb) > 60) then { _onb = createHashMap; _onb set [_anahtar, [time, _prof]]; };
missionNamespace setVariable ["lambs_danger_araziOnb", _onb];

if (isNil "lambs_danger_araziLogN") then { lambs_danger_araziLogN = 0; };
if (lambs_danger_araziLogN < 30) then {
    lambs_danger_araziLogN = lambs_danger_araziLogN + 1;
    diag_log format [
        "[ARAZI] merkez:%1 | r:%2 | egim:%3/%4 | aciklik:%5 (%6/ha) | olu:%7%% | hakim:%8 | ufukRisk:%9 | sure:%10 ms",
        [round (_c select 0), round (_c select 1)], _r, _egimOrt toFixed 1, _egimMax toFixed 1, _aciklik, round _yogunluk,
        round ((_prof get "olu") * 100), if (_hakim isEqualTo []) then {"yok"} else {format ["+%1 m", (_hakim select 1) toFixed 1]}, _ufuk,
        round ((diag_tickTime - _t0) * 1000)
    ];
};

_prof
