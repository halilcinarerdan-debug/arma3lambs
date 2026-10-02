#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * KUMANDA MODULU: FEINT (sinirli hedefli yanilticisi saldiri; kanat manevrasinin ANA CABASINI destekler).
 *
 * DOKTRIN (MCWP 3-11.1 Infantry Company Operations, 2014, s. 6-10 / 6-11; kaynaklar_doktrin/):
 *   'Feints are limited scope attacks with an extremely specific objective intended to cause the enemy to either react in a particular way or delay or disrupt reaction,
 *    such as by repositioning forces, committing reserves, or shifting fires.'  Planlama: kuvveti koruma niyeti, DISENGAGEMENT KRITERLERI ve plani, sinirli derinlik / ulasilabilir hedef,
 *   ana saldiriyi sonradan degerlendirme icin net emirler.  'Feints are successful only if the enemy believes that a full-scale attack is underway; therefore, it is essential that the feints occur
 *   with the same level of precision and violence as any attack.'  Ust komutanlik gorev ve amaci (hangi dusman tepkisi) verir.  'An infantry company is unlikely to conduct a feint internal to its own operations.'
 *   -> Bu modul KUMANDA (ust komutanlik) kararidir; tek bir grubun kendi basina 'fake' yapmasi YOK; 'gerileme taklidi / tuzak' kaynakta YOK ve yapilmaz.
 *   DEMONSTRATION (temassiz gosteri) BILEREK YOK: Arma AI gordugu her seye ates eder, 'temas kurmayan' gosteri guvenilir degil.
 *
 * ARMA 3 UYARLAMASI: aktif KANAT manevrasi (fnc_hqKanat) varken (ana cabasi: kanattan hucum), ucuncu bir MUSAIT grup (>= 4 kisi, 80 - hqKanatM) dusmana ON'den yaklasir:
 *   FEINT NOKTASI: dusmanin 150 m'si (TASARIM), sabitleyen -> dusman ekseninden +-20 derece (yakin taraf). Amac: dusmanin dikkatini / atesini onde tutmak (reposition / shift fires), kanat grubu arkadan vurur.
 *   DISENGAGEMENT KRITERLERI (TASARIM sayilar): kayip >= %25 ya da 100 sn doldu ya da kanat SALDIRI emri verildi ya da bastirma >= 0.7 -> 'FEINT_BIRAK': grup kendi retreat'i ile ayrilir (kayip / bastirmada) ya da LAMBS'a birakilir (saldiri / sure).
 *   Es zamanli en cok 1 feint; ayni sabitleyen icin 240 sn'de bir; yalnizca dusman >= 3 kisi (sit) ve sabitleyen oran <= 1.15.
 * Log: [HQ-FEINT] EMIR / BIRAK. Kapatma: lambs_danger_hqFeintV1 = false; doktrin anahtari hqFeint (varsayilan true).
 *
 * Arguments:
 * 0: Taraf <SIDE>
 * 1: Durum tahtasi <ARRAY of HASHMAP>
 *
 * Return Value: Yeni emir verildi mi <BOOL>
 * Public: No
*/

params [["_taraf", sideUnknown, [sideUnknown]], ["_tahta", [], [[]]]];

if (isNil "lambs_danger_hqFeintler") then { lambs_danger_hqFeintler = createHashMap; };

// 1) calisan feint'ler: ayrilma kriterleri
private _kaldir = [];
{
    private _k = _x;
    _y params ["_fG", "_iG", "_enP", "_t0", "_n0"];
    if (isNull _fG || {!alive (leader _fG)}) then { _kaldir pushBack _k; continue };
    private _n = {alive _x} count (units _fG);
    private _kayip = if (_n0 > 0) then {(_n0 - _n) / _n0} else {0};
    private _bask = 0;
    { _bask = _bask max (getSuppression _x); } forEach ((units _fG) select {alive _x});
    private _anaSaldiri = false;
    { if ((_y select 5) isEqualTo "SALDIRI" && {(_y select 1) isEqualTo _iG}) exitWith { _anaSaldiri = true; }; } forEach (missionNamespace getVariable ["lambs_danger_hqKanatlar", createHashMap]);

    private _neden = "";
    if (_kayip >= 0.25) then { _neden = format ["kayip %1%%", round (_kayip * 100)]; };
    if (_neden isEqualTo "" && {_bask >= 0.7}) then { _neden = format ["bastirma %1", _bask toFixed 2]; };
    if (_neden isEqualTo "" && {(time - _t0) > 100}) then { _neden = "sure doldu (100 sn)"; };
    if (_neden isEqualTo "" && {_anaSaldiri}) then { _neden = "ana saldiri basladi"; };
    if (_neden isNotEqualTo "") then {
        diag_log format ["[HQ-FEINT] %1 | BIRAK %2 | neden:%3 | kayip:%4%% sure:%5 sn", _taraf, groupId _fG, _neden, round (_kayip * 100), round (time - _t0)];
        // ayrilma: kayip / bastirmada kontrollu cekilme, aksi LAMBS'a birak (ana saldiriya yardim: normal taktik)
        if (_kayip >= 0.25 || {_bask >= 0.7}) then {
            if (!isNil "lambs_danger_fnc_tacticsRetreat") then { [_fG, _enP] call FUNC(tacticsRetreat); };
        };
        [_fG, "FEINT_BIRAK", _neden] call FUNC(hqEmir);
        _kaldir pushBack _k;
    };
} forEach lambs_danger_hqFeintler;
{ lambs_danger_hqFeintler deleteAt _x; } forEach _kaldir;

// 2) yeni feint: aktif kanat manevrasi + 3. musait grup
if ((count lambs_danger_hqFeintler) >= 1) exitWith {false};
private _kanatlar = missionNamespace getVariable ["lambs_danger_hqKanatlar", createHashMap];
if ((count _kanatlar) isEqualTo 0) exitWith {false};

private _hedefIstek = grpNull;
private _kanatM = [];
{
    if ((_y select 5) isEqualTo "YOLDA" && {!isNull (_y select 1)} && {(time - ((_y select 1) getVariable ["lambs_danger_hqFeintT", -999])) > 240}) exitWith { _hedefIstek = _y select 1; _kanatM = _y; };
} forEach _kanatlar;
if (isNull _hedefIstek) exitWith {false};
if (!([_hedefIstek, "hqFeint", true] call FUNC(dk))) exitWith {false};

private _giris = _tahta select {(_x get "g") isEqualTo _hedefIstek};
if (_giris isEqualTo []) exitWith {false};
private _sit = (_giris select 0) get "sit";
if (!(_sit isEqualType []) || {(count _sit) < 8} || {(_sit select 2) < 3} || {(_sit select 5) > 1.15} || {!((_sit select 7) isEqualType [])} || {(_sit select 7) isEqualTo [0, 0, 0]}) exitWith {false};

private _enP = +(_sit select 7);
private _iPoz = (_giris select 0) get "poz";
private _menzil = [_hedefIstek, "hqKanatM", 900] call FUNC(dk);

private _adaylar = (_tahta select {(_x get "musait") && {(_x get "n") >= 4}}) select {
    private _d = (_x get "poz") distance2D _iPoz;
    (_x get "g") isNotEqualTo _hedefIstek && {_d >= 80} && {_d <= _menzil}
};
if (_adaylar isEqualTo []) exitWith {false};
private _f = ([_adaylar, [], { -((_x get "poz") distance2D _iPoz) + (10 * (_x get "n")) }, "DESCEND"] call BIS_fnc_sortBy) select 0;
private _fG = _f get "g";

// feint noktasi: dusmanin 150 m'si, sabitleyen ekseninden +-20 derece (musait grubun yakin tarafi)
private _B = _enP getDir _iPoz;
private _c1 = _enP getPos [150, _B + 20];
private _c2 = _enP getPos [150, _B - 20];
private _hedef = [_c2, _c1] select (((_f get "poz") distance2D _c1) < ((_f get "poz") distance2D _c2));
if (surfaceIsWater _hedef) exitWith {false};

if ([_fG, "FEINT", [_hedef, groupId _hedefIstek]] call FUNC(hqEmir)) then {
    lambs_danger_hqFeintler set [groupId _fG, [_fG, _hedefIstek, _enP, time, _f get "n"]];
    _hedefIstek setVariable ["lambs_danger_hqFeintT", time];
    diag_log format [
        "[HQ-FEINT] %1 | EMIR: ana cabasi = kanat manevrasi (%2 grup sabitleyen %3) | feint %4 (%5 kisi, %6 m) -> on cephe %7 | ayrilma: kayip >= %%25 / bastirma >= 0.7 / 100 sn / ana saldiri",
        _taraf, count _kanatlar, groupId _hedefIstek, groupId _fG, _f get "n", round ((_f get "poz") distance2D _iPoz), mapGridPosition _hedef
    ];
    true
} else { false }
