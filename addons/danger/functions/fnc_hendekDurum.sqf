#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * HENDEK DURUMU TANISI (v8.255) — kullanici: "hendege girmiyor, bazilari giriyor bazilari yaninda bekliyor". fnc_hendekYerles askerlere atadigi noktayi (hendekNokta = [nokta, alanIdx]) yazar ve 30 / 90 sn sonra bunu cagirir.
 * Davranis degistirmez. Her alan icin tek satir [HENDEK-DURUM]: grup, saniye, alan indeksi + isaret adi, boyut (yari a x b) + yon, kapasite, atanan asker, ICINDE (alan dikdortgenine mesafe <= 1.2 m), YOLDA (hareket ediyor, atanan noktaya > 5 m),
 * DISINDA (durmus ama alan disinda; ad:mesafe m) listesi, komut ve durus dagilimi, alanin 5 m cevresindeki nesne turleri (ilk cagri; Trencher / hendek nesnesi var mi?).
 * Kapatma: lambs_danger_taniOff = true.  Okuma: python tools/rpt_ozet.py --tani
 *
 * Arguments:
 * 0: Grup <GROUP>
 * 1: Hendek yerlesiminden bu yana gecen saniye (yalniz etiket) <NUMBER>
 *
 * Return Value: Yazilan satir sayisi <NUMBER>
 * Public: No
*/

params [["_g", grpNull, [grpNull]], ["_sn", 30, [0]]];
if (isNull _g || {missionNamespace getVariable ["lambs_danger_taniOff", false]}) exitWith {0};
private _us = (units _g) select {alive _x && {isNull objectParent _x} && {!isNil {_x getVariable QGVAR(hendekNokta)}}};
if (_us isEqualTo []) exitWith {0};
private _liste = ["LISTE"] call FUNC(hendekAlani);
if (isNil "lambs_danger_taniHendekNesne") then { lambs_danger_taniHendekNesne = createHashMap; };

private _alanlar = createHashMap;
{
    private _u = _x;
    (_u getVariable QGVAR(hendekNokta)) params ["_pt", "_aIdx"];
    private _d = ["ICERDE", _aIdx, 0, sideUnknown, getPosATL _u] call FUNC(hendekAlani);
    private _hareket = (speed _u) > 1.5 || {(currentCommand _u) isEqualTo "MOVE" && {(_u distance2D _pt) > 5}};
    private _kayit = _alanlar getOrDefault [_aIdx, [0, 0, 0, [], createHashMap, createHashMap]];
    _kayit set [0, (_kayit select 0) + 1];
    if (_d >= 0 && {_d <= 1.2}) then {
        _kayit set [1, (_kayit select 1) + 1];
    } else {
        if (_hareket) then {
            _kayit set [2, (_kayit select 2) + 1];
        } else {
            (_kayit select 3) pushBack format ["%1:%2m", name _u, round _d];
        };
    };
    private _kmt = currentCommand _u;
    (_kayit select 4) set [_kmt, ((_kayit select 4) getOrDefault [_kmt, 0]) + 1];
    private _dur = unitPos _u;
    (_kayit select 5) set [_dur, ((_kayit select 5) getOrDefault [_dur, 0]) + 1];
    _alanlar set [_aIdx, _kayit];
} forEach _us;

private _satir = 0;
{
    private _aIdx = _x;
    private _k = _alanlar get _aIdx;
    private _al = _liste param [_aIdx, []];
    if (_al isEqualTo []) then { continue };
    _al params ["_c", "_a", "_b", "_dir", "_ad"];
    if ((lambs_danger_taniHendekNesne getOrDefault [_aIdx, []]) isEqualTo []) then {
        private _nes = createHashMap;
        {
            if (!(_x isKindOf "CAManBase") && {!(_x isKindOf "Logic")}) then {
                private _tn = typeOf _x;
                if (_tn isEqualTo "") then { _tn = "(sinifsiz nesne)"; };
                _nes set [_tn, (_nes getOrDefault [_tn, 0]) + 1];
            };
        } forEach (nearestObjects [_c, [], (((_a max _b) + 5) min 60)]);
        private _nl = [];
        { _nl pushBack [_y, _x]; } forEach _nes;
        _nl sort false;
        lambs_danger_taniHendekNesne set [_aIdx, (_nl select [0, 6]) apply { format ["%1 x%2", _x select 1, _x select 0] }];
    };
    private _kmtL = []; { _kmtL pushBack format ["%1:%2", _x, (_k select 4) get _x]; } forEach (keys (_k select 4));
    private _durL = []; { _durL pushBack format ["%1:%2", _x, (_k select 5) get _x]; } forEach (keys (_k select 5));
    diag_log format ["[HENDEK-DURUM] grup=%1 | t=%2sn | alan=%3 (%4) | boyut=%5x%6 yon=%7 | kapasite=%8 | atanan=%9 | icinde=%10 | yolda=%11 | disinda=%12 %13 | komutlar=%14 | duruslar=%15 | nesneler=%16",
        groupId _g, _sn, _aIdx, _ad, round _a, round _b, round _dir, ["KAPASITE", _aIdx] call FUNC(hendekAlani), _k select 0, _k select 1, _k select 2, count (_k select 3), _k select 3, _kmtL, _durL, lambs_danger_taniHendekNesne get _aIdx];
    _satir = _satir + 1;
} forEach (keys _alanlar);
_satir
