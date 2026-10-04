#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * TAKTIK ROTA PLANLAMA v1 (gizli yaklasma) — VBS4 "tactical route planning" fikrinin Arma 3 karsiligi.
 *
 * Arma 3'te navmesh yok: motor yalniz ara nokta verilince kendi yolunu secer. Bu fonksiyon, dusmana yaklasirken
 * dogrudan hat yerine ORTULU (gorus hatti kesilen, agac / cali / duvar / cukur arkasi) yone SAPMA ACISI secer.
 * Bounding atilimlari (_kosanHareket) bu acinin etrafinda yelpaze kurar -> grup "kisa yol" yerine korunakli hatti izler.
 *
 * Yontem: aday sapma acilari [0, +-20, +-40, +-60]. Her aday icin IKI BACAKLI plan (grup -> p1 -> p2, p2 hedefe donuk):
 *   maruziyet = dusman gozunden gorulen ornek orani (6 m'de bir ray)      -> -40 x maruziyet
 *   ortu      = nokta cevresindeki agac / cali / duvar / kaya (en fazla 4)  -> +2 x adet
 *   ilerleme  = hedefe yaklasma orani                                       -> +10 x oran
 *   sapma     = -0.15 x |aci|; bina icine dusme -12; su -500
 * Dogrudan hatta gore kazanc < 8 puansa SAPMA YOK (0 doner: gereksiz dolanma yok).
 * v8.36: ARA NOKTA ZINCIRI — tek aci yerine en fazla 4 bacaklik kalici rota (grup degiskeni lambs_danger_rotaZincir); sonraki zincir noktasina yon doner. Log [ROTA-ZINCIR].
 * Onbellek: 6 sn (zincir 45 sn gecerli); hedef 40 m oynarsa yenilenir. Kapatma: lambs_danger_rotaV1 = false.
 *
 * Arguments:
 * 0: Grup <GROUP>
 * 1: Hedef pozisyon <ARRAY>
 *
 * Return Value:
 * Sapma acisi (derece, +sag / -sol; hedefe dogru hatta gore) <NUMBER>
 *
 * Public: No
*/

params [["_g", grpNull, [grpNull]], ["_hedef", [0, 0, 0], [[]]]];

if (isNull _g || {!(missionNamespace getVariable ["lambs_danger_rotaV1", true])}) exitWith {0};

private _onbellek = _g getVariable [QGVAR(rotaOnbellek), []];
if (_onbellek isNotEqualTo [] && {(time - (_onbellek select 0)) < 6} && {((_onbellek select 1) distance2D _hedef) < 40}) exitWith { _onbellek select 2 };

private _ld = leader _g;
if (isNull _ld || {!alive _ld}) exitWith {0};

private _t0 = diag_tickTime;
private _c = getPosATL _ld;
private _d = _c distance2D _hedef;
// yakin mesafede (CQB / hucum) rota anlamsiz; cok uzakta ise bounding zaten uzun atilim yapar
if (_d < 90 || {_d > 600}) exitWith {
    _g setVariable [QGVAR(rotaOnbellek), [time, +_hedef, 0]];
    0
};

private _bacak = ((_d * 0.35) max 30) min 70;
private _eASL = AGLToASL (_hedef vectorAdd [0, 0, 1.6]);

// v8.60: OLUM BOLGESI GOZLEMCILERI — ayni taraf bu konumlardan (240 sn icinde kayip verilen yerler) vuruldu; bu noktalardan gorulen hatlar da maruziyet sayilir (en fazla 2, hedefe 30 m'den uzak)
private _ekGoz = [];
if (!isNil "lambs_danger_olumBolgeleri") then {
    private _sd = side _g;
    private _adaylarOB = (lambs_danger_olumBolgeleri) select {((_x select 0) isEqualTo _sd) && {(time - (_x select 3)) < 240} && {((_x select 1) distance2D _hedef) > 30} && {((_x select 1) distance2D _c) < 700}};
    _adaylarOB = _adaylarOB apply {[-(_x select 4), ((_x select 1) distance2D _c) + (random 0.01), _x]};
    _adaylarOB sort true;
    _ekGoz = (_adaylarOB select [0, 2]) apply { AGLToASL (((_x select 2) select 1) vectorAdd [0, 0, 1.6]) };
    if (_ekGoz isNotEqualTo []) then { missionNamespace setVariable ["lambs_danger_zekaRotaSay", (missionNamespace getVariable ["lambs_danger_zekaRotaSay", 0]) + 1]; };
};

// bir bacagin maruziyeti: [a -> b] hatti boyunca 6 m'de bir ornek, dusmanin gordugu oran
private _maruz = {
    params ["_a", "_b"];
    private _n = ((floor ((_a distance2D _b) / 6)) max 1);
    private _gorulen = 0;
    for "_k" from 1 to _n do {
        private _p = _a vectorAdd ((_b vectorDiff _a) vectorMultiply (_k / _n));
        private _pASL = AGLToASL (_p vectorAdd [0, 0, 1.2]);
        private _gor = !(terrainIntersectASL [_eASL, _pASL]) && {!(lineIntersects [_eASL, _pASL, objNull, objNull])};
        if (!_gor && {_ekGoz isNotEqualTo []}) then {
            { if (!(terrainIntersectASL [_x, _pASL]) && {!(lineIntersects [_x, _pASL, objNull, objNull])}) exitWith { _gor = true; }; } forEach _ekGoz;
        };
        if (_gor) then { _gorulen = _gorulen + 1; };
    };
    _gorulen / _n
};

private _puanla = {
    params ["_aci", ["_o", _c]];
    private _yon = (_o getDir _hedef) + _aci;
    private _p1 = _o getPos [_bacak, _yon];
    if (surfaceIsWater _p1) exitWith {[-9999, 1, 0, _p1]};
    private _p2 = _p1 getPos [_bacak, _p1 getDir _hedef];
    if (surfaceIsWater _p2) then { _p2 = _p1; };
    private _e1 = [_o, _p1] call _maruz;
    private _e2 = [_p1, _p2] call _maruz;
    private _e = (_e1 + _e2) / 2;
    private _ortu = (count (nearestTerrainObjects [_p1, ["TREE", "BUSH", "SMALL TREE", "HIDE", "WALL", "FENCE", "ROCK"], 8, false, true])) min 4;
    private _bina = (nearestTerrainObjects [_p1, ["BUILDING", "HOUSE"], 6, false, true]) isNotEqualTo [];
    private _ilerleme = ((_o distance2D _hedef) - (_p2 distance2D _hedef)) / (2 * _bacak);
    private _s = (-40 * _e) + (2 * _ortu) + (10 * _ilerleme) - (0.15 * (abs _aci)) - ([0, 12] select _bina);
    [_s, _e, _ortu, _p1]
};

// bir noktadan tek BACAK sec: en iyi aci (dogrudana gore kazanc < 8 ise 0)
private _bacakSec = {
    params ["_o"];
    private _direkt = [0, _o] call _puanla;
    private _en = _direkt;
    private _enAci = 0;
    {
        private _r = [_x, _o] call _puanla;
        if ((_r select 0) > (_en select 0)) then { _en = _r; _enAci = _x; };
    } forEach [20, -20, 40, -40, 60, -60];
    if (((_en select 0) - (_direkt select 0)) < 8) then { _enAci = 0; _en = _direkt; };
    [_enAci, _en, _direkt]
};

// -------------------------------------------------------------------------
// v8.36 ARA NOKTA ZINCIRI (VBS4 'tactical route planning' tamamlanmasi): her 20 sn'de TEK aci yeniden secmek sag / sol salinima yol aciyordu.
//   Zincir: en fazla 4 bacak (kalan mesafe 70 m + bacak'a inene kadar), her bacak oncekinin ucundan secilir; grup degiskeninde SAKLANIR (lambs_danger_rotaZincir = [zaman, hedef, noktalar]).
//   Gecerlilik: < 45 sn, hedef < 40 m oynadi, lider zincirin kalan ilk noktasina < 60 m. Ulasilan nokta (lider < 25 m) zincirden duser. Gecersizse yeniden kurulur.
//   Donus: liderden zincirin sonraki noktasina yon - dogrudan hedefe yon farki (derece, +sag; en fazla +-75).
// -------------------------------------------------------------------------
private _zincir = _g getVariable [QGVAR(rotaZincir), []];
private _gecerli = false;
if (_zincir isNotEqualTo []) then {
    _zincir params ["_zt", "_zh", "_zp"];
    // ulasilan noktalari dus
    while {_zp isNotEqualTo [] && {(_c distance2D (_zp select 0)) < 25}} do { _zp deleteAt 0; };
    // bos zincir (dogrudan hat yeterli) 15 sn gecerli: her cagrida bacak taramasi yapma
    if (_zp isEqualTo [] && {(time - _zt) < 15} && {(_zh distance2D _hedef) < 40}) then { _gecerli = true; };
    if (_zp isNotEqualTo [] && {(time - _zt) < 45} && {(_zh distance2D _hedef) < 40} && {(_c distance2D (_zp select 0)) < 60}) then {
        _gecerli = true;
        _g setVariable [QGVAR(rotaZincir), [_zt, _zh, _zp]];
    };
};

if (!_gecerli) then {
    private _pts = [];
    private _o = +_c;
    private _ilkAci = 0;
    private _ilk = [];
    private _dir = [];
    for "_k" from 0 to 3 do {
        if ((_o distance2D _hedef) < (70 + _bacak) || {(diag_tickTime - _t0) > 0.02}) exitWith {};
        private _r = [_o] call _bacakSec;
        _r params ["_a", "_en", "_di"];
        if (_k == 0) then { _ilkAci = _a; _ilk = _en; _dir = _di; };
        private _nokta = _en select 3;
        if (surfaceIsWater _nokta) exitWith {};
        // sapma yoksa ve ilk bacak ise zincir kurma (dogrudan hat yeterli)
        if (_k == 0 && {_a isEqualTo 0}) exitWith {};
        _pts pushBack _nokta;
        _o = _nokta;
    };
    _g setVariable [QGVAR(rotaZincir), [time, +_hedef, _pts]];
    _zincir = [time, +_hedef, _pts];

    if (isNil "lambs_danger_rotaLogN") then { lambs_danger_rotaLogN = 0; };
    if (lambs_danger_rotaLogN < 80) then {
        lambs_danger_rotaLogN = lambs_danger_rotaLogN + 1;
        diag_log format [
            "[ROTA] %1 | hedef:%2 m | sapma(ilk bacak):%3 | maruziyet direkt:%4%% -> plan:%5%% | ortu:%6 | sure:%7 ms | olum bolgesi gozcusu:%8",
            groupId _g, round _d, _ilkAci,
            round (((_dir param [1, 0])) * 100), round (((_ilk param [1, 0])) * 100), _ilk param [2, 0],
            round ((diag_tickTime - _t0) * 1000), count _ekGoz
        ];
        if (_pts isNotEqualTo []) then {
            diag_log format ["[ROTA-ZINCIR] %1 | %2 bacak (%3 m'lik) | noktalar:%4", groupId _g, count _pts, round _bacak, _pts apply {mapGridPosition _x}];
        };
    };
};

// donus: sonraki zincir noktasina yon farki
private _kalan = (_g getVariable [QGVAR(rotaZincir), [0, [], []]]) select 2;
private _aci = 0;
if (_kalan isNotEqualTo []) then {
    private _sk = _kalan select 0;
    _aci = ((((_c getDir _sk) - (_c getDir _hedef)) + 540) mod 360) - 180;
    _aci = (_aci max -75) min 75;
};

_g setVariable [QGVAR(rotaOnbellek), [time, +_hedef, _aci]];
_g setVariable [QGVAR(rotaAci), _aci];
_aci
