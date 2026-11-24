#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * 3DEN: ELITE EYP Kur (komutla patlayan pusu) modulu (v8.777; kullanici: 'zeus destegi ve editor destegi olsun'; referans: eyp_deme.txt). Modul KONUMU = EYP noktasi; modul YONU (rotasyon oku) = dusmanin EYP'ye GELDIGI yon
 * (gozetleme noktasi bunun tersinde otomatik secilir; mesafe 0 = otomatik). Module SYNC ile BIR asker baglanir = kurucu. Kurucu kurar, cekilir, gozetler, dusman tetik mesafesine girince patlatir (fnc_eypKomut).
 * Init satiri alternatifi: [this, getMarkerPos "eyp_noktasi", getMarkerPos "pusu_noktasi"] spawn lambs_danger_fnc_eypKomut;
 * Arguments: 0: modul <OBJECT>, 1: baglananlar (kullanilmaz), 2: etkin <BOOL>
 * Return Value: None
 * Public: No
*/

params ["_logic", "", "_activated"];
if (!_activated || {!isServer}) exitWith {};

[_logic] spawn {
    params ["_logic"];
    if !(["BEKLE"] call FUNC(edenOrtak)) exitWith { diag_log "[EDEN] EYP kur: ELITE hazir olmadi (180 sn)" };
    waitUntil { sleep 0.5; !isNil "lambs_danger_eypSistemStarted" || {time > 120} };
    sleep 2;
    private _bagli = ["BAGLI", [_logic]] call FUNC(edenOrtak);
    private _kur = _bagli select {_x isKindOf "CAManBase" && {alive _x} && {!isPlayer _x}};
    if (_kur isEqualTo []) exitWith { diag_log format ["[EDEN] EYP kur (3DEN) %1: module bagli kurucu asker yok", mapGridPosition _logic] };
    private _u = _kur select 0;
    private _poz = getPosATL _logic;
    private _hideM = round (["SAYI", [_logic, "lambs_danger_edEypHideM", 0]] call FUNC(edenOrtak));
    private _tetik = round (["SAYI", [_logic, "lambs_danger_edEypTetikM", 12]] call FUNC(edenOrtak));
    private _guc = ((round (["SAYI", [_logic, "lambs_danger_edEypGuc", 0]] call FUNC(edenOrtak))) max 0) min 3;
    private _yon = getDir _logic;
    private _ep = _poz getPos [100, _yon];
    private _hide = [];
    if (_hideM > 0) then { _hide = _poz getPos [_hideM, _yon + 180]; };
    ["lambs_danger_eypKomutIstegi", [netId _u, _poz, _hide, _ep, _tetik, _guc - 1]] call CBA_fnc_serverEvent;
    diag_log format ["[EDEN] EYP kur (3DEN) | kurucu %1 | EYP %2 | yon %3 | gozetleme %4 | tetik %5 m | guc %6", name _u, _poz select [0, 2] apply { round _x }, round _yon, [str _hideM + " m", "otomatik"] select (_hideM <= 0), _tetik, _guc - 1];
};
