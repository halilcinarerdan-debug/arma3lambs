#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * KUMANDA MODULU: KANAT MANEVRASI (ates ustunlugu + kusatma; iki grup koordinasyonu).
 *
 * Doktrin (ozet duzeyinde genel ilke; orijinal kaynak okunmadi): bir grup dusmani ATESLE SABITLER (support by fire / fix), ikinci unsur KANATTAN manevra edip hucum eder (flank / envelopment);
 * iki kanattan gelinirse cift kusatma. Sabitleyen grup dusmani basindirir, manevra unsuru dusmanin ates hattinin DIKINDEN yaklasir.
 * Takviye modulunden farki: takviye grup ZOR DURUMDAYKEN yardim gonderir; kanat manevrasi grup SABIT temastayken (zayif degil) ikinci grubu dusmanin yanina yollar.
 *
 * ISTEK SAHIBI (sabitleyen): temasta >= 20 sn, commanderAssess durumu taze, guc orani <= 1.15, kayip < %40, >= 3 kisi, en yakin dusman 60-450 m,
 *   retreat / kacis / son direnis YOK, son 150 sn'de kanat emri almamis, taraf basina en cok 2 es zamanli manevra.
 * MANEVRA UNSURU: tahta 'musait' grup, >= 4 kisi, 80 - hqKanatM (900) m. Skor = -mesafe + 10 * kisi.  >= 3 musait ve dusman >= 4 kisi ise IKI grup (karsit kanatlar: cift kusatma).
 * KANAT NOKTASI: dusmandan 140 m, sabitleyen -> dusman ekseninin +-85 derecesi (musait grubun yakin oldugu kanat; su ise +-70); sabitleyenin ates hattina DIK.
 * VARIS: kanat noktasina < 60 m ya da 150 sn -> SALDIRI emri (tacticsAssault, hedef: sabitleyenin bildigi dusman noktasi).
 * Log: [HQ-KANAT] EMIR / SALDIRI (ilk 150 satir). Kapatma: lambs_danger_hqKanatV1 = false; doktrin anahtari hqKanat (varsayilan true), hqKanatM (900).
 *
 * Arguments:
 * 0: Taraf <SIDE>
 * 1: Durum tahtasi <ARRAY of HASHMAP>
 *
 * Return Value: Yeni emir verildi mi <BOOL>
 * Public: No
*/

params [["_taraf", sideUnknown, [sideUnknown]], ["_tahta", [], [[]]]];

if (isNil "lambs_danger_hqKanatlar") then { lambs_danger_hqKanatlar = createHashMap; };

// temas suresi izleme
{
    private _g = _x get "g";
    if (_x get "temasta") then {
        if ((_g getVariable ["lambs_danger_hqTemasBas", -1]) < 0) then { _g setVariable ["lambs_danger_hqTemasBas", time]; };
    } else {
        _g setVariable ["lambs_danger_hqTemasBas", -1];
    };
} forEach _tahta;

// 1) calisan manevralar: varis -> SALDIRI
private _kaldir = [];
{
    private _k = _x;
    private _m = _y;
    _m params ["_yG", "_iG", "_hedef", "_enP", "_t0", "_durum"];
    if (isNull _yG || {!alive (leader _yG)}) then { _kaldir pushBack _k; continue };
    if (_durum isEqualTo "YOLDA") then {
        if (((leader _yG) distance2D _hedef) < 60 || {(time - _t0) > 150}) then {
            // sabitleyenin guncel dusman noktasi
            private _sit = _iG getVariable ["lambs_danger_cmdSit", []];
            private _hp = if (_sit isEqualType [] && {(count _sit) >= 8} && {(_sit select 7) isEqualType []} && {(_sit select 7) isNotEqualTo [0, 0, 0]}) then {_sit select 7} else {_enP};
            [_yG, "SALDIRI", [_hp]] call FUNC(hqEmir);
            _m set [5, "SALDIRI"];
            _m set [4, time];
            diag_log format ["[HQ-KANAT] %1 | SALDIRI %2 (kanat noktasi %3 m'de) -> hedef %4", _taraf, groupId _yG, round ((leader _yG) distance2D _hedef), mapGridPosition _hp];
        };
    } else {
        if ((time - _t0) > 120) then { _kaldir pushBack _k; };
    };
} forEach lambs_danger_hqKanatlar;
{ lambs_danger_hqKanatlar deleteAt _x; } forEach _kaldir;

// 2) yeni manevra
private _calisan = {!isNull (_x select 0)} count (values lambs_danger_hqKanatlar);
if (_calisan >= 2) exitWith {false};

private _musaitlar = _tahta select {(_x get "musait") && {(_x get "n") >= 4}};
if (_musaitlar isEqualTo []) exitWith {false};

private _istekler = _tahta select {
    private _g = _x get "g";
    private _sit = _x get "sit";
    (_x get "temasta")
    && {(time - (_g getVariable ["lambs_danger_hqTemasBas", time])) >= 20}
    && {(_x get "n") >= 3}
    && {(_x get "kayip") < 0.4}
    && {(time - (_g getVariable ["lambs_danger_hqKanatT", -999])) > 150}
    && {[_g, "hqKanat", true] call FUNC(dk)}
    && {!(_g getVariable ["lambs_danger_isRetreating", false])} && {!(_g getVariable ["lambs_danger_isBreakingContact", false])} && {!(_g getVariable ["lambs_danger_isSonDirenis", false])}
    && {
        (_sit isEqualType []) && {(count _sit) >= 8} && {(time - (_sit select 0)) < 30}
        && {(_sit select 5) <= 1.15} && {(_sit select 1) >= 60} && {(_sit select 1) <= 450} && {(_sit select 2) >= 1}
        && {(_sit select 7) isEqualType []} && {(_sit select 7) isNotEqualTo [0, 0, 0]}
    }
};
if (_istekler isEqualTo []) exitWith {false};

// en uzun suredir sabit temasta olan once
private _siraliIstek = [_istekler, [], { time - ((_x get "g") getVariable ["lambs_danger_hqTemasBas", time]) }, "DESCEND"] call BIS_fnc_sortBy;
private _istek = _siraliIstek select 0;
private _iG = _istek get "g";
private _iPoz = _istek get "poz";
private _sit = _istek get "sit";
private _enP = +(_sit select 7);
private _enN = _sit select 2;
private _menzil = [_iG, "hqKanatM", 900] call FUNC(dk);

private _adaylar = _musaitlar select {
    private _d = (_x get "poz") distance2D _iPoz;
    (_x get "g") isNotEqualTo _iG && {_d >= 80} && {_d <= _menzil}
};
if (_adaylar isEqualTo []) exitWith {false};
private _sirali = [_adaylar, [], { -((_x get "poz") distance2D _iPoz) + (10 * (_x get "n")) }, "DESCEND"] call BIS_fnc_sortBy;

private _kac = [1, 2] select ((count _adaylar) >= 2 && {_enN >= 4} && {(count _tahta) >= 3});
private _B = _enP getDir _iPoz;
private _kullanilanYan = [];   // 1 = +85, -1 = -85
private _verilen = 0;

{
    private _y = _x;
    private _yG = _y get "g";
    private _yPoz = _y get "poz";
    private _cP = _enP getPos [140, _B + 85];
    private _cN = _enP getPos [140, _B - 85];
    // yakin kanat; 2. grup icin karsit kanat
    private _yan = [-1, 1] select ((_yPoz distance2D _cP) < (_yPoz distance2D _cN));
    if (_yan in _kullanilanYan) then { _yan = -_yan; };
    private _hedef = [_cN, _cP] select (_yan > 0);
    if (surfaceIsWater _hedef) then {
        _hedef = _enP getPos [140, _B + (70 * _yan)];
    };
    if (surfaceIsWater _hedef) then { continue };
    _kullanilanYan pushBack _yan;

    if ([_yG, "KANAT", [_hedef, groupId _iG]] call FUNC(hqEmir)) then {
        lambs_danger_hqKanatlar set [groupId _yG, [_yG, _iG, _hedef, _enP, time, "YOLDA"]];
        _verilen = _verilen + 1;
        if (isNil "lambs_danger_hqKanatN") then { lambs_danger_hqKanatN = 0; };
        if (lambs_danger_hqKanatN < 150) then {
            lambs_danger_hqKanatN = lambs_danger_hqKanatN + 1;
            diag_log format [
                "[HQ-KANAT] %1 | EMIR: sabitleyen %2 (%3 kisi, oran %4, dusman %5 kisi / %6 m) | manevra %7 (%8 kisi, %9 m) -> kanat %10 (eksene %11 derece) | %12",
                _taraf, groupId _iG, _istek get "n", (_sit select 5) toFixed 2, _enN, round (_sit select 1),
                groupId _yG, _y get "n", round (_yPoz distance2D _iPoz), mapGridPosition _hedef, ["+85", "-85"] select (_yan < 0), ["tek kanat", "cift kusatma"] select (_kac > 1)
            ];
        };
    };
} forEach (_sirali select [0, _kac]);

if (_verilen > 0) then {
    _iG setVariable ["lambs_danger_hqKanatT", time];
    [_iG, "KANAT_EMRI", _verilen] call FUNC(olayGonder);
};
_verilen > 0
